%% Quantify motion as the difference between adjacent frames:
base = 'C:\Users\Matthias\Local\Storage\labdata\imaging\MMe001\MMe001_140330\preProcessFunctionTestActivityAcq\processed\';

% Inter-frame difference function:
rsh2d = @(m) reshape(m, [], size(m, 3));
ifd = @(m) nanmean(rsh2d(abs(diff(bsxfun(@rdivide, imgGaussBlur(m, 1), permute(nanmean(rsh2d(m)), [1, 3, 2])), 1, 3))));

% Raw data:
mov = tiffRead(fullfile(base, 'MMe001_140330_920spontAct_001_001_slice1_ch1.tif'));
mov = mov(100:end-100, 100:end-100, :);
motionRaw = ifd(mov);
disp('Raw done.');

% Traditional MC:
mov = tiffRead(fullfile(base, 'MMe001_140330_920spontAct_001_001_mov_Acq1_traditionalMC.tif'));
mov = mov(100:end-100, 100:end-100, :);
motionTrad = ifd(mov);
disp('Trad done.');

% % Old fft MC:
% mov = tiffRead(fullfile(base, 'MMe001_140330_920spontAct_001_001_mov_Acq1_fftMC.tif'));
% motionFftOld = ifd(mov);
% disp('FFT old done.');

% FFT+60ROI+affine
mov = tiffRead(fullfile(base, 'MMe001_140330_920spontAct_001_001_mov_Acq1_50roi_fft_affine.tif'));
mov = mov(100:end-100, 100:end-100, :);
motionFftRoi60affine = ifd(mov);
disp('FFT+60ROI+affine done.');

% % FFT+60ROI+translation
% mov = tiffRead(fullfile(base, 'MMe001_140330_920spontAct_001_001_mov_Acq1_50roi_fft_translation.tif'));
% motionFftRoi60translation = ifd(mov);
% disp('FFT+60ROI+translation done.');

% % FFT+11selectedROI+translation
% mov = tiffRead(fullfile(base, 'MMe001_140330_920spontAct_001_001_mov_Acq1_11selectedROI_transl.tif'));
% motion11selectedROI_transl = ifd(mov);
% disp('motion11selectedROI_transl done.');

% FFT+11selectedROI+translation
mov = tiffRead(fullfile(base, 'MMe001_140330_920spontAct_001_001_mov_Acq1_bloodvessel_corrreject.tif'));
mov = mov(100:end-100, 100:end-100, :);
motionBloodVessel = ifd(mov);
disp('motionBloodVessel done.');

%% Laura's files
base='C:\Users\Matthias\Local\Storage\labdata\imaging\motionCorrectionTests';
% laura old
mov = tiffRead(fullfile(base, 'correctedOld\LD085_131126_001_slice004_Acq6.tif'));
c = floor(size(mov)/2);
movO = mov(c(1)-100:c(1)+100, c(2)-100:c(2)+100, :);
% lauraOld = ifd(mov);
% disp('motionBloodVessel done.');

% laura new transl
% mov = tiffRead(fullfile(base, 'LD085_131126_006_mov_Acq1.tif'));
% mov = mov(100:end-100, 100:end-100, :);
% lauraNewTransl = ifd(mov);
% disp('motionBloodVessel done.');

% laura new bright rois affine
mov = tiffRead(fullfile(base, 'LD085_131126_006_mov_Acq1_bright_affine.tif'));
c = floor(size(mov)/2);
movN = mov(c(1)-100:c(1)+100, c(2)-100:c(2)+100, :);
% lauraNewTransl = ifd(mov);
% disp('motionBloodVessel done.');

% laura raw
mov = tiffRead(fullfile(base, 'LD085_131126_006_slice004.tif'));
c = floor(size(mov)/2);
movR = mov(c(1)-100:c(1)+100, c(2)-100:c(2)+100, :);
% lauraRaw = ifd(mov);
% disp('motionBloodVessel done.');

%% Display:
figure
hold on
% plot(motionRaw, 'r')
plot(lauraOld, 'k')
% plot(motionFftOld, 'b')
% plot(motionFftRoi60affine, 'c')
plot(lauraNewTransl, 'g')

%%
figure
plot(motionRaw, motionTrad, 'b.')
hold on
% plot(motionRaw, motionFftRoi60affine, 'b.')
plot(motionRaw, motionBloodVessel, 'r.')
line

%%
figure
plot(motionFftRoi60translation, motion11selectedROI_transl, 'k.')
hold on
line

%% Compare sharpness by comparing spectra:

% Transform from the spatial domain to the spatial frecuencies domain
thisMov = movN;
thisMov(isnan(thisMov)) = 0;
nonans = mean(imgGaussBlur(thisMov, 5), 3);
FX=fft2(nonans);

% Take the modulus
MFX=abs(FX);

% Fftshift and scale:
MFX = fftshift(log(MFX));

% Average across orientations:
meanMFX = (MFX + rot90(MFX, 1) + rot90(MFX, 2) + rot90(MFX, 3))/4;
meanMFX = meanMFX(floor(1:end/2), floor(1:end/2));

% figure;
% imagesc(meanMFX)

hold on
meanMeanMFX = mean(meanMFX);
plot(meanMeanMFX(end:-1:1), 'g')