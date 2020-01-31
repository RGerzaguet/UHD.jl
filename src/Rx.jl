# --- Working structures 
mutable struct uhd_usrp
end
mutable struct uhd_rx_streamer
end
mutable struct uhd_rx_metadata
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
	usrpPointer = Array{uhd_usrp,1}(undef,1);
	# --- Cal the init
	ccall((:uhd_usrp_make, libUHD), Cvoid, (Ptr{uhd_usrp}, Cstring),usrpPointer,sysImage);
	# ---------------------------------------------------- 
	# --- Rx Streamer  
	# ---------------------------------------------------- 
	# --- Create a pointer related to the Rx streamer
	streamerPointer = Array{uhd_rx_streamer,1}(undef,1);
	# --- Cal the init
	ccall((:uhd_rx_streamer_make, libUHD), Cvoid, (Ptr{uhd_rx_streamer},),streamerPointer);
	# ---------------------------------------------------- 
	# --- Rx Metadata  
	# ---------------------------------------------------- 
	# --- Create a pointer related to Metadata 
	metadataPointer = Array{uhd_rx_metadata,1}(undef,1); 
	# --- Cal the init
	ccall((:uhd_rx_metadata_make, libUHD), Cvoid, (Ptr{uhd_rx_metadata},),metadataPointer);
	# ---------------------------------------------------- 
	# --- Create the USRP wrapper object  
	# ---------------------------------------------------- 
	uhd  = UhdRxWrapper(usrpPointer,streamerPointer,metadataPointer);
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
	ccall((:uhd_usrp_set_rx_rate, libUHD), Cvoid, (uhd_usrp, Cdouble, Csize_t),uhd.pointerUSRP[1],samplingRate,0);
	# --- Get the Rx rate from the radio 
	pointerRate  = Ref{Cdouble}(0);
	ccall((:uhd_usrp_get_rx_rate, libUHD), Cvoid, (uhd_usrp, Csize_t, Ref{Cdouble}),uhd.pointerUSRP[1],0,pointerRate);
	updateRate  = pointerRate[];	
	# --- Print a flag 
	if updateRate != samplingRate 
		@warn "Effective Rate is $(updateRate/1e6) MHz and not $(samplingRate/1e6) MHz\n" 
	else 
		@info "Effective Rate is $(updateRate/1e6) MHz\n";
	end
	## ---------------------------------------------------- 
	## --- Carrier Frequency configuration  
	## ---------------------------------------------------- 
	#tunePointer	  = Ref{uhd_tune_request_t}(tuneRequest);	
	#pointerTuneResult	  = Ref{uhd_tune_result}();	
	#ccall((:uhd_usrp_set_rx_freq, libUHD), Cvoid, (uhd_usrp, Ptr{uhd_tune_request_t}, Csize_t, Ptr{uhd_tune_result}),uhd.pointerUSRP[1],tunePointer,0,pointerTuneResult);
	#pointerCarrierFreq = Ref{Cdouble}(0);
	#ccall((:uhd_usrp_get_rx_freq, libUHD), Cvoid, (uhd_usrp, Csize_t, Ref{Cdouble}),uhd.pointerUSRP[1],0,pointerCarrierFreq); 
	#updateCarrierFreq	= pointerCarrierFreq[];
	#if updateCarrierFreq != carrierFreq 
		#@warn "Effective carrier frequency is $(updateCarrierFreq/1e6) MHz and not $(carrierFreq/1e6) Hz\n" 
	#else 
		#@info "Effective carrier frequency is $(updateCarrierFreq/1e6) MHz\n";
	#end	
	## ---------------------------------------------------- 
	## --- Gain configuration  
	## ---------------------------------------------------- 
	## Update the UHD sampling rate 
	#ccall((:uhd_usrp_set_rx_gain, libUHD), Cvoid, (uhd_usrp, Cdouble, Csize_t, Cstring),uhd.pointerUSRP[1],rxGain,0,"");
	## Get the updated gain from UHD 
	#pointerGain	  = Ref{Cdouble}(0);
	#ccall((:uhd_usrp_get_rx_gain, libUHD), Cvoid, (uhd_usrp, Csize_t, Cstring,Ref{Cdouble}),uhd.pointerUSRP[1],0,"",pointerGain);
	#updateGain	  = pointerGain[]; 
	## --- Print a flag 
	#if updateGain != rxGain 
		#@warn "Effective gain is $(updateGain) dB and not $(rxGain) dB\n" 
	#else 
		#@info "Effective gain is $(updateGain) dB\n";
	#end 
	## ---------------------------------------------------- 
	## --- Antenna configuration 
	## ---------------------------------------------------- 
	#ccall((:uhd_usrp_set_rx_antenna, libUHD), Cvoid, (uhd_usrp, Cstring, Csize_t),uhd.pointerUSRP[1],antenna,0);
	## ---------------------------------------------------- 
	## --- Setting up streamer  
	## ---------------------------------------------------- 
	## --- Setting up arguments 
	#pointerArgs	  = Ref{uhd_stream_args_t}(uhdArgs);
	#ccall((:uhd_usrp_get_rx_stream, libUHD), Cvoid, (uhd_usrp,Ptr{uhd_stream_args_t},uhd_rx_streamer),uhd.pointerUSRP[1],pointerArgs,uhd.pointerStreamer[1]);
	## --- Getting number of samples ber buffer 
	#pointerSamples	  = Ref{Csize_t}(0);
	#ccall((:uhd_rx_streamer_max_num_samps, libUHD), Cvoid, (uhd_rx_streamer,Ref{Csize_t}),uhd.pointerStreamer[1],pointerSamples);
	#nbSamples		  = pointerSamples[];	
	## --- Issue stream command 
	#streamCmd	= stream_cmd(UHD_STREAM_MODE_START_CONTINUOUS,nbSamples,true,0,0.0);
	#pointerCmd	= Ref{stream_cmd}(streamCmd);
	#ccall((:uhd_rx_streamer_issue_stream_cmd, libUHD), Cvoid, (uhd_rx_streamer,Ptr{stream_cmd}),uhd.pointerStreamer[1],pointerCmd);
	## ---------------------------------------------------- 
	## --- Create object and return  
	## ---------------------------------------------------- 
	## --- Return  
	##FIXME free pointerCmd and not store it ?
	#return UHDRx(uhd,updateCarrierFreq,updateRate,updateGain,antenna,nbSamples,0,uhdArgs,tuneRequest,pointerTuneResult,pointerCmd);
end

""" 
--- 
Close the USRP device (Rx mode) and release all associated objects
# --- Syntax 
#	freeUSRP(uhd)
# --- Input parameters 
- uhd	: UHD object [UHDRx]
# --- Output parameters 
- []
# --- 
# v 1.0 - Robin Gerzaguet.
"""
function freeUSRP(uhd::UHDRx)
	# --- Checking realease nature 
	# There is one flag to avoid double free (that leads to seg fault) 
	if uhd.released == 0
		# C Wrapper to ressource release 
		ccall((:uhd_usrp_free, libUHD), Cvoid, (Ptr{uhd_usrp},),uhd.uhd.pointerUSRP);
		#ccall((:uhd_rx_streamer_free, libUHD), Cvoid, (Ptr{uhd_rx_streamer},),uhd.uhd.pointerStreamer);
		#ccall((:uhd_usrp_free, libUHD), Cvoid, (Ptr{uhd_rx_metadata},),uhd.uhd.pointerMD);
	else 
		# print a warning  
		@warn "UHD ressource was already released, abort call";
	end 
	# --- Force flag value 
	uhd.released = 1;

end
