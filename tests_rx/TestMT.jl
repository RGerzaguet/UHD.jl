#/!\ Julia must be fun with julia -p 2
#module TestMP

# ----------------------------------------------------
# --- Core modules
# ----------------------------------------------------
	# --- Core base modules
	using FFTW
	using Debugger
	using Printf
	# --- Custom modules
	using UHD


# ----------------------------------------------------
## --- Define Core functions
# ----------------------------------------------------
global doTask = true;
function stop()
 global doTask = false;
end
function start()
	global doTask = true;
end


function getDataSequential(radio)
	# Pure sequentiel version
	try
		timeInit  = time();
		bA		  = 0;
		sig    = zeros(Complex{Cfloat},radio.packetSize);
		while(true)
			recv!(sig,radio);
			processingData(sig);
			bA	  += length(sig);
			if mod(bA,100000) == 0
				currRate  = round(getRate(timeInit,bA)/1e6;digits=2);
				print("\rUSRP rate is $(currRate) MS/s");
			end
		end
	catch exception;
		closeRadio(radio);
		rethrow(exception);
	end
end


# Using direct call of method
# --> Many alloc ?
function produceData(chnl,radio)
	try
		sig    = zeros(Complex{Cfloat},radio.packetSize);
		while doTask 
			# --- Populate a buffer from the USRP 
			recv!(sig,radio);
			# --- Set the buffer in the common shared channel 
			put!(chnl,sig)
			# --- Force actualisation of state (otherwise cannot have break)
			yield();
		end
		# --- Free environment
		buffer = Any;
		closeRadio(radio);
	catch exception;
		# --- Free environment in case of exception
		closeRadio(radio);
		rethrow(exception);
	end
end
function consummeData(chnl)
	print("coucou \n");
	currRate  = -1;
	try
		patt = take!(chnl);	# Ensure buffer is null
		timeInit  = time();
		bA		  = 0;
		ra		  = 0;
		y	 = similar(patt);
		while(true) && doTask == true
			# --- Recover data from channel
			y .= take!(chnl);
			# --- Processing data
			processingData(y);
			bA	  += length(y);
			ra +=1 
			if mod(ra,10000) == 0
				currRate  = round(getRate(timeInit,bA)/1e6;digits=2);
				print("\rUSRP rate is $(currRate) MS/s\n");
			end
		end
		return currRate;
	catch exception
		rethrow(exception)
	end
end

function processingData(y)
	#println("Getting $(length(y)) samples and ready to process");
	#out = fft(y);
	#out = fft(y);
	#out = fft(y);
	#out = fft(y);
end

function getRate(timeInit,bL)
	return bL/(time() - timeInit);
end


# ----------------------------------------------------
## --- Multiprocess handling
# ----------------------------------------------------




function mainThread()
	# ----------------------------------------------------
	# --- Configuration
	# ----------------------------------------------------
	#
	# --- Main configuration
	carrierFreq         = 156e6;
	bandwidth           = 6e6;
	gain              = -3;
	doTask				= 1;
	start();
	# --- Update x310 configuration
	radio = setRxRadio("",carrierFreq,100e6,gain); 
	# --- Create handler 
	chnl	= Channel{Array{Complex{Cfloat}}}(0);
	# ----------------------------------------------------
	# --- P1 : Getting data
	# ----------------------------------------------------
	# --- Calling method to get data
	T1 = Threads.@spawn produceData(chnl,radio);
	# ----------------------------------------------------
	# --- P1
	# ----------------------------------------------------
	# --- Processing data
	T2 = Threads.@spawn consummeData(chnl);
	return (T1,T2);
end




function mainSeq()
	# --- Main configuration
	carrierFreq         = 156e6;
	bandwidth           = 6e6;
	gain              = -3;
	start();
	# --- Update e310 configuration
	radio = setRxRadio("",carrierFreq,100e6,gain); 
	# ----------------------------------------------------
	# --- P1 : Getting data
	# ----------------------------------------------------
	# --- Calling method to get data
	getDataSequential(radio);
end


