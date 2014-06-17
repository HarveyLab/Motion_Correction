
%% Load data
movO = tiffRead('C:\Users\Matthias\Local\Storage\labdata\imaging\MMe001\MMe001_140330\preProcessFunctionTestActivityAcq\processed\MMe001_140330_920spontAct_001_001_slice1_ch1.tif');
% movO = tiffRead('C:\Users\Matthias\Local\Storage\labdata\laurasData\LD093_130813_view1_005\processed\LD093_130813_view1_005_002_slice2_ch1.tif');


% mov = mov(:,:,1:50);
tgt = median(movO(:,:,90:120), 3);


mov = movO(:, 50:512-50, :);
tgt = tgt(:, 50:512-50);

%% Scale pixel values
tic
tBase = prctile(mov(:),1);
tTop = prctile(mov(:),99);
toc

tic
mov = sqrt(movO);
toc
tMov = (tMov - tBase) / (tTop-tBase);
tMov(tMov<0) = 0; tMov(tMov>1) = 1;
toc
%% Old code:
tic;
[xOld, yOld] = track_subpixel_wholeframe_motion_varythresh(...
            mov, tgt, 5, 0.9, 100, false);
tOld = toc;
fprintf('Old code takes %1.4f seconds per frame.\n', tOld/size(mov, 3));

%% Matlab corr() optimized:
tic;
[xMlO, yMlO] = track_subpixel_wholeframe_motion_varythresh_matlabcorr(...
            mov, tgt, 5, 0.9, 100, false);
fprintf('Matlab corr takes %1.4f seconds per frame.\n', toc/size(mov, 3));

%% FFT:
tic;
[xFft, yFft] = track_subpixel_wholeframe_motion_fft(...
            sqrt(mov), sqrt(tgt), 5, 0.9, 100, false);
fprintf('FFT takes %1.4f seconds per frame.\n', toc/size(mov, 3));
fprintf('Mean difference X:%2.4f+-%2.4f Y:%2.4f+-%2.4f.\n', mean(xFft-xMlO), std(xFft-xMlO), mean(yFft-yMlO), std(yFft-yMlO));

%% Plot comparison
figure
hold all
% plot(xOld)
plot(xMlO)
plot(xFft)
legend('Current code', 'Using Matlab''s corr()', 'Using fft-based correlation')
xlabel('Frame')
ylabel('X Shift')
figure
hold all
% plot(yOld)
plot(yMlO)
plot(yFft)
legend('Current code', 'Using Matlab''s corr()', 'Using fft-based correlation')
xlabel('Frame')
ylabel('Y Shift')
hold off
%% Apply shifts
movC = movO;
R = imref2d([512,512]);
for frame = 1:size(movO, 3)
    frame
    A = eye(3);
    A(3,1) = xFft(frame);
    A(3,2) = yFft(frame);
    tform = affine2d(A);
    movC(:,:,frame) = imwarp(movO(:,:,frame), ...
        tform, 'OutputView', R, 'FillValues', nan);   
end

%% Time difference:
0.1173/0.5566
0.1173\0.5566

0.2591/0.5566
0.2591\0.5566

0.0343\0.5566
0.0343/0.5566
%% Compare results:
fprintf('Average pixel shift difference between old code and Matlab corr: %1.9f\n', ...
    mean([xOld-xMatlab, yOld-yMatlab]));

%% new code:
for i = many
    
end
%% matlab xcorr:
for i = many
    
end

%% Test for equivalence:
a = rand(5, 1);
b = rand(5, 3);

ml = corr(a, b);

corrLength = numel(a)+numel(b)-1;

fftcorr = ...
    fftshift(ifft(bsxfun(@times, fft(a,corrLength), conj(fft(b,corrLength)))));

real( ifft( fft(a) .* fft(fliplr(b)) ));


%%
a = rand(5000, 1);
b = rand(5000, 5000);

%%
tic
ml = corr(a, b);
toc
tic
me = myCorr(a, b);
toc

%% 
A = a;
B = b;

An=bsxfun(@minus,A,mean(A,1)); %%% zero-mean
Bn=bsxfun(@minus,B,mean(B,1)); %%% zero-mean
An=bsxfun(@times,An,1./sqrt(sum(An.^2,1))); %% L2-normalization
Bn=bsxfun(@times,Bn,1./sqrt(sum(Bn.^2,1))); %% L2-normalization

C=sum(bsxfun(@times, An, Bn),1); %% correlation

myCorr = @(A, B, mA, mB) sum(bsxfun(@times, bsxfun(@times, bsxfun(@minus,A,mA), ./sqrt(sum(bsxfun(@minus,A,mA).^2,1))), bsxfun(@times,bsxfun(@minus,B,mB),1./sqrt(sum(bsxfun(@minus,B,mB).^2,1)))),1);
