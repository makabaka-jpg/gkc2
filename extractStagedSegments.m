function segments = extractStagedSegments(burstCaptures, sampRate, opts)
%EXTRACTSTAGEDSEGMENTS Extract baseline and measurement segments from one 15s capture.
%   SEGMENTS = EXTRACTSTAGEDSEGMENTS(BURSTCAPTURES, SAMPRATE, OPTS) assumes
%   the capture contains:
%     0-5 s   : empty-cup baseline
%     5-10 s  : cup switching / transition
%     10-15 s : target-liquid measurement
%
%   One short stable segment is selected from the baseline window and one
%   from the measurement window for downstream feature extraction.

    if nargin < 3
        opts = struct();
    end
    opts = fillStageDefaults(opts);

    x = double(burstCaptures(:));
    x = x(isfinite(real(x)) & isfinite(imag(x)));
    if isempty(x)
        error('Capture contains no finite IQ samples.');
    end

    baselineSamples = round(opts.baselineDurationSec * sampRate);
    transitionSamples = round(opts.transitionDurationSec * sampRate);
    measurementSamples = round(opts.measurementDurationSec * sampRate);
    requiredSamples = baselineSamples + transitionSamples + measurementSamples;
    if numel(x) < requiredSamples
        error('Capture is too short. Need at least %d samples, got %d.', requiredSamples, numel(x));
    end

    baselineWindow = x(1:baselineSamples);
    measurementWindow = x(end - measurementSamples + 1:end);

    [baselineSegment, baselineStart] = selectStableSegment( ...
        baselineWindow, opts.segmentLength, opts.numCandidateStarts);
    [measurementSegment, measurementStart] = selectStableSegment( ...
        measurementWindow, opts.segmentLength, opts.numCandidateStarts);

    segments = struct();
    segments.baselineWindow = baselineWindow;
    segments.measurementWindow = measurementWindow;
    segments.baselineSegment = baselineSegment;
    segments.measurementSegment = measurementSegment;
    segments.baselineStart = baselineStart;
    segments.measurementStart = measurementStart;
    segments.segmentLength = numel(baselineSegment);
    segments.options = opts;
end

function opts = fillStageDefaults(opts)
    defaults.baselineDurationSec = 5;
    defaults.transitionDurationSec = 5;
    defaults.measurementDurationSec = 5;
    defaults.segmentLength = 1e4;
    defaults.numCandidateStarts = 25;

    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end
end

function [segment, bestStart] = selectStableSegment(windowData, segmentLength, numCandidateStarts)
    windowData = windowData(:);
    n = numel(windowData);
    segmentLength = min(round(segmentLength), n);
    if segmentLength < 8
        error('Segment length must be at least 8 samples.');
    end

    maxStart = n - segmentLength + 1;
    if maxStart <= 1
        bestStart = 1;
        segment = windowData(1:segmentLength);
        return;
    end

    starts = round(linspace(1, maxStart, numCandidateStarts));
    starts = unique(max(1, min(maxStart, starts)));

    bestScore = inf;
    bestStart = starts(1);
    for i = 1:numel(starts)
        candidate = windowData(starts(i):(starts(i) + segmentLength - 1));
        score = std(abs(candidate));
        if score < bestScore
            bestScore = score;
            bestStart = starts(i);
        end
    end

    segment = windowData(bestStart:(bestStart + segmentLength - 1));
end
