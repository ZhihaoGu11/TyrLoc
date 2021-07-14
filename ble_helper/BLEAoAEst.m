function doas = BLEAoAEst(rxWaveform, ID, BlePara, PlotFigureFlag)

    doas = [];
    nsig = 1;
    
    SampleRate = BlePara.SampleRate;
    len_txWaveform = BlePara.len_txWaveform;
    pktFrq = BlePara.pktFrq;

    %Preamble Detection
    rxPower = rxWaveform.*conj(rxWaveform);
    W1 = movsum(rxPower, 200);
    R = W1(201:end)./W1(1:end-200);
    threshold = 10;
    posR = find(R > threshold);
    posR = posR + 200;
    diff_posR = diff(posR);
    peakIdx_posR = find(diff_posR > 0.8*SampleRate/pktFrq) + 1;
    slideStartIdx = [posR(peakIdx_posR(1)-1); posR(peakIdx_posR)];
    slideEndIdx = slideStartIdx + len_txWaveform;
 
    preOffset = 64;
    postOffset = 64;
    slideStartIdx = slideStartIdx - preOffset;
    slideEndIdx = slideEndIdx + postOffset;
    len = len_txWaveform + preOffset + postOffset;
    rxSlide = zeros(len, size(slideStartIdx,1));
    for i = 1:length(slideStartIdx)
        if slideEndIdx(i) + postOffset > length(rxWaveform)
            break;
        end
        slideLen = slideEndIdx(i) - slideStartIdx(i) + 1;
        rxSlide(1:slideLen,i) = rxWaveform(slideStartIdx(i):slideEndIdx(i));
    end

    prbDet = comm.PreambleDetector(BlePara.RefSeq, 'Detections', 'First');

    % CoarseCFO Estimation,
    % When collecting signals, you should enable it
    % freqCompensator = comm.CoarseFrequencyCompensator('Modulation', 'OQPSK',...
    %                 'SampleRate', SampleRate,...
    %                 'SamplesPerSymbol', 2*BlePara.SamplesPerSymbol,...
    %                 'FrequencyResolution', 100);

    prbaccLen = length(BlePara.RefSeq);
    rxPreamble = zeros(prbaccLen,size(rxSlide,2));

    i=1;
    pkt = [];
    % Loop to decode the captured BLE samples
    for num = 1:size(rxSlide,2)

        rcvSig = rxSlide(:,num);
        rcvDCFree = rcvSig - mean(rcvSig); % Remove the DC offset
        
        % CoarseCFO Estimation,
        % When collecting signals, you should enable it
        % [rcvDCFree, CoarseCFO] = freqCompensator(rcvDCFree); 
        % release(freqCompensator)
        
        rcvFilt = conv(rcvDCFree,BlePara.h,'same'); % Perform gaussian matched filtering

        % Perform frame timing synchronization
        [~, dtMt] = prbDet(rcvFilt);
        release(prbDet);
        prbDet.Threshold = max(dtMt);
        prbIdx = prbDet(rcvFilt);
        lenRefSeq = length(BlePara.RefSeq);
        IDX(num) = prbIdx-lenRefSeq+1;

        if IDX(num) > 0
            rxPreamble(1:lenRefSeq,i) = rcvFilt(IDX(num):prbIdx);
            pkt(i) = IDX(num) + slideStartIdx(num) - 1;
            i = i + 1;
        end

        release(prbDet)
    end
    
    rxPreamble(:, length(pkt)+1:end) = [];
    AntID = ID(pkt);

    dID = diff(ID);
    sp = find(dID ~= 0);
    LenPreamble = 320;
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
        if pkt(i) - 2*LenPreamble > sp(j)
            j = j+1;
        elseif pkt(i) + 2*LenPreamble <= sp(j)
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
        
        [doas(i, 1:nsig), ang, pwr] = NLASpatialMUSIC(Y, nsig, 0.1, 0.5, idx, SubArrayNum);
        
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

