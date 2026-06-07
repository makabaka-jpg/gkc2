function results = measureHeight(liquidName, dataDir, opts)
%MEASUREHEIGHT Compatibility wrapper for the height-model workflow.
%   RESULTS = MEASUREHEIGHT() trains and evaluates the water height model.
%   This keeps the old entry point while using the new trainHeightModel flow.

    if nargin < 1
        liquidName = 'water';
    end
    if nargin < 2
        dataDir = [];
    end
    if nargin < 3
        opts = struct();
    end

    results = trainHeightModel(liquidName, dataDir, opts);
end
