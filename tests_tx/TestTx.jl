
module TestTx
# ---------------------------------------------------- 
# --- Modules  
# ---------------------------------------------------- 
# --- External modules 
using FFTW 
using Printf
using UHD 
using Random

function main()	
	# ---------------------------------------------------- 
	# --- Physical layer and RF parameters 
	# ---------------------------------------------------- 
	carrierFreq		= 770e6;		
	samplingRate	= 8e6; 
	txGain			= 50.0; 
	nbSamples		= 1000;
	# --- Setting a very first configuration 
	global radio = setTxRadio("",carrierFreq,samplingRate,txGain); 
	print(radio);
	# --- Get samples 
    buffer	= randn(Complex{Cfloat},radio.packetSize);
    buffer	= randn(Cfloat,2*radio.packetSize);

	nbEch	= send(radio,buffer,true)
	#for iN = 1 : 1 : 1000
	#nbEch = sendBuffer(radio,buffer);
	#@show Int(nbEch);
	#end
	@show Int(nbEch);
	# --- Release USRP 
	free(radio);
end

end
