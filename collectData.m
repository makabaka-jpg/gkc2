%% collectData.m - Systematic data collection for liquid identification
% Usage: collectData(liquidName, height_ml, trialNum)
% Example: collectData('water', 1000, 1)
%
% Saves raw I/Q data to ./data/ directory with metadata

function collectData(liquidName, height_ml, trialNum)
    if nargin < 3
        error('Usage: collectData(liquidName, height_ml, trialNum)');
    end

    %% Initialize SDR device
    deviceNameSDR = 'Pluto';
    radio = sdrdev(deviceNameSDR);

    %% Parameters
    samp_rate = 2e6;
    txGain = 0;
    rxGain = 10;
    if_freq = 10e3;
    frameLen = 16e6;  % Max ~16.7M per frame, 8 seconds at 2MHz
    t = 0:1/samp_rate:(frameLen-1)/samp_rate;

    % Tag reflection mode: constant carrier
    txWave = ones(length(t),1) + 1j*ones(length(t),1);

    %% Transmitter
    sdrTransmitter = sdrtx(deviceNameSDR);
    sdrTransmitter.RadioID = 'usb:0';
    sdrTransmitter.BasebandSampleRate = samp_rate;
    sdrTransmitter.CenterFrequency = 915e6;
    sdrTransmitter.ShowAdvancedProperties = true;
    sdrTransmitter.Gain = txGain;

    %% Receiver
    sdrReceiver = sdrrx(deviceNameSDR);
    sdrReceiver.RadioID = 'usb:0';
    sdrReceiver.BasebandSampleRate = samp_rate;
    sdrReceiver.CenterFrequency = sdrTransmitter.CenterFrequency;
    sdrReceiver.GainSource = 'Manual';
    sdrReceiver.Gain = rxGain;
    sdrReceiver.OutputDataType = 'double';

    %% Transmit and capture
    captureLen = frameLen;
    fprintf('Collecting: %s, height=%dml, trial=%d...\n', liquidName, height_ml, trialNum);
    sdrTransmitter.transmitRepeat(txWave);
    pause(0.5);  % Let signal stabilize
    burstCaptures = capture(sdrReceiver, captureLen, 'Samples');
    release(sdrTransmitter);

    %% Save data
    dataDir = fullfile(pwd, 'data');
    if ~exist(dataDir, 'dir')
        mkdir(dataDir);
    end

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('%s_%dml_trial%d_%s.mat', liquidName, height_ml, trialNum, timestamp);
    savePath = fullfile(dataDir, filename);

    % Save parameters along with raw data
    params.samp_rate = samp_rate;
    params.txGain = txGain;
    params.rxGain = rxGain;
    params.if_freq = if_freq;
    params.centerFreq = sdrTransmitter.CenterFrequency;
    params.frameLen = frameLen;
    params.liquidName = liquidName;
    params.height_ml = height_ml;
    params.trialNum = trialNum;
    params.timestamp = timestamp;

    save(savePath, 'burstCaptures', 'txWave', 't', 'params');
    fprintf('Saved to: %s\n', savePath);
end
