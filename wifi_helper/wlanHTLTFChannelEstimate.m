function est = wlanHTLTFChannelEstimate(rxSym,cfgHT,varargin)
% wlanHTLTFChannelEstimate Channel estimation using the HT-LTF
%   EST = wlanHTLTFChannelEstimate(RXSYM,CFGHT) returns the estimated
%   channel between all space-time, extension streams and receive antennas
%   using the High Throughput Long Training Field (HT-LTF). The channel
%   estimate includes the effect of the applied spatial mapping matrix and
%   cyclic shifts at the transmitter.
%
%   EST is a complex Nst-by-(Nsts+Ness)-by-Nr array containing the
%   estimated channel at data and pilot subcarriers, where Nst is the
%   number of subcarriers, Nsts is the number of space-time streams, Ness
%   is the number of extension streams and Nr is the number of receive
%   antennas.
%
%   RXSYM is a complex Nst-by-Nsym-by-Nr array containing demodulated
%   HT-LTF OFDM symbols. Nsym is the number of demodulated HT-LTF OFDM
%   symbols.
%
%   CFGHT is a packet format configuration object of type <a href="matlab:help('wlanHTConfig')">wlanHTConfig</a>. 
%
%   EST = wlanHTLTFChannelEstimate(...,SPAN) performs frequency smoothing
%   by using a moving average filter across adjacent subcarriers to reduce
%   the noise on the channel estimate. The span of the filter in
%   subcarriers, SPAN, must be odd. If adjacent subcarriers are highly
%   correlated frequency smoothing will result in significant noise
%   reduction, however in a highly frequency selective channel smoothing
%   may degrade the quality of the channel estimate.
%
%   Examples:
%
%    Example 1:
%    %  Generate a time domain waveform txWaveform for an 802.11n HT packet
%    %  and combine all transmit antennas onto one receive antenna. Extract
%    %  and demodulate the HT-LTF and perform channel estimation with a
%    %  frequency smoothing span of 3.
%
%       cfgHT = wlanHTConfig;          % Create packet configuration
%       cfgHT.NumTransmitAntennas = 2; % 2 transmit antennas
%       cfgHT.NumSpaceTimeStreams = 2; % 2 spatial streams
%       txWaveform = wlanWaveformGenerator([1;0;0;1],cfgHT);
%
%       rxWaveform = sum(txWaveform,2); % Combine all transmit antennas
%       indHTLTF = wlanFieldIndices(cfgHT,'HT-LTF');
%       sym = wlanHTLTFDemodulate(rxWaveform(indHTLTF(1):indHTLTF(2),:),...
%                                 cfgHT);
%       smoothingSpan = 3;
%       est = wlanHTLTFChannelEstimate(sym,cfgHT,smoothingSpan);
%
%    Example 2:
%    %  Generate a time domain waveform for an 802.11n HT packet, pass it
%    %  through a TGn fading channel and perform HT-LTF channel estimation.
%
%       cfgHT = wlanHTConfig;         % Create packet configuration
%       txWaveform = wlanWaveformGenerator([1;0;0;1],cfgHT);
% 
%       % Configure channel
%       tgnChannel  = wlanTGnChannel;
%       tgnChannel.SampleRate = 20e6;
% 
%       % Pass through channel (with zeros to allow for channel delay)
%       rxWaveform = tgnChannel([txWaveform; zeros(15,1)]);
%       rxWaveform = rxWaveform(5:end,:); % Synchronize for channel delay
% 
%       % Extract HT-LTF and perform channel estimation
%       indHTLTF = wlanFieldIndices(cfgHT,'HT-LTF');
%       sym = wlanHTLTFDemodulate(rxWaveform(indHTLTF(1):indHTLTF(2),:), ...
%                cfgHT);
%       est = wlanHTLTFChannelEstimate(sym,cfgHT);
%
%   See also wlanHTConfig, wlanHTLTFDemodulate, wlanHTDataRecover,
%            wlanLLTFChannelEstimate, wlanVHTLTFChannelEstimate.
 
%   Copyright 2015-2018 The MathWorks, Inc.

%#codegen

% Validate number of arguments
narginchk(2,3);

if nargin > 2
    span = varargin{1};
    enableFreqSmoothing = true;
else
    % Default no frequency smoothing
    enableFreqSmoothing = false;
end

% Validate the packet format configuration object is a valid type
validateattributes(cfgHT,{'wlanHTConfig'},{'scalar'},mfilename, ...
    'packet format configuration object');
validateConfig(cfgHT, 'EssSTS'); 

% Validate symbol type
validateattributes(rxSym,{'single','double'},{'3d'}, ...
    'wlanHTLTFChannelEstimate','HT-LTF OFDM symbol(s)');

cbw = cfgHT.ChannelBandwidth;
numSC = size(rxSym,1);
numRxAnts = size(rxSym,3);
numSTS = cfgHT.NumSpaceTimeStreams;
if wlan.internal.inESSMode(cfgHT)
    numESS = cfgHT.NumExtensionStreams;
else
    numESS = 0;
end

% Return an empty if empty symbols
if isempty(rxSym)
    est = zeros(numSC,numSTS+numESS,numRxAnts);
    return;
end

% Perform channel estimation for all subcarriers
cfgOFDM = wlan.internal.wlanGetOFDMConfig(cbw,'Long','HT',numSTS); % Get OFDM configuration
FFTLen = cfgOFDM.FFTLength;
chanBWInMHz = FFTLen/64*20;
ind = sort([cfgOFDM.DataIndices; cfgOFDM.PilotIndices]); % Estimate all subcarriers
k = ind-FFTLen/2-1; % Active subcarrier frequency index
% Verify number of subcarriers to estimate
coder.internal.errorIf(numSC~=numel(ind), ...
    'wlan:wlanChannelEstimate:IncorrectNumSC',numel(ind),numSC);
est = wlan.internal.htltfEstimate(rxSym,cbw,numSTS,numESS,ind);

% Perform frequency smoothing
if enableFreqSmoothing
    % Undo cyclic shift for each STS+ESS before averaging 
    csh = wlan.internal.getCyclicShiftVal('VHT',numSTS,chanBWInMHz);
    est(:,1:numSTS,:) = wlan.internal.cyclicShiftChannelEstimate(est(:,1:numSTS,:), ...
        -csh,FFTLen,k);
    cshEss = wlan.internal.getCyclicShiftVal('VHT',numESS,chanBWInMHz);
    if numESS>1
        est(:,numSTS+(1:numESS),:) = ...
            wlan.internal.cyclicShiftChannelEstimate(est(:,numSTS+(1:numESS),:),-cshEss, ...
            FFTLen,k);
    end
    % Smooth segments between DC gaps
    switch cbw
        case 'CBW20'
            numGroups = 1;
        otherwise % 'CBW40'
            numGroups = 2;
    end
    groupSize = size(est,1)/numGroups;
    for i = 1:numGroups
        idx = (1:groupSize)+(i-1)*groupSize;
        est(idx,:,:) = wlan.internal.frequencySmoothing(est(idx,:,:),span);
    end

    % Re-apply cyclic shift after averaging and interpolation
    est(:,1:numSTS,:) = wlan.internal.cyclicShiftChannelEstimate(est(:,1:numSTS,:), ...
        csh,FFTLen,k);
    if numESS>1
        est(:,numSTS+(1:numESS),:) = wlan.internal.cyclicShiftChannelEstimate(est(:, ...
            numSTS+(1:numESS),:),cshEss,FFTLen,k);
    end
end

end
