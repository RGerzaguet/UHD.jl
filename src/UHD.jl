module UHD

using Libdl 
using Printf

# ---------------------------------------------------- 
# --- Library managment  
# ---------------------------------------------------- 
# As we shall be able to use the same module on a host PC (like Unix and MacOs, maybe windows ?) but also on ARM devices (targetting USRP E310) 
# We have to separate the fact that we want to use the RFNoC version, installed on the sysroot 
# For MACOS, some issue when UHD is installed from macports (not defined in PATH for compat reasons)
# TODO This is quite a hacky way to do this, a cleaner way to do this ?? 
useRFNoC		= false;  
# Librar$ to use is RFNoC based 
const ARCHI = Sys.CPU_NAME == "cortex-a9" ? "arm" : "pc";
if useRFNoC 
	# We manually load the libuhd.so.4
	#const libUHD	= "/home/root/localInstall/usr/lib/libuhd.so.4";
	const libUHD	= "/home/root/newinstall/usr/lib/libuhd.so.4";
else 
	if Sys.isapple() 
		# --- For apple archi, UHD is installed with macports 
		const libUHD	= "/opt/local/lib/libuhd.dylib"; 
		const FORMAT_LONG = Clonglong;
	else 
		# Default UHD library to be used 
		if ARCHI == "arm"
			const libUHD = "libuhd";
			# For E310 device, TimeStamp is a Int32 and Clonglong is mapped as a 64 bit word.
			const FORMAT_LONG = Int32;
		else 
			const libUHD = "/usr/lib/x86_64-linux-gnu/libuhd.so.3.14.1";
			const FORMAT_LONG = Clonglong;
		 end
	end
end

# ---------------------------------------------------- 
# --- Common configuration and structures 
# ---------------------------------------------------- 
# --- Including the file 
include("common.jl");
export Timestamp


# ---------------------------------------------------- 
# --- Receiver Configuration 
# ---------------------------------------------------- 
# All structures and functions for the Rx side 
include("Rx.jl");
# Structures 
export UHDRxWrapper
# Export functions 
export initRxUHD; 
export setRxRadio;
export recv,recv!;
export populateBuffer!
export getError, getTimestamp


# ---------------------------------------------------- 
# --- Transmitter Configuration  
# ---------------------------------------------------- 
# All structures and functions for the Tx side 
include("Tx.jl");
# Structures 
export UHDTxWrapper;
# Export functions 
export initTxUHD; 
export setTxRadio;
export send;
# ---------------------------------------------------- 
# --- Common functions and structures   
# ---------------------------------------------------- 
export updateSamplingRate!
export updateGain!
export updateCarrierFreq!
export print; 
export close;

""" 
--- 
Init the core parameter of the radio in Tx or in Rx mode and initiate RF parameters 
--- Syntax 
open(mode,sysImage,carrierFreq,samplingRate,txGain,antenna="TX/RX")
# --- Input parameters 
- mode 			: String to open radio in "Tx" (transmitter) or in "Rx" (receive) mode
- sysImage	  : String with the additionnal load parameters (for instance, path to the FPHGA image) [String]
- carrierFreq	: Desired Carrier frequency [Union{Int,Float64}] 
- samplingRate	: Desired bandwidth [Union{Int,Float64}] 
- txGain		: Desired Tx Gain [Union{Int,Float64}] 
- antenna		: Desired Antenna alias [String] (default "TX/RX");
# --- Output parameters 
- RadioTx		  	: UHD Tx object with PHY parameters [RadioTx]  
# --- 
# v 1.0 - Robin Gerzaguet.
""" 
function open(mode::String,sysImage, carrierFreq, samplingRate, txGain, antenna = "TX/RX")
	if mode == "Tx" 
		# --- Open radio in Tx mode 
		 radio 	 = setTxRadio(sysImage, carrierFreq, samplingRate, txGain, antenna);
	elseif mode == "Rx" 
		# --- Open radio in Rx mode 
		 radio 	 = setRxRadio(sysImage, carrierFreq, samplingRate, txGain, antenna);
	else 
		@error "Unknown mode for radio config. First parameter should be Tx or Rx (String)";
	end
	return radio;
end
export open;


end # module
