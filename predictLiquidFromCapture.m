function result = predictLiquidFromCapture(captureInput, modelPath)
%PREDICTLIQUIDFROMCAPTURE Predict liquid type from one staged capture.
%   The classifier uses the phase difference between:
%     1. a short empty-cup baseline segment in the first 5 seconds
%     2. a short steady liquid segment in the last 5 seconds

    if nargin < 1 || isempty(captureInput)
        error('predictLiquidFromCapture requires a .mat file path or loaded struct.');
    end
    if nargin < 2 || isempty(modelPath)
        modelPath = findLatestClassifierModel();
    end

    artifact = load(modelPath);
    [data, capturePath] = loadCaptureInput(captureInput);

    if ~isfield(data, 'burstCaptures') || ~isfield(data, 'params')
        error('Input capture must contain burstCaptures and params.');
    end

    info = extractCoreFeatures(data.burstCaptures, double(data.params.samp_rate), artifact.options);
    X = info.classificationFeatures(1:2);
    [predictedId, distances] = predictCentroidClassifierLocal(artifact, X);

    invDistances = 1 ./ max(distances, 1e-12);
    confidence = max(invDistances) / sum(invDistances);

    result = struct();
    result.capturePath = capturePath;
    result.modelPath = modelPath;
    result.predictedClass = artifact.classNames{predictedId};
    result.predictedClassId = predictedId;
    result.phaseDiffRad = info.phaseDiffRad;
    result.phaseDiffDeg = info.phaseDiffDeg;
    result.classDistances = distances;
    result.confidence = confidence;

    fprintf('\nPredicted liquid class: %s\n', result.predictedClass);
    fprintf('Phase difference      : %.2f deg\n', result.phaseDiffDeg);
    fprintf('Confidence            : %.1f%%\n', 100 * result.confidence);
end

function [predictedId, distances] = predictCentroidClassifierLocal(artifact, X)
    Xz = (X - artifact.preprocess.mean) ./ artifact.preprocess.std;
    diffMat = artifact.classCentroids - Xz;
    distances = sum(diffMat .^ 2, 2);
    [~, predictedId] = min(distances);
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

function modelPath = findLatestClassifierModel()
    modelDir = projectPaths().models;
    files = dir(fullfile(modelDir, 'liquidClassifier_*.mat'));
    if isempty(files)
        error('No saved classifier found in %s. Run classifyLiquids first.', modelDir);
    end
    [~, idx] = max([files.datenum]);
    modelPath = fullfile(modelDir, files(idx).name);
end
