function lsl = initialize_lsl(lsl,config)

%--------------------------------------------------------------------------
%              Read LSL stream from EEG device
%--------------------------------------------------------------------------
% This creates an object named streamName with EEG-set-like properties and methods
% This starts background acquisition on the online stream
run_readlsl_NFB('MatlabStream', lsl.streamName, ...
    'DataStreamQuery', ['type=''EEG'''], ...
    'MarkerStreamQuery', '', ...
    'BufferLength', 60);
lsl.streamName = lsl.streamName(~ismember(lsl.streamName,['-' ' ']));

%--------------------------------------------------------------------------
%              Create LSL outlet for gamma coherence
%--------------------------------------------------------------------------
fprintf('Creating LSL stream for gamma coherence.\n');
info = lsl_streaminfo(lsl.lslObj, 'NFB_coherence', 'EEG', 1, config.GCOH.SRATE, 'cf_float32', 'NFB_coherence');
lsl.outlet_gcoh = lsl_outlet(info);

%--------------------------------------------------------------------------
%              Create LSL outlet for feedback signal
%--------------------------------------------------------------------------
fprintf('Creating LSL stream for feedback signal.\n');
info = lsl_streaminfo(lsl.lslObj, 'NFB_control', 'EEG', 1, config.GCOH.SRATE, 'cf_float32', 'NFB_control');
lsl.outlet_nfb = lsl_outlet(info);


%--------------------------------------------------------------------------
%              Create LSL eventmarker outlet
%--------------------------------------------------------------------------
fprintf('Creating LSL marker stream.\n');
info = lsl_streaminfo(lsl.lslObj, 'NFB_marker', 'Markers', 1, 0, 'cf_string', 'NFB_marker');
lsl.outlet_event = lsl_outlet(info);

end