module Stability 
# ---------------------------------------------------- 
# --- Modules  
# ---------------------------------------------------- 
# --- External modules 
using FFTW 
using Printf
using UHD 
function main()	
	# ---------------------------------------------------- 
	# --- Physical layer and RF parameters 
	# ---------------------------------------------------- 
	carrierFreq		= 770e6;		
	samplingRate	= 100e6; 
	rxGain			= 50.0; 
	nbSamples		= 1000;

	# --- Setting a very first configuration 
	global radio = setRxRadio("",carrierFreq,samplingRate,rxGain); 
	print(radio);
	# --- Get samples 
	nbSamples = 4096; 
	sig		  = zeros(Complex{Cfloat},nbSamples); 
	buffer	  = setBuffer(radio);
	cnt		  = 0;
	try 
		while(true) 
			# --- Direct call to avoid allocation 
			getBuffer!(sig,radio,buffer);
			cnt += 1;
			print("\rProcessed $(cnt) bursts");
		end
		free(radio);
	catch exception;
		# --- Release USRP 
		free(radio);
		@show exception;
	end
end





end
