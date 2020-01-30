# --- Tx structures 
mutable struct UhdTxWrapper 
	lib::Ptr{Nothing};
	pointerUSRP::Ptr{Cvoid};
	pointerStreamer::Ptr{Cvoid};
	pointerMD::Ptr{Cvoid};
end 
mutable struct E310Tx 
	uhd::UhdTxWrapper;
	carrierFreq::Float64;
	samplingRate::Float64;
	rxGain::Int; 
	antenna::String;
	packetSize::Csize_t;
	released::Int;
end


