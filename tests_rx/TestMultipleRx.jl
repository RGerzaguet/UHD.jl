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
	gain			= 50.0; 
	nbSamples		= 1000;

	# --- Setting a very first configuration 
	radio = openUHDRx("",carrierFreq,samplingRate,gain); 
	print(radio);
	# --- Get samples 
	nbSamples = 4096; 
	sig		  = zeros(Complex{Cfloat},nbSamples); 
	#for iN = 1 : 1 : 10 
	cnt = 0; 
	flagCnt = false;
	try 
		while(true) && cnt < 1000 
			# --- Direct call to avoid allocation 
			recv!(sig,radio);
			# @timeit to "populate " populateBuffer!(radio);
			#err = getError(radio);
			#if err > 0xf 
				#@warn "we get unexpected error"
				#flagCnt = true;
			#end
			#if flagCnt 
				#cnt += 1;
			#end
			#if cnt == 25;
				#@error "exiting"
			#end
			#@show getTimestamp(buffer);
			cnt += 1;
		end
		close(radio);
		return sig;
	catch exception;
		# --- Release USRP 
		close(radio);
		@show exception;
		return sig;
	end
end





end
