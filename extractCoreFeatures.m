function featureInfo = extractCoreFeatures(burstCaptures, sampRate, opts)
%EXTRACTCOREFEATURES Extract compact features from a staged 15-second capture.
%   FEATUREINFO = EXTRACTCOREFEATURES(BURSTCAPTURES, SAMPRATE, OPTS)
%   assumes a staged capture:
%     0-5 s   empty-cup baseline
%     5-10 s  transition / swapping
%     10-15 s target-liquid measurement
%
%   Classification uses only baseline-to-measurement phase difference.
%   Height estimation uses only measurement-stage amplitude features.

    if nargin < 3
        opts = struct();
    end

    segments = extractStagedSegments(burstCaptures, sampRate, opts);
    baseline = segments.baselineSegment(:);
    measurement = segments.measurementSegment(:);

    baselineCentroid = mean(baseline);
    measurementCentroid = mean(measurement);
    phaseDiff = angle(measurementCentroid * conj(baselineCentroid));

    baselineAmp = abs(baseline);
    measurementAmp = abs(measurement);
    measurementRadius = abs(measurement - measurementCentroid);

    baselineAmpMean = mean(baselineAmp);
    measurementAmpMean = mean(measurementAmp);
    ampRatioDb = 20 * log10((measurementAmpMean + 1e-12) / (baselineAmpMean + 1e-12));

    featureInfo = struct();
    featureInfo.classificationFeatureNames = { ...
        'phase_diff_sin', ...
        'phase_diff_cos'};
    featureInfo.classificationFeatures = [ ...
        sin(phaseDiff), ...
        cos(phaseDiff)];

    featureInfo.heightFeatureNames = { ...
        'measurement_amp_mean', ...
        'measurement_amp_std'};
    featureInfo.heightFeatures = [ ...
        measurementAmpMean, ...
        std(measurementAmp)];

    featureInfo.phaseDiffRad = phaseDiff;
    featureInfo.phaseDiffDeg = phaseDiff * 180 / pi;
    featureInfo.baselineCentroid = baselineCentroid;
    featureInfo.measurementCentroid = measurementCentroid;
    featureInfo.baselineAmpMean = baselineAmpMean;
    featureInfo.measurementAmpMean = measurementAmpMean;
    featureInfo.ampRatioDb = ampRatioDb;
    featureInfo.measurementAmpStd = std(measurementAmp);
    featureInfo.measurementRadiusStd = std(measurementRadius);
    featureInfo.segments = segments;
end
