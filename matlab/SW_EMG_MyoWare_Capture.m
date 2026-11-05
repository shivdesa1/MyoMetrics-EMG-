%% MyoMetrics | Step 1: Record actual MyoWare ENV data (35 seconds)
% Hardware: Arduino Nano ESP32 with MyoWare ENV -> A0 (3.3V supply).
% Upload ESP32_MyoWare_A0_Logger.ino before running this MATLAB script.
% CLOSE Arduino Serial Monitor and Serial Plotter before MATLAB connects.
% MATLAB R2019b or newer; no additional toolboxes required.
%
% Cue sequence (approximate; follow the messages in the Command Window):
%    0-5   s   REST
%    5-10  s   FIST
%   10-15  s   REST
%   15-20  s   FIST
%   20-25  s   REST
%   25-30  s   FIST
%   30-35  s   REST
%
% Output: data/DAQ_MyoWare_ENV_<timestamp>_v0.2.csv
%         results/RES_MyoWare_Capture_<timestamp>_v0.2.png
% CSV columns include board time, relative time, ADC and display smoothing.

clearvars; clc; close all;
recordSeconds = 35;
baud = 115200;

% Put this script inside your GitHub repo's matlab/ folder.
scriptFolder = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptFolder);
dataDir = fullfile(repoRoot,'data');
resultsDir = fullfile(repoRoot,'results');
if ~exist(dataDir,'dir'), mkdir(dataDir); end
if ~exist(resultsDir,'dir'), mkdir(resultsDir); end

ports = serialportlist('available');
fprintf('Available serial ports:\n');
disp(ports);
assert(~isempty(ports), 'No serial port found. Connect the Nano ESP32.');
if numel(ports) == 1
    port = char(ports(1));
    fprintf('Using port: %s\n', port);
else
    port = strtrim(input('Type your Nano ESP32 port exactly as listed: ', 's'));
end
assert(~isempty(port), 'Serial port is blank.');

sp = serialport(port, baud, 'Timeout', 1);
configureTerminator(sp, 'LF');
pause(1);   % allow any USB serial startup to settle
flush(sp);  % discard old samples

boardMs = nan(6000,1);
envAdc = nan(6000,1);
n = 0;
firstMs = NaN;
nextCue = 1;
cueTimes = [0,5,10,15,20,25,30];
cueWords = {'REST','FIST','REST','FIST','REST','FIST','REST'};
lastRecordedTime = 0;
hostTimer = tic;

fprintf('\nRecording starts on first valid sample. Follow the cues.\n');
fprintf('Do not open Arduino Serial Monitor/Plotter during recording.\n\n');

while toc(hostTimer) < recordSeconds + 12
    try
        line = strtrim(char(readline(sp)));
    catch
        if toc(hostTimer) > 10 && n == 0
            break; % device not sending any lines
        end
        continue;
    end
    vals = sscanf(line,'%f,%f');
    if numel(vals) ~= 2 || any(~isfinite(vals)) || vals(2) < 0 || vals(2) > 4095
        continue;
    end
    if isnan(firstMs), firstMs = vals(1); end
    currentTime = (vals(1)-firstMs)/1000;
    if currentTime < lastRecordedTime || currentTime > recordSeconds + 1
        continue; % ignore resets / out-of-range samples
    end
    if currentTime > recordSeconds
        break;
    end
    if n == numel(boardMs)
        boardMs = [boardMs; nan(3000,1)]; %#ok<AGROW>
        envAdc = [envAdc; nan(3000,1)]; %#ok<AGROW>
    end
    n = n+1;
    boardMs(n) = vals(1);
    envAdc(n) = vals(2);
    lastRecordedTime = currentTime;

    while nextCue <= numel(cueTimes) && currentTime >= cueTimes(nextCue)
        fprintf('  %2d s : %s\n', cueTimes(nextCue), cueWords{nextCue});
        if nextCue > 1, beep; end
        nextCue = nextCue + 1;
    end
end
clear sp;  % release the port before continuing

assert(n >= 100, ['Too few valid samples. Check that the Nano ESP32 is running ', ...
    'the included TWO-COLUMN CSV sketch at 115200 baud.']);
boardMs = boardMs(1:n);
envAdc = envAdc(1:n);
time_s = (boardMs-boardMs(1))/1000;
keep = [true; diff(time_s) > 0];
time_s = time_s(keep);
boardMs = boardMs(keep);
envAdc = envAdc(keep);

sampleHz = 1/median(diff(time_s));
smoothSamples = max(1,round(0.20*sampleHz));
envSmooth = movmean(envAdc,smoothSamples);

stamp = datestr(now,'yyyymmdd_HHMMSS');
csvPath = fullfile(dataDir,['DAQ_MyoWare_ENV_' stamp '_v0.2.csv']);
pngPath = fullfile(resultsDir,['RES_MyoWare_Capture_' stamp '_v0.2.png']);

T = table(boardMs,time_s,envAdc,envSmooth,'VariableNames', ...
    {'board_time_ms','time_s','env_adc','env_smooth_200ms_adc'});
writetable(T,csvPath);

fig = figure('Color','w','Name','MyoMetrics | MyoWare ENV Capture');
plot(time_s,envAdc,'Color',[0.67 0.74 0.81]); hold on;
plot(time_s,envSmooth,'Color',[0.06 0.43 0.63],'LineWidth',1.7);
for b = 5:5:30
    xline(b,':','Color',[0.6 0.6 0.6],'HandleVisibility','off');
end
xlabel('Time from start of recording (seconds)');
ylabel('ENV amplitude (ADC counts)');
title(sprintf('MyoWare 2.0 ENV | Arduino Nano ESP32 | %0.1f Hz',sampleHz));
legend('Recorded envelope','200 ms display smoothing','Location','best');
grid on;
xlim([0 35]);
print(fig,pngPath,'-dpng','-r200');

fprintf('\nCAPTURE COMPLETE: %d samples, %.1f Hz estimated, %.1f seconds.\n', ...
    numel(time_s),sampleHz,time_s(end));
if time_s(end) < recordSeconds-2
    warning('Recording shorter than expected. Review before analysing.');
end
fprintf('CSV saved:   %s\n',csvPath);
fprintf('Plot saved:  %s\n',pngPath);
fprintf('NEXT: run SW_MyoWare_Analyse_v0.2.m and select this CSV.\n');
