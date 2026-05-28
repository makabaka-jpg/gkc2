%% analyzeSignal.m - Feature extraction and visualization for backscatter signals
% Usage: features = analyzeSignal(burstCaptures, params)
% Returns a struct of extracted features from the I/Q signal

function features = analyzeSignal(burstCaptures, params)
    N = length(burstCaptures);
    fs = params.samp_rate;
    t = (0:N-1)' / fs;

    %% Time-domain features
    amp = abs(burstCaptures);          % Amplitude envelope
    phase = angle(burstCaptures);      % Phase (wrapped)

    features.meanAmp = mean(amp);
    features.stdAmp = std(amp);
    features.varAmp = var(amp);
    features.rmsAmp = rms(amp);

    % Unwrap phase for linearity analysis
    phase_unwrapped = unwrap(phase);
    features.meanPhase = mean(phase_unwrapped);
    features.stdPhase = std(phase_unwrapped);

    %% Frequency-domain features
    f = (0:N-1) * fs / N;
    X = fft(burstCaptures, N);
    X_mag = abs(X);
    delta_f = fs / N;

    % Focus on IF range (5kHz ~ 15kHz)
    low_idx = round(5e3 / delta_f);
    high_idx = round(15e3 / delta_f);
    band_spectrum = X_mag(low_idx:high_idx);
    band_freq = f(low_idx:high_idx);

    [~, peak_idx] = max(band_spectrum);
    features.peakFreq = band_freq(peak_idx);
    features.peakMag = band_spectrum(peak_idx);

    % Spectral statistics in band
    features.meanSpectrum = mean(band_spectrum);
    features.stdSpectrum = std(band_spectrum);
    features.totalPower = sum(band_spectrum.^2);

    %% IQ-plane features
    iq_center = mean(burstCaptures);   % Centroid on IQ plane
    features.iqCenterReal = real(iq_center);
    features.iqCenterImag = imag(iq_center);
    features.iqSpread = std(real(burstCaptures)) + 1j*std(imag(burstCaptures));

    iq_centered = burstCaptures - iq_center;
    features.iqRadius = mean(abs(iq_centered));  % Mean distance from centroid

    %% Visualization
    figure('Position', [100, 100, 1200, 800]);

    % 1) Frequency spectrum
    subplot(2, 3, 1);
    plot(band_freq, band_spectrum);
    xlabel('Frequency (Hz)'); ylabel('Magnitude');
    title(sprintf('Spectrum (IF band), Peak @ %.0f Hz', features.peakFreq));
    grid on;

    % 2) Time-domain amplitude
    subplot(2, 3, 2);
    plot(t(1:2000), amp(1:2000));
    xlabel('Time (s)'); ylabel('Amplitude');
    title(sprintf('Amplitude Envelope (mean=%.3f)', features.meanAmp));
    grid on;

    % 3) Phase over time
    subplot(2, 3, 3);
    plot(t(1:2000), phase_unwrapped(1:2000));
    xlabel('Time (s)'); ylabel('Phase (rad)');
    title(sprintf('Unwrapped Phase (mean=%.2f)', features.meanPhase));
    grid on;

    % 4) IQ constellation
    subplot(2, 3, 4);
    idx = 1:100:min(5000, N);
    plot(real(burstCaptures(idx)), imag(burstCaptures(idx)), '.');
    hold on;
    plot(real(iq_center), imag(iq_center), 'rx', 'MarkerSize', 12, 'LineWidth', 2);
    xlabel('I'); ylabel('Q');
    title(sprintf('IQ Plane (centroid marked)'));
    axis equal; grid on;

    % 5) Amplitude histogram
    subplot(2, 3, 5);
    histogram(amp, 50);
    xlabel('Amplitude'); ylabel('Count');
    title(sprintf('Amplitude Distribution (std=%.4f)', features.stdAmp));

    % 6) Phase histogram
    subplot(2, 3, 6);
    histogram(phase, 50);
    xlabel('Phase (rad)'); ylabel('Count');
    title('Phase Distribution');

    sgtitle(sprintf('Signal Analysis: %s, %dml', params.liquidName, params.height_ml));

    %% Extra figure: IQ plane with fitted phase & amplitude
    figure('Position', [200, 200, 700, 650]);

    % Downsample for cleaner scatter
    nPlot = min(3000, N);
    idx = round(linspace(1, N, nPlot));
    iq_data = burstCaptures(idx);

    % Fitted values
    fittedAmp = features.meanAmp;
    fittedPhase = features.meanPhase;

    % Plot IQ scatter
    plot(real(iq_data), imag(iq_data), '.', 'Color', [0.6 0.6 0.6], 'MarkerSize', 4);
    hold on;

    % Draw fitted amplitude circle (centered at origin)
    theta = linspace(0, 2*pi, 360);
    plot(fittedAmp * cos(theta), fittedAmp * sin(theta), 'b--', 'LineWidth', 1.5);

    % Draw fitted phase ray (from origin to fitted amplitude at fitted phase)
    rayEnd = fittedAmp * exp(1j * fittedPhase);
    plot([0, real(rayEnd)], [0, imag(rayEnd)], 'r-', 'LineWidth', 2);

    % Draw centroid (mean of all points)
    iq_center = mean(burstCaptures);
    plot(real(iq_center), imag(iq_center), 'rx', 'MarkerSize', 14, 'LineWidth', 2.5);

    % Draw line from centroid to origin (residual)
    plot([0, real(iq_center)], [0, imag(iq_center)], 'k:', 'LineWidth', 1);

    % Annotations
    plot(real(rayEnd), imag(rayEnd), 'r.', 'MarkerSize', 20);

    xlabel('I (In-Phase)');
    ylabel('Q (Quadrature)');
    title(sprintf('IQ Plane: %s, %dml\nFitted Amp=%.3f, Phase=%.2f rad (%.1f°)', ...
        params.liquidName, params.height_ml, fittedAmp, fittedPhase, rad2deg(fittedPhase)));

    legend({'Signal samples', ...
            sprintf('Fitted Amplitude (r=%.3f)', fittedAmp), ...
            sprintf('Fitted Phase (%.1f°)', rad2deg(fittedPhase)), ...
            'Centroid', ...
            'Origin→Centroid'}, ...
            'Location', 'best');

    axis equal;
    grid on;
    hold off;
end
