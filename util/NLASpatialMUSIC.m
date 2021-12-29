function [doas, ang_deg, pwr] = NLASpatialMUSIC(signal, nsig, Resolution, ElemSpace, AntID, SubArrayNum)
% signal: the signal matrix, Size: SnapshotNum*AntennaNum
% nsig: the predefined number of signal source in MUSIC algorithm
% Resolution(deg): the resolution of MUSIC algorithm, usually 1 or 0.1
% ElemSpace: the space between adjacent antennas, using relative space (space/wavelength)
% AntID: the antenna ID of each column vector of the signal matrix
% SubArrayNum: The number of subarray in MUSIC with spatial smoothing

signal = signal.';
AntNum = size(signal,1);

dAntID = diff(AntID);
AntMiss = sum(dAntID ~= 1);
ang_deg = (-90:Resolution:90);
ang = ang_deg/180*pi;

% Adjust the SectorCenter if necessary
SectorCenter = [-60:30:60];

if AntMiss == 1
    tempdoas = [];
    peakpwr = [];
    for N = 1:length(SectorCenter)
        centerang = SectorCenter(N);
        gap = 1;
        step = 0:gap:gap*(60-1);
        offset = step - mean(step);
        theta_deg = centerang + offset;
        theta = theta_deg/180*pi;

        % A1 Raw direction matrix
        p1 = repmat(-1j*transpose(AntID-1)*2*pi*ElemSpace, 1, length(theta));
        p2 = repmat(sin(theta), AntNum, 1);
        A1 = exp(p1.*p2);
        % A2 Virtural direction matrix
        p1 = repmat(-1j*transpose(0:AntNum-1)*2*pi*ElemSpace, 1, length(theta));
        p2 = repmat(sin(theta), AntNum, 1);
        A2 = exp(p1.*p2);

        % Calculating the mapping matrix
        W = A2*A1'*inv(A1*A1');    
        
        VirtualSignal = W*signal;
        Rt = VirtualSignal*VirtualSignal';
        
        Rfb = zeros(SubArrayNum,SubArrayNum); 
        for i = 1:AntNum - SubArrayNum + 1
            Rfb = Rfb + Rt(i:i+SubArrayNum-1,i:i+SubArrayNum-1);
        end
        Rfb = Rfb/(AntNum - SubArrayNum + 1);
        
        Rn = W*W';
        Rnfb = zeros(SubArrayNum,SubArrayNum);
        for i = 1:AntNum - SubArrayNum + 1
            Rnfb = Rnfb + Rn(i:i+SubArrayNum-1,i:i+SubArrayNum-1);
        end
        Rnfb = Rnfb/(AntNum - SubArrayNum + 1);
        
        % Prewhiten the weighted Noise
        Rfb = (Rnfb^(-0.5))*Rfb*(Rnfb^(-0.5)');
        
        [V,D] = eig(Rfb);
        [~,ind] = sort(diag(D), 'descend');
        Vs = V(:,ind);
        Un = Vs(:, nsig+1:end);

        p1 = repmat(-1j*transpose(0:SubArrayNum-1)*2*pi*ElemSpace, 1, length(ang));
        p2 = repmat(sin(ang), SubArrayNum, 1);
        A = exp(p1.*p2);

        X = sum(abs((A'*Rnfb^(-0.5)*Un)).^2, 2);

        pwr = 1./(X+eps(1));
        
        % Find DOA
        [~, templocs] = findpeaks(pwr,'SortStr','descend');
        
        locs = templocs(templocs*Resolution >= theta_deg(1)+90 & templocs*Resolution <= theta_deg(end)+90);
        peaknum = min(nsig,length(locs));
        
        if peaknum > 0
            tempdoas = [tempdoas, ang_deg(locs(1:peaknum))];
            peakpwr = [peakpwr, pwr(locs(1:peaknum)).'];
        end
    end
    
    [~, ind] = sort(peakpwr, 'descend');
    doas = tempdoas(ind(1:min(nsig, length(tempdoas))));
    if nsig > length(doas)
        doas(length(locs)+1:nsig) = NaN;
    end

else
    Rt = signal*signal';
    Rfb = zeros(SubArrayNum,SubArrayNum);
    for i = 1:AntNum - SubArrayNum + 1
        Rfb = Rfb + Rt(i:i+SubArrayNum-1,i:i+SubArrayNum-1);
    end
    Rfb = Rfb/(AntNum - SubArrayNum + 1);
    [V,D] = eig(Rfb);
    [~,ind] = sort(diag(D), 'descend');
    Vs = V(:,ind);
    Un = Vs(:, nsig+1:end);

    p1 = repmat(-1j*transpose(0:SubArrayNum-1)*2*pi*ElemSpace, 1, length(ang));
    p2 = repmat(sin(ang), SubArrayNum, 1);
    A = exp(p1.*p2);

    X = sum(abs((A'*Un)).^2, 2);
    
    pwr = 1./(X+eps(1));

    % Find DOA
    [~,locs] = findpeaks(pwr,'SortStr','descend');
    
    peaknum = min(nsig,length(locs));
    if peaknum > 0
        doas = ang_deg(locs(1:peaknum));
    else
        doas = [];
    end
    
    if nsig > length(locs)
        [~, I] = max(pwr);
        doas(length(locs)+1:nsig) = ang_deg(I);
    end
    
end
    
end

