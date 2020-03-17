function result = main_NFB(config,lsl)

% define parameters
BG_COLOR = [127 127 127];
text.TEXT_COLOR = [1 1 1];
text.TEXT_FONT = 'Arial';
text.FONT_SIZE = 32;
text.FONT_SIZE_FIXATION = 128;
result = [];

% find channel indices for computing coherence
config.GCOH.CH = zeros(1,2);
for it = 1:2
    config.GCOH.CH(it) = find(strcmp({lsl.inlet.chanlocs.labels},config.GCOH.CHANNAME{it}));
end

%% ------------------------------------------------------------------------
%              Setup PsychoToolbox and Prepare Stim. Screen
%--------------------------------------------------------------------------
fprintf('NFB: Creating windows.\n');

% Check if Psychtoolbox is properly installed:
AssertOpenGL;

% Setup PTB with some default values
PsychDefaultSetup(2);

% For demo purpose - tolerate inaccurate timing (change to 0 for exp)
Screen('Preference', 'SkipSyncTests', config.DEMO);
if ~config.DEMO, HideCursor; end

% prepare keyboard information
KbName('UnifyKeyNames');
escKey = KbName('ESCAPE');
spaceKey = KbName('SPACE');

% if multiple screens opened, select the last one
screenNumber = max(Screen('Screens'));

% obtain the window size and open a window
[WINDOW_WIDTH, WINDOW_HEIGHT] = Screen('WindowSize',screenNumber);
[window, windowRect] = Screen('OpenWindow', screenNumber, BG_COLOR, [], [], 2);
[centX, centY] = RectCenter(windowRect);

% Flip to clear
Screen('Flip', window);


%% ------------------------------------------------------------------------
%              Prepare off-screen windows for experiment
%--------------------------------------------------------------------------
prepareMsg = sprintf('Now loading stimulation screens...');
prepareScreen = sys_prepInstructionScreen(window, prepareMsg, BG_COLOR, ...
    text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE, centX, centY);
Screen('CopyWindow', prepareScreen, window);
Screen('Flip', window);

startMsg_exp0 = cell(1,8);
startMsg_exp0{1} = 'For the next 1 minute, please sit completely still, without talking, moving, or fidgeting. ';
startMsg_exp0{2} = ' ';
startMsg_exp0{3} = 'You will keep your eyes open, fixate at the cross on the screen, ';
startMsg_exp0{4} = ' ';
startMsg_exp0{5} = 'try to minimize eye blinks and just relax your eyes on the screen.';
startMsg_exp0{6} = ' ';
startMsg_exp0{7} = ' ';
startMsg_exp0{8} = 'Are you ready? Press ENTER To Start.';
startExp0Screen = sys_prepInstructionScreen(window, startMsg_exp0, BG_COLOR, ...
    text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE, centX, centY);

exp0_rest = {'Rest'};
exp0_Screen_rest = sys_prepInstructionScreen(window, exp0_rest, BG_COLOR, ...
    text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE, centX, centY);

exp0_fixation = {'+'};
exp0_Screen_fixation = sys_prepInstructionScreen(window, exp0_fixation, BG_COLOR, ...
    text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE_FIXATION, centX, centY);

startMsg_NFB = cell(1,6);
startMsg_NFB{1} = 'You will start the neurofeedback training.';
startMsg_NFB{2} = ' ';
startMsg_NFB{3} = 'For the next 15 minute, please sit still, without talking, moving, or fidgeting. ';
startMsg_NFB{4} = ' ';
startMsg_NFB{5} = ' ';
startMsg_NFB{6} = 'Are you ready? Press ENTER to continue.';
startNFBScreen = sys_prepInstructionScreen(window, startMsg_NFB, BG_COLOR, ...
    text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE, centX, centY);

breakMsg_NFB = cell(1,3);
breakMsg_NFB{1} = 'Take a break!';
breakMsg_NFB{2} = ' ';
breakMsg_NFB{3} = 'When you are ready, press ENTER to continue.';
breakNFBScreen = sys_prepInstructionScreen(window, breakMsg_NFB, BG_COLOR, ...
    text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE, centX, centY);


%% ----------------------------------------------------------------------
%             Eye-open resting EEG
%----------------------------------------------------------------------
Priority(1);

if config.RUN_CALIB
    disp('NFB: Enter Calibration - Resting');
    
    % Event marker
    lsl.outlet_event.push_sample({'exp_rest'});
    
    % present first screen
    Screen('CopyWindow', startExp0Screen, window);
    Screen('Flip', window);
    KbStrokeWait;
    
    % rest - start
    lsl.outlet_event.push_sample({'rest_start'});
    Screen('CopyWindow', exp0_Screen_fixation, window);
    Screen('Flip', window);
    
    start_time = GetSecs;
    while (GetSecs-start_time) < config.REST_DURATION
        % break the loop if press ESC key
        [~, ~, keyCode] = KbCheck;
        if keyCode(escKey)
            Screen('CloseAll');
            return;
        end
    end
    % rest - end
    lsl.outlet_event.push_sample({'rest_end'});
    
end


%% ------------------------------------------------------------------------
%         Compute gamma coherence and determine target threshold
%--------------------------------------------------------------------------

% Grab online data during rest via onl_peak(): at most buffer_length
% increase buffer_length to 60, but may waste time moving data in buffer
calib = onl_peek(lsl.streamName,config.REST_DURATION,'seconds');

% online filtering and artifact removal
calib_data = onl_sigproc(calib.data,calib.srate,config);

% extract gamma coherence during resting session
REST_GCOH = compute_gcoh(calib_data,calib.srate);
fprintf('NFB: gamma coherence of resting session is %f\n',REST_GCOH);

% Display
if config.VERBOSE
    msg_NFB = cell(1,2);
    msg_NFB{1} = 'Resting gamma coherence is:';
    msg_NFB{2} = num2str(REST_GCOH);
    msg_NFBScreen = sys_prepInstructionScreen(window, msg_NFB, BG_COLOR, ...
        text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE, centX, centY);
    
    % present first screen
    Screen('CopyWindow', msg_NFBScreen, window);
    Screen('Flip', window);
    KbStrokeWait;
end

%% ----------------------------------------------------------------------
%                       NFB Session
%----------------------------------------------------------------------
disp('NFB: Enter Neurofeedback Session');
msg_GCOH = cell(1,5);
msg_GCOH{2} = ' ';
msg_GCOH{4} = ' ';

% Event marker
lsl.outlet_event.push_sample({'NFB_exp'});

% import pre-recorded NFB values for MOCK neurofeedback session
if ~config.IS_REAL_SESS
    if config.VERBOSE
        disp('NFB: Mock Session - starting mock neurofeedback');
    end
    if exist(config.MOCK_filename,'file')
        temp = load(config.MOCK_filename); % target_gcoh, gcoh_all, nfb_all
        if isfield(temp,'nfb_all')
            config.MOCK_NFB_ALL = temp.nfb_all;
        else
            error('NFB: no neurofeedback signals available for MOCK NFB session');
        end
        if isfield(temp,'target_gcoh')
            config.MOCK_TARGET_GCOH = temp.target_gcoh(end);
        else
            error('NFB: no target coherence available for MOCK NFB session');
        end
    else
        error('NFB: no pre-recorded NFB data available for MOCK NFB session');
    end
end

% present first screen
Screen('CopyWindow', startNFBScreen, window);
Screen('Flip', window);
KbStrokeWait;

% ======================================================================
%   MAIN LOOP: NEUROFEEDBACK
% ======================================================================

% initiate variable
TARGET_GCOH = [];
gcoh_all = zeros(2,config.NFB_TIME*config.GCOH.SRATE);  % store gamma coherence during the experiment
nfb_all = zeros(2,config.NFB_TIME*config.GCOH.SRATE);   % store nfb signal during the experiment

for SESSION_ID = 1:2
    % start the neurofeedback
    lsl.outlet_event.push_sample({'NFB_start_block'});
    
    % Open movie file
    if config.NFB_MODE
        [NFB_movie, MOVIE_DURATION, MOVIE_FPS, MOVIE_W, MOVIE_H]= Screen('OpenMovie', window, config.MOVIE_NAME{SESSION_ID});
    end
    
    start_time = GetSecs;
    continue_NFB = 1;
    visibleSize = config.MOVIE_INITIAL_SIZE*MOVIE_H;
    
    % Start playback engine
    if config.NFB_MODE
        Screen('PlayMovie', NFB_movie, 1);
    end
    
    while continue_NFB && (GetSecs-start_time)<config.NFB_TIME
        % record inner loop time
        nfb_idx = floor((GetSecs-start_time)/config.GCOH.SRATE) + 1;
        
        % process online data and compute gamma coherence
        EEG = onl_peek(lsl.streamName,config.GCOH.WINSIZE,'seconds');
        data = onl_sigproc(EEG.data,EEG.srate,config);
        gcoh = compute_gcoh(data,EEG.srate);
        gcoh_all(SESSION_ID,nfb_idx) = gcoh;
        
        % output to LSL outlet for gamma coherence
        if lsl.OUTPUT_GCOH, lsl.outlet_gcoh.push_sample(gcoh); end
        
        % compute NFB control signal
        if SESSION_ID == 1
            if nfb_idx <= config.NFB_INI    % initial phase for determining GCOH
                NFB_SIGNAL = true;
            elseif nfb_idx > config.NFB_INI && config.IS_REAL_SESS
                % determine the target value for the NFB session
                if isempty(TARGET_GCOH)
                    % skip the first N seconds (N = window size for computing GCOH
                    idx_range = (config.GCOH.WINSIZE+1):(nfb_idx-1);
                    INI_GCOH = mean( gcoh_all(SESSION_ID,idx_range) );  % average GCOH in the initial phase
                    
                    % logic flow for determining the target value
                    if isempty(config.target_gcoh) % initial session
                        assert(config.SESSION_ID == 1, 'NFB: missing target_gcoh from previous sessions')
                        TARGET_GCOH = 1.05*INI_GCOH;
                    else
                        assert(config.SESSION_ID == (length(config.target_gcoh)+1), 'NFB.m: recorded target_gcoh mistached with session ID');
                        config.target_gcoh(config.SESSION_ID).rest = INI_GCOH;
                        
                        if INI_GCOH >= config.target_gcoh(config.SESSION_ID-1).nfb % current coherence is larger than previous target threshold
                            TARGET_GCOH = INI_GCOH;
                        else
                            if config.SESSION_ID > 4 % current coherence is smaller than previous 4 consecutive sessions
                                if INI_GCOH < config.target_gcoh(config.SESSION_ID-1).nfb && ...
                                        config.target_gcoh(config.SESSION_ID-1).rest < config.target_gcoh(config.SESSION_ID-2).nfb && ...
                                        config.target_gcoh(config.SESSION_ID-2).rest < config.target_gcoh(config.SESSION_ID-3).nfb && ...
                                        config.target_gcoh(config.SESSION_ID-3).rest < config.target_gcoh(config.SESSION_ID-4).nfb
                                    TARGET_GCOH = 1.05 * config.target_gcoh(config.SESSION_ID-1).nfb;
                                end
                            end
                            if isempty(TARGET_GCOH)
                                TARGET_GCOH = config.GCOH.alpha * INI_GCOH + (1-config.GCOH.alpha) * config.target_gcoh(config.SESSION_ID-1).nfb;
                            end
                        end
                    end
                end
                % compute NFB_SIGNAL
                NFB_SIGNAL = (gcoh>=TARGET_GCOH);
            else % MOCK session case
                INI_GCOH = config.MOCK_TARGET_GCOH.ini;
                TARGET_GCOH = config.MOCK_TARGET_GCOH.nfb;
                NFB_SIGNAL = config.MOCK_NFB_ALL(SESSION_ID,nfb_idx);
            end
            
        elseif SESSION_ID == 2 % use the same target threshold from first session
            if config.IS_REAL_SESS
                NFB_SIGNAL = (gcoh>=TARGET_GCOH);
            else
                NFB_SIGNAL = config.MOCK_NFB_ALL(SESSION_ID,nfb_idx);
            end
        end
        nfb_all(SESSION_ID,nfb_idx) = NFB_SIGNAL; % save the NFB_SIGNAL
        
        % output to LSL outlet for NFB control signal
        if lsl.OUTPUT_NFB, lsl.outlet_nfb.push_sample(double(NFB_SIGNAL)); end
        
        % neurofeedback modes
        if config.NFB_MODE == 0 % mode 0: display gamma cohenerece (debug)
            msg_GCOH{1} = sprintf('Time elapsed: %f seconds', GetSecs - start_time);
            msg_GCOH{3} = sprintf('Gamma coherence: %f', gcoh);
            msg_GCOH{5} = sprintf('Neurofeedback: %d', NFB_SIGNAL);
            msg_GCOHScreen = sys_prepInstructionScreen(window, msg_GCOH, BG_COLOR, ...
                text.TEXT_COLOR, text.TEXT_FONT, text.FONT_SIZE, centX, centY);
            Screen('CopyWindow', msg_GCOHScreen, window);
            Screen('Flip', window);
            
        elseif config.NFB_MODE == 2 % mode 2: play movie - stop or play movie
            % play movie at normal or super slow speed
            if NFB_SIGNAL
                Screen('PlayMovie', NFB_movie, 1);
            else % play at super slow speed (1 frame per second)
                Screen('PlayMovie', NFB_movie, 1/MOVIE_FPS, [], 0);
            end
        end
        
        % wait until the next gamma coherence refreshes, including
        % computing time and presentation time
        while (GetSecs-start_time) < (nfb_idx * config.GCOH.SRATE)
            
            if ~config.NFB_MODE == 0
                % Wait for next movie frame, retrieve texture handle to it
                movie_frame = Screen('GetMovieImage', window, NFB_movie);
                % Valid texture returned? A negative value means end of movie reached:
                if movie_frame<=0
                    disp('NFB: movie ends');
                    Screen('CloseAll');
                    return;
                end
                
                % mode 1: play movie - modulate movie frame size and sound volume
                if config.NFB_MODE == 1
                    % determine visible size of the movie frame
                    if NFB_SIGNAL
                        visibleSize = visibleSize + config.MOVIE_RESIZE_RATE;
                    else
                        visibleSize = visibleSize - config.MOVIE_RESIZE_RATE;
                    end
                    
                    % check range of visible size
                    if visibleSize > MOVIE_H
                        visibleSize = MOVIE_H;
                    elseif visibleSize < config.MOVIE_MIN_H
                        visibleSize = config.MOVIE_MIN_H;
                    end
                    
                    % Define source rectangular area for showing the movie frame
                    srcRect=[round((MOVIE_W - visibleSize*MOVIE_W/MOVIE_H)/2), round((MOVIE_H - visibleSize)/2), ...
                        round((MOVIE_W + visibleSize*MOVIE_W/MOVIE_H)/2), round((MOVIE_H + visibleSize)/2)];
                    
                    % Draw the new texture immediately to screen:
                    Screen('DrawTexture', window, movie_frame, srcRect);
                    
                    % determine sound volume based on feedback signal
                    soundvolume = config.VOLUME_MAX * (visibleSize - config.MOVIE_MIN_H) / (MOVIE_H - config.MOVIE_MIN_H);
                    
                    % modify parameters for movie playback (low overhead while playback is active)
                    Screen('PlayMovie', NFB_movie, 1, [], soundvolume);
                    
                elseif config.NFB_MODE == 2
                    % Draw the new texture immediately to screen:
                    Screen('DrawTexture', window, movie_frame);
                end
                
                if config.VERBOSE
                    Screen(window, 'TextFont', text.TEXT_FONT);
                    Screen(window, 'TextSize', text.FONT_SIZE);
                    Screen('DrawText', window, sprintf('Time elapsed: %.1f seconds', GetSecs - start_time), 50, 50, text.TEXT_COLOR);
                    Screen('DrawText', window, sprintf('Gamma coherence: %f', gcoh), 50, 100, text.TEXT_COLOR);
                    Screen('DrawText', window, sprintf('Neurofeedback: %d', NFB_SIGNAL), 50, 150, text.TEXT_COLOR);
                end
                
                % present the edited movie frame
                Screen('Flip', window);
                
                % Release texture:
                Screen('Close', movie_frame);
            end
            
            % break the loop if press SPACE key; break the exp if press ESC key
            [~, ~, keyCode] = KbCheck;
            if keyCode(escKey)
                sca
                return
            end
        end
    end
    
    % NFB - end of block
    lsl.outlet_event.push_sample({'NFB_block_end'});
    
    if config.NFB_MODE
        % Stop playback:
        Screen('PlayMovie', NFB_movie, 0);
        % Close movie:
        Screen('CloseMovie', NFB_movie);
    end
    
    % break / rest until button press (enforced break?)
    if SESSION_ID == 1
        % present break screen
        Screen('CopyWindow', breakNFBScreen, window);
        Screen('Flip', window);
        KbStrokeWait;
    end
end


%% save gamma coherence values and NFB control signals
cat_gcoh = [gcoh_all(1,:), gcoh_all(2,:)];
if config.SAVE_ALL
    cat_nfb = [nfb_all(1,:), nfb_all(2,:)];
    figure, plot((1:length(cat_gcoh))/config.GCOH.SRATE/60, cat_gcoh,'linewidth',2); xlabel('Time (min)'); ylabel('Gamma Coherence'); set(gca,'fontsize',12);
    if ~isempty(TARGET_GCOH), hold on, yline(TARGET_GCOH,'--k'); end
    saveas(gcf, [config.filepath_sess '\\gcoh_all.png']);
    figure, stem((1:length(cat_nfb))/config.GCOH.SRATE/60, cat_nfb); xlabel('Time (min)'); ylabel('Neurofeedback'); set(gca,'fontsize',12);
    saveas(gcf,[config.filepath_sess '\\nfb_all.png']);
end

% modify target gamma coherence if the performance is low
if config.SESSION_ID > 1
    if mean(cat_gcoh > config.target_gcoh(config.SESSION_ID-1).nfb) <= 0.5
        TARGET_GCOH = 0.95 * TARGET_GCOH;
    end
end
config.target_gcoh(config.SESSION_ID).rest = REST_GCOH;
config.target_gcoh(config.SESSION_ID).ini = INI_GCOH;
config.target_gcoh(config.SESSION_ID).nfb = TARGET_GCOH;

% save final results
target_gcoh = config.target_gcoh;
if config.IS_REAL_SESS
    save([config.filepath_sess, sprintf('\\target_gcoh_subj%d_sess%d.mat',config.SUBJECT_ID,config.SESSION_ID)], ...
        'target_gcoh','gcoh_all','nfb_all');
else
    mock_nfb_all = config.MOCK_NFB_ALL;
    mock_filename = config.MOCK_filename;
    save([config.filepath_sess, sprintf('\\target_gcoh_subj%d_sess%d.mat',config.SUBJECT_ID,config.SESSION_ID)], ...
        'target_gcoh','gcoh_all','nfb_all','mock_nfb_all','mock_filename');
end

%% closing
fprintf('NFB: Session ended.\n');
Priority(0);
ShowCursor;
Screen('CloseAll')
sca

end

function handle = sys_prepInstructionScreen(window, msg,...
    bg_color, text_color, text_font, font_size, centX, centY)

handle = Screen(window, 'OpenOffScreenWindow', bg_color);
Screen(handle, 'TextColor', text_color);
Screen(handle, 'TextFont', text_font);
Screen(handle, 'TextSize', font_size);

if ~iscell(msg)
    bounds = Screen(handle, 'TextBounds', msg);
    Screen('DrawText', handle, msg, ...
        centX-bounds(RectRight)/2, centY-bounds(RectBottom)/2, text_color);
else
    nLine = length(msg);
    for it = 1:nLine
        bounds = Screen(handle, 'TextBounds', msg{it});
        Screen('DrawText', handle, msg{it}, ...
            centX-bounds(RectRight)/2, centY-(nLine/2-it+1)*bounds(RectBottom), text_color);
    end
end
end