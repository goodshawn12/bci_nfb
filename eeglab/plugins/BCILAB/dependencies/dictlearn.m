function [D,S] = dictlearn(varargin)

% References:
%     "Online Learning for Matrix Factorization and Sparse Coding"
%     by Julien Mairal, Francis Bach, Jean Ponce and Guillermo Sapiro
%     arXiv:0908.0050
%     
%     "Online Dictionary Learning for Sparse Coding"      
%     by Julien Mairal, Francis Bach, Jean Ponce and Guillermo Sapiro
%     ICML 2009.

args = arg_define(varargin, ...
    arg_nogui({'X','Data'},[],[]), ...
    arg({'whiten','Whiten'}, true, [], 'Whiten the data.'), ...
    arg({'rescale','Rescale'}, true, [], 'Rescale the data.'), ...
    arg({'shuffle','Shuffle'}, true, [], 'Shuffle the data.'), ...
    arg({'haveMemory','HaveMemory'}, true, [], 'Have lots of memory.'), ...
    arg({'D','InitialGuess'},[],[],'Initial guess.'), ...
    arg({'K','NumComponents'},256,[], 'Number of components.'), ...
    arg({'iter','MaxIterations'},500,[], 'Maximum number of iterations.'), ...
    arg({'mode','ObjectiveFunction'},'(1/2)||x_i-Dalpha_i||_2^2 + lambda||alpha_i||_1 + lambda_2||alpha_i||_2^2',{'(1/2)||x_i-Dalpha_i||_2^2  s.t. ||alpha_i||_1 <= lambda','||alpha_i||_1  s.t. ||x_i-Dalpha_i||_2^2 <= lambda','(1/2)||x_i-Dalpha_i||_2^2 + lambda||alpha_i||_1 + lambda_2||alpha_i||_2^2','(1/2)||x_i-Dalpha_i||_2^2  s.t. ||alpha_i||_0 <= lambda','||alpha_i||_0  s.t.  ||x_i-Dalpha_i||_2^2 <= lambda','0.5||x_i-Dalpha_i||_2^2 +lambda||alpha_i||_0'},'Objective function to impose.'), ...
    arg({'modeD','DictionaryConstraints'},'||d_j||_2^2 <= 1',{'||d_j||_2^2 <= 1','||d_j||_2^2 + gamma1||d_j||_1 <= 1','||d_j||_2^2 + gamma1||d_j||_1 + gamma2 FL(d_j) <= 1','(1-gamma1)||d_j||_2^2 + gamma1||d_j||_1 <= 1'},'Constraints to impose on dictionary.'), ...    
    arg({'modeParam','OptimizationMode'},'parameter-free (ICML)',{'parameter-free (ICML)','using rho (arXiv)','exponential decay weights (rho as memory factor, arXiv)'},'Optimization mode to use.'), ...
    arg({'lambda','Lambda'},1,[], 'Main penalty parameter.'), ...
    arg({'lambda2','Lambda2'},1,[], 'Second penalty parameter.'), ...
    arg({'posAlpha','PositiveActivations'},false,[], 'Enforce positive activations. Not compatible with learning modes 3 and 4.'), ...
    arg({'posD','PositiveDictionary'},false,[], 'Enforce positive dictionary. Not compatible with constraint set 2.'), ...
    arg({'gamma1','GammaParam1'},[],[], 'Gamma parameter 1 for dictionary constraint set.'), ...
    arg({'gamma2','GammaParam2'},[],[], 'Gamma parameter 2 for dictionary constraint set.'), ...
    arg({'batchsize','MinibatchSize'},512,[], 'Size of the mini-batches to use.'), ...
    arg({'iter_updateD','NumBCDIterations'},1,[], 'Number of block-coordinate descent iterations. For the dictionary update step.'), ...
    arg({'rho','TuningParameterRho'},[],[], 'Rho tuning parameter. For online opt mode.'), ...
    arg({'t0','TuningParameterT0'},[],[], 'T0 tuning parameter. For online opt mode.'), ...
    arg({'clean','PruneUnused'},true,[], 'Prune unused elements.'), ...
    arg({'verbose','Verbose'},true,[], 'Verbose output.'), ...
    arg({'numThreads','NumThreads'},16,[], 'Number of threads.'), ...
    arg_nogui({'chanlocs','Chanlocs'},16,[], 'Channel locations.'));

% fix up arguments
if isempty(args.D)
    args = rmfield(args,'D'); end
if isempty(args.gamma1)
    args = rmfield(args,'gamma1'); end
if isempty(args.gamma2)
    args = rmfield(args,'gamma2'); end    
if isempty(args.rho)
    args = rmfield(args,'rho'); end    
args.modeParam = hlp_rewrite(args.modeParam,'parameter-free (ICML)',0, 'using rho (arXiv)',1, ...
    'exponential decay weights (rho as memory factor, arXiv)',3);
args.mode = hlp_rewrite(args.mode, ...
    '(1/2)||x_i-Dalpha_i||_2^2  s.t. ||alpha_i||_1 <= lambda',0, ...
    '||alpha_i||_1  s.t. ||x_i-Dalpha_i||_2^2 <= lambda',1, ...
    '(1/2)||x_i-Dalpha_i||_2^2 + lambda||alpha_i||_1 + lambda_2||alpha_i||_2^2',2, ...
    '(1/2)||x_i-Dalpha_i||_2^2  s.t. ||alpha_i||_0 <= lambda',3,...
    '||alpha_i||_0  s.t.  ||x_i-Dalpha_i||_2^2 <= lambda',4,... 
    '0.5||x_i-Dalpha_i||_2^2 +lambda||alpha_i||_0',5);
args.modeD = hlp_rewrite(args.modeD, ...
    '||d_j||_2^2 <= 1',0, ...
    '||d_j||_2^2 + gamma1||d_j||_1 <= 1',1,...
    '||d_j||_2^2 + gamma1||d_j||_1 + gamma2 FL(d_j) <= 1',2, ...
    '(1-gamma1)||d_j||_2^2 + gamma1||d_j||_1 <= 1',3);

X = args.X;

%args.whiten = false;

% Whiten and rescale the data
if args.whiten
    sphere = inv(real(sqrtm(cov_robust(X'))));
else
    sphere = eye(size(X,1));
end
X = sphere*X;

if args.rescale
    m = sqrt(sum(X.^2) + (1e-8));
    X = bsxfunwrap(@rdivide,X,m);
end

if args.shuffle
    idx = shuffle(1:size(X,2));
    X = X(:,idx);
end

%% Run the dictionary learning
if args.haveMemory
    D = mexTrainDL_Memory(X,args);
else
    D = mexTrainDL(X,args);
end
S = sphere;
%Df = inv(S)*D;