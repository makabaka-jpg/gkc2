function results = classifyLiquids(dataDir, opts)
%CLASSIFYLIQUIDS Train a lightweight liquid classifier from staged captures.
%   Each capture is one 15-second experiment:
%     0-5 s   empty cup baseline
%     5-10 s  transition
%     10-15 s target liquid
%
%   The classifier uses only the baseline-to-measurement phase difference,
%   encoded as sine/cosine to avoid angle wrap-around issues.

    paths = projectPaths();
    if nargin < 1 || isempty(dataDir)
        dataDir = paths.data;
    end
    if nargin < 2
        opts = struct();
    end
    opts = fillClassifyDefaults(opts);

    [X, y, fileNames, classNames, phaseDeg, selectedHeightMl] = buildClassificationDataset(dataDir, opts);
    numClasses = numel(classNames);
    if numClasses < 2
        error('Need at least 2 liquid classes for classification.');
    end

    fprintf('=== Lightweight Liquid Classification ===\n');
    fprintf('Data directory: %s\n', dataDir);
    fprintf('Usable files  : %d\n', numel(fileNames));
    fprintf('Feature set   : phase difference only (sin/cos)\n');
    if ~isnan(selectedHeightMl)
        fprintf('Training height: %g ml\n', selectedHeightMl);
    else
        fprintf('Training height: mixed heights\n');
    end

    foldAssignments = createStratifiedFolds(y, opts.kFolds, opts.randomSeed);
    predicted = zeros(size(y));
    for fold = 1:max(foldAssignments)
        trainMask = (foldAssignments ~= fold);
        testMask = (foldAssignments == fold);
        model = fitCentroidClassifier(X(trainMask, :), y(trainMask), classNames);
        predicted(testMask) = predictCentroidClassifier(model, X(testMask, :));
    end

    confusion = confusionMatrixLocal(y, predicted, numClasses);
    [accuracy, macroF1] = scoreConfusion(confusion);
    fprintf('Cross-val accuracy: %.2f%%\n', 100 * accuracy);
    fprintf('Cross-val macro F1: %.2f%%\n', 100 * macroF1);

    finalModel = fitCentroidClassifier(X, y, classNames);

    modelDir = paths.models;
    if ~exist(modelDir, 'dir')
        mkdir(modelDir);
    end
    modelPath = fullfile(modelDir, sprintf('liquidClassifier_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));

    artifact = struct();
    artifact.modelType = 'nearest-centroid-phase-diff';
    artifact.classNames = classNames;
    artifact.featureNames = {'phase_diff_sin', 'phase_diff_cos'};
    artifact.preprocess = finalModel.preprocess;
    artifact.classCentroids = finalModel.classCentroids;
    artifact.options = opts;
    artifact.trainingSummary = struct( ...
        'fileNames', {fileNames}, ...
        'labels', y, ...
        'classNames', {classNames}, ...
        'selectedHeightMl', selectedHeightMl, ...
        'phaseDiffDeg', phaseDeg, ...
        'confusionMatrix', confusion, ...
        'accuracy', accuracy, ...
        'macroF1', macroF1);
    save(modelPath, '-struct', 'artifact');

    plotConfusionMatrix(confusion, classNames, ...
        sprintf('Classification Confusion Matrix (Acc=%.1f%%)', 100 * accuracy));
    plotPhaseScatter(phaseDeg, y, classNames);

    results = struct();
    results.modelPath = modelPath;
    results.classNames = classNames;
    results.fileAccuracy = accuracy;
    results.macroF1 = macroF1;
    results.confusionMatrix = confusion;
    results.phaseDiffDeg = phaseDeg;
    results.fileNames = fileNames;
    results.selectedHeightMl = selectedHeightMl;

    fprintf('Saved trained classifier to: %s\n', modelPath);
end

function opts = fillClassifyDefaults(opts)
    defaults.baselineDurationSec = 5;
    defaults.transitionDurationSec = 5;
    defaults.measurementDurationSec = 5;
    defaults.segmentLength = 1e4;
    defaults.numCandidateStarts = 25;
    defaults.kFolds = 5;
    defaults.randomSeed = 7;

    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end
end

function [X, y, fileNames, classNames, phaseDeg, selectedHeightMl] = buildClassificationDataset(dataDir, opts)
    if ~exist(dataDir, 'dir')
        error('Data directory not found: %s', dataDir);
    end

    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in %s', dataDir);
    end

    rows = struct('label', {}, 'heightMl', {}, 'featureRow', {}, 'phaseDeg', {}, 'fileName', {});

    for i = 1:numel(files)
        data = load(fullfile(dataDir, files(i).name));
        if ~isfield(data, 'burstCaptures') || ~isfield(data, 'params')
            continue;
        end
        if ~isfield(data.params, 'liquidName') || ~isfield(data.params, 'samp_rate')
            continue;
        end

        label = char(string(data.params.liquidName));
        if strcmpi(label, 'unknown')
            continue;
        end
        if ~isfield(data.params, 'height_ml') || ~isfinite(double(data.params.height_ml))
            continue;
        end

        info = extractCoreFeatures(data.burstCaptures, double(data.params.samp_rate), opts);
        rows(end + 1).label = label; %#ok<AGROW>
        rows(end).heightMl = double(data.params.height_ml);
        rows(end).featureRow = info.classificationFeatures(1:2);
        rows(end).phaseDeg = info.phaseDiffDeg;
        rows(end).fileName = files(i).name;
    end

    if isempty(rows)
        error('No usable classification files were found in %s', dataDir);
    end

    selectedHeightMl = chooseSharedClassificationHeight(rows);
    if ~isnan(selectedHeightMl)
        keepMask = arrayfun(@(r) abs(r.heightMl - selectedHeightMl) < 1e-9, rows);
        rows = rows(keepMask);
    end

    X = [];
    y = [];
    phaseDeg = [];
    fileNames = {};
    classNames = {};
    classMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:numel(rows)
        label = rows(i).label;
        if ~isKey(classMap, label)
            classMap(label) = numel(classNames) + 1;
            classNames{end + 1} = label; %#ok<AGROW>
        end
        X(end + 1, :) = rows(i).featureRow; %#ok<AGROW>
        y(end + 1, 1) = classMap(label); %#ok<AGROW>
        phaseDeg(end + 1, 1) = rows(i).phaseDeg; %#ok<AGROW>
        fileNames{end + 1, 1} = rows(i).fileName; %#ok<AGROW>
    end
end

function selectedHeightMl = chooseSharedClassificationHeight(rows)
    heights = unique([rows.heightMl]);
    selectedHeightMl = NaN;
    bestClassCount = 0;
    bestFileCount = 0;

    for i = 1:numel(heights)
        h = heights(i);
        mask = abs([rows.heightMl] - h) < 1e-9;
        labels = {rows(mask).label};
        classCount = numel(unique(labels));
        fileCount = nnz(mask);
        if classCount > bestClassCount || (classCount == bestClassCount && fileCount > bestFileCount)
            bestClassCount = classCount;
            bestFileCount = fileCount;
            selectedHeightMl = h;
        end
    end

    if bestClassCount < 2
        selectedHeightMl = NaN;
    end
end

function foldAssignments = createStratifiedFolds(y, requestedFolds, seed)
    rng(seed);
    n = numel(y);
    foldAssignments = zeros(n, 1);
    classes = unique(y(:))';

    minCount = inf;
    for i = 1:numel(classes)
        minCount = min(minCount, nnz(y == classes(i)));
    end
    if minCount < 2
        error('Need at least 2 files per class for cross-validation.');
    end

    k = max(2, min(requestedFolds, minCount));
    for i = 1:numel(classes)
        idx = find(y == classes(i));
        idx = idx(randperm(numel(idx)));
        for j = 1:numel(idx)
            foldAssignments(idx(j)) = mod(j - 1, k) + 1;
        end
    end
end

function model = fitCentroidClassifier(X, y, classNames)
    preprocess.mean = mean(X, 1);
    preprocess.std = std(X, 0, 1);
    preprocess.std(preprocess.std < 1e-10) = 1;
    Xz = (X - preprocess.mean) ./ preprocess.std;

    numClasses = numel(classNames);
    classCentroids = zeros(numClasses, size(X, 2));
    for i = 1:numClasses
        classCentroids(i, :) = mean(Xz(y == i, :), 1);
    end

    model = struct();
    model.preprocess = preprocess;
    model.classCentroids = classCentroids;
    model.classNames = classNames;
end

function predicted = predictCentroidClassifier(model, X)
    Xz = (X - model.preprocess.mean) ./ model.preprocess.std;
    predicted = zeros(size(X, 1), 1);
    for i = 1:size(Xz, 1)
        diffMat = model.classCentroids - Xz(i, :);
        distances = sum(diffMat .^ 2, 2);
        [~, predicted(i)] = min(distances);
    end
end

function confusion = confusionMatrixLocal(actual, predicted, classCount)
    confusion = zeros(classCount, classCount);
    for i = 1:numel(actual)
        confusion(actual(i), predicted(i)) = confusion(actual(i), predicted(i)) + 1;
    end
end

function [accuracy, macroF1] = scoreConfusion(confusion)
    accuracy = sum(diag(confusion)) / max(sum(confusion(:)), 1);
    f1 = zeros(size(confusion, 1), 1);
    for i = 1:size(confusion, 1)
        tp = confusion(i, i);
        precision = tp / max(sum(confusion(:, i)), 1);
        recall = tp / max(sum(confusion(i, :)), 1);
        f1(i) = 2 * precision * recall / max(precision + recall, 1e-12);
    end
    macroF1 = mean(f1);
end

function plotConfusionMatrix(confusion, classNames, plotTitle)
    figure('Position', [100, 100, 720, 560]);
    imagesc(confusion);
    axis image;
    colormap(parula);
    colorbar;
    set(gca, 'XTick', 1:numel(classNames), 'XTickLabel', classNames);
    set(gca, 'YTick', 1:numel(classNames), 'YTickLabel', classNames);
    xlabel('Predicted');
    ylabel('Actual');
    title(plotTitle);
    for r = 1:size(confusion, 1)
        for c = 1:size(confusion, 2)
            text(c, r, num2str(confusion(r, c)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
end

function plotPhaseScatter(phaseDeg, y, classNames)
    figure('Position', [130, 130, 760, 420]);
    hold on;
    colors = lines(numel(classNames));
    for i = 1:numel(classNames)
        idx = find(y == i);
        jitter = 0.08 * (rand(size(idx)) - 0.5);
        scatter(i + jitter, phaseDeg(idx), 48, 'filled', ...
            'MarkerFaceColor', colors(i, :));
    end
    hold off;
    xlim([0.5, numel(classNames) + 0.5]);
    set(gca, 'XTick', 1:numel(classNames), 'XTickLabel', classNames);
    ylabel('Phase difference (deg)');
    title('Phase-difference distribution by liquid');
    grid on;
end
