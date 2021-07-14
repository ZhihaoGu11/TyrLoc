function bleParam = helperBLEReceiverConfig(phyMode)
%helperBLEReceiverConfig BLE receiver parameters
%   BLEPARAMS = helperBLEReceiverConfig(PHYMODE) returns BLE receiver
%   parameters, BLEPARAMS.
%
%   PHYMODE is a character vector or string specifying the PHY on which
%   decoding is performed. It must be one of the following: 'LE1M','LE2M',
%   'LE500K','LE125K'.
%
%   See also BLEReceiverExample, BLETransmitterExample.

%   Copyright 2019 The MathWorks, Inc.

% Simulation parameters
bleParam.Mode = phyMode;
accessAddHex = '8E89BED6';     % Access address value in hexadecimal
bleParam.AccessAddLen = 32;    % Length of access address
bleParam.SamplesPerSymbol = 8; % Samples per symbol
bleParam.ChannelIndex = 39;    % Channel index value in the range [0,39]
bleParam.CRCLength = 24;       % Length of CRC
bleParam.HeaderLength = 16;    % Length of PDU header
MaximumPayloadLength = 255*8;  % Maximum payload length as per the standard
bleParam.AccessAddress = comm.internal.utilities.de2biBase2RightMSB(hex2dec(accessAddHex),bleParam.AccessAddLen)'; % Access address in binary

% Derive frame length, minimum packet length and symbol rate based on mode
bleParam.SymbolRate = 1e6; % Symbol rate for {'LE1M','LE500K','LE125K'}
if strcmp(bleParam.Mode,'LE1M') || strcmp(bleParam.Mode,'LE2M')
    if strcmp(bleParam.Mode,'LE1M')
        bleParam.PrbLen = 8;
    else
        bleParam.PrbLen = 16;
        bleParam.SymbolRate = 2e6;  % Symbol rate for 'LE2M'
    end
    packetSize  = bleParam.PrbLen + bleParam.AccessAddLen + MaximumPayloadLength + bleParam.CRCLength;
    emptyPacketLen = bleParam.PrbLen + bleParam.AccessAddLen + bleParam.HeaderLength + bleParam.CRCLength;
else
    bleParam.PrbLen = 80;  % Number of samples corresponding to preamble length
    codingIndLen = 2;      % Coding indicator length in bits
    termSeqLen = 3;        % Termination sequence length in bits
    S = 8;                 % Coding scheme for LE125K mode
    fecBlock1Len = (bleParam.AccessAddLen + codingIndLen + termSeqLen)*S;
    if strcmp(bleParam.Mode,'LE500K') % FEC block2 coding scheme for LE500K mode
        S = 2;
    end
    packetSize = bleParam.PrbLen + fecBlock1Len + (MaximumPayloadLength + bleParam.CRCLength + termSeqLen)*S;
    emptyPacketLen = bleParam.PrbLen + fecBlock1Len + (bleParam.HeaderLength + bleParam.CRCLength + termSeqLen)*S;
end
bleParam.FrameLength = bleParam.SamplesPerSymbol * packetSize;
bleParam.MinimumPacketLen = emptyPacketLen*bleParam.SamplesPerSymbol;

% Matched filter coefficients
BT = 0.5;
span = 1;
bleParam.h = gaussdesign(BT,span,bleParam.SamplesPerSymbol);

% Generate reference sequence for preamble detection based on simulation
% mode and access address.
bleParam.Preamble = ble.internal.preambleGenerator(bleParam.Mode,bleParam.AccessAddress);

if any(strcmp(bleParam.Mode,{'LE1M','LE2M'})) % For LE1M or LE2M
    refBits  = [bleParam.Preamble;bleParam.AccessAddress];
else                                          % For LE500K or LE125K
    trellis = poly2trellis(4,[17 13]);
    fecAA = convenc(bleParam.AccessAddress,trellis);
    pattern = [1 1 0 0].';
    patternLen = length(pattern);
    repBlock = reshape(repmat(fecAA.',patternLen,1),1,[]);
    repPattern = reshape(repmat(pattern,1,length(fecAA)),1,[]);
    codedAA = ~xor(repBlock,repPattern).';
    refBits = [bleParam.Preamble; codedAA];
end
bleParam.RefSeq = ble.internal.gmskmod(refBits,bleParam.SamplesPerSymbol);

end