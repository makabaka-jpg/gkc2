function results = trainHeightModel(liquidName, dataDir, opts)
%TRAINHEIGHTMODEL Train a lightweight amplitude-only height model.
%   The model uses only measurement-stage amplitude features from the
%   15-second staged capture:
%     0-5 s   empty cup baseline
%     5-10 s  transition
%     10-15 s target liquid

    if nargin < 1 || isempty(liquidName)
        liquidName = 'water';
    end
    if nargin < 2 || isempty(dataDir)
        dataDir = projectPaths().data;
    end
    if nargin < 3
        opts = struct();
    end
    opts = fillHeightDefaults(opts);

    [X, y, fileNames, featureNames] = buildHeightDataset(liquidName, dataDir, opts);
    if numel(unique(y)) < 2
        error('Need at least 2 distinct height levels for %s.', liquidName);
    end

    model = fitLinearHeightModel(X, y, opts);
    trainPred = predictLinearHeightModel(model, X);
    [rmse, mae, r2] = regressionMetrics(y, trainPred);

    looPred = leaveOneOutPredictions(X, y, opts);
    [looRmse, looMae, looR2] = regressionMetrics(y, looPred);

    fprintf('=== Lightweight Height Model ===\n');
    fprintf('Liquid         : %s\n', liquidName);
    fprintf('Usable files   : %d\n', numel(fileNames));
    fprintf('Feature set    : amplitude only\n');
    fprintf('Train RMSE     : %.1f ml\n', rmse);
    fprintf('Train MAE      : %.1f ml\n', mae);
    fprintf('Train R^2      : %.3f\n', r2);
    fprintf('LOO RMSE       : %.1f ml\n', looRmse);
    fprintf('LOO MAE        : %.1f ml\n', looMae);
    fprintf('LOO R^2        : %.3f\n', looR2);

    modelDir = projectPaths().models;
    if ~exist(modelDir, 'dir')
        mkdir(modelDir);
    end
    modelPath = fullfile(modelDir, sprintf('heightModel_%s_%s.mat', liquidName, datestr(now, 'yyyymmdd_HHMMSS')));

    artifact = struct();
    artifact.modelType = 'linear-amplitude-only';
    artifact.beta = model.beta;
    artifact.preprocess = model.preprocess;
    artifact.featureNames = featureNames;
    artifact.options = opts;
    artifact.liquidName = liquidName;
    artifact.trainingFileNames = fileNames;
    artifact.trainingHeights = unique(y);
    artifact.trainingHeightRange = [min(y), max(y)];
    artifact.trainingMetrics = struct( ...
        'trainRMSE', rmse, ...
        'trainMAE', mae, ...
        'trainR2', r2, ...
        'looRMSE', looRmse, ...
        'looMAE', looMae, ...
        'looR2', looR2);
    save(modelPath, '-struct', 'artifact');

    plotHeightFit(y, trainPred, liquidName, 'Training fit');
    plotHeightFit(y, looPred, liquidName, 'Leave-one-out fit');
    plotFeatureVsHeight(X, y, featureNames, liquidName);

    results = struct();
    results.modelPath = modelPath;
    results.liquidName = liquidName;
    results.trainRMSE = rmse;
    results.trainMAE = mae;
    results.trainR2 = r2;
    results.looRMSE = looRmse;
    results.looMAE = looMae;
    results.looR2 = looR2;
    results.featureNames = featureNames;
    results.fileNames = fileNames;
    fprintf('Saved height model to: %s\n', modelPath);
end

function opts = fillHeightDefaults(opts)
    defaults.baselineDurationSec = 5;
    defaults.transitionDurationSec = 5;
    defaults.measurementDurationSec = 5;
    defaults.segmentLength = 1e4;
    defaults.numCandidateStarts = 25;
    defaults.ridgeLambda = 1e-3;

    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end
end

function [X, y, fileNames, featureNames] = buildHeightDataset(liquidName, dataDir, opts)
    if ~exist(dataDir, 'dir')
        error('Data directory not found: %s', dataDir);
    end

    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in %s', dataDir);
    end

    X = [];
    y = [];
    fileNames = {};
    featureNames = {};

    for i = 1:numel(files)
        data = load(fullfile(dataDir, files(i).name));
        if ~isfield(data, 'burstCaptures') || ~isfield(data, 'params')
            continue;
        end
        if ~isfield(data.params, 'liquidName') || ~strcmpi(data.params.liquidName, liquidName)
            continue;
        end
        if ~isfield(data.params, 'height_ml') || ~isfinite(double(data.params.height_ml))
            continue;
        end

        info = extractCoreFeatures(data.burstCaptures, double(data.params.samp_rate), opts);
        X(end + 1, :) = info.heightFeatures; %#ok<AGROW>
        y(end + 1, 1) = double(data.params.height_ml); %#ok<AGROW>
        fileNames{end + 1, 1} = files(i).name; %#ok<AGROW>
        featureNames = info.heightFeatureNames;
    end

    if isempty(X)
        error('No usable %s training captures were found in %s', liquidName, dataDir);
    end
end

function model = fitLinearHeightModel(X, y, opts)
    preprocess.mean = mean(X, 1);
    preprocess.std = std(X, 0, 1);
    preprocess.std(preprocess.std < 1e-10) = 1;
    Xz = (X - preprocess.mean) ./ preprocess.std;

    design = [ones(size(Xz, 1), 1), Xz];
    reg = diag([0, opts.ridgeLambda * ones(1, size(Xz, 2))]);
    beta = (design' * design + reg) \ (design' * y);

    model = struct();
    model.beta = beta;
    model.preprocess = preprocess;
end

function yPred = predictLinearHeightModel(model, X)
    Xz = (X - model.preprocess.mean) ./ model.preprocess.std;
    design = [ones(size(Xz, 1), 1), Xz];
    yPred = design * model.beta;
end

function looPred = leaveOneOutPredictions(X, y, opts)
    looPred = zeros(size(y));
    for i = 1:size(X, 1)
        trainMask = true(size(y));
        trainMask(i) = false;
        model = fitLinearHeightModel(X(trainMask, :), y(trainMask), opts);
        looPred(i) = predictLinearHeightModel(model, X(i, :));
    end
end

function [rmse, mae, r2] = regressionMetrics(yTrue, yPred)
    rmse = sqrt(mean((yTrue - yPred) .^ 2));
    mae = mean(abs(yTrue - yPred));
    r2 = 1 - sum((yTrue - yPred) .^ 2) / max(sum((yTrue - mean(yTrue)) .^ 2), 1e-12);
end

function plotHeightFit(yTrue, yPred, liquidName, plotTitle)
    figure('Position', [100, 100, 720, 520]);
    scatter(yTrue, yPred, 60, 'filled');
    hold on;
    plot([min(yTrue), max(yTrue)], [min(yTrue), max(yTrue)], 'r--', 'LineWidth', 1.4);
    hold off;
    xlabel('Actual height (ml)');
    ylabel('Predicted height (ml)');
    title(sprintf('%s: %s', liquidName, plotTitle));
    axis equal;
    grid on;
end

function plotFeatureVsHeight(X, y, featureNames, liquidName)
    figure('Position', [120, 120, 1080, 320]);
    for i = 1:size(X, 2)
        subplot(1, size(X, 2), i);
        scatter(y, X(:, i), 45, 'filled');
        xlabel('Height (ml)');
        ylabel(featureNames{i}, 'Interpreter', 'none');
        title(sprintf('%s vs height', featureNames{i}), 'Interpreter', 'none');
        grid on;
    end
    sgtitle(sprintf('Amplitude features for %s', liquidName));
end
