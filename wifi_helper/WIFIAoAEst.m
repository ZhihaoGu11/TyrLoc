function doas = WIFIAoAEst(rxWaveform, ID, DetectThreshold, WifiPara, PlotFigureFlag)

    doas = [];
    nsig = 1;
    
    cfgHT = WifiPara.cfgHT;
    ind = wlanFieldIndices(cfgHT);
    
    SampleRate = WifiPara.SampleRate;
    pktFrq = WifiPara.pktFrq;
    fs = SampleRate;

    %Preamble Detection
    rxPower = rxWaveform.*conj(rxWaveform);
    W1 = movsum(rxPower, 200);
    R = W1(201:end)./W1(1:end-200);
    threshold = 10;
    posR = find(R > threshold);
    posR = posR + 200;
    diff_posR = diff(posR);
    peakIdx_posR = find(diff_posR > 0.8*SampleRate/pktFrq) + 1;
    if isempty(peakIdx_posR)
        fprintf("No packet detected\n");
        return;
    end
    slideStartIdx = [posR(peakIdx_posR(1)-1); posR(peakIdx_posR)];
    slideEndIdx = slideStartIdx + WifiPara.len_txWaveform;
    
    %Dividing the long signal frame into small fragment
    preOffset = 200;
    postOffset = 200;
    slideStartIdx = slideStartIdx - preOffset;
    slideEndIdx = slideEndIdx + postOffset;
    len = WifiPara.len_txWaveform + preOffset + postOffset;
    rxSlide = zeros(len, size(slideStartIdx,1));
    for i = 1:length(slideStartIdx)
        if slideEndIdx(i) > length(rxWaveform)
            break;
        end
        slideLen = slideEndIdx(i) - slideStartIdx(i) + 1;
        rxSlide(1:slideLen,i) = rxWaveform(slideStartIdx(i):slideEndIdx(i));
    end

    i = 1;
    for num = 1:size(rxSlide, 2)
        rcvSig = rxSlide(:,num);
        coarsePktOffset = modified_wlanPacketDetect(rcvSig,cfgHT.ChannelBandwidth, 0, DetectThreshold);

        if isempty(coarsePktOffset)
            continue;
        end

        if coarsePktOffset+800 > slideLen
            continue;
        end

        rcvSig = rcvSig(coarsePktOffset+1:coarsePktOffset+800);
        
        % Extract L-STF and perform coarse frequency offset correction
        lstf = rcvSig(ind.LSTF(1):ind.LSTF(2)); 

        coarseFreqOff = modified_wlanCoarseCFOEstimate(lstf);

        rcvSig = helperFrequencyOffset(rcvSig,fs,-coarseFreqOff);

        % Extract the non-HT fields and determine fine packet offset
        nonhtfields = rcvSig(ind.LSTF(1):ind.LSIG(2)); 

        finePktOffset = modified_wlanSymbolTimingEstimate(nonhtfields,WifiPara.txLLTF);

        % Determine final packet offset
        pktOffset = coarsePktOffset+finePktOffset;
        IDX(i) = pktOffset;
        if pktOffset <= 0
            continue;
        end
        pkt(i) = pktOffset + slideStartIdx(num) + 160;
        
        % Extract L-LTF and perform fine frequency offset correction
        lltf = rcvSig(finePktOffset+(ind.LLTF(1):ind.LLTF(2))); 
        fineFreqOff = modified_wlanFineCFOEstimate(lltf);
        
        %perform FrequencyOffsetCalibration to rcvSig and re-extract LLTF
        rcvSig = helperFrequencyOffset(rcvSig,fs,-fineFreqOff);
        lltf = rcvSig(finePktOffset+(ind.LLTF(1):ind.LLTF(2)));

        % Extract HT-LTF samples from the waveform
        htltf = rcvSig(finePktOffset+(ind.HTLTF(1):ind.HTLTF(2)),:);

        % Calculate the CSI
        % htltfDemod = wlanHTLTFDemodulate(htltf,cfgHT);
        % chanEst = wlanHTLTFChannelEstimate(htltfDemod,cfgHT);
        % CSI(:,i) = chanEst;
        
        LLTF(:, i) = lltf;
        HTLTF(:, i) = htltf;
        
        i = i+1;
    end
    rxPreamble = [LLTF;HTLTF];
    AntID = ID(pkt);

    dID = diff(ID);
    sp = find(dID ~= 0);

    LenHtltf = 240;
    Lenpkt = length(pkt);
    Lensp = length(sp);
    i = 1;
    j = 1;
    k = 1;
    broken = [];
    newpkt = [];
    while i <= Lenpkt
        if j > Lensp
            newpkt = [newpkt, pkt(i:end)];
            break;
        end
        if pkt(i) - 2*LenHtltf > sp(j)
            j = j+1;
        elseif pkt(i) + 2*LenHtltf <= sp(j)
            newpkt(k) = pkt(i);
            k = k + 1;
            i = i + 1;
        else
            broken = [broken, i];
            i = i + 1;
        end
    end

    if length(newpkt) < length(pkt)
        pkt(broken) = [];
        AntID(broken) = [];
        rxPreamble(:, broken) = [];
    end

    
    pktInterval = diff(pkt)/SampleRate;
    % Calibrate the phase distortion of Carrier Frequency Offset(CFO)
    % by inter-packet CFO estimation
    [ArrayCompose, AL] = PhaseCalibration(AntID, pktInterval, rxPreamble);
    
    TF = (AL < 6);
    AL(TF) = [];
    ArrayCompose(:,:,TF) = [];

    if isempty(ArrayCompose)
        fprintf('Antenna Missing\n');
        return;
    end

    for i = 1:size(ArrayCompose, 3)
        idx = ArrayCompose(1,1:AL(i),i);
        x = ArrayCompose(2,1:AL(i),i);
        d = ArrayCompose(4,1:AL(i),i);

        Y = rxPreamble(:, x).*exp(-1j*d).*conj(rxPreamble(:, x-1));

        if AL(i)<=5
            SubArrayNum = AL(i)-2;
        else
            SubArrayNum = 5;
        end
        
        [doas(i, 1:nsig), ang, pwr] = NLASpatialMUSIC(Y, nsig, 0.1, 0.485, idx, SubArrayNum);
        
        %plot the AoA Spectrum
        if PlotFigureFlag
            figure(1)
            cla
            plot(ang,10*log(pwr))
            xlabel("Angle (deg)")
            ylabel("Power (dB)")
            title("AoA Spectrum")
            xlim([-90, 90])
            pause(0.01)
        end
    end
end

