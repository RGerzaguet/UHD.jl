module Rate 


using FFTW 
using UHD 
using Plotly 
using Infiltrator

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
	printRadio(radio);
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
		freeRadio(radio);
		return rate, radio.samplingRate;
	catch exception;
		# --- Release USRP 
		freeRadio(radio);
		@show exception;
	end
end


function bench()
	tRate	= collect(1e6:2e6:100e6);
	oRate	= zeros(Float64,length(tRate));
	fRate	= zeros(Float64,length(tRate));
	for (i,r) in enumerate(tRate) 
		oRate[i],fRate[i] = testRate(r);
	end
	# --- Figure 
	layout = Plotly.Layout(;title="Rate  ",
					xaxis_title="Desired rate  ",
					yaxis_title="Obtained rate  ",
					xaxis_showgrid=true, yaxis_showgrid=true,
					)
	pl1	  = Plotly.scatter(; x=fRate ,y=oRate , name="X310 Rat ");
	plt = Plotly.plot([pl1],layout)
	display(plt);
	return (tRate,oRate,plt);
end


function plotR()
	oRate =[1.0e6
	2.0e6
	3.0e6
	4.0e6
	5.0e6
	6.0e6
	7.0e6
	8.0e6
	9.0e6
	1.0e7
	1.1e7
	1.2e7
	1.3e7
	1.4e7
	1.5e7
	1.6e7];
end



end
