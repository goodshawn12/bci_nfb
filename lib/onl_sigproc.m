function data = onl_sigproc(data,srate,config)

% Segment-wise analysis - offline analytic pipeline is applicable
%   - Channel selection
%   - Resample: resample() from MATLAB (not necessary?)
%   - Rereference: reref() from EEGLAB (to linked ears)
%   - Mean removal: for data visualization 
%   - Band-pass filter: cheb1ord() from MATLAB (not necessary?)
%   - ASR: ?? 

% Select channels
data_proc = data(config.GCOH.CH,:);

% Resampling: (use resample instead of downsample, with anti-aliasing) 
% anti-aliasing filter introduces delay in the signals?
if ~isempty(config.RESAMPLE_RATE)
    data_proc = resample(data_proc', config.RESAMPLE_RATE, srate)';
end

% Spatial filter - rereference
% data_proc = reref(data_proc, config.ref_ch);

% Temporal filter
for ch_i = 1:size(data_proc,1)
        
    % Mean removal
    data_proc(ch_i, :) = data_proc(ch_i, :) - mean(data_proc(ch_i, :));
    
    % Notch filtering
%     data_resampled(ch_i, :) = notch60(squeeze(data_resampled(ch_i, :)), param.resample_rate);

end % ch_i

data = data_proc;

end