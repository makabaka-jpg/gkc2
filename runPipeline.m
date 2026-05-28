%% runPipeline.m - Master script for the liquid identification project
% Step-by-step pipeline: data collection -> analysis -> classification -> height measurement
%
% Run individual sections (Ctrl+Enter) one at a time.

%% ============================
%% STEP 0: Verify SDR Setup
%% ============================
disp('=== STEP 0: Verify SDR Setup ===');
try
    radio = sdrdev('Pluto');
    disp('Pluto SDR device recognized successfully.');
    disp('Ready to proceed with data collection.');
catch
    error('Cannot find Pluto SDR. Check USB connection and MATLAB drivers.');
end

%% ============================
%% STEP 1: Data Collection
%% ============================
% Collect data for each liquid type and height combination.
% Run each line separately, changing physical liquid between runs.
%
% Recommended collection plan:
%   Classification samples - same height, different liquids:
%     collectData('empty',    0, 1);
%     collectData('water',    1500, 1);
%     collectData('saltwater', 1500, 1);
%     collectData('sugarwater', 1500, 1);
%
%   Height measurement samples - same liquid, different heights:
%     collectData('water', 0,    1);
%     collectData('water', 500,  1);
%     collectData('water', 1000, 1);
%     collectData('water', 1500, 1);
%     collectData('water', 2000, 1);
%
%   Multiple trials recommended (trialNum=1,2,3 for each combination).
%
% After collection, all data is saved in ./data/

disp('Use collectData(liquidName, height_ml, trialNum) to collect data.');
disp('Example: collectData(''water'', 1000, 1);');

%% ============================
%% STEP 2: Analyze Single Signal
%% ============================
% Load one sample and visualize its features:
%   data = load('data/water_1000ml_trial1_*.mat');
%   features = analyzeSignal(data.burstCaptures, data.params);

%% ============================
%% STEP 3: Classify Liquid Types
%% ============================
%   classifyLiquids();
% This will:
%  - Load all .mat files from ./data/
%  - Extract 16 features per sample
%  - Show PCA visualization
%  - Run KNN and SVM classifiers with cross-validation
%  - Display confusion matrix

%% ============================
%% STEP 4: Measure Liquid Height
%% ============================
%   measureHeight('water');
% This will:
%  - Load all data matching the specified liquid
%  - Build linear regression: features -> height
%  - Report RMSE, MAE, R²
%  - Show feature-height correlation plots

%% ============================
%% STEP 5: Explore Influencing Factors
%% ============================
% Vary experimental conditions and re-collect:
%   - Change antenna-tag distance
%   - Use different containers
%   - Move setup to different locations
%   - Introduce obstacles
%
% Compare classification accuracy / height RMSE across conditions.
% Document findings with tables and figures.

disp('Pipeline script loaded. Run sections step by step.');
