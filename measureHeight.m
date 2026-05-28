%% measureHeight.m - Liquid height measurement from backscatter signals
% Loads data for a single liquid type at different heights and builds a
% regression model to estimate height from signal features.

function measureHeight(liquidName)
    if nargin < 1
        liquidName = 'water';
    end

    dataDir = fullfile(pwd, 'data');
    if ~exist(dataDir, 'dir')
        error('Data directory not found. Run collectData first.');
    end

    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in ./data/');
    end

    %% Load data matching the specified liquid
    heights = [];
    featureList = [];

    for i = 1:length(files)
        data = load(fullfile(dataDir, files(i).name));
        if ~isfield(data, 'params'), continue; end
        if ~strcmpi(data.params.liquidName, liquidName), continue; end

        feat = extractHeightFeatures(data.burstCaptures, data.params);
        featureList = [featureList; feat];
        heights = [heights; data.params.height_ml];
        fprintf('Loaded: %s (height=%dml)\n', files(i).name, data.params.height_ml);
    end

    uniqueHeights = unique(heights);
    nHeights = length(uniqueHeights);
    fprintf('\nFound %d distinct height levels for %s: %s ml\n', ...
            nHeights, liquidName, mat2str(uniqueHeights'));

    if nHeights < 2
        error('Need at least 2 different heights for regression.');
    end

    %% Feature normalization
    X = featureList;
    X_mean = mean(X, 1);
    X_std = std(X, 1);
    X_norm = (X - X_mean) ./ (X_std + 1e-10);
    y = heights;

    %% Linear regression
    n = size(X_norm, 1);
    X_reg = [ones(n, 1), X_norm];  % Add bias term
    beta = (X_reg' * X_reg) \ (X_reg' * y);
    yPred = X_reg * beta;

    rmse = sqrt(mean((y - yPred).^2));
    mae = mean(abs(y - yPred));
    r2 = 1 - sum((y - yPred).^2) / sum((y - mean(y)).^2);

    fprintf('\n--- Height Regression Results ---\n');
    fprintf('  RMSE: %.1f ml\n', rmse);
    fprintf('  MAE:  %.1f ml\n', mae);
    fprintf('  R²:   %.3f\n', r2);

    %% Plot: predicted vs actual
    figure;
    scatter(y, yPred, 60, 'b', 'filled');
    hold on;
    plot([min(y), max(y)], [min(y), max(y)], 'r--', 'LineWidth', 1.5);
    xlabel('Actual Height (ml)');
    ylabel('Predicted Height (ml)');
    title(sprintf('Height Measurement: %s (RMSE=%.0fml, R^2=%.3f)', liquidName, rmse, r2));
    grid on;
    axis equal;

    %% Leave-one-out cross-validation (robust for small sample sizes)
    yPredCV = zeros(n, 1);
    for i = 1:n
        idx = setdiff(1:n, i);
        X_cv = [ones(n-1, 1), X_norm(idx, :)];
        betaCV = (X_cv' * X_cv) \ (X_cv' * y(idx));
        yPredCV(i) = [1, X_norm(i, :)] * betaCV;
    end

    rmseCV = sqrt(mean((y - yPredCV).^2));
    maeCV = mean(abs(y - yPredCV));
    fprintf('\n--- Cross-Validated Results ---\n');
    fprintf('  RMSE (LOO-CV): %.1f ml\n', rmseCV);
    fprintf('  MAE  (LOO-CV): %.1f ml\n', maeCV);

    %% Feature correlation with height
    fprintf('\n--- Feature-Height Correlation ---\n');
    featureNames = {'meanAmp','stdAmp','rmsAmp','meanPhase','stdPhase', ...
                    'peakMag','meanSpectrum','totalPower','iqReal','iqImag','iqRadius'};
    for fIdx = 1:min(length(featureNames), size(X, 2))
        [r, p] = corrcoef(X(:, fIdx), y);
        fprintf('  %-18s r=%.3f  p=%.3f\n', featureNames{fIdx}, r(1,2), p(1,2));
    end

    %% Visualize relationship for top 2 features
    [~, sortIdx] = sort(abs(corr(X, y)), 'descend');
    figure;
    for i = 1:min(2, size(X, 2))
        subplot(1, 2, i);
        scatter(X(:, sortIdx(i)), y, 60, 'b', 'filled');
        xlabel(featureNames{min(sortIdx(i), length(featureNames))});
        ylabel('Height (ml)');
        title(sprintf('Top Feature #%d vs Height', i));
        lsline;
        grid on;
    end
end

%% Sub-function: feature extraction optimized for height estimation
function featVec = extractHeightFeatures(burstCaptures, params)
    N = length(burstCaptures);
    fs = params.samp_rate;
    amp = abs(burstCaptures);
    phase = unwrap(angle(burstCaptures));

    f1 = mean(amp);
    f2 = std(amp);
    f3 = rms(amp);
    f4 = mean(phase);
    f5 = std(phase);

    X = fft(burstCaptures, N);
    X_mag = abs(X);
    delta_f = fs / N;
    lo = round(5e3 / delta_f);
    hi = round(15e3 / delta_f);
    band = X_mag(lo:hi);

    [peakVal, ~] = max(band);
    f6 = peakVal;
    f7 = mean(band);
    f8 = sum(band.^2);

    iqCenter = mean(burstCaptures);
    f9 = real(iqCenter);
    f10 = imag(iqCenter);
    f11 = mean(abs(burstCaptures - iqCenter));

    featVec = [f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11];
end
