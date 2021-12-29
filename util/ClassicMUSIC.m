function [doas, ang_deg, pwr] = ClassicMUSIC(signal, nsig, Resolution, ElemSpace, AntID)
% signal: the signal matrix, Size: SnapshotNum*AntennaNum
% nsig: the predefined number of signal source in MUSIC algorithm
% Resolution(deg): the resolution of MUSIC algorithm, usually 1 or 0.1
% ElemSpace: the space between adjacent antennas, using relative space (space/wavelength)
% AntID: the antenna ID of each column vector of the signal matrix

signal = signal.';
AntNum = size(signal,1);
R = signal*signal';

[V,D] = eig(R);

[~,ind] = sort(diag(D), 'descend');

Vs = V(:,ind);
Un = Vs(:, nsig+1:end);
ang = (-90:Resolution:90)/180*pi;

p1 = repmat(-1j*transpose(AntID-1)*2*pi*ElemSpace, 1, length(ang));
p2 = repmat(sin(ang), AntNum, 1);
A = exp(p1.*p2);

X = sum(A'*(Un*Un').*transpose(A), 2);

pwr = 1./(abs(X)+eps(1));

% Find DOA
ang_deg = (-90:Resolution:90);
[~,locs] = findpeaks(pwr,'SortStr','descend');
peaknum = min(nsig,length(locs));
if peaknum > 0
    doas = ang_deg(locs(1:peaknum));
else
    doas = [];
end

if nsig > length(locs)
    doas(length(locs)+1:nsig) = NaN;
end

end



