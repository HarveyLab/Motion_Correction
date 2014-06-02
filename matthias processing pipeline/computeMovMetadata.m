function movMetadata = computeMovMetadata(movMetadata)
% movMetadata = com(movMetadata) computes additional metadata for the
% movies specified in the supplied movMetadata files (can be arrays).

%% Loop to load in files and start parallel jobs to calculate metadata.
% The asynchronous parallel function ensures that the calculations and data
% loading happen in parallel.


as it is, this function doesn't work very well -- it loads up the memory
and then becomes very slow.

resultInd = 1;
for i = 1:numel(movMetadata)
    nSlices = numel(movMetadata(i).slice);
    nChannels = numel(movMetadata(i).slice(1).channel);
    for sl = 1:nSlices
        for ch = 1:nChannels
            [folder, fNameBase, ext] = fileparts(movMetadata(i).filePath);
            movMetadata(i).slice(sl).channel(ch).filename = ...
                sprintf('%s_slice%1.0f_ch%1.0f%s', fNameBase, sl, ch, ext);
            mov = tiffRead(fullfile(folder, 'processed', movMetadata(i).slice(sl).channel(ch).filename));
            
            % Calculate metadata:
            results(resultInd) = parfeval(@processFun, 1, mov);
            resultInd = resultInd+1;
        end
    end
end

%% Retrieve results:
% Fetch:
for i = 1:resultInd
	newMetadata(i) = fetchNext(results);
end

% Sort into metadata struct:
resultInd = 1;
for i = 1:numel(movMetadata)
    nSlices = numel(movMetadata(i).slice);
    nChannels = numel(movMetadata(i).slice(1).channel);
    for sl = 1:nSlices
        for ch = 1:nChannels
            % CODE TO SORT HERE:
            movMetadata(i).slice(sl).channel(ch).skewness = ...
                newMetadata(resultInd).skewness;
            movMetadata(i).slice(sl).channel(ch).median = ...
                newMetadata(resultInd).median;
            resultInd = resultInd+1;
        end
    end
end


function out = processFun(mov)
out.skewness = skewness(mov, [], 3);
out.median = median(mov, 3);
