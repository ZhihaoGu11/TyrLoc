function [rx_raw,ID] = AntIDExtractor(rx)
    %When using the PlutoSDR to receive signals, please set 'OutputDataType' to 'int16'
    %That will significantly speed up this function
    if isa(rx, 'int16')
        sign = bitand(imag(rx), int16(-32768)); %-32768=1000000000000000
        %Negative numbers are represented by the complement code
        %if the sign bit is 1: 1000000000000000--->1111000000000000
        bit15_12 = bitshift(sign, -3);
        bit11_0 = bitand(imag(rx), int16(4095)); %4095=0000111111111111
        Q = bitor(bit15_12, bit11_0);
        ID = bitand(imag(rx), int16(28672)); %28672=0111000000000000
        ID = bitshift(ID, -12);
        rx_raw = complex(real(rx), Q);
        rx_raw = double(rx_raw)/4096;
    else
        Q = floor(imag(rx)/2048);
        ID = zeros(length(Q), 1);
        for i = 1:length(Q)
            if Q(i) == 0 || Q(i) == -15
                ID(i) = 0;
                if Q(i) == 0
                    rx(i) = rx(i);
                else
                    rx(i) = rx(i) + 1j*28672; %14*2048
                end
            elseif Q(i) == 2 || Q(i) == -13
                ID(i) = 1;
                if Q(i) == 2
                    rx(i) = rx(i) - 1j*4096; %2*2048
                else
                    rx(i) = rx(i) + 1j*24576; %12*2048
                end
            elseif Q(i) == 4 || Q(i) == -11
                ID(i) = 2;
                if Q(i) == 4
                    rx(i) = rx(i) - 1j*8192; %4*2048
                else
                    rx(i) = rx(i) + 1j*20480; %10*2048
                end
            elseif Q(i) == 6 || Q(i) == -9
                ID(i) = 3;
                if Q(i) == 6
                    rx(i) = rx(i) - 1j*12288; %6*2048
                else
                    rx(i) = rx(i) + 1j*16384; %8*2048
                end
            elseif Q(i) == 8 || Q(i) == -7
                ID(i) = 4;
                if Q(i) == 8
                    rx(i) = rx(i) - 1j*16384; %8*2048
                else
                    rx(i) = rx(i) + 1j*12288; %6*2048
                end
            elseif Q(i) == 10 || Q(i) == -5
                ID(i) = 5;
                if Q(i) == 10
                    rx(i) = rx(i) - 1j*20480; %10*2048
                else
                    rx(i) = rx(i) + 1j*8192; %4*2048
                end
            elseif Q(i) == 12 || Q(i) == -3
                ID(i) = 6;
                if Q(i) == 12
                    rx(i) = rx(i) - 1j*24576; %12*2048
                else
                    rx(i) = rx(i) + 1j*4096; %2*2048
                end
            elseif Q(i) == 14 || Q(i) == -1
                ID(i) = 7;
                if Q(i) == 14
                    rx(i) = rx(i) - 1j*28672; %14*2048
                else
                    rx(i) = rx(i);
                end
            end
        end
        rx_raw = rx/4096;
    end
end
