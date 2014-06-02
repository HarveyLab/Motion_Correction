function preProcess(path, suffix, binFactor)
% preProcess(path, [suffix], [binFactor]) loads all tiff files whose path
% starts with PATH (wildcard allowed), applies lineshift correction, splits
% channels and slices, and saves the result as tiffs for separate channels
% in the same folder.
%
% Optionally, a SUFFIX is added to the base name of the
% files. 
%
% Optionally, pixel binning is applied.

% TODO: Make command line information output nicer.

if ~exist('suffix', 'var') || isempty(suffix)
    suffix = '';
end

if ~exist('binFactor', 'var') || isempty(binFactor)
    binFactor = 1;
end

ls = dir(path);

if isempty(ls)
    error('No files found at the supplied path.')
end

folder = fileparts(path);

for f = ls'
    [~, fNameBase, ext] = fileparts(f.name);
    if ~isempty(suffix)
        fNameBase = [fNameBase, '_', suffix];
    end
    
    % Skip non-tiff files:
    if ~(strcmpi(ext, '.tif') || strcmpi(ext, '.tiff'))
        continue
    end
    
    % Load files:
    [mov, siStruct] = tiffRead(fullfile(folder, f.name), 'uint16');
    siStruct = siStruct.(cell2mat(fieldnames(siStruct))); % Remove unnecessary layer in scanimage struct.
    
    %% Perform lineshift correction:
    % For now, this is done on all channels simultaneously. May be more
    % efficent to use only red channel, but not everyone uses red channel.
    % Also, the correction only takes a few seconds per 1000 frames.
    mov = correctLineShift(mov);
    
    %% Spatial binning:
    if binFactor > 1
        mov = binSpatial(mov, binFactor);
    end
    
    %% Split data into channels/slices:
    mov = parseScanimageTiff(mov, siStruct);
    [~, ~, nChannels, nFrames, nSlices] = size(mov);
    
    %% Save data:
    
    % Check if this is an "anatomical" Z-stack, or a fast volume scan/no
    % stack at all:
    %     isAnatomicalZStack = nSlices>1 && ~siStruct.fastZEnable;
    isAnatomicalZStack = 0; % Dirty fix
    
    if isAnatomicalZStack
        % If this is an anatopical Z-stack, just average across "frames" to
        % output a stack of "slices":
        % First, motion-correct frames within each slice:
        mov = motionCorrectFrames(mov);
        
        % Second, average across slice and concatenate:
        if ~exist('movMean', 'var')
            movMean = mean(mov, 4);
        else
            movMean = cat(5, movMean, mean(mov, 4));
        end
    else
        for sl = 1:nSlices
            for ch = 1:nChannels            
                fName = sprintf('%s_slice%1.0f_ch%1.0f%s', fNameBase, sl, ch, ext);

                tiffWrite(reshape(mov(:,:,ch,:,sl,:), height, width, []), ...
                    fName, fullfile(folder, 'processed'));
            end
        end
    end
end

if isAnatomicalZStack
    for ch = 1:nChannels            
        fName = sprintf('%s_zStack_ch%1.0f%s', fNameBase, ch, ext);

        tiffWrite(reshape(movMean(:,:,ch,:,:,:), height, width, []), ...
            fName, fullfile(folder, 'processed'));
    end
end

function mov = motionCorrectFrames(mov)
[height, width, nChannels, nFramesAvg, nSlices] = size(mov);
R = imref2d([width,height]);
crop = round(width*0.1);
movAlign = single(mov(:, crop:end-crop, :, :, :, :));
movAlign = squeeze(max(movAlign, [], 3)); 
parfor sl = 1:nSlices
    % Max across channels (for motion detection only):
    sliceAlign = movAlign(:, :, :, sl);
    alignTarget = median(sliceAlign(:, :, [1 end], 1), 3);

    [x, y] = track_subpixel_wholeframe_motion_varythresh(...
        squeeze(sliceAlign(:, :, :, 1)), alignTarget, 5, 0.9, 100, false);

    for ch = 1:nChannels
        for frame = 1:nFramesAvg
            A = eye(3);
            A(3,1) = x(frame);
            A(3,2) = y(frame);
            tform = affine2d(A);
            mov(:,:,ch,frame,sl) = imwarp(mov(:,:,ch,frame,sl), ...
                tform, 'OutputView', R, 'FillValues', nan);   
        end
    end
end