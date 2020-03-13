function coh_gamma = compute_gcoh(data,srate,isplot)

if nargin < 3, isplot = 0; end

f_gamma = [30,50];

% use default hamming window and eight sections for computing coherence
NFFT = 2^nextpow2(srate);
[Cxy,f] = mscohere(data(1,:),data(2,:),[],[],NFFT,srate);

% WINDOW = hamming(srate); 
% [Cxy,f] = mscohere(data(1,:),data(2,:),WINDOW,[],NFFT,srate);

f_range = @(x) find(f>=x(1) & f<=x(2));
coh_gamma = mean(sqrt(Cxy(f_range(f_gamma))));

if isplot
    figure, plot(f,sqrt(Cxy));
end

end