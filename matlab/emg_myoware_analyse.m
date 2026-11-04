%% MyoMetrics | Step 2: Analyse MyoWare ENV recording
% Choose the CSV made by SW_MyoWare_Capture_v0.2.m.
% Uses the 0-5 s REST and 5-10 s FIST stages for participant-specific
% threshold calibration, then detects contractions across the 35 s recording.
% MATLAB R2019b or later, NO extra toolboxes required.
%
% ENV is already rectified and smoothed by the sensor. The moving average
% below is used only for robust activity detection and figure readability.
% This is not a validation of the classifier trained on the UCI dataset.

clearvars; clc; close all;
scriptFolder = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptFolder);
dataDir = fullfile(repoRoot,'data');
resultsDir = fullfile(repoRoot,'results');
if ~exist(resultsDir,'dir'), mkdir(resultsDir); end

[fileName,fileFolder] = uigetfile(fullfile(dataDir,'DAQ_MyoWare_ENV_*.csv'), ...
    'Select the MyoWare recording you just made');
if isequal(fileName,0), error('No CSV selected.'); end
filePath = fullfile(fileFolder,fileName);
T = readtable(filePath);
required = {'time_s','env_adc'};
assert(all(ismember(required,T.Properties.VariableNames)), ...
    'Expected CSV columns time_s and env_adc. Use the included capture script.');
t = double(T.time_s(:));
x = double(T.env_adc(:));
good = isfinite(t) & isfinite(x);
t = t(good); x = x(good);
assert(numel(t)>100 && all(diff(t)>0), ...
    'Recording has too few samples or invalid timestamps.');
assert(t(end)>=29, 'Recording must contain the first 30 seconds.');
fs = 1/median(diff(t));
y = movmean(x,max(1,round(0.20*fs)));

% Calibration windows deliberately avoid the rest/fist transitions.
rest = (t>=1 & t<4);
fist = (t>=6 & t<9);
assert(nnz(rest)>=10 && nnz(fist)>=10, 'Missing calibration interval.');
restLevel = median(y(rest));
fistLevel = median(y(fist));
restSpread = std(y(rest));
threshold = (restLevel+fistLevel)/2;
if fistLevel <= restLevel
    warning(['The 6-9s FIST level is not greater than 1-4s REST. ', ...
       'Check whether you followed the timed cues; detection is unreliable.']);
elseif (fistLevel-restLevel) < 3*max(restSpread,1)
    warning('Fist/rest separation is weak. Inspect the trace manually.');
end

% Threshold crossing, merging brief gaps, rejecting short spikes.
active = y > threshold;
edges = diff([false; active; false]);
starts = find(edges==1);
ends = find(edges==-1)-1;
for k=1:numel(starts)-1
    gapSeconds = t(starts(k+1))-t(ends(k));
    if gapSeconds<=0.25
        active(ends(k):starts(k+1))=true;
    end
end
edges = diff([false; active; false]);
starts = find(edges==1);
ends = find(edges==-1)-1;
keep = (t(ends)-t(starts))>=0.40;
starts = starts(keep);
ends = ends(keep);

nEvents = numel(starts);
startTime = t(starts);
endTime = t(ends);
durations = endTime-startTime;
peakAdc = zeros(nEvents,1);
for k=1:nEvents
    peakAdc(k)=max(y(starts(k):ends(k)));
end
Events = table((1:nEvents)',startTime,endTime,durations,peakAdc, ...
    'VariableNames',{'Event','Onset_s','Offset_s','Duration_s','Peak_ENV_ADC'});

[~,stem] = fileparts(fileName);
resultBase = strrep(stem,'DAQ_','RES_');
figurePath = fullfile(resultsDir,[resultBase '_Activation.png']);
eventsPath = fullfile(resultsDir,[resultBase '_Events.csv']);
reportPath = fullfile(resultsDir,[resultBase '_Summary.txt']);
writetable(Events,eventsPath);

fig = figure('Color','w','Name','MyoMetrics | Automatic Activation Detection');
plot(t,x,'Color',[0.76 0.8 0.85]); hold on;
plot(t,y,'Color',[0.04 0.37 0.6],'LineWidth',1.8);
yline(threshold,'--','Color',[0.86 0.32 0.2],'LineWidth',1.4);
for b=5:5:30
    xline(b,':','Color',[0.7 0.7 0.7],'HandleVisibility','off');
end
for k=1:nEvents
    xx=[startTime(k) endTime(k)];
    plot(xx,[threshold threshold],'-','Color',[0.1 0.55 0.32], ...
         'LineWidth',5,'HandleVisibility','off');
    text((xx(1)+xx(2))/2,threshold, sprintf('  %d',k), ...
         'Color',[0.1 0.45 0.25],'FontWeight','bold', ...
         'HorizontalAlignment','center','VerticalAlignment','bottom');
end
xlabel('Time (seconds)');
ylabel('MyoWare ENV (ADC counts)');
title(sprintf('MyoMetrics | %d detected contractions | calibration threshold = %.0f ADC', ...
      nEvents,threshold));
legend('Recorded ENV','Smoothed ENV (200 ms)','Activation threshold','Location','best');
grid on;
xlim([0 max(35,t(end))]);
print(fig,figurePath,'-dpng','-r200');

fid=fopen(reportPath,'w');
assert(fid>0,'Could not create summary report.');
fprintf(fid,'MyoMetrics | MyoWare 2.0 ENV analysis\n');
fprintf(fid,'Source file: %s\n',fileName);
fprintf(fid,'Nominal input: Arduino Nano ESP32 A0; 3.3V sensor supply\n');
fprintf(fid,'Sampling frequency (observed): %.2f Hz\n',fs);
fprintf(fid,'Duration: %.2f s\n',t(end));
fprintf(fid,'Samples: %d\n',numel(t));
fprintf(fid,'Calibration rest median (1-4 s): %.1f ADC\n',restLevel);
fprintf(fid,'Calibration fist median (6-9 s): %.1f ADC\n',fistLevel);
fprintf(fid,'Activation threshold (midpoint): %.1f ADC\n',threshold);
fprintf(fid,'Detected events: %d\n',nEvents);
for k=1:nEvents
    fprintf(fid,'Event %d: onset %.2f s | offset %.2f s | duration %.2f s | peak %.0f ADC\n', ...
       k,startTime(k),endTime(k),durations(k),peakAdc(k));
end
fprintf(fid,'\nMethod: ENV voltage sampled at ~100Hz, ADC counts, 200ms moving mean,\n');
fprintf(fid,'person/recording-specific rest-versus-fist threshold, gap merge <=250ms,\n');
fprintf(fid,'reject activation shorter than 400ms.\n');
fprintf(fid,'Expected protocol: rest 0-5, fist 5-10, rest 10-15, fist 15-20,\n');
fprintf(fid,'rest 20-25, fist 25-30, rest 30-35 seconds. Cue timing approximate.\n');
fprintf(fid,'This is a proof-of-concept, not medical validation or a UCI classifier accuracy.\n');
fclose(fid);

fprintf('\nMyoWare analysis complete.\n');
fprintf('Baseline median: %.0f ADC | Fist median: %.0f ADC\n',restLevel,fistLevel);
fprintf('Threshold: %.0f ADC | Detected contractions: %d\n',threshold,nEvents);
disp(Events);
fprintf('Activation plot: %s\n',figurePath);
fprintf('Event table:    %s\n',eventsPath);
fprintf('Report:         %s\n',reportPath);
if nEvents ~= 3
    warning('Expected approximately 3 contractions. Inspect plot and cue timing.');
end
if nnz(x>=4090)>0.02*numel(x)
    warning('More than 2%% of readings near ADC maximum: possible clipping.');
end
