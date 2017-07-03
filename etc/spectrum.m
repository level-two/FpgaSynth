Fs = 1536000; % Sampling frequency 
T = 1/Fs; % Sampling period 
S = importdata('pulse.txt'); 
Nsamples = length(S);

t = (0:Nsamples-1)*T; % Time vector 

%plot(1000*t(1:Nsamples),S(1:Nsamples)) 
%title('Signal Corrupted with Zero-Mean Random Noise') 
%xlabel('t (milliseconds)') 
%ylabel('X(t)') 

Y = fft(S); 

P2 = abs(Y/Nsamples); 
P1 = P2(1:Nsamples/2+1); 
P1(2:end-1) = 2*P1(2:end-1); 

f = Fs*(0:(Nsamples/2))/Nsamples; 
loglog(f,P1) 
title('Single-Sided Amplitude Spectrum of X(t)') 
xlabel('f (Hz)') 
ylabel('|P1(f)|')