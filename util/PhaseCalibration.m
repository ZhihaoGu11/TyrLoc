function [ArrayCompositon, AL] = PhaseCalibration(AntID, pktInterval, Preamble)   
    
    RelPhi = [];
    ArrayCompositon = [];
    AL = [];
    phi = angle(sum(Preamble));
    
    idx_zero = (AntID == 0);
    idx_cal = idx_zero(1:end-1) & idx_zero(2:end);  %idx_zero is the index of AntID~=0
    cm = Preamble(:,idx_cal).*conj(Preamble(:,[false;idx_cal]));
    avgphi = angle(sum(cm));
    cfo(idx_cal) = avgphi./(2*pi*pktInterval(idx_cal));
    idx_nonzero = ~idx_zero; 
    
    k = 0;
    cnt = 1;
    for i = 1:length(idx_zero) - 1
        %Using Pattern C
        if isequal(idx_zero(i:i+1), [1;1])
            tempcfo = cfo(i);
            k = i;
        elseif idx_nonzero(i) == 1 && k~=0
            RelPhi(cnt,5) = 2*pi*tempcfo*sum(pktInterval(k+1:i-1)); %Phase Distortion Caused by CFO
            p = phi(i) - phi(k+1) - RelPhi(cnt,5);
            RelPhi(cnt,1) = wrapToPi(p); %Wrap the angle in radians to [−pi pi]
            RelPhi(cnt,2) = AntID(i); %Ant ID
            RelPhi(cnt,3) = i; %the colunm index of the preamble
            %Phase Distortion Caused by CFO + Phase of the Pivot Antenna
            RelPhi(cnt,4) = phi(k+1) + RelPhi(cnt,5); 
            cnt = cnt+1;
        end
    end
    
    if isempty(RelPhi)
        fprintf("Pattern Sequence is incomplete\n");
        return
    end
    
    j = 1;
    k = 1;
    array = [];
    tempidx= [];
    for i = 1:size(RelPhi,1) - 1
        if j == 1
            array(1) = RelPhi(i,2);
            tempidx(1) = i;
            j = j+1;
        end

        if array(j-1) < RelPhi(i+1,2)
            array(j) = RelPhi(i+1,2);
            tempidx(j) = i+1;
            j = j+1;
        else
            templen = length(array);
            
            ArrayCompositon(1,1:templen,k) = array;
            ArrayCompositon(2,1:templen,k) = RelPhi(tempidx,3);
            ArrayCompositon(3,1:templen,k) = RelPhi(tempidx,4);
            ArrayCompositon(4,1:templen,k) = RelPhi(tempidx,5);
            
            AL(k) = templen;
            j = 1;
            k = k + 1;
            array = [];
            tempidx= [];
        end
    end
    
end

