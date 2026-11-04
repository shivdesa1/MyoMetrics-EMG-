%% MyoMetrics | STEP 4 — Train and test a simple Rest vs Fist classifier
% University of Bath — Project Week 1
% Contributors: [insert university username(s)]
% Data: UCI EMG Data for Gestures (previously recorded human signals)
%
% AIM: Can RMS and MAV distinguish a resting muscle from a clenched fist?
%
% WHAT YOU WILL DO:
%   1. Select TWO DIFFERENT .txt recordings from the SAME participant.
%      Use one as TRAINING data and the other as TEST data.
%   2. Extract the SAME 200 ms RMS / MAV features from each recording.
%   3. Train a small decision tree using the training recording ONLY.
%   4. Predict Rest (label 1) or Fist (label 2) on the separate test file.
%   5. Show accuracy, a confusion matrix and a prediction-over-time graph.
%
% HOW TO RUN: This script is standalone. Click Run, then choose the files.
% NEEDS: MATLAB Statistics and Machine Learning Toolbox (fitctree).
%
% CAUTION: Dataset label 0 means UNMARKED, not Rest. We only use 1 and 2.
% This demonstrates classification on another recording of the same person.
% It does not prove performance on different people or your MyoWare sensor.

clear; clc; close all;

%% 1. Choose settings (same values as Step 3)
channelNumber = 1;       % UCI channel 1; a single channel like MyoWare
windowSeconds = 0.20;    % 200 ms non-overlapping windows
trimSeconds = 0.10;      % Ignore 100 ms at both ends of each gesture

%% 2. Choose two separate recordings
[trainName, trainFolder] = uigetfile('*.txt', ...
    'Select TRAINING UCI recording (e.g. 1_raw_data_...)');
if isequal(trainName,0), error('No training recording selected.'); end
trainPath = fullfile(trainFolder,trainName);

[testName, testFolder] = uigetfile('*.txt', ...
    'Select DIFFERENT TEST recording from the same participant',trainFolder);
if isequal(testName,0), error('No test recording selected.'); end
testPath = fullfile(testFolder,testName);

if strcmp(trainPath,testPath)
    error('Training and testing MUST use different recording files.');
end
if ~strcmp(trainFolder,testFolder)
    warning('Files are in different folders. For this demonstration, use two recordings from the SAME participant.');
end

%% 3. Extract features separately from each recording
% The same helper function is used for train and test: no special treatment.
trainFeatures = extractUciFeatures(trainPath,channelNumber,windowSeconds,trimSeconds);
testFeatures  = extractUciFeatures(testPath, channelNumber,windowSeconds,trimSeconds);

% RMS and MAV are the two predictors. Label is the known gesture.
Xtrain = [trainFeatures.RMS, trainFeatures.MAV];
ytrain = trainFeatures.Label;
Xtest  = [testFeatures.RMS, testFeatures.MAV];
ytest  = testFeatures.Label;

if ~all(ismember([1 2],unique(ytrain))) || ~all(ismember([1 2],unique(ytest)))
    error('Both files must contain enough labelled Rest (1) AND Fist (2) data.');
end

fprintf('\n--- Step 4: Training and testing ---\n');
fprintf('TRAIN: %s\n',trainName);
fprintf('TEST:  %s\n',testName);
fprintf('Training windows: %d Rest, %d Fist\n',sum(ytrain==1),sum(ytrain==2));
fprintf('Testing windows:  %d Rest, %d Fist\n',sum(ytest==1),sum(ytest==2));

%% 4. Train a SIMPLE decision tree on TRAINING data only
% A shallow tree is easier to explain and less prone to memorising noise.
% The model learns numerical thresholds from the two extracted features.
model = fitctree(Xtrain,ytrain, ...
    'PredictorNames',{'RMS','MAV'}, ...
    'MaxNumSplits',3, 'MinLeafSize',2);

%% 5. Test: predict the labels of windows in an unseen recording
predictedLabels = predict(model,Xtest);
accuracy = 100 * mean(predictedLabels == ytest);

% Rows = actual labels; columns = predicted labels.
C = confusionmat(ytest,predictedLabels,'Order',[1 2]);
fprintf('\nTEST accuracy: %.1f%% (%d / %d windows correct)\n', ...
    accuracy,sum(predictedLabels==ytest),numel(ytest));
fprintf('Confusion matrix (rows: actual Rest/Fist; columns: predicted Rest/Fist):\n');
disp(C);

% Show class-specific recall, so an imbalanced test is not misleading.
fprintf('Rest recall: %.1f%%\n',100*C(1,1)/max(1,sum(C(1,:))));
fprintf('Fist recall: %.1f%%\n',100*C(2,2)/max(1,sum(C(2,:))));

%% 6. Plot the accuracy results
figure('Name','MyoMetrics - Step 4 confusion matrix','Color','w');
confusionchart(C,{'Rest','Fist'});
title(sprintf('Rest vs Fist | Separate recording accuracy: %.1f%%',accuracy));

figure('Name','MyoMetrics - Step 4 test predictions','Color','w');
tiledlayout(2,1,'TileSpacing','compact');

nexttile;
scatter(testFeatures.Time_s,ytest,22,'filled');
ylim([0.5 2.5]); yticks([1 2]); yticklabels({'Rest','Fist'});
title('ACTUAL gesture labels in test recording');
ylabel('Actual'); grid on;

nexttile;
correct = (predictedLabels==ytest);
scatter(testFeatures.Time_s(correct),predictedLabels(correct),22,[0.1 0.55 0.35],'filled');
hold on;
scatter(testFeatures.Time_s(~correct),predictedLabels(~correct),35,[0.85 0.25 0.25],'x','LineWidth',1.4);
hold off;
ylim([0.5 2.5]); yticks([1 2]); yticklabels({'Rest','Fist'});
title('PREDICTED labels (green = correct, red X = wrong)');
xlabel('Time in test recording (s)'); ylabel('Prediction');
grid on;

fprintf('\nDONE. Save the figures for Mahara after checking the results.\n');

%% Helper function — extract the SAME features used in Step 3
% Local functions at the end of a script work in current MATLAB versions.
function features = extractUciFeatures(filePath, channelNumber, windowSeconds, trimSeconds)
    data = readmatrix(filePath,'FileType','text');
    if size(data,2) ~= 10
        error('Expected 10 columns in %s.',filePath);
    end
    data = data(all(isfinite(data),2),:);
    if size(data,1)<100
        error('Not enough data in %s.',filePath);
    end
    t = (double(data(:,1))-double(data(1,1))) / 1000;
    x = double(data(:,1+channelNumber));
    y = round(double(data(:,10)));
    if any(diff(t)<=0)
        error('Time column must be strictly increasing in %s.',filePath);
    end

    % Use stored rows per second for window sizes, NOT an unverified
    % physical MYO armband sampling frequency. No frequency filter here.
    rowRate = (numel(t)-1)/(t(end)-t(1));
    windowRows = max(1,round(windowSeconds*rowRate));
    trimRows = max(0,round(trimSeconds*rowRate));

    runStart = [1; find(diff(y)~=0)+1];
    runEnd = [runStart(2:end)-1; numel(y)];
    rows = zeros(0,4);  % [time, label, RMS, MAV]

    for k = 1:numel(runStart)
        gesture = y(runStart(k));
        if gesture ~= 1 && gesture ~= 2
            continue; % Ignore unmarked (0) and other gestures
        end
        first = runStart(k) + trimRows;
        last  = runEnd(k) - trimRows;
        for s = first:windowRows:(last-windowRows+1)
            idx = s:(s+windowRows-1);
            seg = x(idx);
            rmsValue = sqrt(mean(seg.^2));
            mavValue = mean(abs(seg));
            midTime = mean(t([idx(1),idx(end)]));
            rows(end+1,:) = [midTime,gesture,rmsValue,mavValue]; %#ok<AGROW>
        end
    end
    if isempty(rows)
        error('No usable 200 ms labelled Rest/Fist windows in %s.',filePath);
    end
    features = array2table(rows,'VariableNames',{'Time_s','Label','RMS','MAV'});
end
