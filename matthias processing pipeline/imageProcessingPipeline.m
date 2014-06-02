function imageProcessingPipeline(...
    doMotionCorrection, ...
    doApplyShifts, ...
    doCalculateDerivedData, ...
    doCcipca)
% Wrapper function for image processing pipeline.
% This function handles all file I/O, but all processing is handled by
% separate functions, called by the pipeline function.

if nargin == 0
    doMotionCorrection = true;
    doCalculateDerivedData = true;
    doCcipca = true;
end
%% Get list of all files to be processed:
% TODO: Turn this into a dialog/gui:
% Temp solution: provide list of folders with data:
rawFolders = {...
    'C:\Users\Matthias\Local\Storage\labdata\imaging\MM025\MM025_140530', ...
    };

% Get list of tif files:
movMetadata = [];
% movMetadata is a struct array with metadata for each movie. The basis for
% the struct is the information returned by DIR. More information is then
% added later. Eventually, a separate .mat file is saved for each element
% of movMetadata, i.e. for each tif file.
for f = row(rawFolders)
    thisFolderList = dir(fullfile(f{:}, '140530_MM025_140530_stimTests_002*.tif'));
    
    % Add full file path to each file for convenience and unique id:
    for i = 1:numel(thisFolderList)
%         thisFolderList(i).pathAndName = fullfile(f{:}, thisFolderList(i).name);
        thisFolderList(i).path = f{:};
        thisFolderList(i).pathAndName = fullfile(f{:}, thisFolderList(i).name);
    end
    
    % Concatenate into one long list:
    movMetadata = cat(1, movMetadata, thisFolderList);
end
% Store the file list separately as well, in case we want to load
% previously saved metadata from disk (see below):
rawFileList = movMetadata;

% Order list according to age (oldest first):
[~, ageInd] = sort([movMetadata.datenum]);
movMetadata = movMetadata(ageInd);
nRawFiles = numel(movMetadata);

% TODO: Turn this into a gui.
% TODO: Allow for externally supplied correction file, either in form of a
% simple image matrix or in form of a previously saved metadata file.
% Temp: assign reference source to each Tiff manually:
refInd = 1;
for i = 1:nRawFiles
    movMetadata(i).refFilePath = movMetadata(refInd).pathAndName;
end

% Select which channel to correct on:
for i = 1:nRawFiles
    movMetadata(i).correctOnChannel = 1;
end

% Set bin factor:
for i = 1:nRawFiles
    movMetadata(i).binFactor = 1;
end

% Now, re-order the files such that the ones that have themselves as a
% reference source are first, so that they are corrected first and the
% reference images are then available for the rest:
rawFileListTemp = movMetadata;
movMetadata = [];
for i = 1:nRawFiles
    if strcmp(rawFileListTemp(i).refFilePath, ...
            rawFileListTemp(i).pathAndName)
        movMetadata = [rawFileListTemp(i), movMetadata];
    else
        movMetadata = [movMetadata, rawFileListTemp(i)];        
    end
end

%% Processing loop:
% "Correction" includes line shift and motion correction.
% "Correction" means loading, correcting and saving the tiff, and saving
% metadata.

%TODO: Maybe break this function up so that there is a function which
%processes a single file from A to Z, and then another function which
%supplies many files to that processing function.

% Initialize variables for PCA:
nPCs = 200;
nIterations = 1; % Not sure how much better the result is if this is higher.
chCalcium = 1;
passNumber = 1;

for i = 1:nRawFiles
    if doMotionCorrection
        % Load raw tiff:
        % TODO: Maybe load and process in single precision.
        [mov, movMetadata(i).siStruct] = tiffRead(movMetadata(i).pathAndName, 'single');  
        if isfield(movMetadata(i).siStruct, 'SI4')
            movMetadata(i).siStruct = movMetadata(i).siStruct.SI4;
        end

        % Apply spatial binning:
        if movMetadata(i).binFactor > 1
            mov = binSpatial(mov, movMetadata(i).binFactor);
        end

        % Correct lineshift:
        mov = correctLineShift(mov);

        % Split into channels/slices/frames:
        movStruct = parseScanimageTiff(mov, movMetadata(i).siStruct);
        clear mov; % Not sure if this clear is good. It means that memory has to be re-allocated for next mov.
        
        % Load reference image:
        refInd = strcmp(movMetadata(i).refFilePath, {movMetadata.pathAndName});
        if ~any(refInd)
            error('Todo: write code to load ref file path if it is not in the current batch')
        elseif find(refInd)==i
            % Current file is a reference source and we'll calculate a
            % referance image from it:
            refMetadata = [];
        else
            refMetadata = movMetadata(refInd);
        end

        % Find motion shifts:
        nSlices = numel(movStruct.slice);
        nChannels = numel(movStruct.slice(1).channel);
        for sl = 1:nSlices
            % Find shifts:
            % (Shifts can be scalar, or a vector of multiple tracked points.)

            if isempty(refMetadata)
                % No reference: Call trackFeatures without reference, will use
                % median of the movie itself as reference:
                [x, y, trackedPoints, refImg] = trackFeatures(...
                    movStruct.slice(sl).channel(movMetadata(i).correctOnChannel).mov);
            else
                [x, y, trackedPoints, refImg] = trackFeatures(...
                    movStruct.slice(sl).channel(movMetadata(i).correctOnChannel).mov, ...
                    refMetadata.slice(sl).refImg);
            end

            % Store slice-specific information here:
            movMetadata(i).slice(sl).xShift = x;
            movMetadata(i).slice(sl).yShift = y;
            movMetadata(i).slice(sl).trackedPoints = trackedPoints;
            movMetadata(i).slice(sl).refImg = refImg;        
        end
    else
        % We're not doing motion correction (because it was done at some
        % previous time): Only load corrected file:
        
        % Load movMetadata:
        [rawFilePath, file, tiffExt] = fileparts(rawFileList(i).pathAndName);
        temp = load(fullfile(rawFilePath, 'processed', [file, '.mat']));
        
        if i == 1
            movMetadata = temp.movMetadata;
        else
            movMetadata(i) = temp.movMetadata;
        end
        
        % Load image data:
        if doApplyShifts
            % User selected to apply shifts (will be done below), so load
            % raw data:
            [mov, movMetadata(i).siStruct] = tiffRead(movMetadata(i).pathAndName, 'single');  
            if isfield(movMetadata(i).siStruct, 'SI4')
                movMetadata(i).siStruct = movMetadata(i).siStruct.SI4;
            end
            % Apply spatial binning:
            if movMetadata(i).binFactor > 1
                mov = binSpatial(mov, movMetadata(i).binFactor);
            end
            % Correct lineshift:
            mov = correctLineShift(mov);
            % Split into channels/slices/frames:
            movStruct = parseScanimageTiff(mov, movMetadata(i).siStruct);
        else
            % Load processed data:
            processedFileList = dir(fullfile(rawFilePath, 'processed', [file, '*', tiffExt]));
            for f = processedFileList'
               tokens = regexp(f.name, '.+?slice(\d+)_ch(\d+)\.', 'tokens');
               sl = str2double(tokens{1}{1});
               ch = str2double(tokens{1}{2});
               movStruct.slice(sl).channel(ch).mov = ...
                   tiffRead(fullfile(rawFilePath, 'processed', f.name));
            end
        end
        nSlices = numel(movStruct.slice);
        nChannels = numel(movStruct.slice(1).channel);
    end
    
    if doApplyShifts
        % Apply motion shifts:
        for sl = 1:nSlices
            for ch = 1:nChannels
                movStruct.slice(sl).channel(ch).mov = ...
                    applyShift(movStruct.slice(sl).channel(ch).mov, ...
                        movMetadata(i).slice(sl).xShift, ...
                        movMetadata(i).slice(sl).yShift, ...
                        'translation', ...
                        movMetadata(i).slice(sl).trackedPoints);
            end
        end
    end
    
    % Add useful derived data:
    if doCalculateDerivedData
        for sl = 1:nSlices
            for ch = 1:nChannels
                % Create fields:
                if ~isfield(movMetadata(i), 'slice')
                    movMetadata(i).slice(sl) = struct;
                end
                if ~isfield(movMetadata(i).slice(sl), 'channel')
                    movMetadata(i).slice(sl).channel = struct;
                end
                
                % Mean:
                if ~isfield(movMetadata(i).slice(sl).channel, 'mean') ...
                        || numel(isempty(movMetadata(i).slice(sl).channel)) < ch ...
                        || isempty(movMetadata(i).slice(sl).channel(ch).mean)
                    movMetadata(i).slice(sl).channel(ch).mean = nanmean(movStruct.slice(sl).channel(ch).mov, 3);
                end
                
                % Skewness:
                if ~isfield(movMetadata(i).slice(sl).channel, 'skewness') ...
                        || numel(isempty(movMetadata(i).slice(sl).channel)) < ch ...
                        || isempty(movMetadata(i).slice(sl).channel(ch).mean)
                    movMetadata(i).slice(sl).channel(ch).skewness = skewness(movStruct.slice(sl).channel(ch).mov, [], 3);
                end
                
                % Median:
                if ~isfield(movMetadata(i).slice(sl).channel, 'median') ...
                        || numel(isempty(movMetadata(i).slice(sl).channel)) < ch ...
                        || isempty(movMetadata(i).slice(sl).channel(ch).mean)
                    movMetadata(i).slice(sl).channel(ch).median = nanmedian(movStruct.slice(sl).channel(ch).mov, 3);
                end
                
                % Mean across space:
                if ~isfield(movMetadata(i).slice(sl).channel, 'spatialMean') ...
                        || numel(isempty(movMetadata(i).slice(sl).channel)) < ch ...
                        || isempty(movMetadata(i).slice(sl).channel(ch).mean)
                    movMetadata(i).slice(sl).channel(ch).spatialMean = squeeze(nanmean(nanmean(movStruct.slice(sl).channel(ch).mov))); 
                end
                
                % File name (no path, in case file is moved/copied):
                [~, fNameBase, ext] = fileparts(movMetadata(i).pathAndName);
                movMetadata(i).slice(sl).channel(ch).filename = ...
                    sprintf('%s_slice%1.0f_ch%1.0f%s', fNameBase, sl, ch, ext);
            end
        end
    end
    
    % Calculate spatial principal components on corrected movie:
    if doCcipca
        warning('Todo: change this to explicitly limit the PC calculation to within an acquisition');
        fprintf('Calculating CCIPCA...\n');
        for sl = 1:nSlices
            [h, w, z] = size(movStruct.slice(sl).channel(chCalcium).mov);
            % Initialize empty PCest: TODO: make this adapt to whichever is the
            % correct movMetadata:
            if i==1
                PCestOld = [];
            else
                PCestOld = reshape(movMetadata(1).slice(sl).channel(chCalcium).PCest, [], nPCs);
            end
            
            % TODO: make this adapt to whichever is the correct metadata:
            if isfield(movMetadata(1).slice(sl).channel(chCalcium), 'passNumber')
                passNumber = movMetadata(1).slice(sl).channel(chCalcium).passNumber;
            end
            
            % Use DF/F normalization:
            movNorm = bsxfun(@rdivide, movStruct.slice(sl).channel(chCalcium).mov, ...
                                       movMetadata(i).slice(sl).channel(ch).mean);
            [PCest, evals, passNumber] = ...
                ccipca(reshape(movNorm, [], z), ...
                       nPCs, ...
                       nIterations, ...
                       PCestOld, ...
                       passNumber);

            % Store CCIPCA results in the metadata of the reference tiff (not
            % in every single file).
            movMetadata(1).slice(sl).channel(chCalcium).PCest = reshape(PCest, h, w, []);
            movMetadata(1).slice(sl).channel(chCalcium).evals = evals;
            movMetadata(1).slice(sl).channel(chCalcium).passNumber = passNumber;
            % Debug: put copy into workspace:
            assignin('base', 'iPP_intermediate_PCest', PCest);
        end
    end
    
    % Optional break point if we want to check data:
%     breakStart = tic;
%     disp('Press any button in the next 10 seconds to pause execution. Type RETURN to exit keyboard mode.')
%     while toc(breakStart) < 10
%         if KbCheck
%             keyboard
%         end
%     end
    
    % Save corrected movies and metadata:
    % ...save movie:
    if doMotionCorrection || doApplyShifts
        for sl = 1:nSlices
            for ch = 1:nChannels
                [rawFilePath, fNameBase, ~] = fileparts(movMetadata(i).pathAndName);

                tiffWrite(movStruct.slice(sl).channel(ch).mov, ...
                     movMetadata(i).slice(sl).channel(ch).filename, ...
                     fullfile(rawFilePath, 'processed'));
            end
        end
    end
    % ...save metadata (one file per original tiff file, no matter how many
    % slices etc.)
    % TODO: clean up clunky renaming scheme:
    [rawFilePath, fNameBase, ~] = fileparts(movMetadata(i).pathAndName);
    movMetadataAll = movMetadata;
    movMetadata = movMetadata(i);
    save(fullfile(rawFilePath, 'processed', fNameBase), 'movMetadata');
    movMetadata = movMetadataAll;
    warning('Todo: make sure all useful information is stored in this file!');
    
    % Need to calculate mean, median and skewness, or make that an output of
    % trackMotion. Also store mean or median intensity of each frame, for
    % later adaptation.
end















