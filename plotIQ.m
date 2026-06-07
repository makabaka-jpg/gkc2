function summary = plotIQ(captureInput, opts)
%PLOTIQ Visualize the staged IQ analysis for one 15-second capture.
%   The figure compares:
%     1. empty-cup baseline segment (from the first 5 s)
%     2. liquid measurement segment (from the last 5 s)
%     3. amplitude traces of the two selected segments
%     4. centroid phase difference used for liquid classification

    if nargin < 1 || isempty(captureInput)
        error('plotIQ requires a .mat file path or loaded capture struct.');
    end
    if nargin < 2
        opts = struct();
    end
    opts = fillIQDefaults(opts);

    [data, label] = loadCaptureInput(captureInput);
    if ~isfield(data, 'burstCaptures') || ~isfield(data, 'params')
        error('Input capture must contain burstCaptures and params.');
    end

    info = extractCoreFeatures(data.burstCaptures, double(data.params.samp_rate), opts);
    baseline = info.segments.baselineSegment(:);
    measurement = info.segments.measurementSegment(:);

    baselinePlot = downsampleForPlot(baseline, opts.numPoints);
    measurementPlot = downsampleForPlot(measurement, opts.numPoints);

    figure('Position', [100, 100, 1100, 760]);

    subplot(2, 2, 1);
    plot(real(baselinePlot), imag(baselinePlot), '.', 'Color', [0.15, 0.45, 0.85], 'MarkerSize', 6);
    hold on;
    plot(real(info.baselineCentroid), imag(info.baselineCentroid), 'rx', 'MarkerSize', 12, 'LineWidth', 1.8);
    hold off;
    axis equal;
    grid on;
    xlabel('I');
    ylabel('Q');
    title('Baseline IQ (0-5 s empty cup)');

    subplot(2, 2, 2);
    plot(real(measurementPlot), imag(measurementPlot), '.', 'Color', [0.90, 0.35, 0.10], 'MarkerSize', 6);
    hold on;
    plot(real(info.measurementCentroid), imag(info.measurementCentroid), 'rx', 'MarkerSize', 12, 'LineWidth', 1.8);
    hold off;
    axis equal;
    grid on;
    xlabel('I');
    ylabel('Q');
    title('Measurement IQ (10-15 s target liquid)');

    subplot(2, 2, 3);
    plot(abs(baseline), 'Color', [0.15, 0.45, 0.85], 'LineWidth', 1.0);
    hold on;
    plot(abs(measurement), 'Color', [0.90, 0.35, 0.10], 'LineWidth', 1.0);
    hold off;
    grid on;
    xlabel('Sample index');
    ylabel('Amplitude');
    title(sprintf('Amplitude comparison | ratio = %.2f dB', info.ampRatioDb));
    legend({'Baseline segment', 'Measurement segment'}, 'Location', 'best');

    subplot(2, 2, 4);
    theta = linspace(0, 2 * pi, 360);
    plot(cos(theta), sin(theta), 'k--', 'LineWidth', 1.0);
    hold on;
    baseVec = info.baselineCentroid / max(abs(info.baselineCentroid), 1e-12);
    measVec = info.measurementCentroid / max(abs(info.measurementCentroid), 1e-12);
    quiver(0, 0, real(baseVec), imag(baseVec), 0, 'Color', [0.15, 0.45, 0.85], 'LineWidth', 2, 'MaxHeadSize', 0.4);
    quiver(0, 0, real(measVec), imag(measVec), 0, 'Color', [0.90, 0.35, 0.10], 'LineWidth', 2, 'MaxHeadSize', 0.4);
    hold off;
    axis equal;
    xlim([-1.2, 1.2]);
    ylim([-1.2, 1.2]);
    grid on;
    xlabel('Cosine');
    ylabel('Sine');
    title(sprintf('Centroid phase difference = %.2f deg', info.phaseDiffDeg));
    legend({'Unit circle', 'Baseline centroid', 'Measurement centroid'}, 'Location', 'best');

    sgtitle(buildFigureTitle(data, label));

    summary = struct();
    summary.label = label;
    summary.phaseDiffDeg = info.phaseDiffDeg;
    summary.phaseDiffRad = info.phaseDiffRad;
    summary.ampRatioDb = info.ampRatioDb;
    summary.measurementAmpMean = info.measurementAmpMean;
    summary.measurementAmpStd = info.measurementAmpStd;
    summary.baselineCentroid = info.baselineCentroid;
    summary.measurementCentroid = info.measurementCentroid;
end

function opts = fillIQDefaults(opts)
    defaults.baselineDurationSec = 5;
    defaults.transitionDurationSec = 5;
    defaults.measurementDurationSec = 5;
    defaults.segmentLength = 1e4;
    defaults.numCandidateStarts = 25;
    defaults.numPoints = 3000;

    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end
end

function [data, label] = loadCaptureInput(captureInput)
    if ischar(captureInput) || isstring(captureInput)
        label = char(captureInput);
        data = load(label);
    else
        label = 'capture';
        data = captureInput;
    end
end

function xPlot = downsampleForPlot(x, numPoints)
    x = x(:);
    n = min(numel(x), numPoints);
    idx = round(linspace(1, numel(x), n));
    xPlot = x(idx);
end

function titleText = buildFigureTitle(data, label)
    liquidName = 'unknown';
    if isfield(data, 'params') && isfield(data.params, 'liquidName')
        liquidName = char(string(data.params.liquidName));
    end

    heightText = 'unknown height';
    if isfield(data, 'params') && isfield(data.params, 'height_ml')
        h = data.params.height_ml;
        if isnumeric(h) && isfinite(h)
            heightText = sprintf('%g ml', h);
        end
    end

    titleText = sprintf('Staged IQ analysis | %s | %s', liquidName, heightText);
    if ~isempty(label)
        titleText = sprintf('%s\n%s', titleText, label);
    end
end
