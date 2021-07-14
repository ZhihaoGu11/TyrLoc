function foffset = modified_wlanFineCFOEstimate(in)
%wlanFineCFOEstimate Fine carrier frequency offset estimation
%   FOFFSET = wlanFineCFOEstimate(IN,CHANBW) estimates the carrier
%   frequency offset FOFFSET in Hertz using time-domain L-LTF (non-HT Long
%   Training Field). The long length of the periodic sequence within the
%   L-LTF allows fine frequency offset estimation to be performed.
%
%   IN is a complex Ns-by-Nr matrix where Ns is the number of time domain
%   samples in the L-LTF, and Nr is the number of receive antennas. If Ns
%   exceeds the number of time domain samples in the L-LTF, trailing
%   samples are not used for estimation.
%
%   CHANBW is a character vector or string describing the channel bandwidth
%   which must be one of the following: 'CBW5','CBW10','CBW20','CBW40',
%   'CBW80','CBW160'.
%
%   FOFFSET = wlanFineCFOEstimate(IN,CHANBW,CORROFFSET) estimates the
%   carrier frequency offset with a specified correlation offset
%   CORROFFSET. The correlation offset specifies the start of the
%   correlation as a fraction of the guard interval between 0 and 1,
%   inclusive. The guard interval for the fine estimation is the first
%   1.6us of the L-LTF for 20 MHz operation. When unspecified a value of
%   0.75 is used.
%
%   Example:
%   %   Generate an non-HT waveform, add a 1kHz carrier frequency offset,
%   %   and then estimate and correct the offset.
%
%       % Generate an non-HT waveform
%       cfgNonHT = wlanNonHTConfig();
%       tx = wlanWaveformGenerator([1;0;0;1],cfgNonHT);
% 
%       % Configure frequency impairment object
%       phaseFrequencyOffset = comm.PhaseFrequencyOffset;
%       phaseFrequencyOffset.SampleRate = 20e6;
%       phaseFrequencyOffset.PhaseOffset = 0;
%       phaseFrequencyOffset.FrequencyOffsetSource = 'Input port';
% 
%       % Add frequency offset
%       freqOffset = 1e3; % 1 kHz
%       rx = phaseFrequencyOffset(tx,freqOffset);
% 
%       % Estimate and correct the carrier frequency offset 
%       lltfInd = wlanFieldIndices(cfgNonHT,'L-LTF');
%       rxlltf = rx(lltfInd(1):lltfInd(2),:);
%       freqOffsetEst = wlanFineCFOEstimate(rxlltf,'CBW20');
%       disp(['Estimated frequency offset: ' num2str(freqOffsetEst) 'Hz']);
%       rxCorrected = phaseFrequencyOffset(rx,-freqOffsetEst);
%
%   See also wlanLLTF, wlanCoarseCFOEstimate, comm.PhaseFrequencyOffset.

%   Copyright 2015-2018 The MathWorks, Inc.

%#codegen


%Modification part
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
num20 = 1;
corrOffset = 0.75;

FFTLen = 64*num20;
Nltf = 160*num20;   % Number of samples in L-LTF
fs = 20e6;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Extract L-LTF or as many samples as we can
lltf = in(1:min(Nltf,end),:);

% Fine CFO estimate assuming one repetition per FFT period (2 OFDM symbols)
M = FFTLen;             % Number of samples per repetition
GI = FFTLen/2;          % Guard interval length
S = M*2;                % Maximum useful part of L-LTF (2 OFDM symbols)
N = size(lltf,1);       % Number of samples in the input

% We need at most S samples
offset = round(corrOffset*GI);
use = lltf(offset+(1:min(S,N-offset)),:);

foffset = wlan.internal.cfoEstimate(use,M).*fs/M;

end