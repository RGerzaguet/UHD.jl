# --- Working structures 
mutable struct uhd_usrp
end
mutable struct uhd_rx_streamer
end
mutable struct uhd_string_vector
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
@enum uhd_error begin 
	UHD_ERROR_NONE = 0;
	UHD_ERROR_INVALID_DEVICE = 1;
	UHD_ERROR_INDEX = 10;
	UHD_ERROR_KEY = 11;
	UHD_ERROR_NOT_IMPLEMENTED = 20;
	UHD_ERROR_USB = 21;
	UHD_ERROR_IO = 30;
	UHD_ERROR_OS = 31;
	UHD_ERROR_ASSERTION = 40;
	UHD_ERROR_LOOKUP = 41;
	UHD_ERROR_TYPE = 42;
	UHD_ERROR_VALUE = 43;
	UHD_ERROR_RUNTIME = 44;
	UHD_ERROR_ENVIRONMENT = 45;
	UHD_ERROR_SYSTEM = 46;
	UHD_ERROR_EXCEPT = 47;
	UHD_ERROR_BOOSTEXCEPT = 60;
	UHD_ERROR_STDEXCEPT = 70;
	UHD_ERROR_UNKNOWN = 100
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
mutable struct UHDRxWrapper 
	flag::Bool;
	pointerUSRP::Ptr{uhd_usrp};
	pointerStreamer::Ptr{uhd_rx_streamer};
	pointerMD::Ptr{uhd_rx_metadata};
	addressUSRP::Ref{Ptr{uhd_usrp}};
	addressStream::Ref{Ptr{uhd_rx_streamer}};
	addressMD::Ref{Ptr{uhd_rx_metadata}};
end 
mutable struct RadioRx 
	uhd::UHDRxWrapper;
	carrierFreq::Float64;
	samplingRate::Float64;
	rxGain::Union{Int,Float64}; 
	antenna::String;
	packetSize::Csize_t;
	released::Int;
end

struct Buffer 
	x::Array{Cfloat};
	#md::Ref{Ptr{uhd_rx_metadata}};
	ptr::Ref{Ptr{Cvoid}};
	pointerSamples::Ref{Csize_t};
	pointerError::Ref{error_code_t};
	pointerFullSec::Ref{Clonglong};
	pointerFracSec::Ref{Cdouble};
end

"""
" @assert_uhd macro
# Get the current UHD flag and raise an error if necessary 
"""
macro assert_uhd(ex)
	quote 
		local flag = $(esc(ex));
		if flag == UHD_ERROR_KEY
			error("Unable to create the UHD device. No attached UHD device found."); 
		elseif flag != UHD_ERROR_NONE 
			error("Unable to create or instantiate the UHD device. The return error flag is $flag"); 
		end
	end
end




""" 
--- 
Initiate all structures to instantiaet and pilot a USRP device.
--- Syntax 
uhd	  = initRxUHD(sysImage)
# --- Input parameters 
- sysImage	  : String with the additionnal load parameters (for instance, path to the FPHGA image) [String]
# --- Output parameters 
- uhd		  = UHD Rx object [UHDRxWrapper] 
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function initRxUHD(sysImage)
	# ---------------------------------------------------- 
	# --- Handler  
	# ---------------------------------------------------- 
	addressUSRP = Ref{Ptr{uhd_usrp}}();
	# --- Cal the init
	@assert_uhd ccall((:uhd_usrp_make, libUHD), uhd_error, (Ptr{Ptr{uhd_usrp}}, Cstring),addressUSRP,sysImage);
	# --- Get the usable object 
	usrpPointer = addressUSRP[];
	# ---------------------------------------------------- 
	# --- Rx Streamer  
	# ---------------------------------------------------- 
	# --- Create a pointer related to the Rx streamer
	addressStream = Ref{Ptr{uhd_rx_streamer}}(); 
	# --- Cal the init
	@assert_uhd ccall((:uhd_rx_streamer_make, libUHD), uhd_error, (Ptr{Ptr{uhd_rx_streamer}},),addressStream);
	streamerPointer = addressStream[];
	# ---------------------------------------------------- 
	# --- Rx Metadata  
	# ---------------------------------------------------- 
	# --- Create a pointer related to Metadata 
	addressMD = Ref{Ptr{uhd_rx_metadata}}(); 
	# --- Cal the init
	@assert_uhd ccall((:uhd_rx_metadata_make, libUHD), uhd_error, (Ptr{Ptr{uhd_rx_metadata}},),addressMD);
	# --- Get the usable object 
	metadataPointer = addressMD[];
	# ---------------------------------------------------- 
	# --- Create the USRP wrapper object  
	# ---------------------------------------------------- 
	uhd  = UHDRxWrapper(true,usrpPointer,streamerPointer,metadataPointer,addressUSRP,addressStream,addressMD);
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
- RadioRx		  	: UHD Rx object with PHY parameters [RadioRx]  
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function setRxRadio(sysImage,carrierFreq,samplingRate,rxGain,antenna="RX2")
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
	# --- Create streamer master 
	#streamCmd	= stream_cmd(UHD_STREAM_MODE_NUM_SAMPS_AND_DONE,nbSamples,true,0,0.0);
	streamCmd	= stream_cmd(UHD_STREAM_MODE_START_CONTINUOUS,nbSamples,true,0,0.0);
	pointerCmd	= Ref{stream_cmd}(streamCmd);
	ccall((:uhd_rx_streamer_issue_stream_cmd, libUHD), Cvoid, (Ptr{uhd_stream_args_t},Ptr{stream_cmd}),uhd.pointerStreamer,pointerCmd);
	# ---------------------------------------------------- 
	# --- Create object and return  
	# ---------------------------------------------------- 
	# --- Return  
	return RadioRx(uhd,updateCarrierFreq,updateRate,updateGain,antenna,nbSamples,0);
end

""" 
--- 
Close the USRP device (Rx mode) and release all associated objects
# --- Syntax 
#	free(uhd)
# --- Input parameters 
- uhd	: UHD object [RadioRx]
# --- Output parameters 
- []
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function free(radio::RadioRx)
	# --- Checking realease nature 
	# There is one flag to avoid double free (that leads to seg fault) 
	if radio.released == 0
		# C Wrapper to ressource release 
		@assert_uhd  ccall((:uhd_usrp_free, libUHD), uhd_error, (Ptr{Ptr{uhd_usrp}},),radio.uhd.addressUSRP);
		#@assert_uhd ccall((:uhd_rx_streamer_free, libUHD), uhd_error, (Ptr{Ptr{uhd_rx_streamer}},),radio.uhd.addressStream);
		#@assert_uhd ccall((:uhd_usrp_free, libUHD), uhd_error, (Ptr{Ptr{uhd_rx_metadata}},),radio.uhd.addressMD);
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
function print(radio::RadioRx)
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
- radio	  : Radio device [RadioRx]
- samplingRate	: New desired sampling rate 
# --- Output parameters 
- 
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function updateSamplingRate!(radio::RadioRx,samplingRate)
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
- radio	  : Radio device [RadioRx]
- gain	: New desired gain 
# --- Output parameters 
- 
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function updateGain!(radio::RadioRx,gain)
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

function updateCarrierFreq!(radio::RadioRx,carrierFreq)
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
-  radio  : UHD object [RadioRx]
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
	# --- Pointer to recover number of samples received 
	pointerSamples  = Ref{Csize_t}(0);
	return Buffer(buff,ptr,pointerSamples,Ref{error_code_t}(),Ref{Clonglong}(),Ref{Cdouble}());
end

""" 
--- 
Get a single buffer from the USRP device, and create all the necessary resources
# --- Syntax 
	sig	  = getBuffer(radio)
# --- Input parameters 
- radio	  : Radio object [RadioRx]
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
	x	  = buffer.x;
	# --- Return (only) the baseband samples
	return x;
end
#TODO Should we keep this function ? 

""" 
--- 
Get a single buffer from the USRP device, and create all the necessary ressources
# --- Syntax 
	sig	  = getBuffer(radio,nbSamples)
# --- Input parameters 
- radio	  : Radio object [RadioRx]
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
	return sigRx 
end 



""" 
--- 
Get a single buffer from the USRP device, using the Buffer structure 
# --- Syntax 
	getBuffer!(sig,radio,nbSamples)
# --- Input parameters 
- sig	  : Complex signal to populate [Array{Complex{Cfloat}}]
- radio	  : Radio object [RadioRx]
- buffer  : Buffer object [Buffer] (obtained with setBuffer(radio))
# --- Output parameters 
- sig	  : baseband signal from radio [Array{Complex{Cfloat}},radio.packetSize]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function getBuffer!(sig::Array{Complex{Cfloat}},radio::RadioRx,buffer::Buffer)
	# --- Defined parameters for multiple buffer reception 
	filled		= false;
	posT		= 0;
	nbSamples	= length(sig);
	#nb = 0;
	while !filled 
		# --- Get a buffer 
		cSamples  = populateBuffer!(buffer,radio);
		(posT+cSamples  > nbSamples) ? n = nbSamples - posT : n = cSamples;
		# --- Populate the complete buffer 
		#sig[posT .+ (1:n)] .= @views(buffer.x[1:2:2n]) .+ 1im*(@views buffer.x[2:2:2n]);
		sig[posT .+ (1:n)] .= reinterpret(Complex{Cfloat},@view buffer.x[1:2n]);
		# --- Update counters 
		posT += n; 
		# --- Breaking flag
		(posT == nbSamples) ? filled=true : filled = false;
		#nb = nb + 1;
	end
	#@show nb
	return posT
end

""" 
--- 
Populate the Buffer structure with ccall from UHD. 
# --- Syntax 
populateBuffer!(buffer::Buffer,radio)
# --- Input parameters 
- buffer  : Buffer structure [Buffer]
- radio	  : Radio device [RadioRx]
# --- Output parameters 
- nbSamples	  : Complex samples obtained [Int]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function populateBuffer!(buffer::Buffer,radio)
	# --- Effectively recover data
	ccall((:uhd_rx_streamer_recv, libUHD), Cvoid,(Ptr{uhd_rx_streamer},Ptr{Ptr{Cvoid}},Csize_t,Ptr{Ptr{uhd_rx_metadata}},Cfloat,Cint,Ref{Csize_t}),radio.uhd.pointerStreamer,buffer.ptr,radio.packetSize,radio.uhd.addressMD,10,false,buffer.pointerSamples);
		# --- Pointer deferencing 
	return Int(buffer.pointerSamples[]);
end#

""" 
--- 
Returns the Error flag of the current UHD burst 
--- Syntax 
flag = getError(radio)
# --- Input parameters 
- radio : UHD object [RadioRx]
# --- Output parameters 
- err	: Error Flag [error_code_t]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function getError(radio::RadioRx)
	ptrErr = Ref{error_code_t}();
	ccall((:uhd_rx_metadata_error_code,libUHD), Cvoid,(Ptr{uhd_rx_metadata},Ref{error_code_t}),radio.uhd.pointerMD,ptrErr);
	return err = ptrErr[];
end


""" 
--- 
Return the timestamp of the last UHD burst 
--- Syntax 
(second,fracSecond) = getTimestamp(radio)
# --- Input parameters 
- radio	  : UHD Radio object [RadioRx]
# --- Output parameters 
- second  : Second value for the flag [Int]
- fracSecond : Fractional second value [Float64]
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function getTimestamp(radio::RadioRx)
	ptrFullSec = Ref{Clonglong}();
	ptrFracSec = Ref{Cdouble}();
	ccall( (:uhd_rx_metadata_time_spec,libUHD), Cvoid, (Ptr{uhd_rx_metadata},Ref{Clonglong},Ref{Cdouble}),radio.uhd.pointerMD,ptrFullSec,ptrFracSec);
	return (ptrFullSec[],ptrFracSec[]);
end

