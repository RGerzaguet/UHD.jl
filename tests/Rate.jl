module Rate 


using FFTW 
using UHD 
using Plotly 

struct timeStamp 
	intPart::Clonglong;
	fracPart::Cdouble;
end

function getRate(tInit,tFinal,nbSamples)
	sDeb = 60*tInit.intPart + tInit.fracPart;
	sFin = 60*tFinal.intPart + tFinal.fracPart; 
	timing = sFin - sDeb; 
	return nbSamples / timing;
end


function testRate(samplingRate)
	carrierFreq		= 770e6;		
	rxGain			= 10.0; 
	# --- Setting a very first configuration 
	radio = setRxRadio("",carrierFreq,samplingRate,rxGain); 
	print(radio);
	# --- Get samples 
	nbSamples = radio.packetSize;
	sig		  = zeros(Complex{Cfloat},nbSamples); 
	buffer	  = setBuffer(radio);
	try 
		#while(true)
		bL		  = 0;
		nbRun	  = 1000000;
		tInit	= Any;
		tFinal	= Any; 
		while bL < nbRun
			# --- Direct call to avoid allocation 
			nS = getBuffer!(sig,radio,buffer);
			#nS = populateBuffer!(buffer,radio);
			if bL == 0
				tInit  = timeStamp(getTimestamp(buffer)...);
			end
			bL += nS;
		end
		tFinal= timeStamp(getTimestamp(buffer)...);
		@show rate  = getRate(tInit,tFinal,bL);
		free(radio);
		return rate, radio.samplingRate;
	catch exception;
		# --- Release USRP 
		free(radio);
		@show exception;
	end
end


function bench()
	carrierFreq		= 770e6;		
	rxGain			= 10.0; 
	tRate	= collect(1e6:2e6:200e6);
	oRate	= zeros(Float64,length(tRate));
	fRate	= zeros(Float64,length(tRate));
	# --- Setting a very first configuration 
	radio = setRxRadio("",carrierFreq,100e6,rxGain); 
	for (i,r) in enumerate(tRate) 
		updateSamplingRate!(radio,r);
		print(radio);
		# --- Get samples 
		nbSamples = 20*radio.packetSize;
		sig		  = zeros(Complex{Cfloat},nbSamples); 
		buffer	  = setBuffer(radio);
		try 
			#while(true)
			bL		  = 0;
			nbRun	  = 1000000;
			tInit	= Any;
			tFinal	= Any; 
			while bL < nbRun
				# --- Direct call to avoid allocation 
				nS = getBuffer!(sig,radio,buffer);
				#nS = populateBuffer!(buffer,radio);
				if bL == 0
					tInit  = timeStamp(getTimestamp(buffer)...);
				end
				bL += nS;
			end
			tFinal	  = timeStamp(getTimestamp(buffer)...);
			rate	  = getRate(tInit,tFinal,bL);
			oRate[i]  = rate;
			fRate[i]  = radio.samplingRate;
		catch exception;
			# --- Release USRP 
			buffer = Any;
			free(radio);
			@show exception;
		end
	end
	buffer = Any;
	free(radio);
	# --- Figure 
	layout = Plotly.Layout(;title="Rate  ",
						   xaxis_title="Desired rate  ",
						   yaxis_title="Obtained rate  ",
						   xaxis_showgrid=true, yaxis_showgrid=true,
						   )
	pl1	  = Plotly.scatter(; x=fRate ,y=oRate , name="X310 Rat ");
	plt = Plotly.plot([pl1],layout)
	display(plt);
	return (fRate,oRate,plt);
end






end
