function paths = projectPaths()
%PROJECTPATHS Return canonical folders for the liquid sensing project.
%   PATHS = PROJECTPATHS() resolves paths relative to this file, so the
%   scripts work even when MATLAB's current folder is elsewhere.

    rootDir = fileparts(mfilename('fullpath'));
    paths = struct();
    paths.root = rootDir;
    paths.data = fullfile(rootDir, 'data');
    paths.models = fullfile(rootDir, 'models');
    paths.results = fullfile(rootDir, 'results');
end
