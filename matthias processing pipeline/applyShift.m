function mov = applyShift(mov, xShift, yShift, method, referencePoints)
if ~exist('referencePoints', 'var')
    referencePoints = [];
end

[h, w, z] = size(mov);
referenceFrame = imref2d([h, w]);

switch method
    case 'affine'
        for f = 1:z
            if mod(f,250)==1
                display(sprintf('frame: %d',f)),
            end
            
            movingPoints = referencePoints - [xShift(:, f), yShift(:, f)];
            tform = fitgeotrans(movingPoints, referencePoints, 'affine');
            mov(:,:,f) = imwarp(mov(:,:,f), tform, ...
                'OutputView', referenceFrame, 'FillValues', nan);  
        end
    case 'translation'
        for f = 1:z
            if mod(f,250)==1
                display(sprintf('frame: %d',f)),
            end
            
            % Calculate compound shift values:
            thisXShift = median(xShift(:, f));
            thisYShift = median(yShift(:, f));
            
            % Don't allow absurdly large shifts:
            if abs(thisXShift) > 10 || abs(thisYShift) > 10
                warning('Large shift in frame %1.0d.', f);
                continue
            end
            
            tformMat = eye(3);
            tformMat(3, 1) = thisXShift;
            tformMat(3, 2) = thisYShift;
            tform = affine2d(tformMat);
            mov(:,:,f) = imwarp(mov(:,:,f), tform, ...
                'OutputView', referenceFrame, 'FillValues', nan); 
        end
    otherwise
        error('Unknown transformation method.');
end