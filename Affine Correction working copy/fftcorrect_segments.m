%% Load data
movO = tiffRead('C:\Users\Matthias\Local\Storage\labdata\imaging\MMe001\MMe001_140330\preProcessFunctionTestActivityAcq\processed\MMe001_140330_920spontAct_001_001_slice1_ch1.tif');
% movO = tiffRead('C:\Users\Matthias\Local\Storage\labdata\laurasData\LD093_130813_view1_005\processed\LD093_130813_view1_005_002_slice2_ch1.tif');


% mov = mov(:,:,1:50);
tgt = median(movO(:,:,90:120), 3);


mov = sqrt(movO(:, 50:512-50, :));
tgt = sqrt(tgt(:, 50:512-50));

%% get block indices by hand:
nRows = 8;
nCols = 4;

[m, n, z] = size(mov);

rStart = 1:ceil(m/nRows):m;
rEnd = [rStart(2:end)-1 m];
rCenter = round(rStart+0.5*(rEnd-rStart));

cStart = 1:ceil(n/nCols):n;
cEnd = [cStart(2:end)-1 n];
cCenter = round(cStart+0.5*(cEnd-cStart));

%% Block-wise fft:
profile on
profile clear
tic
xFft = zeros(i,1000);
yFft = zeros(i,1000);

rpts = zeros(nRows*nCols, 2);
fpts = zeros(nRows*nCols, 2, z);

iSeg = 0;
for r = 1:nRows
    for c = 1:nCols
        iSeg = iSeg+1;
        disp(nRows*nCols-iSeg)
        % Reference coordinates:
        rpts(iSeg, :) = [rCenter(r), cCenter(c)];
        
        [xFft(iSeg,:), yFft(iSeg,:)] = track_subpixel_wholeframe_motion_fft(...
            mov(rStart(r):rEnd(r), cStart(c):cEnd(c), :), ...
            tgt(rStart(r):rEnd(r), cStart(c):cEnd(c)),...
            5, 0.9, 100, false);
        
        % Shifted image coordinates:
        fpts(iSeg, 1, :) = rCenter(r)-yFft(iSeg,:);
        fpts(iSeg, 2, :) = cCenter(c)-xFft(iSeg,:);
    end
end
toc/1000
profile report
%% FFT:
tic;
[xFft, yFft] = track_subpixel_wholeframe_motion_fft(...
            sqrt(mov), sqrt(tgt), 5, 0.9, 100, false);
fprintf('FFT takes %1.4f seconds per frame.\n', toc/size(mov, 3));
fprintf('Mean difference X:%2.4f+-%2.4f Y:%2.4f+-%2.4f.\n', mean(xFft-xMlO), std(xFft-xMlO), mean(yFft-yMlO), std(yFft-yMlO));


%% Apply affine transformation
movC = movO;
R = imref2d([512,512]);

for frame = 1:size(movO, 3)
    if mod(frame,250)==0
        display(sprintf('frame: %d',frame)),
    end
    
    tform = fitgeotrans(fpts(:,:,frame),rpts,'pwl');
    movC(:,:,frame) = imwarp(movO(:,:,frame),tform,'OutputView',R,'FillValues',nan);   
end 