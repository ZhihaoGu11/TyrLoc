function est = htltfEstimate(sym,chanBW,numSTS,numESS,ind)
%htltfEstimate Channel estimate using the HT-LTF
%
%   Note: This is an internal undocumented function and its API and/or
%   functionality may change in subsequent releases.
%
%   EST = htltfEstimate(SYM,CHANBW,NUMSTS,NUMESS,IND) returns channel
%   estimate for each subcarrier specified by the indices IND, using
%   received symbols SYM, channel bandwidth CHANBW, number of space-time
%   streams NUMSTS and number of extension streams NUMESS.

%   Copyright 2015-2016 The MathWorks, Inc.

%#codegen

if ((numSTS+numESS)==1)
    % If one space time stream then use LS estimation directly
    ltf = wlan.internal.vhtltfSequence(chanBW,numSTS,numESS);
    est = bsxfun(@rdivide,squeeze(sym(:,1,:)),ltf(ind));
    est = permute(est,[1 3 2]);
else               
    % MIMO channel estimation as per Perahia, Eldad, and Robert Stacey.
    % Next Generation Wireless LANs: 802.11 n and 802.11 ac. Cambridge
    % university press, 2013, page 100, Eq 4.39.
    [ltf,P,dltf,eltf] = wlan.internal.vhtltfSequence(chanBW,numSTS,numESS);

    % Verify enough symbols to estimate
    nsym = size(sym,2);
    coder.internal.errorIf(nsym<dltf+eltf, ...
        'wlan:wlanChannelEstimate:NotEnoughHTSymbols',numSTS,numESS, ...
        dltf+eltf,nsym);

    Pd = P(1:numSTS,1:dltf)'; % Extract, conjugate P matrix for HT-DLTFs
    denomD = dltf.*ltf(ind);

    Pe = P(1:numESS,1:eltf)'; % Extract, conjugate P matrix for HT-ELTFs
    denomE = eltf.*ltf(ind);
    numRx = size(sym,3);
    
    est = complex(zeros(numel(ind),numSTS+numESS,numRx));
    for i = 1:numRx
        rxsym = squeeze(sym(:,(1:dltf),i)); % Symbols on 1 receive antenna
        for j = 1:numSTS
            est(:,j,i) = rxsym*Pd(:,j)./denomD;
        end
        
        if numESS>0
            rxsym = squeeze(sym(:,dltf+(1:eltf),i)); % Symbols on 1 receive antenna
            for j = 1:numESS
                est(:,numSTS+j,i) = rxsym*Pe(:,j)./denomE;
            end
        end
    end
end
end