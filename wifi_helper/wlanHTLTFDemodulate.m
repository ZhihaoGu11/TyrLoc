function y = wlanHTLTFDemodulate(rxHTLTF, cfgHT, varargin)
%wlanHTLTFDemodulate OFDM demodulate HT-LTF signal
%
%   Y = wlanHTLTFDemodulate(RXHTLTF, CFGHT) demodulates the time-domain
%   HT-LTF received signal for the HT-Mixed transmission format.
%
%   Y is the frequency-domain signal corresponding to the HT-LTF. It is a
%   complex matrix or 3-D array of size Nst-by-Nsym-by-Nr, where Nst
%   represents the number of data and pilot subcarriers in the HT-LTF, Nsym
%   represents the number of OFDM symbols in the HT-LTF, and Nr
%   represents the number of receive antennas.
%
%   RXHTLTF is the received time-domain HT-LTF signal. It is a complex
%   matrix of size Ns-by-Nr, where Ns represents the number of samples. Ns
%   can be greater than or equal to the HT-LTF length, lenHT, where only
%   the first lenHT samples of RXHTLTF are used.
%   
%   CFGHT is the format configuration object of type <a href="matlab:help('wlanHTConfig')">wlanHTConfig</a>, which
%   specifies the parameters for the HT-Mixed format.
%
%   Y = wlanHTLTFDemodulate(..., SYMOFFSET) specifies the optional OFDM
%   symbol sampling offset as a fraction of the cyclic prefix length
%   between 0 and 1, inclusive. When unspecified, a value of 0.75 is used.
%
%   Example: 
%   %  Demodulate a received HT-LTF signal 
%
%      cfgHT = wlanHTConfig;                % HT-Mixed format configuration
%      txHTLTF = wlanHTLTF(cfgHT);          % HT-LTF generation
%       
%      rxHTLTF = awgn(txHTLTF, 1, 1);              % Add noise
%      y = wlanHTLTFDemodulate(rxHTLTF, cfgHT);    % Demodulate
%
%   See also wlanHTLTF, wlanHTConfig, wlanHTLTFChannelEstimate.

%   Copyright 2015-2016 The MathWorks, Inc.

%#codegen

narginchk(2,3);

% cfgHT validation
validateattributes(cfgHT, {'wlanHTConfig'}, {'scalar'}, mfilename, ...
                   'HT-Mixed format configuration object');
validateConfig(cfgHT, 'EssSTS'); 

% Input rxHTLTF validation
validateattributes(rxHTLTF, {'double'}, {'2d', 'finite'}, ...
    'rxHTLTF', 'HT-LTF signal'); 

if nargin == 3
    validateattributes(varargin{1}, {'double'}, ...
        {'real','scalar','>=',0,'<=',1}, mfilename, 'symOffset');
    
    symOffset = varargin{1};
else    % default
    symOffset = 0.75;
end

numRx = size(rxHTLTF, 2);
if size(rxHTLTF, 1) == 0
    y = zeros(0, 0, numRx);
    return;
end

chanBW = cfgHT.ChannelBandwidth;
numSTS = cfgHT.NumSpaceTimeStreams;
if wlan.internal.inESSMode(cfgHT)
    numESS = cfgHT.NumExtensionStreams;
else
    numESS = 0;
end
[~,~,dltf,eltf] = wlan.internal.vhtltfSequence(chanBW, numSTS, numESS);
numSym = dltf+eltf;

% Get OFDM configuration
cfgOFDM = wlan.internal.wlanGetOFDMConfig(cfgHT.ChannelBandwidth, ...
    'Long', 'HT', numSTS);
[~, sortedDataPilotIdx] = sort([cfgOFDM.DataIndices; cfgOFDM.PilotIndices]);

% Validate length of input
minInpLen = numSym*(cfgOFDM.FFTLength+cfgOFDM.CyclicPrefixLength);
coder.internal.errorIf(size(rxHTLTF, 1) < minInpLen, ...
    'wlan:wlanHTLTFDemodulate:ShortDataInput', minInpLen);
    
% Demodulate HT-DLTFs and HT-ELTFs together
[ofdmDemodData, ofdmDemodPilots] = ...
    wlan.internal.wlanOFDMDemodulate(rxHTLTF(1:minInpLen,:), cfgOFDM, ...
      symOffset);

% Sort data and pilot subcarriers
ofdmDemod = [ofdmDemodData; ofdmDemodPilots];
y = ofdmDemod(sortedDataPilotIdx, :, :);

if numESS>0
    % Rescale ELTFs
    y(:,dltf+(1:eltf),:) = y(:,dltf+(1:eltf),:).*sqrt(numSTS)./sqrt(numESS);
end

end

% [EOF]