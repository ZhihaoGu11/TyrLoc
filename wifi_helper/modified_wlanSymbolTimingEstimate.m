function [startOffset, M] = modified_wlanSymbolTimingEstimate(x, LLTF)
%wlanSymbolTimingEstimate Fine symbol timing estimation using the L-LTF
%
%   STARTOFFSET = wlanSymbolTimingEstimate(X,CHANBW) returns the offset
%   from the start of the input waveform to the estimated start of the
%   L-STF using cross-correlation with the L-LTF. Only non-HT with OFDM
%   modulation, HT-mixed and VHT packet formats are supported.
%
%   X is the received time-domain signal on which symbol timing is
%   performed. It is an Ns-by-Nr matrix of real or complex values, where Ns
%   represents the number of time-domain samples and Nr represents the
%   number of receive antennas. It is expected that X contains the L-LTF.
%
%   CHANBW is a character vector or string describing the channel bandwidth
%   and must be one of 'CBW5', 'CBW10', 'CBW20' 'CBW40', 'CBW80' or
%   'CBW160'.
%
%   STARTOFFSET is an integer within the range [-L, Ns-2L], where L denotes
%   the length of the L-LTF. STARTOFFSET is empty when Ns<L. When
%   STARTOFFSET is negative, this implies the input waveform does not
%   contain a complete L-STF.
%
%   STARTOFFSET = wlanSymbolTimingEstimate(...,THRESHOLD) optionally
%   specifies the threshold which the decision metric must meet or exceed
%   to obtain a symbol timing estimate. THRESHOLD is a real scalar between
%   0 and 1. When unspecified a value of 1 is used by default.
%
%   [STARTOFFSET,M] = wlanSymbolTimingEstimate(...) returns the decision
%   metric used to perform the symbol timing algorithm. M is a real vector
%   of size (Ns-L+1)-by-1, representing the cross-correlation between X and
%   locally generated L-LTF of the first transmit antenna.
%
%   Example 1:
%   %  Return the symbol timing and decision metric of an 802.11ac packet
%   %  without channel impairments
%
%      cfgVHT = wlanVHTConfig; % Create packet configuration
%      cfgVHT.NumTransmitAntennas = 2;
%      cfgVHT.NumSpaceTimeStreams = 2;
%   
%      % Generate transmit waveform
%      txWaveform = wlanWaveformGenerator([1;0;0;1],cfgVHT);
%
%      % Delay the transmit waveform by 50 samples
%      txWaveform = [zeros(50, cfgVHT.NumTransmitAntennas); txWaveform];
% 
%      % Extract the non-HT fields and obtain the decision metric
%      ind = wlanFieldIndices(cfgVHT);
%      nonhtfields = txWaveform(ind.LSTF(1):ind.LSIG(2),:);
%      [startOffset, M] = wlanSymbolTimingEstimate(nonhtfields,...
%           cfgVHT.ChannelBandwidth);
%      figure; plot(M);
%      xlabel('symbol timing index');
%      ylabel('Decision metric M');
%
%   Example 2:
%   %  Detect a received 802.11n packet and then estimate its symbol timing
%   %  at 20dB SNR.
%
%      cfgHT = wlanHTConfig; % Create packet configuration
%      SNR = 20;             % In decibels
%      tgn = wlanTGnChannel;
%   
%      % Generate transmit waveform
%      txWaveform = wlanWaveformGenerator([1;0;0;1],cfgHT);
% 
%      % Pass the waveform through the TGn channel model and add noise
%      fadedSig = tgn(txWaveform); 
%      rxWaveform = awgn(fadedSig,SNR,0);
%      
%      % Detect packet
%      startOffset = wlanPacketDetect(rxWaveform,cfgHT.ChannelBandwidth);
%      
%      % Extract the non-HT fields and estimate fine packet offset
%      ind = wlanFieldIndices(cfgHT);
%      nonhtfields = rxWaveform(startOffset+(ind.LSTF(1):ind.LSIG(2)),:);
%      startOffset = wlanSymbolTimingEstimate(nonhtfields,...
%           cfgHT.ChannelBandwidth);
%
%   See also wlanPacketDetect, wlanCoarseCFOEstimate, wlanFineCFOEstimate,
%   wlanFieldIndices.

%   Copyright 2016-2017 The MathWorks, Inc.

%#codegen


%Modification part
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs = 20e6;
threshold = 1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% startOffset and M are returned as empty when input signal length is less
% than that of L-LTF
L = size(LLTF, 1);
if size(x, 1) < L
    startOffset = [];
    M = [];
    return;
end

% Calculate cross-correlation between x and L-LTF from the 1st antenna
corr = filter(conj(flipud(LLTF(:, 1))), 1, x);

% Calculate decision metric and get initial timing estimate
Metric = sum(abs(corr(L:end, :)).^2, 2);
[Mmax, nInitial] = max(Metric);

% Refine timing estimate by taking into account cyclic shift delay (CSD)
deltaCSD = 200e-9*fs; % The largest CSD defined in 802.11n/ac
if (nInitial + deltaCSD) > length(Metric)
    idx = find(Metric(nInitial:end) >= threshold*Mmax, 1, 'last');
else
    idx = find(Metric(nInitial:nInitial + deltaCSD) >= threshold*Mmax, 1, 'last');
end
nMax = nInitial + (idx - 1);

% Prepare the output
startOffset = nMax - L - 1;
M = Metric; % For codegen

end