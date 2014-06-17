function [gui, roiMask] = anatomicalRoiExtract(gui, row, col, radius, roiSizeOffset)


showFig = 1;

img = gui.img;

% Extract pixels in polar coordinates from clicked point:
nRays = 300;

% nPoints determines the radius of the captured circle. This should contain
% the entire cell:
nPoints = radius*0.6;
theta = linspace(0, 2*pi, nRays);
rho = nPoints:-1:1;
[thetaGrid, rhoGrid] = meshgrid(theta, rho);
[polX, polY] = pol2cart(thetaGrid, rhoGrid);
i = sub2ind(size(img), round(polY(:)+row), round(polX(:)+col));
ray = reshape(img(i), nPoints, []);

% if showFig
%     h.ray = subplot(1, 5, 1, 'parent', h.fig);
%     imagesc(ray, 'parent', h.ray);
% %     set(h.ray, 'dataaspect', [1 1 1]);
% end

% % Get small region around seed:
% if row-offs < 1 || col-offs < 1 || row+offs > size(img, 1) || col+offs > size(img, 2)
%     roiLabels = false(size(img));
%     return
% end
% region = img(row-offs:row+offs, ...
%              col-offs:col+offs);
% % exclude = exclude(row-offs:row+offs, ...
% %                   col-offs:col+offs);

% Find "inside" of the cell, defined as the area contained within the
% maximum intensity pixel along each ray:
[rayMaxV, rayMaxI] = max(ray);

% Fit a sinusoidal boundary to delineate the "inside" of the cell:
% offset = median(rayMaxI);
[~, offset] = max(mean(ray-mean(ray(:)), 2));
objFun = @(x) doughnutObjectiveFun(x, offset, ray, nRays, nPoints);
x = fminsearch(objFun, [10, 1]);
boundInd = round(median(rayMaxI) + x(1)*cos(x(2)+linspace(0, 2*pi, nRays)));
maskOutside = bsxfun(@gt, boundInd, (1:nPoints)');

% i = sub2ind(size(ray), rayMaxI, 1:nRays);
% maxPix = zeros(size(ray));
% maxPix(i) = 1;
% maskOutside = ~cumsum(maxPix);

% if showFig
%     h.maskOutside = subplot(1, 5, 2, 'parent', h.fig);
%     temp = ray;
%     temp(logical(maskOutside)) = min(temp(:));
%     imagesc(temp, 'parent', h.maskOutside);
%     title(h.maskOutside, '"Outside of cell"');
% %     set(h.ray, 'dataaspect', [1 1 1]);
% end

% Get column-wise regional minima:
colMin = reshape(imregionalmin(ray(:), 4), size(ray, 1), []);

% Find pixels that are lower than the SD cutoff:
sdThresh = 1;
imgMean = mean(img(:));
imgSd = std(img(:));
darkPix = (ray-imgMean)/imgSd < sdThresh;

% Combine all these masks to get the boundary: the boundary is constrained
% to be beyond the first maximum, but before either the first dark pixel,
% or the first regional minimum:
mask = maskOutside & (colMin | darkPix);
mask = flipud(cumsum(flipud(mask)))>0;

% Find boundary indices:
% (Summing of the 1's in each column gives the index of where the 1's end.)
boundInd = sum(mask, 1);

% if showFig
%     h.mask = subplot(1, 5, 3, 'parent', h.fig);
%     temp = ray;
%     temp(logical(mask)) = min(temp(:));
%     imagesc(temp, 'parent', h.mask);
%     title(h.mask, 'Colmin & dark pixels');
% %     set(h.ray, 'dataaspect', [1 1 1]);
% end

% Columns with no boundary are invalid:
boundInd(boundInd==0) = NaN;

% Pad boundInd to avoid boundary effects:
boundInd = [boundInd(round(nRays/2):nRays) boundInd, boundInd(1:round(nRays/2)-1)];

% Iteratively discard "outliers" (diff>median+3*std):
boundIndOld = NaN;
while ~isequaln(boundInd, boundIndOld)
    boundIndOld = boundInd;
    
    % Use difference of neighboring boundary points:
    boundIndDiff = diff(boundInd([end, 1:end]));
    
    % Discard boundary points that are too far from their neighbors:
    boundInd(abs(boundIndDiff)>nanmedian(abs(boundIndDiff))+1*nanstd(abs(boundIndDiff))) = NaN;
    notNan = ~isnan(boundInd);
    x = 1:(nRays*2);
    
    % Interpolate across discarded points:
    boundInd = interp1(x(notNan), boundInd(notNan), x);
end

% Unpad:
boundInd = boundInd(round(nRays/2)+1:round(nRays/2)+nRays);

% Adjust boundary size as per user input:
boundInd = boundInd + roiSizeOffset;

% Exclude pixels that already belong to another ROI:
rayOtherRois = flipud(cumsum(flipud(reshape(gui.roiLabels(i), nPoints, []))))~=0;
boundOtherRois = sum(rayOtherRois);
boundInd = max(boundInd, boundOtherRois);

if showFig
    rayImg = ray;
    rayImg(rayOtherRois) = min(ray(:));
    imagesc(rayImg, 'parent', gui.hAxAux1);
    hold(gui.hAxAux1, 'on');
    colormap(gui.hAxAux1, jet);
    plot(gui.hAxAux1, 1:nRays, boundInd, '.k');
    hold(gui.hAxAux1, 'off');
    title(gui.hAxAux1, 'Detected boundary');
    set(gui.hAxAux1, 'ydir', 'reverse', ...
        'xtick', [], 'ytick', []);
%     set(h.ray, 'dataaspect', [1 1 1]);
end

% Convert back to image coordinates:
[cartX, cartY] = pol2cart(theta, nPoints-boundInd(1:end));
i = sub2ind(size(img), round(cartY(:)+row), round(cartX(:)+col));

% Show ROI in image coordinates:
% if showFig
%     offs = 1*radius;
%     region = img(row-offs:row+offs, ...
%                  col-offs:col+offs);
% 
%     h.imgRoi = subplot(1, 5, 5, 'parent', h.fig);
%     hold(h.imgRoi, 'on');
%     imagesc(region, 'parent', h.imgRoi);
%     colormap(h.imgRoi, gray);
% %     plot(h.imgRoi, round(cartX(:)+offs), round(cartY(:)+offs), '.k');
%     hold(h.imgRoi, 'off');
%     title(h.imgRoi, 'Boundary in image coords');
%     set(h.imgRoi, 'ydir', 'reverse');
%     
%     % Impoly:
%     h.imPoly = impoly(h.imgRoi, [round(cartX(1:30:end)+offs); round(cartY(1:30:end)+offs)]')
% %     set(h.ray, 'dataaspect', [1 1 1]);
% end

%% Draw imPoly to allow the user to adjust the ROI:
% TODO: make the number of vertices variable...

gui.imPoly(end+1) = impoly(gui.hAxMain, [round(cartX(1:30:end)+col); round(cartY(1:30:end)+row)]');

% figure
imgBound = false(size(img));
imgBound(i) = 1;

% Fill ROI before downsampling (a one-pixel-boundary might vanish during
% downsampling):
roiMask = imfill(imgBound, [row, col], 4);

% Downsample:
% imgRoi = imresize(imgRoi, 1/gui.usFac, 'nearest');
% imagesc(md./imgGaussBlur(md, 1)-1*imgRoi)
% set(gca, 'dataa', [1 1 1]);


% TODO:
% - investigate pixel shift
% - plot all stages along the way to monitor effect of parameters
