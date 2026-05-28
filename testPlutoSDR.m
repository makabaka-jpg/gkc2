clear all
close all

%% Initialize SDR device
deviceNameSDR = 'Pluto'; % Set SDR Device
radio = sdrdev(deviceNameSDR); % Create SDR device object

%% Prepare wave
samp_rate = 2e6; %Sampling rate;
txGain = 0;
rxGain = 10;
if_freq = 10e3; % Intermediate frequency
frameLen = 10e6; % Frame length in num. of samples
t = 0:1/samp_rate:(frameLen-1)/samp_rate; % Discrete time sequence
txWave = exp(1j*2*pi*if_freq*t).'; % !!!! use it when testing tx->rx link
% txWave = ones(length(t),1)+1j*ones(length(t),1); % !!!! use it when testing tx->tag->rx link

%% Transmitter set
sdrTransmitter = sdrtx(deviceNameSDR); % Transmitter properties
sdrTransmitter.RadioID = 'usb:0';
sdrTransmitter.BasebandSampleRate = samp_rate;
sdrTransmitter.CenterFrequency = 915e6; % Carrier Frequency, 915MHz in our project
sdrTransmitter.ShowAdvancedProperties = true;
sdrTransmitter.Gain = txGain;

%% Receiver set
sdrReceiver = sdrrx(deviceNameSDR);
sdrReceiver.RadioID = 'usb:0';
sdrReceiver.BasebandSampleRate = samp_rate;
sdrReceiver.CenterFrequency = sdrTransmitter.CenterFrequency; % Carrier Frequency, 915MHz in our project
sdrReceiver.GainSource = 'Manual';
sdrReceiver.Gain = rxGain;
sdrReceiver.OutputDataType = 'double';

%% tramsmit and receive
captureLen = frameLen;
sdrTransmitter.transmitRepeat(txWave);
burstCaptures = capture(sdrReceiver, captureLen, 'Samples'); % received signal
release(sdrTransmitter);

%% data plot
N=size(t,2);
fs=samp_rate;
f=(0:N-1)*fs/N;
xt=fft(txWave,N);
delta_f=fs/N;
up_freq=15e3;
down_freq=5e3;
subplot(4,1,1);
plot(f(round(down_freq/delta_f):round(up_freq/delta_f)),abs(xt(round(down_freq/delta_f):round(up_freq/delta_f))),'b');
[max1, idex_tx]=max(abs(xt));
f_tx=f(idex_tx)
xlabel('frequency/Hz')
ylabel('amplitude')
title('tx freq gram')
% 

xr=fft(burstCaptures,N);
subplot(4,1,2);
plot(f(round(down_freq/delta_f):round(up_freq/delta_f)),abs(xr(round(down_freq/delta_f):round(up_freq/delta_f))),'b');
xlabel('frequency/Hz')
ylabel('amplitude')
title('rx freq gram')
% 
subplot(4,1,3)
hold on
plot(t(1:500),real(txWave(1:500)),'b')
plot(t(1:500),imag(txWave(1:500)),'c')
legend('r','i')
xlabel('times/s')
ylabel('amplitude')
title('tx wave')

subplot(4,1,4)
hold on
N=50000;
plot(t(1:500),real(burstCaptures(1:500)),'r')
plot(t(1:500),imag(burstCaptures(1:500)),'g')
legend('r','i')
xlabel('times/s')
ylabel('amplitude')
title('rx wave')

% figure(2) % !!!! use it when testing tx->tag->rx link
% plot(burstCaptures(10000:10100),'.')
% xlim([-1,1])