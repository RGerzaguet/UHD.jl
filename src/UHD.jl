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
if useRFNoC 
	# We manually load the libuhd.so.4
	#const libUHD	= "/home/root/localInstall/usr/lib/libuhd.so.4";
	const libUHD	= "/home/root/newinstall/usr/lib/libuhd.so.4";
else 
	if Sys.isapple() 
		# --- For apple archi, UHD is installed with macports 
		const libUHD	= "/opt/local/lib/libuhd.dylib"; 
	else 
		# Default UHD library to be used 
		const libUHD = "libuhd";
	end
end

# Getting current lib folder to extract full paths of C executable
libFolder	= @__DIR__;

pathLibRx		= "$libFolder/../uhdRx.so";	  # Getting Rx library path 
#pathLibTx		= "$libFolder/../uhdTx.so";	  # GettingTRx library path 


function __init__()
	# ---------------------------------------------------- 
	# --- Loading librairies in __init__ 
	# ---------------------------------------------------- 
	global libRx		= Libdl.dlopen(pathLibRx);
	#global libTx		= Libdl.dlopen(pathLibTx);
end



# ---------------------------------------------------- 
# --- Receiver Configuration 
# ---------------------------------------------------- 
# All structures and functions for the Rx side 
include("Rx.jl");
# Structures 
export UhdRxWrapper
# Export functions 
export initRxUHD; 
export setRxRadio;
export freeRadio;
export printRadio;
export updateSamplingRate!
export updateGain!
export updateCarrierFreq!
#export getRxBuffer, getRxBuffer!
export getSingleBuffer
export getBuffer, getBuffer!, setBuffer


# ---------------------------------------------------- 
# --- Transmitter Configuration  
# ---------------------------------------------------- 
# All structures and functions for the Tx side 
include("Tx.jl");


end # module
