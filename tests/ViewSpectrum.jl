module ViewSpectrum

# ----------------------------------------------------
## --- Loading Modules
# ----------------------------------------------------
# --- Core Julia modules
using Plots
gr()
using Printf
using FFTW
using Suppressor
# --- Custom modules
using UHD

export @updateCarrierFreq
export @updateGain
export @updateBand
export @updateMean

const supressO = true;


# ----------------------------------------------------
## --- Processing functions
# ----------------------------------------------------
""" hostSpectrum
---
Acquire signal from USRP and compute the spectrum. Plot the obtained PSD  on a GR plot figure
# --- Syntax
hostSpectrum(nFFT)
# --- Input parameters
- nFFT			: FFT size
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
function hostSpectrum(nFFT);
	# --- Update USRP config.
	global doTask	= 1;
	global yLim	    = (-40,40);
	global changed  = 0;
	sF 	            = zeros(Cfloat,nFFT);
	y	            = zeros(Cfloat,nFFT);
	xAx		        = ((collect(0:nFFT-1) ./ nFFT) .-0.5) .*  round(radio.samplingRate,digits=2);
	fMHz	= round(radio.carrierFreq / 1e6, digits=3) ;
	sig				= zeros(Complex{Cfloat},nFFT); 
	buffer			= setBuffer(radio);
	while(true)
		sF .= 0;
		for iN  = 1 : 1 : nbSegMean
			# --- Getting samples
			#@suppress_err let 	
			@suppress let 	
				getBuffer!(sig,radio,buffer);
			end
			@show err = getError(buffer);
			y	  .= abs2.(fftshift(fft(@view sig[1:nFFT])));
			sF		= sF .+ y;
		end
		sF		= sF ./ nbSegMean;
		# --- Configuration axis 
		if changed == 1
			xAx     = ((collect(0:nFFT-1) ./ nFFT) .-0.5) .* round(radio.samplingRate,digits=2);
			fMHz	= round(radio.carrierFreq / 1e6, digits=3) ;
			changed = 0;
		end
		# --- Update plot 
		plt		= plot(xAx/1e6,10*log10.(sF),title="Spectrum of $(round(radio.samplingRate/1e6,digits=2)) MHz @ $fMHz MHz ",xlabel="Frequency [MHz]",ylabel="Power",label="",ylims=yLim,reuse=false);
		plt.attr[:size]=(1200,800)
		display(plt);
		# --- Sleep for @async
		#FIXME keep that ?
		sleep(0.001);
		# --- Interruption manager 
		if doTask != 1
			break;
		end
	end
	# --- Release USRP 
	freeRadio(radio);
end

""" killSpectrum
---
Interrupt hostSpectrum function when run in asynchronous mode
# --- Syntax
killSpectrum()
# --- Input parameters
- []
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
function stop()
	global doTask = 0;
end
function killSpectrum()
	global doTask			  = 0;
end

""" @updateCarrierFreq
---
Update carrier frequency during T/F analysis
# --- Syntax
@updateCarrierFreq xxx
# --- Input parameters
- xxx	: Value of new desired carrier frequency
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
macro updateCarrierFreq(param)
	# --- Updating carrier frequency
	global changed = 1;
	global carrierFreq = param;
	# --- Calling routine to update radio
	updateCarrierFreq!(radio,param);
end

""" @updateGain
---
Macro to dynamically update Rx gain during T/F grid
# --- Syntax
@updateGain xxx
# --- Input parameters
- xxx	: New value of Rx gain
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
macro updateGain(param)
	# --- Updating carrier frequency
	global gainRx = param;
	global changed = 1;
	# --- Calling routine to update radio
	updateGain!(radio,gainRx);
end


""" @updateBand
---
Dynamically update Rx sample rate
# --- Syntax
@updateBand xxx
# --- Input parameters
- xxx	: New desired value for sample rate
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
macro updateBand(param)
	# --- Updating carrier frequency
	global sampleRate = param;
	global changed = 1;
	# --- Calling routine to update radio
	updateSamplingRate!(radio,sampleRate);
end

""" @updateLim
---
Update the y axis limit view dynamically
# --- Syntax
@updateLim (xxx1,xxx2)
# --- Input parameters
- xxx1	  : New minimal y value
- xxx2	  : New maximal  y value
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
macro updateLim(param)
	global yLim=eval(param);
end

"""	@updateMean
---
Update the averaging system to compute spectrum
# --- Syntax
@updateMean xxx
# --- Input parameters
- xxx	: New number of mean
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
macro updateMean(param)
	global nbSegMean = param;
end


# ----------------------------------------------------
## --- Main call
# ----------------------------------------------------
""" main
---
Main routine to display Power spectral density
# --- Syntax
main()
# --- Input parameters
- []
# --- Output parameters
- []
# ---
# v 1.0 - Robin Gerzaguet.
"""
function start()
	main();
end
function main()
	# --- Simulation parameters
	global carrierFreq		  = 770e6;		  # --- Starting frequency
	global gainRx			  = 25;			  # --- Analog Rx gain
	global sampleRate		  = 80e6;		  # --- Sampling
	global nbSegMean 		  = 32; 		  # --- Number of mean
	nFFT 		              = 2048;
	# --- Update radio configuration
	global radio			= setRxRadio("",carrierFreq,sampleRate,gainRx); 
	@async task =  hostSpectrum(nFFT);

end


end
