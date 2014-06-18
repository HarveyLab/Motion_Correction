function score = doughnutObjectiveFunv2(xIn, ray, nRays, nPoints)

% Parameters:
% 1 - outer sin offset
% 2 - outer sin amplitude
% 3 - outer sin shift
% 4 - inner sin offset (must be < x(1))

x(1) = xIn(1);
x(2) = 0;
x(3) = 0;
x(4) = xIn(2);


th = (2*pi)/nRays:(2*pi)/nRays:2*pi;

outer = x(1) + x(2)*sin(th+x(3));
inner = x(4) + x(2)*sin(th+x(3));


indOut = bsxfun(@(o, ptInd) ptInd<o, outer, (1:nPoints)');
indIn  = bsxfun(@(i, ptInd) ptInd<i, inner, (1:nPoints)');

score = mean(mean(ray(indOut))) - mean(mean(ray(indIn)));

score = -score.^2;