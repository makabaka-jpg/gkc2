function summary = batchCollect(mode, opts)
%BATCHCOLLECT Guided staged collection for classification and height datasets.
%   Every saved file follows the same 15-second protocol:
%     0-5 s   empty cup
%     5-10 s  transition
%     10-15 s target liquid

    if nargin < 1 || isempty(mode)
        mode = 'all';
    end
    if nargin < 2
        opts = struct();
    end
    opts = fillBatchDefaults(opts);

    summary = struct();
    summary.savedFiles = {};
    summary.mode = lower(mode);

    fprintf('==========================================\n');
    fprintf('  Staged Liquid Sensing Collection\n');
    fprintf('==========================================\n');
    fprintf('Each capture uses: 0-5s empty, 5-10s switch, 10-15s target.\n');

    switch lower(mode)
        case 'classification'
            summary.savedFiles = collectClassificationSet(opts);
        case 'height'
            summary.savedFiles = collectHeightSet(opts);
        case 'all'
            filesA = collectClassificationSet(opts);
            filesB = collectHeightSet(opts);
            summary.savedFiles = [filesA(:); filesB(:)];
        otherwise
            error('Unknown mode "%s". Use classification, height, or all.', mode);
    end

    summary.totalFiles = numel(summary.savedFiles);
    fprintf('\nCollection complete. %d files saved.\n', summary.totalFiles);
end

function opts = fillBatchDefaults(opts)
    defaults.classificationLiquids = {'water', 'saltwater', 'sugarwater'};
    defaults.classificationHeightMl = 500;
    defaults.classificationTrials = [];
    defaults.heightLiquid = 'water';
    defaults.heightLevelsMl = [0, 250, 500, 750, 1000];
    defaults.heightTrials = [];
    defaults.pauseForUser = true;
    defaults.collectOptions = struct();

    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end

    if isempty(opts.classificationTrials)
        opts.classificationTrials = askTrialCount('How many trials per liquid class? [default 3]: ', 3);
    end
    if isempty(opts.heightTrials)
        opts.heightTrials = askTrialCount('How many trials per height level? [default 3]: ', 3);
    end
end

function fileList = collectClassificationSet(opts)
    fileList = {};
    fprintf('\n--- Classification Data ---\n');
    fprintf('Target height: %g ml\n', opts.classificationHeightMl);
    fprintf('Liquids      : %s\n', strjoin(opts.classificationLiquids, ', '));

    for i = 1:numel(opts.classificationLiquids)
        liquidName = opts.classificationLiquids{i};
        waitForPlacement(sprintf([ ...
            'Prepare classification sample "%s" at %g ml.\n' ...
            'Remember: 0-5s empty cup, 5-10s replace, 10-15s keep %s steady.\n' ...
            'Press Enter to continue.'], ...
            liquidName, opts.classificationHeightMl, liquidName), opts.pauseForUser);

        for trial = 1:opts.classificationTrials
            fileList{end + 1, 1} = collectData( ... %#ok<AGROW>
                liquidName, opts.classificationHeightMl, [], opts.collectOptions);
            fprintf('  Finished %s trial %d/%d\n', liquidName, trial, opts.classificationTrials);
        end
    end
end

function fileList = collectHeightSet(opts)
    fileList = {};
    fprintf('\n--- Height Data ---\n');
    fprintf('Liquid : %s\n', opts.heightLiquid);
    fprintf('Heights: %s ml\n', mat2str(opts.heightLevelsMl));

    for i = 1:numel(opts.heightLevelsMl)
        heightMl = opts.heightLevelsMl(i);
        waitForPlacement(sprintf([ ...
            'Prepare %s at %g ml.\n' ...
            'Remember: 0-5s empty cup, 5-10s replace, 10-15s keep target steady.\n' ...
            'Press Enter to continue.'], ...
            opts.heightLiquid, heightMl), opts.pauseForUser);

        for trial = 1:opts.heightTrials
            fileList{end + 1, 1} = collectData( ... %#ok<AGROW>
                opts.heightLiquid, heightMl, [], opts.collectOptions);
            fprintf('  Finished %s %g ml trial %d/%d\n', ...
                opts.heightLiquid, heightMl, trial, opts.heightTrials);
        end
    end
end

function waitForPlacement(message, pauseForUser)
    if pauseForUser
        input(sprintf('\n%s\n', message), 's');
    else
        fprintf('\n%s\n', message);
    end
end

function value = askTrialCount(prompt, defaultValue)
    raw = input(prompt, 's');
    if isempty(strtrim(raw))
        value = defaultValue;
        return;
    end
    value = str2double(raw);
    if ~isfinite(value) || value < 1
        value = defaultValue;
    end
    value = round(value);
end
