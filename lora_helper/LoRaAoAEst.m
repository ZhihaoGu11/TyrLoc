function [doas] = LoRaAoAEst(rxWaveform, ID, DetectThreshold, LoraPara, PlotFigureFlag)

    doas = [];
    nsig = 1;
    
    L = LoraPara.symLen;
    
    dID = diff(ID);
    sp = find(dID == 1);
    if isempty(sp)
        return;
    end
    spstart = sp(1)+1 - floor((sp(1)+1)/LoraPara.symLen)*LoraPara.symLen;
    spend = sp(1)+1 + floor((length(ID) - sp(1))/LoraPara.symLen)*LoraPara.symLen;
    SwitchPoint = spstart:LoraPara.symLen:spend;

    pkt = LoraPreambleDetector(rxWaveform, DetectThreshold, LoraPara);
    %Check the frequency spectrum
    %stft(rxWaveform(pkt(1):pkt(1)+36*LoraPara.symLen-1), Fs,'Window',kaiser(256,5),'OverlapLength',220,'FFTLength',512);

    if isempty(pkt)
        fprintf("No pakcet detected\n");
        return;
    end

    UsedPreSymNum = LoraPara.PreSymNum - 1;
    rxPreamble = complex(zeros(L, UsedPreSymNum, length(pkt)));
    AntID = zeros(UsedPreSymNum, length(pkt));
    PrbIdx = zeros(UsedPreSymNum, length(pkt));

    for i = 1:length(pkt)
        temp = find((SwitchPoint - double(pkt(i))) >= 0);
        sigoffset = SwitchPoint(temp(1)) - pkt(i);
        for j = 1:UsedPreSymNum
            rxPreamble(1:L,j,i) = rxWaveform(pkt(i)+(j-1)*LoraPara.symLen+sigoffset:pkt(i)+(j-1)*LoraPara.symLen+L+sigoffset-1);
            AntID(j,i) = ID(pkt(i)+(j-1)*LoraPara.symLen+sigoffset);
            PrbIdx(j,i) = pkt(i)+(j-1)*LoraPara.symLen+sigoffset;
        end
    end
    pktInterval(1:size(rxPreamble,3), 1:size(rxPreamble,2)-1) = LoraPara.symTime;

    theta = angle(rxPreamble);
    phi = squeeze(angle(sum(exp(1j*theta),1)));

    if length(pkt) == 1
        phi = transpose(phi);
    end

    for N = 1:size(phi, 2)
        % Calibrate the phase distortion of Carrier Frequency Offset(CFO)
        % by inter-packet CFO estimation
        [ArrayCompositon, AL] = PhaseCalibration(AntID(:,N), pktInterval(N,:), rxPreamble(:,:,N));

        if isempty(ArrayCompositon)
            fprintf("Antenna Missing\n");
            return;
        end

        TF = (AL < 6);
        AL(TF) = [];
        ArrayCompositon(:,:,TF) = [];
        
        for i = 1:size(ArrayCompositon, 3)
            idx = ArrayCompositon(1,1:AL(i),i);
            x = ArrayCompositon(2,1:AL(i),i);
            d = ArrayCompositon(4,1:AL(i),i);
            Y = rxPreamble(:, x, N).*exp(-1j*d).*conj(rxPreamble(:, x-1, N));

            if AL<=5
                SubArrayNum = AL-2;
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
end


