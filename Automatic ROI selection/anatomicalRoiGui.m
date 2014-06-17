function anatomicalRoiGui(imgMean, roiLabels, imgSecondary)
% anatomicalRoiGui(imgMean, roiLabels, imgSecondary)
% Interactive GUI to speed up hand-selection of GCaMP-labelled cells.
%
% 
% USAGE:
% 1. Run anatomicalRoiGui(imgMean, ..., ...)
% 2. Click on the CENTER of a cell to select it.
% 3. An interactive polygon-ROI will appear. It can be moved/resized etc.
%    It is saved as a ROI when the user clicks outside of the active ROI (i.e.
%    when selecting the next ROI).
% 4. ROIs can be deleted by clicking on them (for saved ROIs) or pressing
%    "d" (for the currently active ROI).
% 5. Repeat until done.
% 6. Press "s" (on keyboard) to save a variable called "roiLabels" to the base
%    workspace, which contains all ROI labels.
%
%
% INPUTS:
% imgMean               A mean or median projection of the movie to select 
%                       ROIs from.
% roiLabels (opt.)      An image of size(imgMean) containing previously
%                       selected ROIs. This is an image as returned by
%                       BWLABEL, i.e. background pixels are zeros and ROI
%                       pixels are filled with each ROIs number (integer).
% imgSecondary (opt).   A single image or stack of images of size(imgMean)
%                       that are useful as guidance for ROI selection.
%                       These could be mean images from other sessions or
%                       processed movie projections (e.g. skewness or DFF)
%                       that show active cells. The imgSecondary images are
%                       not used by the ROI selection algorithm and are
%                       just to guide the user in selecting cells.
%
%
% KEYBOARD SHORTCUTS:
% s             Save current ROI labels to base workspace.
% d             Delete currently active ROI polygon.
% z             Toggle zoom tool. Any tools (zoom, pan etc.) must be
%               de-selected to select ROIs.
% f & b         Move forward/backward through the main and secondary
%               images.
% Scrollwheel   Increase/Decrease size of currently active ROI.
%
%
% TODO:
% - go through todos in code.


if ~exist('imgSecondary', 'var') || isempty(imgSecondary)
    imgSecondary = [];
end

if ~exist('roiLabels', 'var') || isempty(roiLabels)
    roiLabels = zeros(size(imgMean));
end


%% Dev:
% load('C:\Users\Matthias\Local\Storage\labdata\imaging\MM021\MM021_140602\MM021_140602_task_001_001.mat')
% imgMean = movMetadata.slice.channel(1).median;

% These values may have to be adjusted:
% radius in cbMouseclick: Specifies a circle that is larger than any cell, in upscaled pixels.

% Create struct that will contain all GUI data:
gui = struct;

% Prepare image:
[h, w] = size(imgMean);
imgMean(isnan(imgMean)) = 0;

% Unsharp mask:
sd = max(h, w)/256; % Empirical: 1 px blurring for 256 pixel images.
img = scaleImg(imgMean./imgGaussBlur(imgMean, sd));

% Increase image contrast:
clipPercent = 0.1;
cent = img(round(0.2*h):round(0.8*h), round(0.2*w):round(0.8*w));
img = imadjust(img, [prctile(cent(:), clipPercent), prctile(cent(:), 100-clipPercent)]);

% Upsample:
gui.usFac = ceil(2000/max(h, w)); % 2000 x 2000 pixels seems reasonable.
img = imresize(img, gui.usFac);
if ~isempty(imgSecondary)
    imgSecondary = imresize(imgSecondary, gui.usFac);
end

% Create GUI figure and data:
gui.img = img;
gui.imgSecondary = imgSecondary;
gui.roiLabels = imresize(roiLabels, gui.usFac, 'nearest');
gui.hFig = figure;
gui.roiSizeOffset = 0;

% ... figure layout depends on screen orientation:
screenSize = get(0,'screensize');
if screenSize(3) > screenSize(4)
    gui.hAxMain = subplot(3, 4, [2 3 4; 6 7 8; 10 11 12]);
    gui.hAxOverview = subplot(3, 4, 1);
    gui.hAxAux1 = subplot(3, 4, 5);
    gui.hAxAux2 = subplot(3, 4, 9);
else
    gui.hAxMain = subplot(4, 3, 4:12);
    gui.hAxOverview = subplot(4, 3, 1);
    gui.hAxAux1 = subplot(4, 3, 2);
    gui.hAxAux2 = subplot(4, 3, 3);
end

set([gui.hAxAux1, gui.hAxAux2], 'xtick', [], 'ytick', []);

set(gui.hFig, 'WindowButtonDownFcn', @cbMouseclick, ...
              'WindowScrollWheelFcn', @cbScrollwheel, ...
              'KeyPressFcn', @cbKeypress);

gui.roiList = unique(gui.roiLabels(:));
gui.roiList(gui.roiList==0) = [];
gui.roiColors = lines(30);
gui.imPoly = impoly.empty; % For the imPoly object that will appear when the user clicks.
gui.temp = struct; % Temp storage for expensive calculations, e.g. for display.

% Display images:
gui.secondaryImgInd = 0;
gui.hImgMain = imshow(gui.img, 'parent', gui.hAxMain);
title(gui.hAxMain, 'Primary');

gui.hImgOverview = imshow(gui.img, 'parent', gui.hAxOverview);
title(gui.hAxOverview, 'Overview');
set(gui.hFig, 'userdata', gui);
updateDisplay(gui.hFig);

% Finally, store update the figure's user data:
set(gui.hFig, 'userdata', gui);

function cbMouseclick(obj, ~)
gui = get(obj, 'userdata');
clickCoord = get(gui.hAxMain, 'currentpoint');

row = floor(clickCoord(1, 2));
col = floor(clickCoord(1, 1));

% Ignore clicks that are outside of the image:
[h, w] = size(gui.img);
if row<1 || col<1 || row>h || col>w
    return
end

% If there's an impoly object present, then clicks close to the object are
% ignored to allow manipulation of the object. Clicks in the center delete
% the object.
if ~isempty(gui.imPoly)
   pos = gui.imPoly.getPosition;
else
    pos = nan(1, 2);
end

if (any(abs(pos(:, 1)-col)<5) && any(abs(pos(:, 2)-row)<5)) || ...
        inpolygon(col, row, pos(:,1), pos(:,2))
    % Click is insider polygon or within 5 pixels of it: do nothing to
    % allow user to manipulate the impoly.
else 
    % Click is not close to the current impoly:
    if ~isempty(gui.imPoly)
        % Turn impoly into a roi:
        mask = gui.imPoly.createMask(gui.hImgMain);
        if ~isempty(gui.roiList)
            freeRoiNumber = setdiff(1:max(gui.roiList)+1, gui.roiList);
        else
            freeRoiNumber = 1;
        end
        gui.roiLabels(mask) = freeRoiNumber(1);
        gui.roiList = sort([gui.roiList; freeRoiNumber(1)]);
        gui.imPoly.delete;
        gui.imPoly = impoly.empty;
    end
    
    if gui.roiLabels(row, col)
        % Click was inside an existing ROI: delete that ROI and turn it
        % into an impoly again:
        gui.roiLabels(gui.roiLabels == gui.roiLabels(row, col)) = 0;
        gui.roiList(gui.roiList == gui.roiLabels(row, col)) = [];
    end
    
    gui = anatomicalRoiExtract(gui, row, col, 80, gui.roiSizeOffset);
end



% gui.nRois = gui.nRois + 1;
% gui.roiLabels(imgRoi) = gui.nRois;

set(gui.hFig, 'userdata', gui);
updateDisplay(gui.hFig);

function cbKeypress(obj, evt)
gui = get(obj, 'userdata');
switch evt.Key
    case 'rightarrow'
    case 'leftarrow'
    case 'uparrow'
    case 'downarrow'
        
    case 'd' % delete current impoly
       if ~isempty(gui.imPoly)
           delete(gui.imPoly);
           gui.imPoly = impoly.empty;
       end
        
    case 'f' % forward through images
        if ~isempty(gui.imgSecondary)
            gui.secondaryImgInd = gui.secondaryImgInd + 1;
            gui.secondaryImgInd = mod(gui.secondaryImgInd, 1+size(gui.imgSecondary, 3));
        end
        
    case 'b' % backward through images
        if ~isempty(gui.imgSecondary)
            gui.secondaryImgInd = gui.secondaryImgInd - 1;
            gui.secondaryImgInd = mod(gui.secondaryImgInd, 1+size(gui.imgSecondary, 3));
        end
        
    case 'z' % toggle zoom tool
        zoomState = get(zoom(gui.hFig), 'enable');
        switch zoomState
            case 'off'
                zoom(gui.hFig, 'on');
                % The following is necessary to detect key presses during
                % zooming (the ZOOM function would otherwise hijack the
                % KeyPressFcn).
                hManager = uigetmodemanager(gui.hFig);
                set(hManager.WindowListenerHandles, 'Enable', 'off');
                set(gui.hFig, 'KeyPressFcn', @cbKeypress);
            case 'on'
                zoom(gui.hFig, 'off');
        end
        
    case 's' % save roi img to base workspace:
        varName = 'roiLabels';
        % The following makes sure that no variables with the same name are
        % over-written by the new one:
        if evalin('base',['exist(''', varName ''',''var'')'])
            nameForExistingVar = [varName 'Old1'];
            nameForExistingVar = recursiveRenameVarsInBase(nameForExistingVar);

            % Rename existing var:
            evalin('base',[nameForExistingVar '=' varName ';']);
            evalin('base',['clear ' varName]);
            fprintf('Found existing SN in base workspace. Renamed old sn to ''%s''\n', nameForExistingVar)
        end
        
        % Turn last impoly into a roi:
        if ~isempty(gui.imPoly)
            mask = gui.imPoly.createMask(gui.hImgMain); 
            if ~isempty(gui.roiList)
                freeRoiNumber = setdiff(1:max(gui.roiList)+1, gui.roiList);
            else
                freeRoiNumber = 1;
            end
            gui.roiLabels(mask) = freeRoiNumber(1);
            gui.imPoly.delete;
            gui.imPoly = impoly.empty;
            set(gui.hFig, 'userdata', gui);
            updateDisplay(gui.hFig);
        end
        
        % Downsample to original resolution:
        roiDs = imresize(gui.roiLabels, gui.usFac^-1, 'nearest');
        assignin('base', varName, roiDs);
        
end
set(obj, 'userdata', gui);
updateDisplay(gui.hFig);

function cbScrollwheel(obj, evt)
gui = get(obj, 'userdata');

% Ignore if there is no polygon:
if isempty(gui.imPoly)
    return
end

% Get data from last click:
clickCoord = get(gca, 'currentpoint');
row = floor(clickCoord(1, 2));
col = floor(clickCoord(1, 1));
pos = gui.imPoly.getPosition;

% Ignore if click/mouseWheel event was outside of polygon:
if ~inpolygon(col, row, pos(:,1), pos(:,2))
    return
end

% Adjust current ROI according to mouse wheel motion:
switch sign(evt.VerticalScrollCount)
    case -1 % Scrolling up
        pos = resizePolygon(pos, 1);

    case 1 % Scrolling down
        pos = resizePolygon(pos, -1);
end
gui.imPoly.setPosition(pos);
set(obj, 'userdata', gui);


function updateDisplay(hFig)

gui = get(hFig, 'userdata');

if gui.secondaryImgInd
    % Display chosen secondary image:
    if ~isfield(gui.temp, 'cdataSecondaryImg') || isempty(gui.temp.cdataSecondaryImg)
        for i = 1:size(gui.imgSecondary, 3)
            gui.temp.cdataSecondaryImg(:,:,1) = scaleImg(gui.imgSecondary(:,:,i));
        end
    end
    cdata = repmat(gui.temp.cdataSecondaryImg(:,:,gui.secondaryImgInd), [1 1 3]);
    set(get(gui.hAxMain,'Title'), 'String', sprintf('Secondary image %1.0f', gui.secondaryImgInd)); 
else
    % Display primary image:
    if ~isfield(gui.temp, 'cdataMainImg') || isempty(gui.temp.cdataMainImg)
        gui.temp.cdataMainImg = repmat(scaleImg(gui.img), [1 1 3]);
    end
    cdata = gui.temp.cdataMainImg;
    set(get(gui.hAxMain,'Title'), 'String', '');
end

% Add colored ROI labels:
if ~isempty(gui.roiList)
    clut = gui.roiColors(mod(1:max(gui.roiList), 30)+1, :);
    roiCdata = double(myLabel2rgb(gui.roiLabels, clut))/255;
    cdata = scaleImg(cdata.*roiCdata);
end

% Overviewimg is only updated when the primary image is displayed:
if ~gui.secondaryImgInd
    gui.temp.cdataOvervieImg = cdata;
    set(gui.hImgOverview, 'cdata', gui.temp.cdataOvervieImg);
end

set(gui.hImgMain, 'cdata', cdata);

function goodName = recursiveRenameVarsInBase(testName)
if evalin('base',['exist(''', testName ''',''var'')'])
    currentNum = regexp(testName, '\d+$', 'match');
    if isempty(currentNum)
        newName = [testName 'Old1'];
    else
        newNum = str2double(currentNum)+1;
        newName = testName(1:end-numel(currentNum{:}));
        newName = [newName, num2str(newNum)];
    end
    goodName = recursiveRenameVarsInBase(newName);
else
    goodName = testName;
end

function img = scaleImg(img)
img = img-min(img(:));
img = img./max(img(:));

function RGB = myLabel2rgb(label, cmap)
% Like MATLAB label2RGB, but skipping some checks to be faster:
cmap = [[1 1 1]; cmap]; % Add zero color
RGB = ind2rgb8(double(label)+1, cmap);

function pos = resizePolygon(pos, offs)
meanPos = mean(pos);
pos = bsxfun(@minus, pos, meanPos);
[theta, rho] = cart2pol(pos(:,1), pos(:,2));
[pos(:,1), pos(:,2)] = pol2cart(theta, rho+offs);
pos = bsxfun(@plus, pos, meanPos);

function img = imgGaussBlur(img, sd)
f = fspecial('gaussian', min(round(50*sd), min(size(img))), round(sd));
img = imfilter(img, f);


