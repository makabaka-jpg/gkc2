%% batchCollect.m - Batch data collection with prompts
% Guides you through collecting all samples systematically.
% Run this script and follow the console prompts.

function batchCollect()
    fprintf('==========================================\n');
    fprintf('  Batch Data Collection for Liquid ID\n');
    fprintf('==========================================\n\n');

    % === Classification samples ===
    fprintf('--- Part A: Liquid Classification Samples ---\n');
    fprintf('Prepare the following liquids at ~1500ml each:\n');
    fprintf('  1. Empty bottle\n');
    fprintf('  2. Pure water\n');
    fprintf('  3. Salt water (concentrated)\n');
    fprintf('  4. Sugar water (concentrated)\n');
    fprintf('  (Optional) 5. Oil or other liquid\n\n');

    nTrials = input('How many trials per sample? (recommended: 3-5): ');
    liquids = {'empty', 'water', 'saltwater', 'sugarwater'};

    for L = 1:length(liquids)
        fprintf('\n>>> NEXT: Place "%s" container, then press Enter...', liquids{L});
        pause;  % Wait for user to press Enter
        for t = 1:nTrials
            fprintf('  Trial %d/%d for %s...\n', t, nTrials, liquids{L});
            collectData(liquids{L}, 1500, t);
        end
    end

    % === Height measurement samples ===
    fprintf('\n--- Part B: Height Measurement Samples ---\n');
    fprintf('Prepare pure water at these levels:\n');
    fprintf('  0ml, 500ml, 1000ml, 1500ml, 2000ml\n');

    heights = [0, 500, 1000, 1500, 2000];
    nHeightTrials = input('How many trials per height? (recommended: 3): ');

    for h = 1:length(heights)
        fprintf('\n>>> NEXT: Fill water to %dml, then press Enter...', heights(h));
        pause;
        for t = 1:nHeightTrials
            fprintf('  Trial %d/%d for water at %dml...\n', t, nHeightTrials, heights(h));
            collectData('water', heights(h), t);
        end
    end

    fprintf('\n==========================================\n');
    fprintf('  Data collection complete!\n');
    fprintf('  Files saved to ./data/\n');
    fprintf('  Next: run classifyLiquids() and measureHeight(''water'')\n');
    fprintf('==========================================\n');
end
