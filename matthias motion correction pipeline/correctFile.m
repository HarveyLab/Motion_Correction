function out = correctFile(pp, tiffPath, refImg)

if ~exist('refImg', 'var')
    refImg = [];
end

% Load file and scanimage metadata:
[mov, pp.siStruct] = tiffRead(tiffPath);

% Todo:
% subdivide preprocess such that these are all separate functions that work on "movs";
% - binning...
% - divide channels...
% - divide slices...
% think of good data structure for all this...either the high-d array or something like
% siTiff.channesl.slices = 3d matrix...maybe as a class which contains everything as a high-d array but has
% getter functions to access everything easily.
% Optionally, data is not saved but put out as a structure containing the
% movie data. Only works if everything fits into memory.