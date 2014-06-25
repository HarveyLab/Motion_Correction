function TrackROIs(fullfilename,movie_file,nSegments,segSize)

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
if isempty(MovFile.movie_mask)
    refWin=mean(mov,3);
    imshow(histeq(refWin/max(refWin(:)))),
    h=imrect;
    pause;
    movie_mask = round(getPosition(h));
    MovFile.movie_mask = movie_mask;
else
    movie_mask = MovFile.movie_mask;
end
mov = mov(movie_mask(2):movie_mask(2)+movie_mask(4),movie_mask(1):movie_mask(1)+movie_mask(3),:);
M=movie_mask(3)+1;
N=movie_mask(4)+1;

%% Construct Movie Segments
if isempty(MovFile.segPos),
    ref = double(median(mov,3));
    inF = fspecial('gaussian',25,3);
    outF = fspecial('gaussian',25,6);
    ref = abs(imfilter(ref,inF-outF));
    ref=ref-min(ref(:));
    ref = ref/max(ref(:));
    ref = adapthisteq(ref);
    ref = imfilter(ref,inF);
    segCenters = imregionalmax(ref);
    [yInd , xInd] = find(segCenters);
    badX = find(xInd < segSize/2 | xInd>M-segSize/2);
    badY = find(yInd < segSize/2 | yInd>N-segSize/2);
    vals = ref(segCenters(:));
    vals(union(badX,badY))=0;
    segInd = find(vals>prctile(vals,(1-nSegments/length(vals))*100));
    xInd = xInd(segInd);
    yInd = yInd(segInd);
    segPos = [xInd-fix(segSize/2)+1 yInd-fix(segSize/2)+1 ones(length(segInd),2)*(segSize-1)];
    nSeg = size(segPos,1);
    MovFile.segPos = segPos;
else
    segPos = MovFile.segPos;
    nSeg = size(segPos,1);
end

%% First order motion correction
%Break Movie into Sliced Segments and clear original
for Seg = 1:nSeg
    MovCell{Seg} = mov(segPos(Seg,2):segPos(Seg,2)+segPos(Seg,4),segPos(Seg,1):segPos(Seg,1)+segPos(Seg,3),:);
end

parfor Seg = 1:nSeg
    display(sprintf('Segment: %d',Seg)),
    tMov = MovCell{Seg};
    [xshifts(Seg,:),yshifts(Seg,:)]=track_subpixel_wholeframe_motion_fft(tMov, median(tMov,3));
end
clear MovCell
badFrames = find(isnan(xshifts+yshifts));
xshifts(badFrames) = (xshifts(badFrames-nSeg)+xshifts(badFrames+nSeg))/2;
yshifts(badFrames) = (yshifts(badFrames-nSeg)+yshifts(badFrames+nSeg))/2;


%Calculate correction for reference image and crop
refFrame = median(AcquisitionCorrect(mov,mean(xshifts),mean(yshifts)),3);
refFrame = refFrame(1+10:end-10,1+10:end-10,:);

%Save results to disk
acqFrames = MovFile.acqFrames;
startFrame = sum(acqFrames)+1;
endFrame = startFrame+Z-1;
MovFile.acqFrames = cat(1,acqFrames,Z);
MovFile.cated_xShift(1:nSeg,startFrame:endFrame) = xshifts;
MovFile.cated_yShift(1:nSeg,startFrame:endFrame) = yshifts;
MovFile.acqRef(1:size(refFrame,1),1:size(refFrame,2),length(MovFile.acqFrames)+1) = refFrame;