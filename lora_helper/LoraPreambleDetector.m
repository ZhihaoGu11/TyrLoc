function pkt = LoraPreambleDetector(rxWaveform, DetectThreshold, LoraPara)

    pkt = [];
    PreSymNum = LoraPara.PreSymNum - 1;
    BW = LoraPara.BW;
    SF = LoraPara.SF;
    Fs = LoraPara.Fs;
    symTime = 2^SF/BW;
    symLen = 2^SF*Fs/BW;
    f0 = -BW/2;
    f1 = BW/2;
    t = 0:1/Fs:symTime - 1/Fs;
    upchirpI = chirp(t, f0, symTime, f1, 'linear', 90);
    upchirpQ = chirp(t, f0, symTime, f1, 'linear', 0);
    upChirp = transpose(complex(upchirpI, upchirpQ));

    %spectrogram(rxWaveform,256,192,256,Fs,'yaxis','centered');
    A1 = conj(rxWaveform(1:end-symLen)).*rxWaveform(symLen+1:end);
    P = movsum(A1,symLen);
    %Simliar to Sch-Cox algorithm
    A2 = rxWaveform(symLen+1:end).*conj(rxWaveform(symLen+1:end));
    R = movsum(A2, symLen);
    M = P.*conj(P)./(R.*R + 1);
    sumM = movsum(M, 200) + eps(1);
    W1 = sumM(201:end)./sumM(1:end-200);
    posR = find(W1 > DetectThreshold*1000);
    posR = posR + 200;
    diff_posR = diff(posR);
    peakIdx_posR = find(diff_posR > 32*symLen) + 1;
    slideStartIdx = posR(peakIdx_posR);
    if isempty(slideStartIdx)
        fprintf("No preamble detected\n");
        return
    end
    if posR(1) ~= 1
        slideStartIdx = [posR(1) - symLen;slideStartIdx];
    end
    if slideStartIdx(end) + PreSymNum*symLen > length(rxWaveform)
        slideStartIdx(end) = [];
    end
    slideEndIdx = slideStartIdx + (PreSymNum+4)*symLen;
    if slideStartIdx(1) < 1
        slideEndIdx(1) = [];
        slideStartIdx(1) = [];
    end
    if slideEndIdx(end) > length(rxWaveform)
        slideEndIdx(end) = [];
        slideStartIdx(end) = [];
    end
    
    agc10 = comm.AGC('DesiredOutputPower',10);
    SF2 = symLen;
    nfft = symLen;
    idx = int64(zeros(1,(PreSymNum+4)));
    power = zeros(1,(PreSymNum+4));
    for N = 1:length(slideStartIdx)
        rxSlide = rxWaveform(slideStartIdx(N):slideEndIdx(N));
        rxSlide = agc10(rxSlide);
        hopidx = 0:SF2:length(rxSlide)-SF2;
        d = zeros(SF2,length(hopidx)) + 1j*ones(SF2,length(hopidx));
        for i = 1:length(hopidx)
            d(1:SF2,i) = rxWaveform(slideStartIdx(N)+hopidx(i):slideStartIdx(N)+hopidx(i)+SF2-1).*conj(upChirp);
        end


        Y = fft(d,nfft,1);
        P2 = abs(Y/nfft);
        P1 = P2(1:nfft/2+1,:);
        P1(2:end-1,:) = 2*P1(2:end-1,:);
              

        for i = 1:size(P1,2)
            power(i) = max(P1(:,i));
            Eq = find(P1(:,i) == power(i));
            idx(i) = Eq(1);
        end
        

        relativepower = power(2:end)/power(1);
        for i = 1:size(idx,2)-PreSymNum
            temppower = relativepower(i:i+PreSymNum-1);
            tempidx = idx(i+1:i+PreSymNum);
            if sum(temppower > 5) == PreSymNum && sum(abs(tempidx - mean(tempidx)) < 5) == PreSymNum
                pkt = [pkt; slideStartIdx(N) - idx(i+1)*Fs/BW + 1 + i*symLen];
                break;
            end
        end
        
    end
    
    
    line = zeros(length(rxWaveform), 1);
    for i = 1:length(slideStartIdx)
        line(slideStartIdx(i):slideEndIdx(i),1) = max(abs(rxWaveform));
    end
    

    if isempty(pkt)
        fprintf("Packet Loss\n");
        return;
    end
    
end



