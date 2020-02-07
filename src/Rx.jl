# --- Working structures 
mutable struct uhd_usrp
end
mutable struct uhd_rx_streamer
end
mutable struct uhd_rx_metadata
end

struct Buffer 
	x::Array{Cfloat};
	md::Ref{Ptr{uhd_rx_metadata}};
	ptr::Ref{Ptr{Cvoid}};
	pointerSamples::Ref{Csize_t};
end


#
#
#Base.unsafe_convert(T::Type{Ptr{Ptr{Cvoid}}}, t::Base.RefValue{Array{Float32,1}}) = t;
#Base.unsafe_convert(::Type{Ptr{Ptr{Cvoid}}}, obj::Base.RefValue{Array{Float32,1}}) = Base.cconvert(Ptr{Ptr{Cvoid}},pointer_from_objref(obj));


# Direclry inherited from C file tune_request.h
@enum uhd_tune_request_policy_t begin 
	UHD_TUNE_REQUEST_POLICY_NONE=78;
	UHD_TUNE_REQUEST_POLICY_AUTO=65;
	UHD_TUNE_REQUEST_POLICY_MANUAL=77
end
# Directly inherited from C file usrp.h
@enum uhd_stream_mode_t  begin 
	UHD_STREAM_MODE_START_CONTINUOUS   = 97;
	UHD_STREAM_MODE_STOP_CONTINUOUS    = 111;
	UHD_STREAM_MODE_NUM_SAMPS_AND_DONE = 100;
	UHD_STREAM_MODE_NUM_SAMPS_AND_MORE = 109
end

# --- Runtime structure 
# These structures are necessary to tun the Rx wrapper 
struct uhd_stream_args_t 
	cpu_format::Cstring
	otw_format::Cstring;
	args::Cstring;
	channel_list::Ref{Csize_t};
	n_channels::Cint;
end
struct uhd_tune_request_t 
	target_freq::Cdouble;
	rf_freq_policy::uhd_tune_request_policy_t;
	dsp_freq_policy::uhd_tune_request_policy_t;
end
struct uhd_tune_result 
	clipped_rf_freq::Cdouble;
	target_rf_freq::Cdouble;
	actual_rf_freq::Cdouble;
	target_dsp_freq::Cdouble;
	actual_dsp_freq::Cdouble;
end
struct stream_cmd
	stream_mode::uhd_stream_mode_t;
	num_samps::Csize_t;
	stream_now::Cint;
	time_spec_full_secs::Cintmax_t;
	time_spec_frac_secs::Cdouble;
end


# --- Rx structures 
mutable struct UhdRxWrapper 
	pointerUSRP::Ptr{uhd_usrp};
	pointerStreamer::Ptr{uhd_rx_streamer};
	pointerMD::Ptr{uhd_rx_metadata};
	addressUSRP::Any;
	addressStream::Any;
	addressMD::Any;
end 
mutable struct UHDRx 
	uhd::UhdRxWrapper;
	carrierFreq::Float64;
	samplingRate::Float64;
	rxGain::Union{Int,Float64}; 
	antenna::String;
	packetSize::Csize_t;
	released::Int;
	uhdArgs::uhd_stream_args_t;
	tuneRequest::uhd_tune_request_t;
	pointerTuneResult::Ref{uhd_tune_result};
	pointerCmd::Ref{stream_cmd};
end


""" 
--- 
Initiate all structures to instantiaet and pilot a USRP device.
--- Syntax 
uhd	  = initRxUHD(sysImage)
# --- Input parameters 
- sysImage	  : String with the additionnal load parameters (for instance, path to the FPHGA image) [String]
# --- Output parameters 
- uhd		  = UHD Rx object [UhdRxWrapper] 
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function initRxUHD(sysImage)
	# ---------------------------------------------------- 
	# --- Handler  
	# ---------------------------------------------------- 
	# --- Create a pointer related to the incoming USRP 
	usrpPointer = Array{Ptr{uhd_usrp},1}(undef,1); 
	# --- Cal the init
	ccall((:uhd_usrp_make, libUHD), Cvoid, (Ptr{Ptr{uhd_usrp}}, Cstring),usrpPointer,sysImage);
	# --- Recover the USRP
	usrp	  = usrpPointer[1];
	# ---------------------------------------------------- 
	# --- Rx Streamer  
	# ---------------------------------------------------- 
	# --- Create a pointer related to the Rx streamer
	streamerPointer = Array{Ptr{uhd_rx_streamer},1}(undef,1); 
	# --- Cal the init
	ccall((:uhd_rx_streamer_make, libUHD), Cvoid, (Ptr{Ptr{uhd_rx_streamer}},),streamerPointer);
	# --- Recover the streamer
	streamer  = streamerPointer[1];
	# ---------------------------------------------------- 
	# --- Rx Metadata  
	# ---------------------------------------------------- 
	# --- Create a pointer related to Metadata 
	metadataPointer = Array{Ptr{uhd_rx_metadata},1}(undef,1); 
	# --- Cal the init
	ccall((:uhd_rx_metadata_make, libUHD), Cvoid, (Ptr{Ptr{uhd_rx_metadata}},),metadataPointer);
	# --- Recover Metadata
	metadata = metadataPointer[1];
	# ---------------------------------------------------- 
	# --- Create the USRP wrapper object  
	# ---------------------------------------------------- 
	uhd  = UhdRxWrapper(usrp,streamer,metadata,usrpPointer,streamerPointer,metadataPointer);
	@info("Done init \n");
	return uhd;
end


""" 
--- 
Init the core parameter of the radio and intiate RF parameters 
--- Syntax 
setRxRadio(uhd,carrierFreq,samplingRate,rxGain,antenna="TX/RX")
# --- Input parameters 
- uhd	  : UHD object set from initRxUHD [UhdRxWrapper] 
- carrierFreq	: Desired Carrier frequency [Union{Int,Float64}] 
- samplingRate	: Desired bandwidth [Union{Int,Float64}] 
- rxGain		: Desired Rx Gain [Union{Int,Float64}] 
- antenna		: Desired Antenna alias [String] (default "TX/RX");
# --- Output parameters 
- UHDRx		  	: UHD Rx object with PHY parameters [UHDRx]  
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function setRxRadio(uhd,carrierFreq,samplingRate,rxGain,antenna="TX/RX")
	# ---------------------------------------------------- 
	# --- Creating Runtime structures  
	# ---------------------------------------------------- 
	# --- Create structure for request 
	tuneRequest	   = uhd_tune_request_t(carrierFreq,UHD_TUNE_REQUEST_POLICY_AUTO,UHD_TUNE_REQUEST_POLICY_AUTO);
	# --- Create structure for UHD argument 
	# TODO Adding custom levels here for user API
	channel		   =  Ref{Csize_t}(0);
	a1			   =  Base.unsafe_convert(Cstring,"fc32");
	a2			   =  Base.unsafe_convert(Cstring,"sc16");
	a3			   =  Base.unsafe_convert(Cstring,"");
	uhdArgs		   = uhd_stream_args_t(a1,a2,a3,channel,1);
	# ---------------------------------------------------- 
	# --- Sampling rate configuration  
	# ---------------------------------------------------- 
	# --- Update the Rx sampling rate 
	ccall((:uhd_usrp_set_rx_rate, libUHD), Cvoid, (Ptr{uhd_usrp}, Cdouble, Csize_t),uhd.pointerUSRP,samplingRate,0);
	# --- Get the Rx rate from the radio 
	pointerRate  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_rate, libUHD), Cvoid, (Ptr{uhd_usrp}, Csize_t, Ref{Cdouble}),uhd.pointerUSRP,0,pointerRate);
	updateRate  = pointerRate[];	
	# --- Print a flag 
	if updateRate != samplingRate 
		@warn "Effective Rate is $(updateRate/1e6) MHz and not $(samplingRate/1e6) MHz\n" 
	else 
		@info "Effective Rate is $(updateRate/1e6) MHz\n";
	end
	# ---------------------------------------------------- 
	# --- Carrier Frequency configuration  
	# ---------------------------------------------------- 
	tunePointer	  = Ref{uhd_tune_request_t}(tuneRequest);	
	pointerTuneResult	  = Ref{uhd_tune_result}();	
	ccall((:uhd_usrp_set_rx_freq, libUHD), Cvoid, (Ptr{uhd_usrp}, Ptr{uhd_tune_request_t}, Csize_t, Ptr{uhd_tune_result}),uhd.pointerUSRP,tunePointer,0,pointerTuneResult);
	pointerCarrierFreq = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_freq, libUHD), Cvoid, (Ptr{uhd_usrp}, Csize_t, Ref{Cdouble}),uhd.pointerUSRP,0,pointerCarrierFreq); 
	updateCarrierFreq	= pointerCarrierFreq[];
	if updateCarrierFreq != carrierFreq 
		@warn "Effective carrier frequency is $(updateCarrierFreq/1e6) MHz and not $(carrierFreq/1e6) Hz\n" 
	else 
		@info "Effective carrier frequency is $(updateCarrierFreq/1e6) MHz\n";
	end	
	# ---------------------------------------------------- 
	# --- Gain configuration  
	# ---------------------------------------------------- 
	# Update the UHD sampling rate 
	ccall((:uhd_usrp_set_rx_gain, libUHD), Cvoid, (Ptr{uhd_usrp}, Cdouble, Csize_t, Cstring),uhd.pointerUSRP,rxGain,0,"");
	# Get the updated gain from UHD 
	pointerGain	  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_gain, libUHD), Cvoid, (Ptr{uhd_usrp}, Csize_t, Cstring,Ref{Cdouble}),uhd.pointerUSRP,0,"",pointerGain);
	updateGain	  = pointerGain[]; 
	# --- Print a flag 
	if updateGain != rxGain 
		@warn "Effective gain is $(updateGain) dB and not $(rxGain) dB\n" 
	else 
		@info "Effective gain is $(updateGain) dB\n";
	end 
	# ---------------------------------------------------- 
	# --- Antenna configuration 
	# ---------------------------------------------------- 
	ccall((:uhd_usrp_set_rx_antenna, libUHD), Cvoid, (Ptr{uhd_usrp}, Cstring, Csize_t),uhd.pointerUSRP,antenna,0);
	# ---------------------------------------------------- 
	# --- Setting up streamer  
	# ---------------------------------------------------- 
	# --- Setting up arguments 
	pointerArgs	  = Ref{uhd_stream_args_t}(uhdArgs);
	ccall((:uhd_usrp_get_rx_stream, libUHD), Cvoid, (Ptr{uhd_usrp},Ptr{uhd_stream_args_t},Ptr{uhd_rx_streamer}),uhd.pointerUSRP,pointerArgs,uhd.pointerStreamer);
	# --- Getting number of samples ber buffer 
	pointerSamples	  = Ref{Csize_t}(0);
	ccall((:uhd_rx_streamer_max_num_samps, libUHD), Cvoid, (Ptr{uhd_stream_args_t},Ref{Csize_t}),uhd.pointerStreamer,pointerSamples);
	nbSamples		  = pointerSamples[];	
	# --- Issue stream command 
	streamCmd	= stream_cmd(UHD_STREAM_MODE_START_CONTINUOUS,nbSamples,true,0,0.0);
	pointerCmd	= Ref{stream_cmd}(streamCmd);
	ccall((:uhd_rx_streamer_issue_stream_cmd, libUHD), Cvoid, (Ptr{uhd_stream_args_t},Ptr{stream_cmd}),uhd.pointerStreamer,pointerCmd);
	# ---------------------------------------------------- 
	# --- Create object and return  
	# ---------------------------------------------------- 
	# --- Return  
	#FIXME free pointerCmd and not store it ?
	#TODO Need to save tuneRequest // pointerTuneResult and uhdArgs
	return UHDRx(uhd,updateCarrierFreq,updateRate,updateGain,antenna,nbSamples,0,uhdArgs,tuneRequest,pointerTuneResult,pointerCmd);
end

""" 
--- 
Close the USRP device (Rx mode) and release all associated objects
# --- Syntax 
#	freeRadio(uhd)
# --- Input parameters 
- uhd	: UHD object [UHDRx]
# --- Output parameters 
- []
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function freeRadio(radio::UHDRx)
	# --- Checking realease nature 
	# There is one flag to avoid double free (that leads to seg fault) 
	if radio.released == 0
		# C Wrapper to ressource release 
		ccall((:uhd_usrp_free, libUHD), Cvoid, (Ptr{Ptr{uhd_usrp}},),radio.uhd.addressUSRP);
		#FIXME Should be Ptr{Ptr} ?
		ccall((:uhd_rx_streamer_free, libUHD), Cvoid, (Ptr{uhd_rx_streamer},),radio.uhd.addressStream);
		ccall((:uhd_usrp_free, libUHD), Cvoid, (Ptr{uhd_rx_metadata},),radio.uhd.addressMD);
		@info "USRP device is now free.";
	else 
		# print a warning  
		@warn "UHD ressource was already released, abort call";
	end 
	# --- Force flag value 
	radio.released = 1;
end

""" 
--- 
Print the radio configuration 
# --- Syntax 
#	printRadio(radio)
# --- Input parameters 
- radio		: UHD object (Tx or Rx)
# --- Output parameters 
- []
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function printRadio(radio::UHDRx)
	# Get the gain from UHD 
	pointerGain	  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_gain, libUHD), Cvoid, (Ptr{Cvoid}, Csize_t, Cstring,Ref{Cdouble}),radio.uhd.pointerUSRP,0,"",pointerGain);
	updateGain	  = pointerGain[]; 
	# Get the rate from UHD 
	pointerRate	  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_rate, libUHD), Cvoid, (Ptr{Cvoid}, Csize_t, Ref{Cdouble}),radio.uhd.pointerUSRP,0,pointerRate);
	updateRate	  = pointerRate[]; 
	# Get the freq from UHD 
	pointerFreq	  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_freq, libUHD), Cvoid, (Ptr{Cvoid}, Csize_t, Ref{Cdouble}),radio.uhd.pointerUSRP,0,pointerFreq);
	updateFreq	  = pointerFreq[];
	# Print message 
	strF  = @sprintf(" Carrier Frequency: %2.3f MHz\n Sampling Frequency: %2.3f MHz\n Rx Gain: %2.2f dB\n",updateFreq/1e6,updateRate/1e6,updateGain);
	@info "Current Radio Configuration in Rx mode\n$strF"; 
end


""" 
--- 
Update sampling rate of current radio device, and update radio object with the new obtained sampling frequency  
--- Syntax 
  updateSamplingRate!(radio,samplingRate)
# --- Input parameters 
- radio	  : Radio device [UHDRx]
- samplingRate	: New desired sampling rate 
# --- Output parameters 
- 
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function updateSamplingRate!(radio::UHDRx,samplingRate)
	# ---------------------------------------------------- 
	# --- Sampling rate configuration  
	# ---------------------------------------------------- 
	@info  "Try to change rate from $(radio.samplingRate/1e6) MHz to $(samplingRate/1e6) MHz";
	# --- Update the Rx sampling rate 
	ccall((:uhd_usrp_set_rx_rate, libUHD), Cvoid, (Ptr{uhd_usrp}, Cdouble, Csize_t),radio.uhd.pointerUSRP,samplingRate,0);
	# --- Get the Rx rate from the radio 
	pointerRate  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_rate, libUHD), Cvoid, (Ptr{uhd_usrp}, Csize_t, Ref{Cdouble}),radio.uhd.pointerUSRP,0,pointerRate);
	updateRate  = pointerRate[];	
	# --- Print a flag 
	if updateRate != samplingRate 
		@warn "Effective Rate is $(updateRate/1e6) MHz and not $(samplingRate/1e6) MHz\n" 
	else 
		@info "Effective Rate is $(updateRate/1e6) MHz\n";
	end
	radio.samplingRate = updateRate;
end


""" 
--- 
Update gain of current radio device, and update radio object with the new obtained  gain
--- Syntax 
  updateGain!(radio,gain)
# --- Input parameters 
- radio	  : Radio device [UHDRx]
- gain	: New desired gain 
# --- Output parameters 
- 
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function updateGain!(radio::UHDRx,gain)
	# ---------------------------------------------------- 
	# --- Sampling rate configuration  
	# ---------------------------------------------------- 
	@info  "Try to change gain from $(radio.rxGain) dB to $(gain) dB";
	# Update the UHD sampling rate 
	ccall((:uhd_usrp_set_rx_gain, libUHD), Cvoid, (Ptr{uhd_usrp}, Cdouble, Csize_t, Cstring),radio.uhd.pointerUSRP,gain,0,"");
	# Get the updated gain from UHD 
	pointerGain	  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_gain, libUHD), Cvoid, (Ptr{uhd_usrp}, Csize_t, Cstring,Ref{Cdouble}),radio.uhd.pointerUSRP,0,"",pointerGain);
	updateGain	  = pointerGain[]; 
	# --- Print a flag 
	if updateGain != gain 
		@warn "Effective gain is $(updateGain) dB and not $(rxGain) dB\n" 
	else 
		@info "Effective gain is $(updateGain) dB\n";
	end 
	radio.rxGain = updateGain;
end

function updateCarrierFreq!(radio::UHDRx,carrierFreq)
	# ---------------------------------------------------- 
	# --- Carrier Frequency configuration  
	# ---------------------------------------------------- 
	@info  "Try to change carrier frequency from $(radio.carrierFreq/1e6) MHz to $(carrierFreq/1e6) MHz";
	tuneRequest   = uhd_tune_request_t(carrierFreq,UHD_TUNE_REQUEST_POLICY_AUTO,UHD_TUNE_REQUEST_POLICY_AUTO);
	tunePointer	  = Ref{uhd_tune_request_t}(tuneRequest);	
	pointerTuneResult	  = Ref{uhd_tune_result}();	
	ccall((:uhd_usrp_set_rx_freq, libUHD), Cvoid, (Ptr{uhd_usrp}, Ptr{uhd_tune_request_t}, Csize_t, Ptr{uhd_tune_result}),radio.uhd.pointerUSRP,tunePointer,0,pointerTuneResult);
	pointerCarrierFreq = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_freq, libUHD), Cvoid, (Ptr{uhd_usrp}, Csize_t, Ref{Cdouble}),radio.uhd.pointerUSRP,0,pointerCarrierFreq); 
	updateCarrierFreq	= pointerCarrierFreq[];
	if updateCarrierFreq != carrierFreq 
		@warn "Effective carrier frequency is $(updateCarrierFreq/1e6) MHz and not $(carrierFreq/1e6) Hz\n" 
	else 
		@info "Effective carrier frequency is $(updateCarrierFreq/1e6) MHz\n";
	end	
	radio.carrierFreq = carrierFreq;
end


""" 
--- 
Create a buffer structure to mutualize all needed ressource to populate an incoming buffer from UHD
# --- Syntax 
#	buffer = setBuffer(radio)
# --- Input parameters 
-  radio  : UHD object [UHDRx]
# --- Output parameters 
- buffer  : Buffer structure [Buffer]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function setBuffer(radio)
	# --- Instantiate buffer 
	buff            = Vector{Cfloat}(undef,2*radio.packetSize);
	# --- Convert it to void** 
	ptr				= Ref(Ptr{Cvoid}(pointer(buff)));
	# --- Passing metadata to pointer for getting info from USRP 
	md			    = Ref(radio.uhd.pointerMD);
	# --- Pointer to recover number of samples received 
	pointerSamples  = Ref{Csize_t}(0);
	return Buffer(buff,md,ptr,pointerSamples);
end

""" 
--- 
Get a single buffer from the USRP device, and create all the necessary resources
# --- Syntax 
	sig	  = getBuffer(radio)
# --- Input parameters 
- radio	  : Radio object [UHDRx]
# --- Output parameters 
- sig	  : baseband signal from radio [Array{CFloat},2*radio.packetSize]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function getSingleBuffer(radio)
	# --- Create the buffer object to recover data 
	buffer = setBuffer(radio);
	# --- Populate the incoming buffer 
	getBuffer!(buffer,radio);
	# --- Return (only) the baseband samples
	return buffer.x;
end
#TODO Should we keep this function ? 

""" 
--- 
Get a single buffer from the USRP device, and create all the necessary ressources
# --- Syntax 
	sig	  = getBuffer(radio,nbSamples)
# --- Input parameters 
- radio	  : Radio object [UHDRx]
- nbSamples : Desired number of samples [Int]
# --- Output parameters 
- sig	  : baseband signal from radio [Array{Complex{CFloat}},radio.packetSize]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function getBuffer(radio,nbSamples)
	# --- Create the buffer object to recover data 
	buffer	= setBuffer(radio);
	# --- Create the global container 
	sigRx	= zeros(Complex{Cfloat},nbSamples); 
	# --- Populate the buffer 
	getBuffer!(sigRx,radio,buffer);
end 



""" 
--- 
Get a single buffer from the USRP device, using the Buffer structure 
# --- Syntax 
	getBuffer!(sig,radio,nbSamples)
# --- Input parameters 
- sig	  : Complex signal to populate [Array{Complex{Cfloat}}]
- radio	  : Radio object [UHDRx]
- buffer  : Buffer object [Buffer] (obtained with setBuffer(radio))
# --- Output parameters 
- sig	  : baseband signal from radio [Array{Complex{Cfloat}},radio.packetSize]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function getBuffer!(sig::Array{Complex},radio::UHDRx,buffer::Buffer)
	# --- Defined parameters for multiple buffer reception 
	filled	= false;
	posT	= 1;
	while !filled 
		# --- Get a buffer 
		cSamples  = populateBuffer!(buffer,radio);
		(posT+cSamples  > nbSamples) ? n = nbSamples - posT : n = cSamples;
		# --- Populate the complete buffer 
		sigRx[posT .+(1:n)] .= buffer.x[1:2:end] .+ 1im*buffer.x[2:2:end];
		# --- Update counters 
		posT += nS; 
		# --- Breaking flag
		(posT == nbSamples) ? filled=true : filled = false;
	end
end

""" 
--- 
Populate the Buffer structure with ccall from UHD. 
# --- Syntax 
populateBuffer!(buffer::Buffer,radio)
# --- Input parameters 
- buffer  : Buffer structure [Buffer]
- radio	  : Radio device [UHDRx]
# --- Output parameters 
- nbSamples	  : Complex samples obtained [Int]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function populateBuffer!(buffer::Buffer,radio)
	# --- Callling the receive lib.
	ccall((:uhd_rx_streamer_recv, libUHD), Cvoid,(Ptr{uhd_rx_streamer},Ptr{Ptr{Cvoid}},Csize_t,Ptr{Ptr{uhd_rx_metadata}},Cfloat,Cint,Ref{Csize_t}),radio.uhd.pointerStreamer,buffer.ptr,radio.packetSize,buffer.md,3.0,false,buffer.pointerSamples);
	# --- Pointer deferencing  -> ÷2 for Complex output
	return (buffer.pointerSamples[]÷2);
end 
