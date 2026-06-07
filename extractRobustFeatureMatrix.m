function [featureMatrix, featureNames] = extractRobustFeatureMatrix(burstCaptures, sampRate, opts)
%EXTRACTROBUSTFEATUREMATRIX Extract robust segment-level features from one capture.
%   [X, NAMES] = EXTRACTROBUSTFEATUREMATRIX(BURSTCAPTURES, SAMPRATE, OPTS)
%   trims unstable regions, slices the capture into steady-state segments,
%   and returns one robust feature vector per segment.

    if nargin < 3
        opts = struct();
    end
    opts = fillFeatureDefaults(opts);

    x = double(burstCaptures(:));
    x = x(isfinite(real(x)) & isfinite(imag(x)));
    x = trimCapture(x, opts.trimFractions);

    segmentLength = round(opts.segmentLengthSec * sampRate);
    if numel(x) < segmentLength || segmentLength < 8
        featureMatrix = zeros(0, 0);
        featureNames = {};
        return;
    end

    starts = chooseSegmentStarts(numel(x), segmentLength, opts.segmentsPerFile);
    if isempty(starts)
        featureMatrix = zeros(0, 0);
        featureNames = {};
        return;
    end

    featureMatrix = zeros(numel(starts), 32);
    featureNames = {};
    for i = 1:numel(starts)
        segment = x(starts(i):(starts(i) + segmentLength - 1));
        [feat, names] = extractOneSegment(segment, sampRate, opts);
        featureMatrix(i, :) = feat;
        if isempty(featureNames)
            featureNames = names;
        end
    end

    invalidMask = ~all(isfinite(featureMatrix), 1);
    if any(invalidMask)
        featureMatrix(:, invalidMask) = 0;
    end
end

function opts = fillFeatureDefaults(opts)
    defaults.segmentLengthSec = 0.20;
    defaults.segmentsPerFile = 8;
    defaults.trimFractions = [0.15, 0.90];
    defaults.maxSpectrumSamples = 65536;
    defaults.featureBandHz = [1000, 40000];
    defaults.lowSubBandHz = [1000, 10000];
    defaults.highSubBandHz = [10000, 40000];

    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end
end

function x = trimCapture(x, trimFractions)
    n = numel(x);
    startIdx = max(1, floor(trimFractions(1) * n));
    endIdx = min(n, ceil(trimFractions(2) * n));
    if endIdx <= startIdx
        x = x(:);
        return;
    end
    x = x(startIdx:endIdx);
end

function starts = chooseSegmentStarts(signalLength, segmentLength, segmentsPerFile)
    maxStart = signalLength - segmentLength + 1;
    if maxStart < 1
        starts = [];
        return;
    end
    if segmentsPerFile <= 1 || maxStart == 1
        starts = 1;
        return;
    end
    starts = round(linspace(1, maxStart, segmentsPerFile));
    starts = unique(max(1, min(maxStart, starts)));
end

function [features, names] = extractOneSegment(segment, fs, opts)
    x = double(segment(:));
    x = x - mean(x);
    amp = abs(x);
    ampScale = median(amp);
    if ampScale < 1e-12
        ampScale = max(mean(amp), 1e-12);
    end
    x = x / ampScale;
    amp = abs(x);

    t = (0:numel(x) - 1)' / fs;
    phaseWrapped = angle(x);
    phaseUnwrapped = unwrap(phaseWrapped);
    phasePoly = polyfit(t, phaseUnwrapped, 1);
    phaseResidual = phaseUnwrapped - polyval(phasePoly, t);
    phaseDiff = diff(phaseResidual);

    center = mean(x);
    xc = x - center;
    radius = abs(xc);
    iqCov = cov([real(xc), imag(xc)], 1);
    eigVals = sort(max(eig(iqCov), 0), 'descend');
    if numel(eigVals) < 2
        eigVals = [eigVals(:); 0];
    end

    spec = computeSpectrumSummary(x, fs, opts);

    ampP10 = percentileValue(amp, 10);
    ampP50 = percentileValue(amp, 50);
    ampP90 = percentileValue(amp, 90);
    ampMean = mean(amp);
    ampStd = std(amp);
    ampMad = median(abs(amp - ampP50));
    ampCv = ampStd / max(ampMean, 1e-12);
    ampCrest = max(amp) / max(rms(amp), 1e-12);
    ampSkew = centeredMoment(amp, 3) / max(ampStd^3, 1e-12);
    ampKurt = centeredMoment(amp, 4) / max(ampStd^4, 1e-12);

    phaseResidStd = std(phaseResidual);
    phaseResidMad = median(abs(phaseResidual - median(phaseResidual)));
    phaseDiffStd = std(phaseDiff);
    phaseDiffMad = median(abs(phaseDiff - median(phaseDiff)));
    phaseConcentration = abs(mean(exp(1j * phaseWrapped)));
    phaseCircularVar = 1 - phaseConcentration;

    iqEigRatio = eigVals(1) / max(eigVals(2), 1e-12);
    iqCovOffDiag = iqCov(1, 2);

    features = [ ...
        ampMean, ampStd, ampCv, ampP90 - ampP10, ampMad, ampCrest, std(diff(amp)), ...
        ampSkew, ampKurt, phasePoly(1), phaseResidStd, phaseResidMad, phaseDiffStd, ...
        phaseDiffMad, phaseConcentration, phaseCircularVar, mean(radius), std(radius), ...
        iqEigRatio, iqCovOffDiag, std(real(xc)), std(imag(xc)), spec.peakFreq, ...
        spec.peakRatio, spec.centroid, spec.bandwidth, spec.rolloff85, spec.entropy, ...
        spec.flatness, spec.bandPower, spec.subBandRatio, spec.lowBandFraction];

    names = { ...
        'amp_mean','amp_std','amp_cv','amp_p90_minus_p10','amp_mad','amp_crest', ...
        'amp_diff_std','amp_skew','amp_kurtosis','phase_slope','phase_resid_std', ...
        'phase_resid_mad','phase_diff_std','phase_diff_mad','phase_concentration', ...
        'phase_circular_var','iq_radius_mean','iq_radius_std','iq_eig_ratio', ...
        'iq_cov_offdiag','iq_real_std','iq_imag_std','spec_peak_freq', ...
        'spec_peak_ratio','spec_centroid','spec_bandwidth','spec_rolloff85', ...
        'spec_entropy','spec_flatness','spec_band_power','spec_low_high_ratio', ...
        'spec_low_fraction'};
end

function summary = computeSpectrumSummary(x, fs, opts)
    x = x(:);
    n = numel(x);
    take = min(n, opts.maxSpectrumSamples);
    startIdx = floor((n - take) / 2) + 1;
    x = x(startIdx:(startIdx + take - 1));
    n = numel(x);

    if n == 1
        x = [x; x];
        n = 2;
    end

    w = 0.5 - 0.5 * cos(2 * pi * (0:n-1)' / max(n-1, 1));
    nfft = 2 ^ nextpow2(n);
    spectrum = fft(x .* w, nfft);
    powerSpec = abs(spectrum(1:(nfft / 2 + 1))).^2;
    freq = (0:(nfft / 2))' * (fs / nfft);

    bandMask = freq >= opts.featureBandHz(1) & freq <= opts.featureBandHz(2);
    if ~any(bandMask)
        bandMask = freq > 0;
    end
    bandFreq = freq(bandMask);
    bandPower = powerSpec(bandMask) + 1e-12;

    [peakPower, peakIdx] = max(bandPower);
    powerTotal = sum(bandPower);
    normPower = bandPower / powerTotal;
    centroid = sum(bandFreq .* normPower);
    bandwidth = sqrt(sum(((bandFreq - centroid) .^ 2) .* normPower));

    cumulative = cumsum(normPower);
    rolloffIdx = find(cumulative >= 0.85, 1, 'first');
    if isempty(rolloffIdx)
        rolloffIdx = numel(bandFreq);
    end

    lowMask = bandFreq >= opts.lowSubBandHz(1) & bandFreq < opts.lowSubBandHz(2);
    highMask = bandFreq >= opts.highSubBandHz(1) & bandFreq <= opts.highSubBandHz(2);
    lowPower = sum(bandPower(lowMask));
    highPower = sum(bandPower(highMask));

    summary = struct();
    summary.peakFreq = bandFreq(peakIdx);
    summary.peakRatio = peakPower / median(bandPower);
    summary.centroid = centroid;
    summary.bandwidth = bandwidth;
    summary.rolloff85 = bandFreq(rolloffIdx);
    summary.entropy = -sum(normPower .* log(normPower + 1e-12));
    summary.flatness = exp(mean(log(bandPower))) / mean(bandPower);
    summary.bandPower = log10(powerTotal);
    summary.subBandRatio = log10((lowPower + 1e-12) / (highPower + 1e-12));
    summary.lowBandFraction = lowPower / (lowPower + highPower + 1e-12);
end

function value = percentileValue(x, pct)
    xs = sort(x(:));
    if isempty(xs)
        value = 0;
        return;
    end
    position = 1 + (numel(xs) - 1) * (pct / 100);
    low = floor(position);
    high = ceil(position);
    if low == high
        value = xs(low);
        return;
    end
    alpha = position - low;
    value = (1 - alpha) * xs(low) + alpha * xs(high);
end

function momentValue = centeredMoment(x, order)
    x = x(:);
    mu = mean(x);
    momentValue = mean((x - mu) .^ order);
end
