module TestConfigRadio 
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

	@printf("done -- \n");

	# --- Setting a very first configuration 
	global radio = setRxRadio("",carrierFreq,samplingRate,rxGain); 
	printRadio(radio);
	  
	# --- Update configuration 
	updateCarrierFreq!(radio,660e6);
	updateSamplingRate!(radio,100e6);
	updateGain!(radio,15);
	printRadio(radio);
	
	updateSamplingRate!(radio,16e6);
	# --- Release USRP 
	free(radio);
end





end
