%% calibratePhase.m - Phase calibration using reference signal
% Since SDR initial phase is random each startup, use relative phase
% differences for robust classification.
%
% Usage: calData = calibratePhase(data, refData)
%   data   - signal data structure from collectData
%   refData - reference data (e.g., empty bottle)
%   Returns calibrated data with relative phase

function calData = calibratePhase(data, refData)
    if nargin < 2
        error('Usage: calData = calibratePhase(data, refData)');
    end

    % Extract phase from reference
    refPhase = unwrap(angle(refData.burstCaptures));
    refPhaseMean = mean(refPhase);

    % Extract phase from target
    targetPhase = unwrap(angle(data.burstCaptures));
    targetPhaseMean = mean(targetPhase);

    % Phase difference (relative to reference)
    calData.phaseDiff = targetPhaseMean - refPhaseMean;  % scalar
    calData.phaseDiffVec = targetPhase - refPhase;         % vector

    % Also compute amplitude ratio
    refAmpMean = mean(abs(refData.burstCaptures));
    targetAmpMean = mean(abs(data.burstCaptures));
    calData.ampRatio = targetAmpMean / refAmpMean;         % scalar
    calData.ampRatioDB = 20 * log10(calData.ampRatio);     % dB

    % Relative IQ center shift
    refIQ = mean(refData.burstCaptures);
    targetIQ = mean(data.burstCaptures);
    calData.iqShift = targetIQ - refIQ;
    calData.iqShiftMag = abs(calData.iqShift);
    calData.iqShiftAngle = angle(calData.iqShift);

    fprintf('Calibration (relative to %s):\n', refData.params.liquidName);
    fprintf('  Phase diff:     %.3f rad (%.1f deg)\n', ...
            calData.phaseDiff, rad2deg(calData.phaseDiff));
    fprintf('  Amplitude ratio: %.3f (%.1f dB)\n', ...
            calData.ampRatio, calData.ampRatioDB);
    fprintf('  IQ shift:        mag=%.4f, angle=%.1f deg\n', ...
            calData.iqShiftMag, rad2deg(calData.iqShiftAngle));
end
