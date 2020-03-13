function onl_est_gcoh(config,lsl,isplot)

figure(1)
figure(2), 
start_time = 0;
tic
while true % start_time < 30
    % Grab online data via onl_peak():
    % should grab a longer window for filtering
    EEG = onl_peek(lsl.streamName,config.GCOH.WINSIZE,'seconds');
    
    % online filtering and artifact removal
    data = onl_sigproc(EEG.data,EEG.srate,config);
    
    % Compute gamma coherence
    gcoh = compute_gcoh(data,config.RESAMPLE_RATE);
    
    % output to LSL outlet 
    lsl.outlet_gcoh.push_sample(gcoh);
    
    % visualize data and gcoh
    if isplot
        figure(1), plot(data');
        figure(2), scatter(start_time, gcoh); set(gca,'YLim',[0,1]); hold on,
    end
    
    pause(1);
    start_time = toc;
end

end