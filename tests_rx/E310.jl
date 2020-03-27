module E310


using UHD 
using Sockets 


include("../ConnectPC.jl");
using .ConnectPC 


function main(carrierFreq,samplingRate,rxGain,nbSamples)
	# --- Setting a very first configuration 
	global radio = setRxRadio("",carrierFreq,samplingRate,rxGain); 
	print(radio);
	# --- Get samples 
	sig		  = zeros(Complex{Cfloat},nbSamples); 
	cnt		  = 0;
	try 
		while(true) 
			# --- Direct call to avoid allocation 
            recv!(sig,radio);
            # --- To UDP socket
            ConnectPC.send(sig);
		end
		close(radio);
	catch exception;
		# --- Release USRP 
		close(radio);
        @show exception;
    end
end


end
