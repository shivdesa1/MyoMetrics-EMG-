%% MyoMetrics | STEP 2 — Understand muscle activation with an RMS envelope
% University of Bath — Project Week 1
% Authors: [add your university username(s)]
% Data: UCI EMG Data for Gestures (Krilova et al.), DOI 10.24432/C5ZP5C
%
% HOW TO USE
% 1. Run SW_EMG_Import_Overview_v0.1.m (Step 1) and select the UCI .txt file.
% 2. WITHOUT clearing the workspace, run this Step 2 script.
% 3. Inspect the diagnostic message and the three plots.
%
% This stage deliberately DOES NOT apply a band-pass filter yet. UCI's
% millisecond timestamps may not represent independently sampled EMG data.
% We first inspect repeated values and calculate an amplitude envelope.

%% 1. Check that Step 1 has already loaded the data
assert(exist('emg','var') == 1 && exist('time_s','var') == 1 && ...
       exist('labels','var') == 1, ...
       'Run Step 1 first. It must create emg, time_s and labels.');

channelNumber = 1;    % Change to 2..8 to inspect a different UCI channel
windowSeconds = 0.20; % 200 ms: typical EMG amplitude-analysis window
showSeconds = 15;     % Number of seconds shown in the plots

% Convert time and signal to column vectors
x = double(emg(:,channelNumber));
t = double(time_s(:));
y = double(labels(:));

assert(numel(x)==numel(t) && numel(x)==numel(y), 'Data lengths do not match.');
assert(all(isfinite(x)) && all(isfinite(t)), 'Data contains invalid values.');
assert(all(diff(t) >= 0), 'Time must be non-decreasing.');

%% 2. Inspect whether the recorded values are repeated between timestamps
% The UCI timestamps can advance in 1 ms increments even when independent
% sensor updates occur less frequently. This matters for frequency filters.
timeDiff = diff(t);
positiveDiff = timeDiff(timeDiff > 0);
assert(~isempty(positiveDiff), 'Time column is invalid.');
Fs_timestamp = 1 / median(positiveDiff);
Fs_overall = (numel(t)-1)/(t(end)-t(1));

% Look for consecutive *identical* 8-channel measurements.
% This is only a diagnostic, not a definitive estimate of sensor rate.
repeatedAllChannels = all(diff(double(emg),1,1)==0,2);
repeatPercent = 100*mean(repeatedAllChannels);

fprintf('\n--- MyoMetrics: Step 2 diagnostics ---\n');
fprintf('Timestamp-based frequency: %.1f Hz\n', Fs_timestamp);
fprintf('Row rate over recording:  %.1f rows/s\n', Fs_overall);
fprintf('Consecutive rows with all 8 channels identical: %.1f%%\n', repeatPercent);
if repeatPercent > 30
    fprintf(['IMPORTANT: Many rows repeat. Do not assume timestamp rate is the\n' ...
             'physical EMG sampling frequency when choosing filter cut-offs.\n']);
else
    fprintf('Few exact repeats detected. Confirm sampling rate from acquisition metadata.\n');
end

%% 3. Create rectified EMG and a 200 ms RMS envelope
% Rectification makes all values non-negative.
rectified = abs(x);

% RMS measures signal magnitude without positive/negative cancellation.
% This moving window is defined by elapsed time on the stored row grid.
% Repeated samples can affect filtering; here the window still provides a
% useful picture of muscle activation over ~0.2 seconds.
windowRows = max(1, round(windowSeconds * Fs_overall));
rmsEnvelope = sqrt(movmean(x.^2, windowRows));

%% 4. Plot the raw signal, envelope, and ground-truth gesture labels
plotMask = t <= min(showSeconds,t(end));
figure('Name','MyoMetrics - UCI envelope and labels', 'Color','w');
tiledlayout(3,1,'TileSpacing','compact');

nexttile;
plot(t(plotMask),x(plotMask),'Color',[0.15 0.40 0.75]);
title(sprintf('Raw EMG - channel %d',channelNumber));
ylabel('Source units'); grid on;

nexttile;
plot(t(plotMask),rectified(plotMask),'Color',[0.75 0.75 0.75]);
hold on;
plot(t(plotMask),rmsEnvelope(plotMask),'r','LineWidth',1.4);
hold off;
title(sprintf('Full-wave rectification and %.0f ms RMS envelope',1000*windowSeconds));
ylabel('Amplitude');
legend('Rectified EMG','RMS envelope','Location','northeast');
grid on;

nexttile;
stairs(t(plotMask),y(plotMask),'k','LineWidth',1.1);
title('Dataset gesture labels (0 = unmarked; 1 = rest; 2 = fist; 3 = flexion)');
xlabel('Time (s)'); ylabel('Class');
yticks(0:7); ylim([-0.5 7.5]); grid on;

% Keep calculated variables for later stages: x, t, y, rectified,
% rmsEnvelope, windowSeconds. Step 3 will add features and validation.
