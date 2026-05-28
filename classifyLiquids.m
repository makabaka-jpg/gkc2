%% classifyLiquids.m - Liquid type classification using backscatter signals
% Loads all .mat files from ./data/ and performs classification

function classifyLiquids()
    dataDir = fullfile(pwd, 'data');
    if ~exist(dataDir, 'dir')
        error('Data directory not found. Run collectData first.');
    end

    %% Load all data files
    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in ./data/');
    end

    fprintf('Found %d data files.\n', length(files));

    allFeatures = [];
    allLabels = {};
    fileInfo = {};

    for i = 1:length(files)
        data = load(fullfile(dataDir, files(i).name));
        if ~isfield(data, 'params')
            fprintf('Skipping %s (no params field)\n', files(i).name);
            continue;
        end

        feat = extractFeatures(data.burstCaptures, data.params);
        allFeatures = [allFeatures; feat];
        allLabels{end+1} = data.params.liquidName;
        fileInfo{end+1} = files(i).name;
        fprintf('Loaded: %s\n', files(i).name);
    end

    uniqueLiquids = unique(allLabels);
    nClasses = length(uniqueLiquids);
    fprintf('\nFound %d liquid classes: %s\n', nClasses, strjoin(uniqueLiquids, ', '));

    if nClasses < 2
        error('Need at least 2 liquid classes for classification.');
    end

    %% Prepare feature matrix and labels
    X = allFeatures;
    % Normalize features
    X_mean = mean(X, 1);
    X_std = std(X, 1);
    X_norm = (X - X_mean) ./ (X_std + 1e-10);

    % Convert string labels to numeric
    y = zeros(size(allLabels));
    for i = 1:length(allLabels)
        y(i) = find(strcmp(uniqueLiquids, allLabels{i}));
    end

    %% Feature importance (simple ANOVA-style ranking)
    fprintf('\n--- Feature Ranking (F-ratio) ---\n');
    featureNames = {'meanAmp','stdAmp','varAmp','rmsAmp','meanPhase','stdPhase', ...
                    'peakFreq','peakMag','meanSpectrum','stdSpectrum','totalPower', ...
                    'iqReal','iqImag','iqSpread_real','iqSpread_imag','iqRadius'};

    for fIdx = 1:size(X, 2)
        groupMeans = zeros(nClasses, 1);
        groupVars = zeros(nClasses, 1);
        for c = 1:nClasses
            mask = (y == c);
            groupMeans(c) = mean(X(mask, fIdx));
            groupVars(c) = var(X(mask, fIdx));
        end
        overallMean = mean(X(:, fIdx));
        ssBetween = sum(arrayfun(@(c) sum(y == c) * (groupMeans(c) - overallMean)^2, 1:nClasses));
        ssWithin = sum(arrayfun(@(c) (sum(y == c) - 1) * groupVars(c), 1:nClasses));
        fRatio = (ssBetween / (nClasses - 1)) / (ssWithin / (length(y) - nClasses));
        if fIdx <= length(featureNames)
            fprintf('  %-18s F=%.2f\n', featureNames{fIdx}, fRatio);
        end
    end

    %% PCA visualization
    [coeff, score, ~, ~, explained] = pca(X_norm);
    figure('Position', [100, 100, 800, 600]);
    colors = lines(nClasses);
    hold on;
    for c = 1:nClasses
        mask = (y == c);
        scatter(score(mask, 1), score(mask, 2), 80, colors(c, :), 'filled', ...
                'DisplayName', uniqueLiquids{c});
    end
    xlabel(sprintf('PC1 (%.1f%%)', explained(1)));
    ylabel(sprintf('PC2 (%.1f%%)', explained(2)));
    title(sprintf('PCA: Liquid Classification (%d classes, %d samples)', nClasses, length(y)));
    legend('Location', 'best');
    grid on;
    hold off;

    %% Cross-validation with multiple classifiers
    cv = cvpartition(y, 'KFold', min(5, min(histcounts(y))));

    % KNN
    knnModel = fitcknn(X_norm, y, 'OptimizeHyperparameters', 'auto', ...
                       'HyperparameterOptimizationOptions', ...
                       struct('ShowPlots', false, 'Verbose', 0));
    knnPred = kfoldPredict(crossval(knnModel, 'CVPartition', cv));
    knnAcc = sum(knnPred == y) / length(y);

    % SVM
    if nClasses > 2
        svmTemplate = templateSVM('Standardize', true);
        svmModel = fitcecoc(X_norm, y, 'Learners', svmTemplate);
    else
        svmModel = fitcsvm(X_norm, y, 'Standardize', true);
    end
    svmPred = kfoldPredict(crossval(svmModel, 'CVPartition', cv));
    svmAcc = sum(svmPred == y) / length(y);

    fprintf('\n--- Classification Results (%d-fold CV) ---\n', cv.NumTestSets);
    fprintf('  KNN Accuracy: %.1f%%\n', knnAcc * 100);
    fprintf('  SVM Accuracy: %.1f%%\n', svmAcc * 100);

    %% Confusion matrix (using best model)
    [bestAcc, bestIdx] = max([knnAcc, svmAcc]);
    if bestIdx == 1
        bestModel = knnModel;
    else
        bestModel = svmModel;
    end

    yPred = predict(bestModel, X_norm);
    figure;
    confusionchart(y, yPred, uniqueLiquids);
    title(sprintf('Confusion Matrix (Best: %.1f%%)', bestAcc * 100));
end

%% Sub-function: extract feature vector from raw signal
function featVec = extractFeatures(burstCaptures, params)
    N = length(burstCaptures);
    fs = params.samp_rate;
    amp = abs(burstCaptures);
    phase = unwrap(angle(burstCaptures));

    % Amplitude features
    f1 = mean(amp);
    f2 = std(amp);
    f3 = var(amp);
    f4 = rms(amp);

    % Phase features
    f5 = mean(phase);
    f6 = std(phase);

    % Frequency domain
    X = fft(burstCaptures, N);
    X_mag = abs(X);
    delta_f = fs / N;
    lo = round(5e3 / delta_f);
    hi = round(15e3 / delta_f);
    band = X_mag(lo:hi);
    freqBand = (lo:hi)' * delta_f;

    [peakVal, peakLocalIdx] = max(band);
    f7 = freqBand(peakLocalIdx);
    f8 = peakVal;
    f9 = mean(band);
    f10 = std(band);
    f11 = sum(band.^2);

    % IQ plane features
    iqCenter = mean(burstCaptures);
    f12 = real(iqCenter);
    f13 = imag(iqCenter);
    f14 = std(real(burstCaptures));
    f15 = std(imag(burstCaptures));
    f16 = mean(abs(burstCaptures - iqCenter));

    featVec = [f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16];
end
