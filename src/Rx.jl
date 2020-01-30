# --- Working structures 
mutable struct uhd_usrp
end
mutable struct uhd_rx_streamer
end
mutable struct uhd_rx_metadata
end

# --- Rx structures 
mutable struct UhdRxWrapper 
	pointerUSRP::Ptr{uhd_usrp};
	pointerStreamer::Ptr{uhd_rx_streamer};
	pointerMD::Ptr{uhd_rx_metadata};
end 
mutable struct E310Rx 
	uhd::UhdRxWrapper;
	carrierFreq::Float64;
	samplingRate::Float64;
	rxGain::Int; 
	antenna::String;
	nbSamples::Int;
	packetSize::Csize_t;
	released::Int;
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
	uhd  = UhdRxWrapper(usrp,streamer,metadata);
	@info("Done init \n");
	return uhd;
end
