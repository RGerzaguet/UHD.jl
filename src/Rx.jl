# --- Working structures 
mutable struct uhd_usrp
end
mutable struct uhd_rx_streamer
end

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
@enum error_code_t begin
	ERROR_CODE_NONE = 0x0;
	ERROR_CODE_TIMEOUT = 0x1;
	ERROR_CODE_LATE_COMMAND = 0x2;
	ERROR_CODE_BROKEN_CHAIN = 0x4;
	ERROR_CODE_OVERFLOW = 0x8;
	ERROR_CODE_ALIGNMENT = 0xc;
	ERROR_CODE_BAD_PACKET = 0xf;
	BIG_PROBLEM;
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

struct uhd_rx_metadata 
	has_time_spec::Cuchar;
	time_spec::Clonglong;
	time_spec_frac::Cdouble;
	more_fragments::Cuchar;
	fragment_offset::Csize_t;
	start_of_burst::Cuchar;
	end_of_burst::Cuchar;
	eov_positions::Ref{Csize_t};
	eov_positions_size::Csize_t;
	eov_positions_count::Csize_t;
	error_code::error_code_t;
	out_of_sequence::Cuchar;
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
	pointerCmd::Ref{stream_cmd};
	#uhdArgs::uhd_stream_args_t;
	#tuneRequest::uhd_tune_request_t;
	#pointerTuneResult::Ref{uhd_tune_result};
end

struct Buffer 
	x::Array{Cfloat};
	md::Ref{Ptr{uhd_rx_metadata}};
	ptr::Ref{Ptr{Cvoid}};
	pointerSamples::Ref{Csize_t};
	pointerError::Ref{error_code_t};
	pointerFullSec::Ref{Clonglong};
	pointerFracSec::Ref{Cdouble};
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
- sysImage	  : String with the additionnal load parameters (for instance, path to the FPHGA image) [String]
- carrierFreq	: Desired Carrier frequency [Union{Int,Float64}] 
- samplingRate	: Desired bandwidth [Union{Int,Float64}] 
- rxGain		: Desired Rx Gain [Union{Int,Float64}] 
- antenna		: Desired Antenna alias [String] (default "TX/RX");
# --- Output parameters 
- UHDRx		  	: UHD Rx object with PHY parameters [UHDRx]  
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function setRxRadio(sysImage,carrierFreq,samplingRate,rxGain,antenna="TX/RX")
	# ---------------------------------------------------- 
	# --- Init  UHD object  
	# ---------------------------------------------------- 
	uhd	  = initRxUHD(sysImage);
	# ---------------------------------------------------- 
	# --- Creating Runtime structures  
	# ---------------------------------------------------- 
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
	# --- Create structure for request 
	tuneRequest	   = uhd_tune_request_t(carrierFreq,UHD_TUNE_REQUEST_POLICY_AUTO,UHD_TUNE_REQUEST_POLICY_AUTO);
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
	#ccall((:uhd_usrp_set_rx_antenna, libUHD), Cvoid, (Ptr{uhd_usrp}, Cstring, Csize_t),uhd.pointerUSRP,antenna,0);
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
	# --- Create streamer master 
	#streamCmd	= stream_cmd(UHD_STREAM_MODE_NUM_SAMPS_AND_DONE,nbSamples,true,0,0.0);
	streamCmd	= stream_cmd(UHD_STREAM_MODE_START_CONTINUOUS,nbSamples,true,0,0.5);
	pointerCmd	= Ref{stream_cmd}(streamCmd);
	ccall((:uhd_rx_streamer_issue_stream_cmd, libUHD), Cvoid, (Ptr{uhd_stream_args_t},Ptr{stream_cmd}),uhd.pointerStreamer,pointerCmd);
	# ---------------------------------------------------- 
	# --- Create object and return  
	# ---------------------------------------------------- 
	# --- Return  
	return UHDRx(uhd,updateCarrierFreq,updateRate,updateGain,antenna,nbSamples,0,pointerCmd);
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
	return Buffer(buff,md,ptr,pointerSamples,Ref{error_code_t}(),Ref{Clonglong}(),Ref{Cdouble}());
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
	populateBuffer!(buffer,radio);
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
	nbSamples = getBuffer!(sigRx,radio,buffer);
	return nbSamples
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
@inline function getBuffer!(sig::Array{Complex{Cfloat}},radio::UHDRx,buffer::Buffer)
	# --- Defined parameters for multiple buffer reception 
	filled		= false;
	posT		= 0;
	nbSamples	= length(sig);
	while !filled 
		# --- Get a buffer 
		cSamples  = populateBuffer!(buffer,radio);
		(posT+cSamples  > nbSamples) ? n = nbSamples - posT : n = cSamples;
		# --- Populate the complete buffer 
		sig[posT .+ (1:n)] .= @views(buffer.x[1:2:2n]) .+ 1im*(@views buffer.x[2:2:2n]);
		# --- Update counters 
		posT += n; 
		# --- Breaking flag
		(posT == nbSamples) ? filled=true : filled = false;
	end
	return posT
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
	# --- Issue stream command 
	#ccall((:uhd_rx_streamer_issue_stream_cmd, libUHD), Cvoid, (Ptr{uhd_stream_args_t},Ptr{stream_cmd}),radio.uhd.pointerStreamer,radio.pointerCmd);
	# --- Effectively recover data
	ccall((:uhd_rx_streamer_recv, libUHD), Cvoid,(Ptr{uhd_rx_streamer},Ptr{Ptr{Cvoid}},Csize_t,Ptr{Ptr{uhd_rx_metadata}},Cfloat,Cint,Ref{Csize_t}),radio.uhd.pointerStreamer,buffer.ptr,radio.packetSize,buffer.md,10,false,buffer.pointerSamples);
		# --- Pointer deferencing 
	return Int(buffer.pointerSamples[]);
end#


function getError(radio::UHDRx)
	ptrErr = Ref{error_code_t}();
	ccall((:uhd_rx_metadata_error_code,libUHD), Cvoid,(Ptr{uhd_rx_metadata},Ref{error_code_t}),radio.uhd.pointerMD,ptrErr);
	return err = ptrErr[];
end
function getError(buffer::Buffer)
	#ccall((:uhd_rx_metadata_error_code,libUHD), Cvoid,(Ptr{uhd_rx_metadata},Ref{error_code_t}),buffer.md[],buffer.pointerError);
	#return err = buffer.pointerError[];
	pointerError = Ref{Cint}();
	ccall((:uhd_rx_metadata_error_code,libUHD), Cvoid,(Ptr{uhd_rx_metadata},Ref{Cint}),buffer.md[],pointerError);
	return pointerError[];
end
function getTimestamp(radio::UHDRx)
	ptrFullSec = Ref{Clonglong}();
	ptrFracSec = Ref{Cdouble}();
	ccall( (:uhd_rx_metadata_time_spec,libUHD), Cvoid, (Ptr{uhd_rx_metadata},Ref{Clonglong},Ref{Cdouble}),radio.uhd.pointerMD,ptrFullSec,ptrFracSec);
	return (ptrFullSec[],ptrFracSec[]);
end
function getTimestamp(buffer::Buffer)
	ccall( (:uhd_rx_metadata_time_spec,libUHD), Cvoid, (Ptr{uhd_rx_metadata},Ref{Clonglong},Ref{Cdouble}),buffer.md[],buffer.pointerFullSec,buffer.pointerFracSec);
	return (buffer.pointerFullSec[],buffer.pointerFracSec[]);
end
