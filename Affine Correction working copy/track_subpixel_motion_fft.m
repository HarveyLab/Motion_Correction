function [xShift, yShift] = ...
    track_subpixel_motion_fft(stack, ref)
%[xshifts,yshifts]=track_subpixel_wholeframe_motion(movref,refframenum,maxshift);


% Tips:
% - This function performs best if the input matrices have even numbers
%   of rows and columns.
% - The function performs slightly faster on doubles, but can also take
%   singles.



% Efficient subpixel image registration by crosscorrelation.
%
% The most important parts of this code come from the MathWorks
% FileExchange submission accessible here:
% http://www.mathworks.com/matlabcentral/fileexchange/18401-efficient-subpixel-image-registration-by-cross-correlation
%
% Citation for this algorithm:
% Manuel Guizar-Sicairos, Samuel T. Thurman, and James R. Fienup, 
% "Efficient subpixel image registration algorithms," Opt. Lett. 33, 
% 156-158 (2008).
%
% This code gives the same precision as the FFT upsampled cross correlation
% in a small fraction of the computation time and with reduced memory
% requirements. It obtains an initial estimate of the crosscorrelation peak
% by an FFT and then refines the shift estimation by upsampling the DFT
% only in a small neighborhood of that estimate by means of a
% matrix-multiply DFT. With this procedure all the image points are used to
% compute the upsampled crosscorrelation. Manuel Guizar - Dec 13, 2007
%
% Portions of this code were taken from code written by Ann M. Kowalczyk 
% and James R. Fienup. 
% J.R. Fienup and A.M. Kowalczyk, "Phase retrieval for a complex-valued 
% object by using a low-resolution image," J. Opt. Soc. Am. A 7, 450-458 
% (1990).

% Free parameter: usfac specifies by how much we upsample to refine the
% sub-pixel estimate of the shift:
usfac = 20;

% Pre-calculate some values:
stack_fft = fft2(stack);
[m,n,z] = size(stack_fft);

% Partial-pixel shift:
% First upsample by a factor of 2 to obtain initial estimate
% Embed Fourier data in a 2x larger array
mlarge=m*2;
nlarge=n*2;

CC = zeros(mlarge,nlarge,z);
CC(m+1-fix(m/2):m+1+fix((m-1)/2), n+1-fix(n/2):n+1+fix((n-1)/2), :) = ...
    bsxfun(@times, conj(stack_fft), fft2(ref));
% CC = ref_fftshift.*conj(fftshift(mov_fft));

% Compute crosscorrelation and locate the peak 
% CC = ifft2(ifftshift(ifftshift(CC, 1), 2)); % Calculate cross-correlation
% No need to fftshift be cause we are not interested in phase
% information:
CC = ifft2(CC); % Calculate cross-correlation

% Find per-frame maxima:
[~, maxInd] = max(reshape(CC, [], z), [], 1);

% Find subscripts of maxima:
[rloc, cloc] = ind2sub(size(CC(:,:,1)), maxInd);

% Obtain shift in original pixel grid from the position of the
% crosscorrelation peak 
[m,n,z] = size(CC);
md2 = floor(m/2); 
nd2 = floor(n/2);

rowShift = rloc - 1;
rowShift(rloc>md2) = rloc(rloc>md2) - m - 1;
rowShift = rowShift/2;

colShift = cloc - 1;
colShift(cloc>nd2) = cloc(cloc>nd2) - n - 1;
colShift = colShift/2;

% Refine estimate with matrix multiply DFT
%%% DFT computation %%%
% Initial shift estimate in upsampled grid
dftshift = ((usfac*1.5)/2); %% Center of output array at dftshift+1

% Matrix multiply DFT around the current shift estimate
nRow = (usfac*1.5);
nCol = (usfac*1.5);
offRow = dftshift-rowShift*usfac;
offCol = dftshift-colShift*usfac;

upsampled = dftups(bsxfun(@times, stack_fft, conj(fft2(ref))), nRow, nCol, usfac, offRow, offCol);
CC = conj(upsampled)/(md2*nd2*usfac^2);

% Locate maximum and map back to original pixel grid
% Find per-frame maxima:
[~, maxInd] = max(reshape(CC, [], z), [], 1);

% Find subscripts of maxima:
[rloc, cloc] = ind2sub(size(CC(:,:,1)), maxInd);

rloc = rloc - dftshift - 1;
cloc = cloc - dftshift - 1;
rowShift = rowShift + rloc/usfac;
colShift = colShift + cloc/usfac;

% Output:
xShift = colShift;
yShift = rowShift;

function out = dftups(in, nRow, nCol, usfac, offRow, offCol)
% function out=dftups(in,nRow,nCol,usfac,offRow,offCol);
% Upsampled DFT by matrix multiplies, can compute an upsampled DFT in just
% a small region.
% usfac         Upsampling factor (default usfac = 1)
% [nRow,nCol]     Number of pixels in the output upsampled DFT, in
%               units of upsampled pixels (default = size(in))
% offRow, offCol    Row and column offsets, allow to shift the output array to
%               a region of interest on the DFT (default = 0)
% Recieves DC in upper left corner, image center must be in (1,1) 
% Manuel Guizar - Dec 13, 2007
% Modified from dftus, by J.R. Fienup 7/31/06

% This code is intended to provide the same result as if the following
% operations were performed
%   - Embed the array "in" in an array that is usfac times larger in each
%     dimension. ifftshift to bring the center of the image to (1,1).
%   - Take the FFT of the larger array
%   - Extract an [nRow, nCol] region of the result. Starting with the 
%     [offRow+1 offCol+1] element.

% It achieves this result by computing the DFT in the output array without
% the need to zeropad. Much faster and memory efficient than the
% zero-padded FFT approach if [nRow nCol] are much smaller than [nr*usfac nc*usfac]

[nr, nc, nFrame] = size(in);

out = zeros(nRow, nCol, nFrame);

colFactor = (-1i*2*pi/(nc*usfac))*(ifftshift((0:nc-1)).' - floor(nc/2));
rowFactor = ifftshift(0:nr-1) - floor(nr/2);

for i = 1:nFrame
    % Compute kernels and obtain DFT by matrix products
    kernc = exp(colFactor*( (0:nCol-1) - offCol(i) ));
    kernr = exp((-1i*2*pi/(nr*usfac))*((0:nRow-1).' - offRow(i))*rowFactor);
    out(:,:,i) = kernr*in(:,:,i)*kernc;
end
return






