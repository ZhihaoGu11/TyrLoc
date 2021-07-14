clc;
clear;
close all;
SampleRate = 8e6; % Sample Rate of the PlutoSDR
PlotFigureFlag = 0; % Whether to plot the AoA Spectrum
phyMode = 'LE1M'; % PhyMode setting, in the experiments, we use LE1M  
delay = round((10/250e3 + 0.2e-6)*SampleRate) + 2 + 40; % Compensate the transmission delay
BlePara = helperBLEReceiverConfig(phyMode);
BlePara.SampleRate = SampleRate;
BlePara.pktFrq = 500;

if strcmp(phyMode, 'LE1M')
    BlePara.len_txWaveform = 1216;
elseif strcmp(phyMode, 'LE125K')
    BlePara.len_txWaveform = 11904;
end

%Cnt    1    2     3     4     5     6     7    8      9
ANG = {'0'; '10'; '20'; '30'; '40'; '50'; '60'; '70'; '80';...
%       10     11     12     13     14     15     16     17
       '-10'; '-20'; '-30'; '-40'; '-50'; '-60'; '-70'; '-80'};

for fileCnt = 1
    load(['data/ble_data/ble_', ANG{fileCnt},'.mat']);
    
    cnt = 1;
    for roundCnt = 1:size(allrx, 2)
        [rxWaveform, ID] = AntIDExtractor(allrx(:, roundCnt));

        ID = ID(1:end-delay);
        rxWaveform = rxWaveform(delay+1:end);
        
        doas = BLEAoAEst(rxWaveform, ID, BlePara, PlotFigureFlag);
        
        AoAEstResult{cnt} = doas;
        
        fprintf("******AoA Estimation Result of the %dth Round Receiving******\n", roundCnt);
        fprintf("Ground Truth(deg): %d\n", str2double(ANG{fileCnt}));
        fprintf("AoA Estimation(deg): ");
        fprintf("%f\t", doas);
        fprintf("\n\n")
        cnt = cnt + 1;
    end
end

