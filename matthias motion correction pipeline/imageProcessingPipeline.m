function imageProcessingPipeline(pp)
% Wrapper function for image processing pipeline.

% Maybe put the following code into separate functions:

%% Get list of all files to be processed:
% Test if it's one or several folders:
if ischar(pp.tiffDirList)
    pp.tiffDirList = {pp.tiffDirList};
end
% Get list of tif files:
pp.tiffFileList = [];
for f = row(pp.tiffDirList)
    pp.tiffFileList = cat(1, pp.tiffFileList, dir(fullfile(f{:}, '*.tif')));
end
% Order list according to age (oldest first):
[~, listInd] = sort([pp.tiffFileList.datenum]);
pp.tiffFileList = pp.tiffFileList(listInd);

%% Correct first file:
% "Correction" includes line shift and motion correction.
% "Correction" means loading, correcting and saving the tiff, and saving
% metadata.
correctFile(pp, tiffPath, ref)















