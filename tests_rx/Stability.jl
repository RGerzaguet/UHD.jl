module Stability 
# ---------------------------------------------------- 
# --- Modules  
# ---------------------------------------------------- 
# --- External modules 
using FFTW 
using Printf
using UHD 
using LinearAlgebra 

function getRate(tInit,tFinal,nbSamples)
	sDeb = tInit.intPart + tInit.fracPart;
	sFin = tFinal.intPart + tFinal.fracPart; 
	timing = sFin - sDeb; 
	return nbSamples / timing / 1e6;
end

struct Res 
	carrierFreq::Float64;
	rxGain::Float64;	
	rateVect::Array{Float64};
	fftVect::Array{Float64};
	benchPerf::Array{Float64};
	radioRate::Array{Float64};
end
export Res

function main()	
	# ---------------------------------------------------- 
	# --- Physical layer and RF parameters 
	# ---------------------------------------------------- 
	carrierFreq		= 770e6;		
	samplingRate	= 8e6; 
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
			recv!(sig,radio,buffer);
			cnt += 1;
			#print("\rProcessed $(cnt) bursts");
		end
		free(radio);
	catch exception;
		# --- Release USRP 
		free(radio);
		@show exception;
	end
end


function mainFFT(radio,samplingRate,nbSamples)	
	# ---------------------------------------------------- 
	# --- Physical layer and RF parameters 
	# ---------------------------------------------------- 
	if radio == Any;
		# --- Create the radio object in function
		carrierFreq		= 770e6;		
		rxGain			= 50.0; 
		radio			= setRxRadio("",carrierFreq,samplingRate,rxGain); 
		@show radio.packetSize;
		toRelease		= true;
	else 
		# --- Call from a method that have degined radio 
		# Radio will be released there
		toRelease = false;
		# --- We only have to update carrier frequency 
		updateSamplingRate!(radio,samplingRate);
	end
	print(radio);
	# --- Get samples 
	sig		  = zeros(Complex{Cfloat},nbSamples); 
	out		  = zeros(Complex{Cfloat},nbSamples); 
	P		  = plan_fft(sig;flags=FFTW.PATIENT);
	buffer	  = setBuffer(radio);
	cnt		  = 0;
	nS		  = 0;
	nbBuffer  = Int(1e4);
	# --- Pre-processing 
	recv!(sig,radio,buffer);
	#processing!(sig,out,P);
	# --- Timestamp init 
	p = recv!(sig,radio,buffer);
	#processing!(sig,out,P);
	# --- MEtrics 
	nS		+= p;
	timeInit  = Timestamp(getTimestamp(radio)...);
	while true
		# --- Direct call to avoid allocation 
		p = recv!(sig,radio,buffer);
		# --- Apply processing method
		#processing!(sig,out,P);
		# ---  Ensure packet is OK
		# --- Update counter
		cnt += 1;
		nS		+= p;
		# --- Before releasing buffer, we need a valid received system to have a valid timeStamp
		err = getError(radio);
		# --- Interruption 
		if cnt > nbBuffer  && err == UHD.ERROR_CODE_NONE 
			break 
		end
	end
	# --- Last timeStamp and rate 
	timeFinal = Timestamp(getTimestamp(radio)...);
	# --- Getting effective rate 
	radioRate	  = radio.samplingRate;
	effectiveRate = getRate(timeInit, timeFinal, nS);
	# --- Free all and return
	if toRelease 
		@show timeInit 
		@show timeFinal
		@show Int(nS);
		free(radio);
	end
	return (radioRate,effectiveRate);
end

function processing!(sig,out,P)
	# --- Plan FFT 
	mul!(out,P,sig);
	# --- |.|^2 
	sig .= abs2.(out);
end


function bench()
	carrierFreq		= 770e6;		
	rxGain			= 50.0; 
	rateVect	= [1e3;100e3;500e3;1e6:1e6:16e6];
	#fftVect = [1024];
	fftVect		= [64;128;256;512;1016;1024;2048];
	benchPerf	= zeros(Float64,length(fftVect),length(rateVect));
	radioRate	= zeros(Float64,length(rateVect));
	# --- Setting a very first configuration 
	global radio = setRxRadio("",carrierFreq,1e6,rxGain); 
	for (iR,targetRate) in enumerate(rateVect)
		for (iN,fftSize) in enumerate(fftVect)
			# --- Calling method 
			(eR,cR)            = mainFFT(radio,targetRate,fftSize);
			# --- Getting rate 
			benchPerf[iN,iR] = cR;
			# --- Getting radio rate 
			radioRate[iR]      = eR;
			# --- Print a flag
			print("$targetRate - $fftSize -- ");
			print("$eR MS/s -- $cR MS/s\n");
		end
	end
	free(radio);
	strucRes  = Res(carrierFreq,rxGain,rateVect,fftVect,benchPerf,radioRate);
	return strucRes;
end


end
