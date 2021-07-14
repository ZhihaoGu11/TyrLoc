clc;
clear;
close all;
SampleRate = 20e6; % Sample Rate of the PlutoSDR
PlotFigureFlag = 0; % Whether to plot the AoA Spectrum
delay = round((10/250e3 + 0.2e-6)*SampleRate) + 2 + 40;
WifiPara.SampleRate = SampleRate;
WifiPara.len_txWaveform = 1200;
WifiPara.pktFrq = 500;

% Create a format configuration object for WIFI
cfgHT = wlanHTConfig;
cfgHT.ChannelBandwidth = 'CBW20'; % 20 MHz channel bandwidth
cfgHT.NumTransmitAntennas = 1;    % 1 transmit antennas
cfgHT.NumSpaceTimeStreams = 1;    % 1 space-time streams
cfgHT.PSDULength = 64;            % PSDU length in bytes
cfgHT.MCS = 1;                    % Modulation and Coding Scheme
cfgHT.ChannelCoding = 'BCC';      % BCC channel coding
WifiPara.cfgHT = cfgHT;
load('wifi_helper/txLLTF.mat');
WifiPara.txLLTF = txLLTF;

%Cnt    1    2     3     4     5     6     7    8      9
ANG = {'0'; '10'; '20'; '30'; '40'; '50'; '60'; '70'; '80';...
%       10     11     12     13     14     15     16     17
       '-10'; '-20'; '-30'; '-40'; '-50'; '-60'; '-70'; '-80'};
   
for fileCnt = 1
    load(['data/wifi_data/wifi_', ANG{fileCnt},'.mat']);
    
    cnt = 1;
    for roundCnt = 1:size(allrx, 2)
        [rxWaveform, ID] = AntIDExtractor(allrx(:, roundCnt));
        ID = ID(1:end-delay);
        rxWaveform = rxWaveform(delay+1:end);

        rxWaveformLen = size(rxWaveform,1);

        doas =  WIFIAoAEst(rxWaveform, ID, 0.8, WifiPara, PlotFigureFlag);
        
        AoAEstResult{cnt} = doas;
        
        fprintf("******AoA Estimation Result of the %dth Round Receiving******\n", roundCnt);
        fprintf("Ground Truth(deg): %d\n", str2double(ANG{fileCnt}));
        fprintf("AoA Estimation(deg): ");
        fprintf("%f\t", doas);
        fprintf("\n\n")
        cnt = cnt + 1;
    end
end

