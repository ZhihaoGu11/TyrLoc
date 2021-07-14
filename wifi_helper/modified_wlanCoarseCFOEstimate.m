function foffset = modified_wlanCoarseCFOEstimate(in)
%wlanCoarseCFOEstimate Coarse carrier frequency offset estimation
%   FOFFSET = wlanCoarseCFOEstimate(IN,CHANBW) estimates the carrier
%   frequency offset FOFFSET in Hertz using time-domain L-STF (non-HT Short
%   Training Field). The short length of the periodic sequence within the
%   L-STF allows coarse frequency offset estimation to be performed.
%  
%   IN is a complex Ns-by-Nr matrix where Ns is the number of time domain
%   samples in the L-STF, and Nr is the number of receive antennas. If Ns
%   exceeds the number of time domain samples in the L-STF, trailing
%   samples are not used for estimation.
%  
%   CHANBW is a character vector or string describing the channel bandwidth
%   which must be one of the following: 'CBW5','CBW10','CBW20','CBW40',
%   'CBW80', 'CBW160'.
%  
%   FOFFSET = wlanCoarseCFOEstimate(IN,CHANBW,CORROFFSET) estimates the
%   carrier frequency offset with a specified correlation offset
%   CORROFFSET. The correlation offset specifies the start of the
%   correlation as a fraction of the guard interval between 0 and 1,
%   inclusive. The guard interval for coarse estimation is the first 0.8us
%   of the L-STF for 20 MHz operation. When unspecified a value of 0.75 is
%   used.
%  
%   Example:
%   %   Generate an non-HT waveform, add a 400kHz carrier frequency offset,
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
%       freqOffset = 400e3; % 400 kHz
%       rx = phaseFrequencyOffset(tx,freqOffset);
%   
%       % Estimate and correct the carrier frequency offset 
%       freqOffsetEst = wlanCoarseCFOEstimate(rx,'CBW20');
%       disp(['Estimated frequency offset: ' num2str(freqOffsetEst) 'Hz']);
%       rxCorrected = phaseFrequencyOffset(rx,-freqOffsetEst);
%  
%     See also wlanLSTF, wlanFineCFOEstimate, comm.PhaseFrequencyOffset.

%   Copyright 2015-2017 The MathWorks, Inc.

%#codegen

%Modification part
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
corrOffset = 0.75;
num20 = 1;

FFTLen = 64*num20;
Nstf = 160*num20; % Number of samples in L-STF

fs = 20e6;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Extract L-STF or as many samples as we can
lstf = in(1:min(Nstf,end),:);

% Coarse CFO estimate assuming 4 repetitions per FFT period
M = FFTLen/4;           % Number of samples per repetition
GI = FFTLen/4;          % Guard interval length
S = M*9;                % Maximum useful part of L-STF
N = size(lstf,1);       % Number of samples in the input

% We need at most S samples
offset = round(corrOffset*GI);
use = lstf(offset+(1:min(S,N-offset)),:);
foffset = wlan.internal.cfoEstimate(use,M).*fs/M;