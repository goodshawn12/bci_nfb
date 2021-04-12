% require PsychToolbox setup
% set current directory to the folder
folder_path = 'C:\Users\fnlab\Documents\bci_nfb';
cd(folder_path)

% addpath and tools
if ~exist('IS_SET_PATH')
    addpath('eeglab'); 
    eeglab; close
    bcilab; close
    cd(folder_path)
    addpath('media'); addpath(genpath('lib'))
    IS_SET_PATH = 1;
end
delete(timerfindall)
sca


%% input study#, subject and session information
% dialog box for user input
prompt = {'Subject ID:','Session ID:'};
dlgtitle = 'Input';
dims = [1 70];
opts.Resize = 'on';

% choose study number
study_list = {'R33', 'R01'};
[STUDY_ID,tf] = listdlg('ListString',study_list,'ListSize',[150,150],...
    'SelectionMode', 'Single', 'PromptString', 'Select the study name.');
config.STUDY_ID = study_list{STUDY_ID};
addpath(genpath(sprintf('%s_data', config.STUDY_ID)));

ID_input = inputdlg(prompt,dlgtitle,dims,{'',''},opts);

SUBJECT_ID = str2double(ID_input{1});
SESSION_ID = str2double(ID_input{2});

% check if entered values are valid
while (isnan(SUBJECT_ID) || isnan(SESSION_ID) || (SUBJECT_ID < 1) || (SUBJECT_ID > 90) || ... 
        ((mod(SUBJECT_ID,1) + mod(SESSION_ID,1)) ~= 0 )  || (SESSION_ID < 1)) % subj ID range 1~90
    dlgtitle = 'Invalid Value. Please enter again.';
    prompt = {'Enter subject ID (1 to 90):','Enter session ID:'};
    ID_input = inputdlg(prompt,dlgtitle,dims,{'',''},opts);
    SUBJECT_ID = str2double(ID_input{1});
    SESSION_ID = str2double(ID_input{2});
end

config.SUBJECT_ID = SUBJECT_ID;
config.SESSION_ID = SESSION_ID;

% load randomization information
if exist(sprintf('%s_subject_randomization.mat', config.STUDY_ID))
    load(sprintf('%s_subject_randomization.mat', config.STUDY_ID));  % randomization
    idx_subjID = find(randomization.SUBJECT_ID == SUBJECT_ID);
    config.IS_REAL_SESS = randomization.IS_REAL_SESS(idx_subjID);            % 1: real session, 0: mock session (use NFB from previous session)
    % define mock session
    if ~config.IS_REAL_SESS
        config.MOCK_SUBJECT_ID = randomization.MOCK_SUBJECT_ID(idx_subjID);  % Subject ID from which the pre-recorded NFB data were drawn
        
        % (TODO) check if real session data exist
        config.MOCK_SESSION_ID = config.SESSION_ID;     % Session ID from which the pre-recorded NFB data were drawn
    end
else
    error('Randomization error');
end

%% define configuration 
% EXP / NFB parameters
config.SIMULATION = 0;      % 1: use play-back EEG stream, 0: use online stream
config.DEMO = 0;            % 1: for testing (debug), 0: for actual experiment
config.RUN_CALIB = 1;       % run eye-open resting session
config.NFB_MODE = 2;        % 0: display gamma cohenerece (debug)
                            % 1: play movie - modulate movie frame size and sound volume
                            % 2: play movie - stop or play movie                                    
config.SAVE_ALL = 1;        % save NFB signals and gamma coherences
config.SKIP_TEST = 1;        % 1: skip PTB time sync tests

% define DEMO and ACTUAL experiment settings
if config.DEMO
    config.VERBOSE = 1;         % display information on screen (gamma coherence values) 
    config.REST_DURATION = 5;   % duration of resting session (in sec)
    config.NFB_INI = 30;        % duration of NFB session for determining threshold (in sec)
    config.NFB_TIME = 60;       % duration of NFB session (in sec)
    config.NFB_DYN_TIME = 15;   % duration of NFB session for determining dynamic threshold (in sec)
    config.USER_SELECT = 0;     % 1: user select movie, 0: default movie (best with size 1920 x 1080)
else
    
    
    config.VERBOSE = 0;         % display information on screen (gamma coherence values) 
    config.REST_DURATION = 60;  % duration of resting session (in sec)
    config.NFB_INI = 60;        % duration of NFB session for determining threshold (in sec)
    config.NFB_TIME = 60*15;    % duration of NFB session (in sec)
    config.NFB_DYN_TIME = 60*3; % duration of NFB session for determining dynamic threshold (in sec)
    config.USER_SELECT = 1;     % 1: user select movie, 0: default movie (best with size 1920 x 1080)
end

% Neurofeedback session
config.MOVIE_MIN_H = 100;           % minimum movie size / height (in pixels)
config.MOVIE_RESIZE_RATE = 5;       % increase visiable size (pixels / movie frame)
config.MOVIE_INITIAL_SIZE = 1.0;    % ratio of the movie size
config.VOLUME_MAX = 1.0;            % max sound volume (depends on movie soundtrack)

% Online signal processing
config.RESAMPLE_RATE = 500;         % resampling rate for online signal processing, []: keep the same sampling rate

% Computing gamma coherence
config.GCOH.WINSIZE = 3;            % window length for computing gamma coherence (in sec)
config.GCOH.CHANNAME = {'F3','F4'}; % channel labels for gamma coherence
config.GCOH.SRATE = 1;              % refresh rate for gamma coherence (in Hz) 
config.GCOH.alpha = 0.5;            % coefficient for determining target threshold

% LSL stream setting
lsl.OUTPUT_GCOH = 1;        % create lsl stream for gamma coherence (to be tested)
lsl.OUTPUT_NFB = 1;         % create lsl stream for neurofeedback signal (to be tested)
    
%% set up parameters
% define default movie files for the two NFB sessions
if ~config.USER_SELECT && exist('media\NFB_1_Nature_Classical.mp4') && exist('media\Feeling_Happy_Fish.mp4')
    config.MOVIE_NAME{1} = [folder_path '\media\NFB_1_Nature_Classical.mp4'];
    config.MOVIE_NAME{2} = [folder_path '\media\Feeling_Happy_Fish.mp4'];
else % user select movie file used for neurofeedback
    [movie_file,movie_path] = uigetfile([folder_path '\media\*.*'],'Select two movie files','MultiSelect','on');
    if length(movie_file) == 2
        config.MOVIE_NAME{1} = [movie_path movie_file{1}];
        config.MOVIE_NAME{2} = [movie_path movie_file{2}];
    else
        error('Please select two movie files')
    end
end

% load target thresholds from previous sessions
config.filepath_subj = [folder_path sprintf('\\%s_data\\Subj_%d',config.STUDY_ID, config.SUBJECT_ID)];
config.filepath_sess = [folder_path sprintf('\\%s_data\\Subj_%d\\Sess_%d',config.STUDY_ID, config.SUBJECT_ID,config.SESSION_ID)];
config.filename_prev = [folder_path sprintf('\\%s_data\\Subj_%d\\Sess_%d\\target_gcoh_subj%d_sess%d.mat', ...
    config.STUDY_ID,config.SUBJECT_ID,config.SESSION_ID-1,config.SUBJECT_ID,config.SESSION_ID-1)];
if ~exist(config.filepath_subj,'dir'), mkdir(config.filepath_subj); end
if ~exist(config.filepath_sess,'dir'), mkdir(config.filepath_sess); end
if exist(config.filename_prev,'file')
    load(config.filename_prev); % target_gcoh
    config.target_gcoh = target_gcoh;
else
    assert(config.SESSION_ID == 1, 'Target thresholds from previous sessions are missing. Check if SESSION_ID is input correctly.');
    config.target_gcoh = [];
end

% load NFB data from recorded session for MOCK NFB session
if ~config.IS_REAL_SESS
%     fprintf('Mock Session: importing data from Subject %d, Session %d\n',config.MOCK_SUBJECT_ID,config.MOCK_SESSION_ID);
    config.MOCK_filename = sprintf('%s_data\\Subj_%d\\Sess_%d\\target_gcoh_subj%d_sess%d.mat', ...
        config.STUDY_ID, config.MOCK_SUBJECT_ID,config.MOCK_SESSION_ID,config.MOCK_SUBJECT_ID,config.MOCK_SESSION_ID);
    if ~exist(config.MOCK_filename,'file')
        error('Missing file');
    end
end

%% playback LSL stream or resolve online stream
lsl.lslObj = lsl_loadlib();
if config.SIMULATION    % play back data stream from pre-recorded data
    playback_data = pop_loadset('R33_data\demo_data.set');
    handles = play_eegset_lsl('Dataset', playback_data, ...
        'DataStreamName', 'EEG2LSL', ...
        'EventStreamName', 'EEG2LSL-marker', ...
        'Background', true, 'NoMarkers', true);
    lsl.streamName = 'EEG2LSL';
else    % resovle online data stream
    streams = lsl_resolve_all(lsl.lslObj,0.1);
    streamnames = cellfun(@(s)s.name(),streams ,'UniformOutput',false);
    if isempty(streamnames)
        error('There is no stream visible on the network.');
    elseif length(streamnames) == 1
        lsl.streamName = streamnames{1};
    else
        [streamind, ok] = listdlg('ListString', streamnames, ...
            'SelectionMode', 'Single', 'PromptString', 'Select which EEG stream to use.');
        assert(ok && ~isempty(streamind), 'No LSL stream selection was made.')
        lsl.streamName = streamnames{streamind};
    end
end

%% read LSL stream from EEG device
lsl = initialize_lsl(lsl,config);
lsl.inlet = eval(lsl.streamName); % grab info from lsl streawm


%% start resting session
disp('Press Any Key To Start the Experiment!')
KbStrokeWait;
result = main_DynNFB(config,lsl); 

%% terminate all LSL streams
% terminate lsl streams
delete(lsl.outlet_event); 
if lsl.OUTPUT_GCOH, delete(lsl.outlet_gcoh); end
if lsl.OUTPUT_NFB, delete(lsl.outlet_nfb); end

% terminate simulated EEG stream
if config.SIMULATION, stop(handles); end

delete(timerfindall)

