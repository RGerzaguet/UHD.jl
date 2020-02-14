module TestMultipleRx
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
	samplingRate	= 66e6; 
	rxGain			= 50.0; 
	nbSamples		= 1000;

	# --- Setting a very first configuration 
	global radio = setRxRadio("",carrierFreq,samplingRate,rxGain); 
	printRadio(radio);
	# --- Get samples 
	nbSamples = 4096; 
	sig		  = zeros(Complex{Cfloat},nbSamples); 
	buffer	  = setBuffer(radio);
	#for iN = 1 : 1 : 10 
	try 
		while(true)
			# --- Direct call to avoid allocation 
			getBuffer!(sig,radio,buffer);
@printf(".");
		end
	catch exception;
		# --- Release USRP 
		freeRadio(radio);
		@show exception;
	end
end





end
