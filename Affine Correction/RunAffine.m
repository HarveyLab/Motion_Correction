%% Initialization and Parameters
close all,
clear all,
tic,
InitMovieFiles,

nSegments = 6; %Can only be 9, 6 or 4 at this point, but simple to modify code to allow more
nPCs = 200;
PCuse = 1:100;
mu=.15;
nIC = length(PCuse);
maxshift = 5; %Maximum LOCAL (within acquisition) shift. Smaller than maximal GLOBAL shift (including btw acq drift)
%% Load Individual Sessions and Calculate Segment Shifts
display('---------------------Tracking Segments-----------------------')
for j=1:num_files
    j,
    fullfilename = correct_filenames{j};
    TrackSegments(fullfilename,movie_file,maxshift,nSegments);
end

MovFile.acqRef = MovFile.acqRef(:,:,1+(1:length(MovFile.acqFrames)));
trackTime = toc,
%% Load and Affine-Correct Each Acquisition
display('---------------------Applying Motion Correction-----------------------')
Affine_Transform_Frames(apply_filenames,movie_file);
transformTime = toc,
%% Calculate PCs
display('---------------------Computing Principle Components-----------------------')
Movie_PCA(movie_file,nPCs)

pcaTime = toc,

%% Calculate ICs and Segments
mixedsig = MovFile.mixedsig;
mixedfilters = MovFile.mixedfilters;
blank_frame = MovFile.blank_frame;
mixedfilters = mixedfilters(blank_frame(1):blank_frame(2),blank_frame(3):blank_frame(4),:);
satisfaction = 0;
while satisfaction == 0
    nanRows = sum(isnan(mixedfilters(:,:,1)),2);
    nanCols = sum(isnan(mixedfilters(:,:,1)),1);
    badRows = find(nanRows>5);
    badCols = find(nanCols>5);
    if isempty(badRows) & isempty(badCols)
        satisfaction = 1;
    elseif ~isempty(badRows)
        display(sprintf('Erasing Rows %d',badRows)),
        mixedfilters(badRows,:,:) = [];
    elseif ~isempty(badCols)
        display(sprintf('Erasing Cols %d',badCols)),
        mixedfilters(:,badRows,:) = [];
    end
end 

[ica_sig, ica_filters, ica_A, numiter] = CellsortICA(...
     mixedsig,mixedfilters, MovFile.CovEvals, PCuse, mu, nIC, [], 5e-7, 1e3);
[ica_segments, segmentlabel, segcentroid] = CellsortSegmentation...
    (ica_filters, smwidth, thresh, arealims, plotting);
for i=1:size(ica_segments,1)
    normSeg(:,:,i)=100*ica_segments(i,:,:)/norm(reshape(ica_segments(i,:,:),1,[]));
end
