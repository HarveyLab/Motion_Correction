function refImg = TrackROIsMJLM(...
    fullfilename, movie_file, nSegments, segSize, showFigs, refImg)

% fullfilename:     Path to tiff stack to motion correct.
% movie_file:       MAT-file object for a file containing movie metadata.
% nSegments:        How many

if ~exist('refImg', 'var') || isempty(refImg)
    refImg = 0;
end

% May be input argument later:
showFigs = true;

MovFile = matfile([movie_file '.mat'],'Writable',true);
%% Load tiff File
t=Tiff(fullfilename);
N = t.getTag('ImageLength');
M = t.getTag('ImageWidth');
t.setDirectory(1);
while ~t.lastDirectory
    t.nextDirectory;
end
Z = t.currentDirectory;
mov = zeros(N,M,Z,'single');
for frame = 1:Z
    t.setDirectory(frame);
    mov(:,:,frame) = t.read;  
    if ~mod(frame, 100)
        fprintf('%1.0f frames loaded.\n', frame);
    end
end

%% Clip bad image region 
% if isempty(MovFile.movie_mask)
%     refWin = mean(mov,3)./imgGaussBlur(mean(mov,3), 20);
%     imshow(refWin),
%     h=imrect;
%     pause;
%     movie_mask = round(getPosition(h));
% else
%     movie_mask = MovFile.movie_mask;
% end
% mov = mov(movie_mask(2):movie_mask(2)+movie_mask(4),movie_mask(1):movie_mask(1)+movie_mask(3),:);
% N=movie_mask(3)+1;
% M=movie_mask(4)+1;

% mov = mov(:,51:end-50,:);
[M, N, Z] = size(mov);
movie_mask = [1, 1 N-1, M-1];

MovFile.movie_mask = movie_mask;

%% Construct Movie Segments
logistic = @(x) ((1./(1+exp(-x*(-log(1/3)/(0.5*median(x(1:101:end))))))-0.5)*2); % The term in the exponent input such that "halfMax" input value becomes 0.5 in logistic function output.
movLog = logistic(bsxfun(@rdivide, mov, imgGaussBlur(mean(mov, 3), 20)));

if ~refImg
    refImg = median(movLog, 3);
end

lookForDarkRois = 1;

if ~isfield(MovFile, 'segPos') || isempty(MovFile.segPos)
        
    inF = fspecial('gaussian',25,1);
%     outF = fspecial('gaussian',25,10);
    refBlur1 = imfilter(refImg, inF);
%     refBlur10 = imfilter(ref, outF);

    if lookForDarkRois
        segCenters = imregionalmin(refBlur1);
    else 
        segCenters = imregionalmax(refBlur1);
    end
    
    [yInd , xInd] = find(segCenters);
    
    discardMargin = max(segSize/2, 50);
    badPos = (xInd < 1+discardMargin | xInd > N-1-discardMargin) ...
        | (yInd < 1+discardMargin | yInd > M-1-discardMargin);
    
    xInd(badPos) = [];
    yInd(badPos) = [];
    
    vals = refBlur1(sub2ind(size(refImg), yInd, xInd));
    % Selection loop for spaced-out segments:
    
    % 1. Sort everything according to value:
    if lookForDarkRois
        [vals, sortInd] = sort(vals, 'ascend');
    else
        [vals, sortInd] = sort(vals, 'descend');
    end
    xInd = xInd(sortInd);
    yInd = yInd(sortInd);
    
    % 2. Go through values...
    xIndSelected = [];
    yIndSelected = [];
    valSelected = [];
    nhood = 40;
    while ~isempty(xInd)  
        % Select darkest available point:
        xIndSelected(end+1) = xInd(1);
        yIndSelected(end+1) = yInd(1);
        valSelected(end+1) = vals(1);

        % Delete this and surrounding indices:
        nhoodInd = abs(xInd-xIndSelected(end))<nhood ...
            & abs(yInd-yIndSelected(end))<nhood;
        xInd(nhoodInd) = [];
        yInd(nhoodInd) = [];
        vals(nhoodInd) = [];
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
    segPos = [xInd-fix(segSize/2)+1 yInd-fix(segSize/2)+1 ones(length(xInd),2)*(segSize-1)];
    nSeg = size(segPos,1);
    MovFile.segPos = segPos;
else
    segPos = MovFile.segPos;
    nSeg = size(segPos,1);
end

%% First order motion correction
% Start parfeval workers:
fprintf('Starting motion tracking...\n');
for Seg = 1:nSeg
    results(Seg) = parfeval(@track_subpixel_motion_fft, 2, ...
        movLog(segPos(Seg,2):segPos(Seg,2)+segPos(Seg,4),segPos(Seg,1):segPos(Seg,1)+segPos(Seg,3),:), ...
        refImg(segPos(Seg,2):segPos(Seg,2)+segPos(Seg,4),segPos(Seg,1):segPos(Seg,1)+segPos(Seg,3)));
end

% To do: If we want to be super fast and have memory to spare, it would
% make sense to load the next acquisition/movie file from disk now, while
% the CPU works on the motion correction (parfeval is asynchronous).

% Retrieve results:
fprintf('Segments to go:\n%1.0f', nSeg);
for Seg = 1:nSeg
    [segInd, xshiftThis, yshiftThis] = fetchNext(results);
    xshifts(segInd,:) = xshiftThis;
    yshifts(segInd,:) = yshiftThis;
    fprintf('...%1.0f', nSeg-Seg);
    if ~mod(Seg, 10)
        fprintf('\n');
    end
end
fprintf('\nDone tracking segments.\n');

badFrames = find(isnan(xshifts+yshifts));
xshifts(badFrames) = (xshifts(badFrames-nSeg)+xshifts(badFrames+nSeg))/2;
yshifts(badFrames) = (yshifts(badFrames-nSeg)+yshifts(badFrames+nSeg))/2;

% Discard uncorrelated segments:
medCorr = median(corr([xshifts, yshifts]')); % Median: Discount high-corr outliers, e.g. due to imaging artefacts.
badSeg = medCorr < median(medCorr);
xshifts(badSeg, :) = [];
yshifts(badSeg, :) = [];

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


segPos(badSeg, :) = [];
MovFile.segPos = segPos;

nSeg = size(xshifts, 1);

%Calculate correction for reference image and crop
% refFrame = median(AcquisitionCorrect(mov,mean(xshifts),mean(yshifts)),3);
% refFrame = refFrame(1+10:end-10,1+10:end-10,:);

%Save results to disk
acqFrames = MovFile.acqFrames;
startFrame = sum(acqFrames)+1;
endFrame = startFrame+Z-1;
MovFile.acqFrames = cat(1,acqFrames,Z);
MovFile.cated_xShift(1:nSeg,startFrame:endFrame) = xshifts;
MovFile.cated_yShift(1:nSeg,startFrame:endFrame) = yshifts;
MovFile.acqRef(1:M,1:N,Z+1) = refImg;