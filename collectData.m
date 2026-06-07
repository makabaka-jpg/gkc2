function savePath = collectData(liquidName, height_ml, trialNum, opts)
%COLLECTDATA Collect one 15-second staged SDR capture.
%   SAVEPATH = COLLECTDATA(LIQUIDNAME, HEIGHT_ML) records one experiment
%   using the fixed protocol:
%     0-5 s   empty cup
%     5-10 s  replace with target liquid
%     10-15 s hold target liquid steady
%
%   This protocol is designed for:
%     1. Liquid classification using baseline-to-liquid phase difference
%     2. Height estimation using liquid-stage amplitude features only

    if nargin < 1 || isempty(liquidName)
        error('collectData requires liquidName.');
    end
    if nargin < 2 || isempty(height_ml)
        height_ml = 0;
    end
    if nargin < 3
        trialNum = [];
    end
    if nargin < 4
        opts = struct();
    end

    opts = fillCollectDefaults(opts);
    paths = projectPaths();
    ensureFolder(paths.data);

    if isempty(trialNum)
        trialNum = inferNextTrial(paths.data, liquidName, height_ml);
    end

    captureDurationSec = opts.baselineDurationSec + opts.transitionDurationSec + opts.measurementDurationSec;
    frameLen = round(captureDurationSec * opts.sampRate);
    if frameLen < 1
        error('Capture duration is too short.');
    end

    if round(opts.segmentLength) >= round(opts.baselineDurationSec * opts.sampRate)
        error('segmentLength must be shorter than the 5-second baseline window.');
    end
    if round(opts.segmentLength) >= round(opts.measurementDurationSec * opts.sampRate)
        error('segmentLength must be shorter than the 5-second measurement window.');
    end

    deviceNameSDR = 'Pluto';
    sdrdev(deviceNameSDR);

    txWave = createTxWave(opts);
    sdrTransmitter = createTransmitter(deviceNameSDR, opts);
    sdrReceiver = createReceiver(deviceNameSDR, opts);

    printProtocol(liquidName, height_ml, trialNum, captureDurationSec);
    input('Press Enter when you are ready to start the 15-second capture: ', 's');

    sdrTransmitter.transmitRepeat(txWave);
    pause(opts.settleTimeSec);

    fprintf('Capture started. Follow the timeline now.\n');
    fprintf('  0-5 s  : keep EMPTY cup steady\n');
    fprintf('  5-10 s : replace with target liquid\n');
    fprintf('  10-15 s: keep target liquid steady\n');

    burstCaptures = capture(sdrReceiver, frameLen, 'Samples');

    release(sdrTransmitter);
    release(sdrReceiver);

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    if isnumeric(height_ml) && isfinite(height_ml)
        heightToken = sprintf('%gml', height_ml);
    else
        heightToken = 'unknownml';
    end
    fileName = sprintf('%s_%s_trial%d_%s.mat', liquidName, heightToken, trialNum, timestamp);
    savePath = fullfile(paths.data, fileName);

    params = struct();
    params.samp_rate = opts.sampRate;
    params.txGain = opts.txGain;
    params.rxGain = opts.rxGain;
    params.if_freq = opts.ifFreq;
    params.centerFreq = opts.centerFreq;
    params.frameLen = frameLen;
    params.captureDurationSec = captureDurationSec;
    params.baselineDurationSec = opts.baselineDurationSec;
    params.transitionDurationSec = opts.transitionDurationSec;
    params.measurementDurationSec = opts.measurementDurationSec;
    params.featureSegmentLength = opts.segmentLength;
    params.radioId = opts.radioId;
    params.signalMode = opts.signalMode;
    params.txWaveDurationSec = opts.txWaveDurationSec;
    params.liquidName = liquidName;
    params.height_ml = height_ml;
    params.trialNum = trialNum;
    params.timestamp = timestamp;
    params.protocol = '0-5s empty, 5-10s transition, 10-15s target';

    save(savePath, 'burstCaptures', 'params', '-v7.3');
    fprintf('Saved to: %s\n', savePath);
end

function opts = fillCollectDefaults(opts)
    defaults.baselineDurationSec = 5;
    defaults.transitionDurationSec = 5;
    defaults.measurementDurationSec = 5;
    defaults.segmentLength = 1e4;
    defaults.sampRate = 2e5;
    defaults.txGain = 0;
    defaults.rxGain = 10;
    defaults.ifFreq = 10e3;
    defaults.centerFreq = 915e6;
    defaults.radioId = 'usb:0';
    defaults.signalMode = 'tag';
    defaults.settleTimeSec = 0.4;
    defaults.txWaveDurationSec = 0.10;

    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end
end

function printProtocol(liquidName, height_ml, trialNum, captureDurationSec)
    fprintf('\n==========================================\n');
    fprintf('  Staged Capture Protocol\n');
    fprintf('==========================================\n');
    fprintf('Liquid   : %s\n', liquidName);
    if isnumeric(height_ml) && isfinite(height_ml)
        fprintf('Height   : %g ml\n', height_ml);
    else
        fprintf('Height   : unknown\n');
    end
    fprintf('Trial    : %d\n', trialNum);
    fprintf('Duration : %.1f s\n', captureDurationSec);
    fprintf('\nProtocol:\n');
    fprintf('  0-5 s   empty cup\n');
    fprintf('  5-10 s  replace with target liquid\n');
    fprintf('  10-15 s keep target liquid steady\n\n');
end

function ensureFolder(folderPath)
    if ~exist(folderPath, 'dir')
        mkdir(folderPath);
    end
end

function trialNum = inferNextTrial(dataDir, liquidName, height_ml)
    if isnumeric(height_ml) && isfinite(height_ml)
        heightToken = sprintf('%gml', height_ml);
    else
        heightToken = 'unknownml';
    end
    pattern = sprintf('%s_%s_trial*.mat', liquidName, heightToken);
    files = dir(fullfile(dataDir, pattern));
    trials = [];
    for i = 1:numel(files)
        token = regexp(files(i).name, 'trial(\d+)', 'tokens', 'once');
        if ~isempty(token)
            trials(end + 1) = str2double(token{1}); %#ok<AGROW>
        end
    end
    if isempty(trials)
        trialNum = 1;
    else
        trialNum = max(trials) + 1;
    end
end

function txWave = createTxWave(opts)
    txLen = max(1024, round(opts.txWaveDurationSec * opts.sampRate));
    switch lower(opts.signalMode)
        case 'tone'
            t = (0:txLen - 1)' / opts.sampRate;
            txWave = exp(1j * 2 * pi * opts.ifFreq * t);
        otherwise
            txWave = complex(ones(txLen, 1, 'single'), ones(txLen, 1, 'single'));
    end
end

function sdrTransmitter = createTransmitter(deviceNameSDR, opts)
    sdrTransmitter = sdrtx(deviceNameSDR);
    sdrTransmitter.RadioID = opts.radioId;
    sdrTransmitter.BasebandSampleRate = opts.sampRate;
    sdrTransmitter.CenterFrequency = opts.centerFreq;
    sdrTransmitter.ShowAdvancedProperties = true;
    sdrTransmitter.Gain = opts.txGain;
end

function sdrReceiver = createReceiver(deviceNameSDR, opts)
    sdrReceiver = sdrrx(deviceNameSDR);
    sdrReceiver.RadioID = opts.radioId;
    sdrReceiver.BasebandSampleRate = opts.sampRate;
    sdrReceiver.CenterFrequency = opts.centerFreq;
    sdrReceiver.GainSource = 'Manual';
    sdrReceiver.Gain = opts.rxGain;
    sdrReceiver.OutputDataType = 'single';
end
