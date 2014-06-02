function [xShift, yShift, trackedPoints, refImg] = ...
    trackFeatures(mov, refImg, segSize, maxSegs, showFigs)

% fullfilename:     Path to tiff stack to motion correct.
% movie_file:       MAT-file object for a file containing movie metadata.
% nSegments:        How many

if ~exist('refImg', 'var') || isempty(refImg)
    refImg = 0;
end
if ~exist('segSize', 'var') || isempty(segSize)
    segSize = 60;
end
if ~exist('maxSeg', 'var') || isempty(maxSegs)
    maxSegs = 80;
end
if ~exist('showFigs', 'var') || isempty(showFigs)
    showFigs = false;
end

%% Construct Movie Segments
% Pre-process movie:
[w, h, ~] = size(mov);
logistic = @(x) ((1./(1+exp(-x*(-log(1/3)/(0.5*median(x(1:101:end))))))-0.5)*2); % The term in the exponent input such that "halfMax" input value becomes 0.5 in logistic function output.
movLog = logistic(bsxfun(@rdivide, mov, imgGaussBlur(mean(mov, 3), 20)));
if ~refImg
    refImg = median(movLog, 3);
end

% Find features:
inF = fspecial('gaussian',25,1);
refBlur1 = imfilter(refImg, inF);

% We use both maxima and minima, and process them together:
minima = imregionalmin(refBlur1);
maxima = imregionalmax(refBlur1);

% Get rid of "minima" that are actually very bright pixels:
maxMinBoundary = graythresh(refBlur1(minima));
minima = minima & refBlur1<maxMinBoundary;
% Get rid of "maxima" that are darker than the brightest minima:
maxima = maxima & refBlur1>maxMinBoundary;

[yInd , xInd] = find(minima | maxima);
discardMargin = max(segSize/2, 20);
badPos = (xInd < 1+discardMargin | xInd > h-1-discardMargin) ...
    | (yInd < 1+discardMargin | yInd > w-1-discardMargin);
xInd(badPos) = [];
yInd(badPos) = [];

vals = refBlur1(sub2ind(size(refImg), yInd, xInd));

% Selection loop for spaced-out segments:
% 1. Sort everything according to value (brightest first):
[vals, sortInd] = sort(vals, 'descend');
xInd = xInd(sortInd);
yInd = yInd(sortInd);

% 2. Go through values...
xIndSelected = [];
yIndSelected = [];
valSelected = [];
nhood = round(h*0.1);
while numel(xIndSelected) < maxSegs+1000
    % Select next darkest available point:
    xIndSelected(end+1) = xInd(end);
    yIndSelected(end+1) = yInd(end);
    valSelected(end+1) = vals(end);
    
    % Delete this and surrounding indices:
    nhoodInd = abs(xInd-xIndSelected(end))<nhood ...
        & abs(yInd-yIndSelected(end))<nhood;
    xInd(nhoodInd) = [];
    yInd(nhoodInd) = [];
    vals(nhoodInd) = [];
    
    if isempty(xInd)
        break
    end
    
    % For the first few segments, select only dark segments.
    % The idea is that there will be a few clear blood vessels which we
    % want to be certain to capture. After that, we will capture bright and
    % dark ones in turn.
    if numel(xIndSelected) < 7
        continue
    end
    
    % Select next darkest available point:
    xIndSelected(end+1) = xInd(1);
    yIndSelected(end+1) = yInd(1);
    valSelected(end+1) = vals(1);

    % Delete this and surrounding indices:
    nhoodInd = abs(xInd-xIndSelected(end))<nhood ...
        & abs(yInd-yIndSelected(end))<nhood;
    xInd(nhoodInd) = [];
    yInd(nhoodInd) = [];
    vals(nhoodInd) = []; 
    
    if isempty(xInd)
        break
    end
end

% Display:
if showFigs
    hRoiFig = figure;
    imagesc(refImg)
    hold on
    plot(xInd, yInd, 'wx');
    plot(xIndSelected, yIndSelected, 'bx');
    hold off
    colormap(gray);
    drawnow
end

fprintf('Selected %1.0f segments.\n', numel(xIndSelected));

xInd = xIndSelected(:);
yInd = yIndSelected(:);
trackedPoints = [xInd, yInd];

segPos = [xInd-fix(segSize/2)+1 yInd-fix(segSize/2)+1 ones(length(xInd),2)*(segSize-1)];
nSeg = size(segPos,1);

%% First order motion correction
% Start parfeval workers:
fprintf('Starting motion tracking...\n');
for s = 1:nSeg
    results(s) = parfeval(@track_subpixel_wholeframe_motion_fft, 2, ...
        movLog(segPos(s,2):segPos(s,2)+segPos(s,4),segPos(s,1):segPos(s,1)+segPos(s,3),:), ...
        refImg(segPos(s,2):segPos(s,2)+segPos(s,4),segPos(s,1):segPos(s,1)+segPos(s,3)));
end

% To do: If we want to be super fast and have memory to spare, it would
% make sense to load the next acquisition/movie file from disk now, while
% the CPU works on the motion correction (parfeval is asynchronous).

% Retrieve results:
fprintf('Segments to go:\n%1.0f', nSeg);
for s = 1:nSeg
    [segInd, xshiftThis, yshiftThis] = fetchNext(results);
    xShift(segInd,:) = xshiftThis;
    yShift(segInd,:) = yshiftThis;
    fprintf('...%1.0f', nSeg-s);
    if ~mod(s, 10)
        fprintf('\n');
    end
end
fprintf('\nDone tracking segments.\n');

badFrames = find(isnan(xShift+yShift));
xShift(badFrames) = (xShift(badFrames-nSeg)+xShift(badFrames+nSeg))/2;
yShift(badFrames) = (yShift(badFrames-nSeg)+yShift(badFrames+nSeg))/2;

% Discard uncorrelated segments:
medCorr = median(corr([xShift, yShift]')); % Median: Discount high-corr outliers, e.g. due to imaging artefacts.
badSeg = medCorr < median(medCorr);
xShift(badSeg, :) = [];
yShift(badSeg, :) = [];
trackedPoints(badSeg, :) = [];

% Display:
if showFigs
    figure(hRoiFig);
    hold on
    h = plot(xInd, yInd, 'gx');
    h(2) = plot(xInd(badSeg), yInd(badSeg), 'rx');
    hold off
    legend(h, 'Accepted', 'Rejected');
    colormap(gray);
    drawnow
end