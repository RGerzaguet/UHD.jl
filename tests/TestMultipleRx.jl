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
	samplingRate	= 100e6; 
	rxGain			= 50.0; 
	nbSamples		= 1000;

	# --- Setting a very first configuration 
	global radio = setRxRadio("",carrierFreq,samplingRate,rxGain); 
	printRadio(radio);
	# --- Get samples 
	nbSamples = 4096; 
	sig		  = zeros(Complex{Cfloat},nbSamples); 
	global buffer	  = setBuffer(radio);
	#for iN = 1 : 1 : 10 
	cnt = 0; 
	flagCnt = false;
	try 
		while(true)
			# --- Direct call to avoid allocation 
			#getBuffer!(sig,radio,buffer);
			populateBuffer!(buffer,radio);
			@show err = getError(buffer);
			if err > 0xf 
				@warn "we get unexpected error"
				flagCnt = true;
			end
			if flagCnt 
				cnt += 1;
			end
			if cnt == 25;
				@error "exiting"
			end
			@show getTimestamp(buffer);
		end
	catch exception;
		# --- Release USRP 
		freeRadio(radio);
		@show exception;
	end
end





end
