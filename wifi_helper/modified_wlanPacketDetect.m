function [startOffset,M] = modified_wlanPacketDetect(x, chanBW, offset, threshold)
%WLANPACKETDETECT OFDM packet detection using the L-STF
%
%   STARTOFFSET = wlanPacketDetect(X, CHANBW) returns the offset from the
%   start of the input waveform to the start of the detected preamble using
%   auto-correlation. Only OFDM modulation is supported.
%
%   STARTOFFSET is an integer scalar indicating the location of the start
%   of a detected packet as the offset from the start of the matrix X. If
%   no packet is detected an empty value is returned.
%
%   X is the received time-domain signal. It is an Ns-by-Nr matrix of real
%   or complex samples, where Ns represents the number of time domain
%   samples and Nr represents the number of receive antennas.
%   
%   CHANBW is a character vector or string describing the channel bandwidth
%   and must be 'CBW5', 'CBW10', 'CBW20' 'CBW40', 'CBW80' or 'CBW160'.
%
%   STARTOFFSET = wlanPacketDetect(..., OFFSET) specifies the offset to
%   begin the auto-correlation process from the start of the matrix X. The
%   STARTOFFSET is relative to the input OFFSET when specified. It is an
%   integer scalar greater than or equal to zero. When unspecified a value
%   of 0 is used.
%
%   STARTOFFSET = wlanPacketDetect(..., OFFSET, THRESHOLD) specifies the
%   threshold which the decision statistic must meet or exceed to detect a
%   packet. THRESHOLD is a real scalar greater than 0 and less than or
%   equal to 1. When unspecified a value of 0.5 is used.
%
%   [STARTOFFSET, M] = wlanPacketDetect(...) returns the decision
%   statistics of the packet detection algorithm of matrix X. When
%   THRESHOLD is set to 1, the decision statistics of the complete waveform
%   will be returned and STARTOFFFSET will be empty.
%
%   M is a real vector of size N-by-1, representing the decision statistics
%   based on auto-correlation of the input waveform. The length of N
%   depends on the starting location of the auto-correlation process till
%   the successful detection of a packet.
%
%   Example 1:
%   %  Detect a received 802.11n packet at 20dB SNR.
%
%      cfgHT = wlanHTConfig; % Create packet configuration
%      SNR = 20;             % In decibels
%      tgn = wlanTGnChannel('LargeScaleFadingEffect','None');
%   
%      % Generate transmit waveform
%      txWaveform = wlanWaveformGenerator([1;0;0;1],cfgHT);
% 
%      fadedSig = tgn(txWaveform); 
%      rxWaveform = awgn(fadedSig,SNR,0);
%
%      startOffset = wlanPacketDetect(rxWaveform,cfgHT.ChannelBandwidth);
%
%   Example 2:
%   % Detect a received 802.11a packet without channel impairments
%       
%      cfgNonHT = wlanNonHTConfig; % Create packet configuration
%   
%      % Generate transmit waveform
%      txWaveform = wlanWaveformGenerator([1;0;0;1],cfgNonHT, ...
%                   'WindowTransitionTime', 0);
% 
%      % Delay the signal by appending zeros at the start
%      rxWaveform = [zeros(20,1);txWaveform];
% 
%      startOffset = wlanPacketDetect(rxWaveform, ...
%                    cfgNonHT.ChannelBandwidth,0,0.99);
%      sprintf('Packet start offset: %d',startOffset)
%
%   Example 3:
%   % Return the decision statistics of the input waveform. The waveform
%   % consists of five WLAN packets. The decision statistics shows five
%   % peaks. Each peak corresponds to the detection of a single packet.
%
%       cfgNonHT = wlanNonHTConfig;
%       txWaveform = wlanWaveformGenerator([1;0;0;1],cfgNonHT, ...
%             'NumPackets',5,'IdleTime',20e-6);
%       [~,M] = wlanPacketDetect(txWaveform,cfgNonHT.ChannelBandwidth,0,1);
%       figure; plot(M);
%
%   See also wlanSymbolTimingEstimate, wlanCoarseCFOEstimate,
%   wlanFieldIndices.
 
%   Copyright 2016-2017 The MathWorks, Inc.

%#codegen

narginchk(2,4);
nargoutchk(0,2);

% Check if M is requested
if nargout==2
    M = [];
end

startOffset = [];

if isempty(x)
    return;
end

Td = 0.8e-6; % Time period of a short training symbol for 20MHz
                
switch chanBW
    case 'CBW40'
        symbolLength = Td/(1/40e6);
    case {'CBW80'}
        symbolLength = Td/(1/80e6);
    case {'CBW160'}
        symbolLength = Td/(1/160e6);
    otherwise % 'CBW5', 'CBW10', 'CBW20'
        symbolLength = Td/(1/20e6); % In samples
end

lenLSTF = symbolLength*10; % Length of 10 L-STF symbols 
lenHalfLSTF = lenLSTF/2;   % Length of 5 L-STF symbols
inpLength = (size(x,1) - offset); 

% Append zeros to make the input equal to multiple of L-STF/2
if inpLength<=lenHalfLSTF
    numPadSamples = lenLSTF - inpLength;
else
    numPadSamples = lenHalfLSTF*ceil(inpLength/lenHalfLSTF) - inpLength;
end
padSamples = zeros(numPadSamples, size(x,2));

% Process the input waveform in blocks of L-STF length. The processing
% blocks are offset by half the L-STF length.
numBlocks = (inpLength + numPadSamples)/lenHalfLSTF;

if nargout==2
% Define decision statistics vector
DS = coder.nullcopy(zeros(size(x,1) + length(padSamples) - offset -2*symbolLength + 1, 1));
    if numBlocks > 2
        for n=1:numBlocks-2
            % Update buffer
            buffer = x((n-1)*lenHalfLSTF + (1:lenLSTF) + offset, :);
            [startOffset, out] = correlateSamples(buffer, symbolLength, lenLSTF, threshold);

            DS((n-1)*lenHalfLSTF + 1:lenHalfLSTF*n, 1) = out(1:lenHalfLSTF);

            if ~(isempty(startOffset))
                % Packet detected
                startOffset = startOffset + (n-1)*lenHalfLSTF;
                DS((n-1)*lenHalfLSTF + (1:length(out)), 1) = out;
                % Resize decision statistics
                M = DS(1:(n-1)*lenHalfLSTF + length(out));
                return;
            end
        end
        % Process last block of data
        blkOffset = lenHalfLSTF*(numBlocks-2);
        buffer = [x(blkOffset + 1 + offset:end, :); padSamples];
        [startOffset, out] = correlateSamples(buffer, symbolLength, lenLSTF, threshold);
            if ~(isempty(startOffset))
                startOffset = startOffset + blkOffset; % Packet detected
            end
        DS(blkOffset + 1:end, 1) = out;
        M = DS(1:end-length(padSamples)); 
    else
        buffer = [x(offset + 1:end, :); padSamples];
        [startOffset, out] = correlateSamples(buffer, symbolLength, lenLSTF, threshold);
        M = out;
    end
else
    if numBlocks > 2
        for n=1:numBlocks-2
            buffer = x((n-1)*lenHalfLSTF + (1:lenLSTF) + offset, :); % Update buffer
            startOffset = correlateSamples(buffer, symbolLength, lenLSTF, threshold);

            if ~(isempty(startOffset))
                startOffset = startOffset + (n-1)*lenHalfLSTF; % Packet detected
                return;
            end
        end
    % Process last block of data
    blkOffset = lenHalfLSTF*(numBlocks-2);
    buffer = [x(blkOffset + 1 + offset:end, :); padSamples];
    startOffset = correlateSamples(buffer, symbolLength, lenLSTF, threshold);
        if ~(isempty(startOffset))
            startOffset = startOffset + blkOffset; % Packet detected
        end
    else
        buffer = [x(offset + 1:end, :); padSamples];
        startOffset = correlateSamples(buffer, symbolLength, lenLSTF, threshold); 
    end
end

end

function [packetStart,Mn] = correlateSamples(rxSig, symbolLength, lenLSTF, threshold)
%   Estimate the start offset of the preamble of the receive WLAN packet,
%   using auto-correlation method [1,2].

%   [1] OFDM Wireless LANs: A Theoretical and Practical Guide 1st Edition
%       by Juha Heiskala (Author),John Terry Ph.D. ISBN-13:978-0672321573
%   [2] OFDM Baseband Receiver Design for Wireless Communications by
%       Tzi-Dar Chiueh, Pei-Yun Tsai. ISBN: 978-0-470-82234-0

correlationLength = lenLSTF - (symbolLength*2);
pNoise = eps; % Adding noise to avoid the divide by zero
weights = ones(symbolLength, 1);
index = 1:correlationLength + 1;

packetStart = []; % Initialize output

% Shift data for correlation
rxDelayed = rxSig(symbolLength + 1:end , :); % Delayed samples
rx = rxSig(1:end-symbolLength, :);        % Actual samples

% Sum output on multiple receive antennas
C = sum(filter(weights, 1,(conj(rxDelayed).*rx)), 2);
CS = C(symbolLength:end)./symbolLength;

% Sum output on multiple receive antennas
P = sum(filter(weights, 1, (abs(rxDelayed).^2+abs(rx).^2)/2)./symbolLength, 2);

PS = P(symbolLength:end) + pNoise;

Mn = abs(CS).^2./PS.^2;
N = Mn > threshold;

if (sum(N) >= symbolLength*1.5)
    found = index(N);
    packetStart = found(1) - 1;
    % Check the relative distance between peaks relative to the first
    % peak. If this exceed three times the symbol length then the
    % packet is not detected.
    if sum((found(2:symbolLength) - found(1))>symbolLength*3)
        packetStart = [];
    end
end

end