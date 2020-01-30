# UHD.jl


## Purpose 

This simple package proposes some bindings to the UHD, the C driver of the Universaa Software Radio Peripheral [USRP](https://files.ettus.com/manual/) 

The purpose is to able to see the radio peripheral inside a Julia session and to be able to send and receive complex samples direclty within a Julia session. 

For instance, in order to get 4096 samples at 868MHz with a instantaneous bandwidth of 16MHz, with a 30dB Rx Gain, the following Julia code should do the trick. 

	function main()
		# ---------------------------------------------------- 
		# --- Physical layer and RF parameters 
		# ---------------------------------------------------- 
		carrierFreq		= 770e6;		
		samplingRate	= 16e6; 
		rxGain			= 50.0; 
		nbSamples		= 4096;
	
		# ---------------------------------------------------- 
		# --- Getting all system with function calls  
		# ---------------------------------------------------- 
		uhd		= initRxUHD("");
		x310	= setRxRadio(uhd,carrierFreq,samplingRate,rxGain)
		try 
				printRxConfig(x310)
				sigAll = getRxBuffer(x310,nbSamples)
		catch exception;
			@printf("Releasing UHD ressources \n");
			freeRxUHD(x310); 
			rethrow(exception);
		end
	end


## Installation

The package can be installed with the Julia package manager.
From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

```
pkg> add UHD 
```

Or, equivalently, via the `Pkg` API:

```julia
julia> import Pkg; Pkg.add("UHD")
```

## Documentation

- [**STABLE**]() &mdash; **documentation of the most recently tagged version.**
