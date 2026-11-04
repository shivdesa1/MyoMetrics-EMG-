%% MyoMetrics | STEP 5 — Save and explain classifier results
% University of Bath — Project Week 1
% Contributors: [insert contributor university username(s)]
%
% PURPOSE
% This short script runs AFTER SW_EMG_Train_Test_v0.1.m (Step 4).
% It saves a simple results graph, confusion matrix, CSV and text report.
% It DOES NOT train or test the classifier again.
%
% Instructions:
% 1. Run Step 4 and select a training and separate testing recording.
% 2. Without clearing the Workspace, run this Step 5 script.
% 3. Look in the repository's top-level 'results' folder.
%
% IMPORTANT: 96.7% (if reproduced) is performance on ONE separate
% recording of the SAME participant. It does not validate new users or
% MyoWare recordings, and neighbouring 200 ms windows are correlated.

%% 1 — Check that Step 4 has already run
required = {'testPath','testFeatures','predictedLabels','ytest', ...
    'accuracy','C','channelNumber','windowSeconds','trainName','testName'};
for i = 1:numel(required)
    if ~exist(required{i}, 'var')
        error('Please run Step 4 first. Missing workspace variable: %s', required{i});
    end
end

% Store outputs in the repository's results/ folder (next to matlab/).
scriptFolder = fileparts(mfilename('fullpath'));
repoFolder = fileparts(scriptFolder);
outputFolder = fullfile(repoFolder,'results');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% 2 — Load the test recording again for a plot of the actual EMG signal
recording = readmatrix(testPath,'FileType','text');
recording = recording(all(isfinite(recording),2),:);
if size(recording,2) ~= 10
    error('Expected the UCI recording to have 10 columns.');
end

time = (recording(:,1)-recording(1,1))/1000;   % milliseconds to seconds
signal = recording(:,1+channelNumber);          % same EMG channel as Step 4

% The time column may describe a 1 ms row grid with repeated samples.
% We calculate a 200 ms RMS envelope based on the displayed time span,
% but DO NOT assume that the actual sensor sampled at 1000 Hz.
rowRate = (numel(time)-1)/(time(end)-time(1));
windowRows = max(1,round(windowSeconds*rowRate));
rmsEnvelope = sqrt(movmean(signal.^2,windowRows));

%% 3 — Plot EMG envelope and classified test windows
isCorrect = predictedLabels == ytest;
fig = figure('Color','w', 'Name','MyoMetrics — Test results summary');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile;
plot(time,rmsEnvelope,'LineWidth',1.4,'Color',[0.75 0.20 0.22]);
ylabel('RMS (source units)');
title('EMG activation envelope — TEST recording');
grid on;
xlim([time(1),time(end)]);

nexttile;
hold on;
% True labels: small grey circles.
scatter(testFeatures.Time_s,ytest,24,[0.45 0.45 0.45],'o', ...
    'DisplayName','Actual labels');
% Predicted labels: coloured points; misclassified windows marked X.
scatter(testFeatures.Time_s(isCorrect),predictedLabels(isCorrect),24, ...
    [0.10 0.55 0.35],'filled','DisplayName','Correct prediction');
scatter(testFeatures.Time_s(~isCorrect),predictedLabels(~isCorrect),60, ...
    [0.85 0.20 0.20],'x','LineWidth',1.5,'DisplayName','Incorrect prediction');
hold off;
ylim([0.5 2.5]); yticks([1 2]); yticklabels({'Rest','Fist'});
ylabel('Gesture'); xlabel('Time (s)');
title(sprintf('Rest/Fist decisions — %.1f%% of %d windows correct', ...
    accuracy,numel(ytest)));
xlim([time(1),time(end)]);
legend('Location','best'); grid on;

exportgraphics(fig,fullfile(outputFolder,'RES_EMG_Test_Summary_v0.1.png'), ...
    'Resolution',200);

%% 4 — Export the confusion matrix from Step 4
confFig = findall(0,'Type','figure','Name','MyoMetrics - Step 4 confusion matrix');
if ~isempty(confFig)
    exportgraphics(confFig(1), ...
        fullfile(outputFolder,'RES_EMG_Confusion_Matrix_v0.1.png'), ...
        'Resolution',200);
end

%% 5 — Export window-by-window results for reproducibility
results = table(testFeatures.Time_s,ytest,predictedLabels,isCorrect, ...
    testFeatures.RMS,testFeatures.MAV, ...
    'VariableNames',{'Time_s','ActualLabel','PredictedLabel','Correct','RMS','MAV'});
writetable(results,fullfile(outputFolder,'RES_EMG_Window_Predictions_v0.1.csv'));

%% 6 — Write a simple results report; avoid overstating accuracy
reportPath = fullfile(outputFolder,'RES_EMG_Test_Report_v0.1.txt');
fid = fopen(reportPath,'w');
if fid < 0
    error('Could not create results report: %s', reportPath);
end
fprintf(fid,'MyoMetrics — EMG Rest versus Fist classifier\n');
fprintf(fid,'Training file: %s\n',trainName);
fprintf(fid,'Testing file: %s\n',testName);
fprintf(fid,'UCI EMG channel: %d\n',channelNumber);
fprintf(fid,'Window length: %.0f ms\n',1000*windowSeconds);
fprintf(fid,'Features: Root Mean Square (RMS), Mean Absolute Value (MAV)\n');
fprintf(fid,'Training method: shallow decision tree (see Step 4 script)\n');
fprintf(fid,'Testing windows: %d\n',numel(ytest));
fprintf(fid,'Correct predictions: %d\n',sum(isCorrect));
fprintf(fid,'Test accuracy: %.1f%%\n',accuracy);
fprintf(fid,'Confusion matrix rows = actual Rest/Fist; columns = predicted Rest/Fist:\n');
fprintf(fid,'  %d  %d\n',C(1,1),C(1,2));
fprintf(fid,'  %d  %d\n',C(2,1),C(2,2));
fprintf(fid,'Rest recall: %.1f%%\n',100*C(1,1)/max(1,sum(C(1,:))));
fprintf(fid,'Fist recall: %.1f%%\n',100*C(2,2)/max(1,sum(C(2,:))));
fprintf(fid,'\nLIMITATIONS\n');
fprintf(fid,'Evaluation uses a separate recording of the SAME person.\n');
fprintf(fid,'Only 200 ms labelled Rest/Fist windows are scored; label 0 is excluded.\n');
fprintf(fid,'Neighbouring time windows may be correlated and the test set is small.\n');
fprintf(fid,'No claim of accuracy on unseen participants or MyoWare hardware.\n');
fclose(fid);

fprintf('\nStep 5 complete. Saved results in:\n%s\n',outputFolder);
fprintf('Exported a plot, CSV, report, and confusion matrix if its window was open.\n');
