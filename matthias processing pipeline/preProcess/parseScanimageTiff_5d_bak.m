function [mov5d, dimLabels] = parseScanimageTiff(mov, siStruct)
% Nomenclature: frames and slices refer to the concepts used in
    % ScanImage. For clarity, the z-dimenstion in the tiff is therefore
    % called "tiffPage" here.
[height, width, nTiffPages] = size(mov);
fZ              = siStruct.fastZEnable;
nChannels       = numel(siStruct.channelsSave);
nSlices         = siStruct.stackNumSlices + (fZ*siStruct.fastZDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).
nFramesAvg      = siStruct.acqNumFrames; % Frames are acquired at same locations.
nFramesPerFile  = siStruct.loggingFramesPerFile;

% Reshape into 5d array:
mov5d = mov; % Rename separately so that no memory is re-allocated. Not sure if necessary, just in case.
clear mov;
mov5d = reshape(mov5d, height, width, nChannels, min(nFramesAvg, nFramesPerFile), []);

% Discard flyback frames:
if siStruct.fastZEnable && siStruct.fastZDiscardFlybackFrames > 1
    mov5d(:, :, :, :, end-siStruct.fastZDiscardFlybackFrames+1:end) = [];
end

% Dimension labels:
dimLabels = {'height', ...
             'width', ...
             'channel', ...
             'frame', ...
             'slice'};