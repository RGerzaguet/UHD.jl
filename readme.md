# UHD.jl


## Purpose 

This simple package proposes some bindings to the UHD, the C driver of the Universal Software Radio Peripheral [USRP](https://files.ettus.com/manual/) 

The purpose is to able to see the radio peripheral inside a Julia session and to be able to send and receive complex samples direclty within a Julia session. 

For instance, in order to get 4096 samples at 868MHz with a instantaneous bandwidth of 16MHz, with a 30dB Rx Gain, the following Julia code should do the trick. 

	function main()
		# ---------------------------------------------------- 
		# --- Physical layer and RF parameters 
		# ---------------------------------------------------- 
		carrierFreq		= 868e6;	    % --- The carrier frequency 	
		samplingRate	        = 16e6;         % --- Targeted bandwdith 
		rxGain			= 30.0;         % --- Rx gain 
		nbSamples		= 4096;         % --- Desired number of samples
	
		# ---------------------------------------------------- 
		# --- Getting all system with function calls  
		# ---------------------------------------------------- 
		% --- Creating the radio ressource 
		% The first parameter is for specific parameter (FPGA bitstream, IP address)
		radio	= setRxRadio("",carrierFreq,samplingRate,rxGain);
		try 
		        % --- Display the current radio configuration
				printRxConfig(x310)
				% --- Getting a buffe from the radio 
				sigAll	= getBuffer(radio,nbSamples);
		catch exception;
			@printf("Releasing UHD ressources \n");
			freeRadio(radio); 
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
