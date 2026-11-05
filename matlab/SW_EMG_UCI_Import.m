%% MyoMetrics | STEP 1 — Import and inspect a UCI EMG recording
% University of Bath — Project Week 1
% Student: [your university username]
% Data source: Krilova et al., UCI 'EMG Data for Gestures', DOI 10.24432/C5ZP5C
%
% PURPOSE:
%   1. Select ONE UCI recording from the downloaded dataset.
%   2. Check the expected 10-column format and estimate sampling rate.
%   3. Plot one EMG channel and the gesture labels over the same time period.
%
% NOTE: This file uses real, previously recorded data, NOT simulated EMG.
% Labels: 0 = unmarked, 1 = rest, 2 = fist, 3 = wrist flexion,
%         4 = wrist extension, 5 = radial deviation,
%         6 = ulnar deviation, 7 = extended palm (not all subjects).

clear; clc; close all;

%% 1. Select one UCI recording
% Browse into EMG_data_for_gestures-master, choose a participant folder,
% e.g. 01, and select a file ending in _raw_data_*.txt.
[fileName, folderName] = uigetfile('*.txt', ...
    'Select one UCI EMG raw_data text file');

if isequal(fileName, 0)
    error('No file chosen. Run the script again and select a raw_data .txt file.');
end
filePath = fullfile(folderName, fileName);
fprintf('Loading: %s\n', filePath);

%% 2. Import numeric values and check layout
% The UCI file should contain 10 numeric columns:
% time (ms), eight EMG channels, gesture label.
data = readmatrix(filePath, 'FileType', 'text');

if size(data, 2) ~= 10
    error('Expected 10 columns, found %d. Check that you selected a UCI raw_data .txt file.', size(data,2));
end

% Remove a possible nonnumeric header or incomplete row, if present.
validRows = all(isfinite(data), 2);
if any(~validRows)
    warning('Removing %d invalid/non-numeric rows.', sum(~validRows));
    data = data(validRows, :);
end
if size(data,1) < 100
    error('Too few numeric rows were loaded. Inspect the input file.');
end

%% 3. Separate the columns and calculate sampling rate
time_ms = data(:,1);       % milliseconds in UCI dataset
emg = data(:,2:9);         % eight EMG channels
labels = round(data(:,10)); % label ID (not EMG amplitude)

time_s = (time_ms - time_ms(1)) / 1000;  % seconds from recording start
positiveSteps = diff(time_s);
positiveSteps = positiveSteps(positiveSteps > 0 & isfinite(positiveSteps));
if isempty(positiveSteps)
    error('Time column is not increasing. Inspect the selected file.');
end
Fs_est = 1 / median(positiveSteps); % estimate from timestamps

fprintf('Rows: %d | EMG channels: %d | Approx. sample rate: %.1f Hz\n', ...
    size(data,1), size(emg,2), Fs_est);
fprintf('Recording duration: %.1f seconds\n', time_s(end));
fprintf('Gesture labels found: %s\n', mat2str(unique(labels)'));

%% 4. Plot 15 seconds from ONE EMG channel
channelNumber = 1;     % switch to 2..8 to inspect other channels
showSeconds = 15;      % change for a longer/shorter excerpt
idx = (time_s <= min(showSeconds, time_s(end)));

figure('Name','MyoMetrics - UCI EMG overview','Color','w');
tiledlayout(2,1, 'TileSpacing','compact');

nexttile;
plot(time_s(idx), emg(idx, channelNumber), 'LineWidth', 0.7);
ylabel('EMG (source units)');
title(sprintf('Raw EMG - Channel %d', channelNumber));
grid on;

nexttile;
stairs(time_s(idx), labels(idx), 'LineWidth', 1.2);
ylabel('Gesture label');
xlabel('Time (s)');
yticks(0:7);
ylim([-0.5, 7.5]);
grid on;
title('UCI labels: 0 = unmarked, 1 = rest, 2 = fist, 3 = flexion, 4 = extension');

sgtitle(sprintf('UCI recording: %s | Fs ~ %.1f Hz', fileName, Fs_est), ...
    'Interpreter','none');

%% 5. Keep variables available for the next stage
% Key variables:
%   emg          = N-by-8 original UCI EMG channels
%   time_s       = N-by-1 time stamps in seconds
%   labels       = N-by-1 gesture labels
%   Fs_est       = estimated samples/second
%   channelNumber = channel selected for plots
%
% IMPORTANT: Class 0 is unmarked data, not rest.
% NEXT STEP: inspect data quality and decide on preprocessing.
