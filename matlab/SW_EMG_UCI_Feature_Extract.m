%% MyoMetrics | STEP 3 — Extract features for Rest vs Fist
% University of Bath — Project Week 1
% Authors: [add the contributing university username(s)]
% Dataset: UCI EMG Data for Gestures (public, previously recorded data)
%
% HOW TO RUN
% 1. Run SW_EMG_Import_Overview_v0.1.m and select a UCI recording.
% 2. Optionally run Step 2 to see the 200 ms RMS envelope.
% 3. Run this script. It uses variables produced by Step 1.
%
% WHAT THIS SCRIPT DOES
% - Uses EMG channel 1 (change channelNumber if needed).
% - Keeps ONLY labelled Rest (1) and Fist (2) segments.
% - Removes 100 ms from each end of a labelled segment to reduce
%   boundary/transition contamination.
% - Splits the remaining samples into non-overlapping 200 ms windows.
% - Calculates two simple features for each window: RMS and MAV.
% - Plots the results and keeps a feature table for Step 4.
%
% IMPORTANT: This is feature extraction, NOT model training or a test.
% We will train on one recording and test on a SEPARATE recording later.

%% 1. Check the data from Step 1
assert(exist('emg','var')==1 && exist('time_s','var')==1 && ...
       exist('labels','var')==1, 'Run Step 1 first to load the recording.');

channelNumber = 1;      % Use one channel so the approach also suits MyoWare
windowSeconds = 0.20;   % 200 ms amplitude-feature window
trimSeconds = 0.10;     % Ignore 100 ms at either end of a labelled segment

x = double(emg(:,channelNumber));
t = double(time_s(:));
y = double(labels(:));
assert(numel(x)==numel(t) && numel(x)==numel(y), 'Input lengths mismatch.');
assert(all(isfinite(x)) && all(isfinite(t)), 'Invalid signal or time values.');
assert(all(diff(t)>0), 'Expected strictly increasing timestamps.');

% Rate of STORED ROWS, not necessarily the physical MYO sensor sample rate.
rowRate = (numel(t)-1)/(t(end)-t(1));
windowRows = max(1, round(windowSeconds*rowRate));
trimRows = max(0, round(trimSeconds*rowRate));
fprintf('\n--- Step 3: Feature extraction ---\n');
fprintf('Stored row rate: %.1f rows/s (physical sampling rate unverified)\n', rowRate);
fprintf('Window length: %d rows (~%.0f ms)\n', windowRows, 1000*windowSeconds);

%% 2. Find contiguous runs of each class
% 0 is unmarked; 1 is Rest; 2 is Fist. For our first classifier we use
% ONLY 1 and 2, and we NEVER turn unmarked (0) into Rest.
runStart = [1; find(diff(y)~=0)+1];
runEnd = [runStart(2:end)-1; numel(y)];

% Collect one row of results per 200 ms window.
% Column layout: [time at middle, class label, RMS, MAV]
featureRows = zeros(0,4);

for k = 1:numel(runStart)
    thisClass = y(runStart(k));
    if thisClass ~= 1 && thisClass ~= 2
        continue;  % Ignore all other gestures and unmarked intervals
    end

    firstRow = runStart(k) + trimRows;
    lastRow = runEnd(k) - trimRows;

    % Consecutive non-overlapping windows INSIDE one labelled segment.
    for startRow = firstRow:windowRows:(lastRow-windowRows+1)
        idx = startRow:(startRow+windowRows-1);
        segment = x(idx);
        rmsValue = sqrt(mean(segment.^2));
        mavValue = mean(abs(segment));
        midTime = mean(t([idx(1) idx(end)]));
        featureRows(end+1,:) = [midTime, thisClass, rmsValue, mavValue]; %#ok<SAGROW>
    end
end

if isempty(featureRows)
    error('No labelled 200 ms Rest/Fist windows. Select another UCI recording.');
end

%% 3. Store results in a clearly named table for Step 4
featureTable = array2table(featureRows, 'VariableNames', ...
    {'Time_s','Label','RMS','MAV'});
restRows = (featureTable.Label==1);
fistRows = (featureTable.Label==2);

fprintf('Rest windows: %d\n', sum(restRows));
fprintf('Fist windows: %d\n', sum(fistRows));
if any(restRows)
    fprintf('Average Rest RMS: %.5g source units\n', mean(featureTable.RMS(restRows)));
end
if any(fistRows)
    fprintf('Average Fist RMS: %.5g source units\n', mean(featureTable.RMS(fistRows)));
end
if ~any(restRows) || ~any(fistRows)
    warning('This recording lacks one of the target classes; choose another file for training.');
end

%% 4. Plot features (these are REAL values from the selected recording)
figure('Name','MyoMetrics - Step 3 features','Color','w');
tiledlayout(2,1,'TileSpacing','compact');

nexttile;
plot(featureTable.Time_s(restRows),featureTable.RMS(restRows), ...
    'bo','MarkerSize',5); hold on;
plot(featureTable.Time_s(fistRows),featureTable.RMS(fistRows), ...
    'ro','MarkerSize',5); hold off;
title('200 ms RMS by gesture');
xlabel('Time (s)'); ylabel('RMS (source units)');
legend('Rest (1)','Fist (2)','Location','best'); grid on;

nexttile;
plot(featureTable.MAV(restRows),featureTable.RMS(restRows), ...
    'bo','MarkerSize',6); hold on;
plot(featureTable.MAV(fistRows),featureTable.RMS(fistRows), ...
    'ro','MarkerSize',6); hold off;
title('Feature scatter: can RMS and MAV separate Rest and Fist?');
xlabel('Mean Absolute Value (source units)');
ylabel('RMS (source units)');
legend('Rest (1)','Fist (2)','Location','best'); grid on;

% Keep featureTable, x, t and y in MATLAB's workspace.
% NEXT: Run Step 3 on a separate recording, then train/test the classifier
% without mixing windows from the same recording across both sets.
