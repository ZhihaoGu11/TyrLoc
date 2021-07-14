clear;
clc;
close all;
SampleRate = 1e6; % Sample Rate of the PlutoSDR 
PlotFigureFlag = 0; % Whether to plot the AoA Spectrum
Delay = round((10/250e3 + 0.2e-6)*SampleRate) + 2 + 40;

LoraPara.PreSymNum = 128; % The number of Up-Chirp symbol in the preamble
LoraPara.BW = 250e3; % Bandwidth
LoraPara.SF = 9; % Spread Factor
LoraPara.Fs = SampleRate; % Sample Rate
LoraPara.symTime = 2^LoraPara.SF/LoraPara.BW; % Transmission time of a Up-Chirp symbol
LoraPara.symLen = 2^LoraPara.SF*LoraPara.Fs/LoraPara.BW; % Length of a Up-Chirp symbol


% Cnt   1    2     3     4     5     6     7    8      9
ANG = {'0'; '10'; '20'; '30'; '40'; '50'; '60'; '70'; '80';...
%       10     11     12     13     14     15     16     17
       '-10'; '-20'; '-30'; '-40'; '-50'; '-60'; '-70'; '-80'};
   
for fileCnt = 1
    load(['data/lora_data/lora_', ANG{fileCnt},'.mat']);
    
    cnt = 1;
    for roundCnt = 1:size(allrx, 2)
        [rxWaveform, ID] = AntIDExtractor(allrx(:, roundCnt)); %Extract the Antenna ID
        ID = ID(1:end-Delay);
        rxWaveform = rxWaveform(Delay+1:end);

        doas = LoRaAoAEst(rxWaveform, ID, 0.9, LoraPara, PlotFigureFlag); %AoA Estimation

        AoAEstResult{cnt} = doas;
        
        fprintf("******AoA Estimation Result of the %dth Round Receiving******\n", roundCnt);
        fprintf("Ground Truth(deg): %d\n", str2double(ANG{fileCnt}));
        fprintf("AoA Estimation(deg): ");
        fprintf("%f\t", doas);
        fprintf("\n\n")
        cnt = cnt + 1;      
    end
end
