function result = predictHeightFromCapture(captureInput, modelPath)
%PREDICTHEIGHTFROMCAPTURE Predict liquid height/volume from one staged capture.
%   The prediction uses amplitude-only features from the final 5-second
%   measurement stage of the 15-second protocol.

    if nargin < 1 || isempty(captureInput)
        error('predictHeightFromCapture requires a .mat file path or loaded struct.');
    end
    if nargin < 2 || isempty(modelPath)
        modelPath = findLatestHeightModel();
    end

    artifact = load(modelPath);
    [data, capturePath] = loadCaptureInput(captureInput);

    if ~isfield(data, 'burstCaptures') || ~isfield(data, 'params')
        error('Input capture must contain burstCaptures and params.');
    end

    info = extractCoreFeatures(data.burstCaptures, double(data.params.samp_rate), artifact.options);
    yPred = predictLinearHeightModelLocal(artifact, info.heightFeatures);

    result = struct();
    result.capturePath = capturePath;
    result.modelPath = modelPath;
    result.liquidName = artifact.liquidName;
    result.predictedHeightMl = yPred;
    result.measurementAmpMean = info.measurementAmpMean;
    result.measurementAmpStd = info.measurementAmpStd;
    result.ampRatioDb = info.ampRatioDb;

    fprintf('\nPredicted %s height: %.1f ml\n', artifact.liquidName, yPred);
    fprintf('Measurement amp mean: %.6f\n', result.measurementAmpMean);
    fprintf('Measurement amp std : %.6f\n', result.measurementAmpStd);
    fprintf('Amplitude ratio     : %.2f dB\n', result.ampRatioDb);
end

function yPred = predictLinearHeightModelLocal(artifact, X)
    Xz = (X - artifact.preprocess.mean) ./ artifact.preprocess.std;
    design = [1, Xz];
    yPred = design * artifact.beta;
end

function [data, capturePath] = loadCaptureInput(captureInput)
    if ischar(captureInput) || isstring(captureInput)
        capturePath = char(captureInput);
        data = load(capturePath);
    else
        capturePath = '<in-memory>';
        data = captureInput;
    end
end

function modelPath = findLatestHeightModel()
    modelDir = projectPaths().models;
    files = dir(fullfile(modelDir, 'heightModel_*.mat'));
    if isempty(files)
        error('No saved height model found in %s. Run trainHeightModel first.', modelDir);
    end
    [~, idx] = max([files.datenum]);
    modelPath = fullfile(modelDir, files(idx).name);
end
