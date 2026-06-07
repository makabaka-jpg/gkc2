function output = runPipeline(action, varargin)
%RUNPIPELINE Unified entry point for the staged 15-second sensing workflow.
%   RUNPIPELINE() prints the quick-start menu.
%
%   Every capture follows the same protocol:
%       0-5 s   empty cup
%       5-10 s  transition / replace with target liquid
%       10-15 s keep target liquid steady
%
%   Classification workflow:
%       runPipeline('check')
%       runPipeline('collect-class')
%       runPipeline('classify')
%       runPipeline('predict-class')
%       runPipeline('predict-class', 'path/to/newCapture.mat')
%
%   Height / volume workflow:
%       runPipeline('collect-height')
%       runPipeline('train-height', 'water')
%       collectData('water', NaN)
%       runPipeline('predict-height')
%       runPipeline('predict-height', 'path/to/newWaterCapture.mat')

    if nargin < 1 || isempty(action)
        printQuickHelp();
        output = [];
        return;
    end

    paths = projectPaths();
    command = lower(string(action));

    switch command
        case {"help", "menu", "quickstart"}
            printQuickHelp();
            output = [];

        case "check"
            output = checkPlutoConnection();

        case {"collect", "collect-all"}
            checkPlutoConnection();
            output = batchCollect('all');

        case {"collect-class", "collect-classification"}
            checkPlutoConnection();
            output = batchCollect('classification');

        case {"collect-height", "collect-regression"}
            checkPlutoConnection();
            output = batchCollect('height');

        case {"analyze", "analyze-latest"}
            latestFile = getLatestDataFile(paths.data);
            data = load(latestFile);
            output = plotIQ(data, struct());

        case {"iq", "iq-latest", "plot-iq"}
            if nargin >= 2 && ~isempty(varargin{1})
                capturePath = varargin{1};
            else
                capturePath = getLatestDataFile(paths.data);
            end
            if nargin >= 3
                iqOpts = varargin{2};
            else
                iqOpts = struct();
            end
            output = plotIQ(capturePath, iqOpts);

        case {"classify", "train-classifier", "train-classification"}
            if nargin >= 2
                opts = varargin{1};
            else
                opts = struct();
            end
            output = classifyLiquids(paths.data, opts);

        case {"predict-class", "predict-liquid"}
            if nargin >= 2 && ~isempty(varargin{1})
                capturePath = varargin{1};
            else
                capturePath = getLatestDataFile(paths.data);
            end
            if nargin >= 3 && ~isempty(varargin{2})
                modelPath = varargin{2};
            else
                modelPath = [];
            end
            output = predictLiquidFromCapture(capturePath, modelPath);

        case {"height", "measure-height", "train-height"}
            if nargin >= 2 && ~isempty(varargin{1})
                liquidName = varargin{1};
            else
                liquidName = 'water';
            end
            if nargin >= 3
                opts = varargin{2};
            else
                opts = struct();
            end
            output = trainHeightModel(liquidName, paths.data, opts);

        case {"predict-height", "predict-volume"}
            if nargin >= 2 && ~isempty(varargin{1})
                capturePath = varargin{1};
            else
                capturePath = getLatestDataFile(paths.data);
            end
            if nargin >= 3 && ~isempty(varargin{2})
                modelPath = varargin{2};
            else
                modelPath = [];
            end
            output = predictHeightFromCapture(capturePath, modelPath);

        otherwise
            error('Unknown action "%s". Run runPipeline() to see valid commands.', action);
    end
end

function info = checkPlutoConnection()
    fprintf('Checking Pluto SDR connection...\n');
    try
        radio = sdrdev('Pluto');
        disp('Pluto SDR detected and ready.');
        info = radio;
    catch ex
        error('Cannot find Pluto SDR. Check USB connection and MATLAB support package.\n%s', ex.message);
    end
end

function latestFile = getLatestDataFile(dataDir)
    if ~exist(dataDir, 'dir')
        error('Data directory not found: %s', dataDir);
    end
    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        error('No .mat captures found in %s', dataDir);
    end
    [~, idx] = max([files.datenum]);
    latestFile = fullfile(dataDir, files(idx).name);
    fprintf('Analyzing latest file: %s\n', files(idx).name);
end

function printQuickHelp()
    paths = projectPaths();
    fprintf('==========================================\n');
    fprintf('  Staged Liquid Sensing Commands\n');
    fprintf('==========================================\n');
    fprintf('Project root : %s\n', paths.root);
    fprintf('Data folder  : %s\n', paths.data);
    fprintf('Models folder: %s\n', paths.models);
    fprintf('\nCapture protocol for every sample:\n');
    fprintf('  0-5 s   empty cup\n');
    fprintf('  5-10 s  replace with target liquid\n');
    fprintf('  10-15 s keep target liquid steady\n');
    fprintf('\nClassification:\n');
    fprintf('  runPipeline(''check'')\n');
    fprintf('  runPipeline(''collect-class'')\n');
    fprintf('  runPipeline(''classify'')\n');
    fprintf('  collectData(''unknown'', NaN)\n');
    fprintf('  runPipeline(''predict-class'')    %% use latest capture\n');
    fprintf('\nHeight / volume estimation:\n');
    fprintf('  runPipeline(''collect-height'')\n');
    fprintf('  runPipeline(''train-height'', ''water'')\n');
    fprintf('  collectData(''water'', NaN)\n');
    fprintf('  runPipeline(''predict-height'')   %% use latest capture\n');
    fprintf('\nUtilities:\n');
    fprintf('  runPipeline(''collect'')\n');
    fprintf('  runPipeline(''analyze-latest'')   %% staged IQ analysis for latest capture\n');
    fprintf('  runPipeline(''iq'')               %% staged IQ comparison figure\n');
end
