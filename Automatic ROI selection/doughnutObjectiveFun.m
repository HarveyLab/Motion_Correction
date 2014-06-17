function score = doughnutObjectiveFun(x, offset, ray, nRays, nPoints)

rowSub = round(offset + x(1)*cos(x(2)+linspace(0, 2*pi, nRays)));
rowSub(rowSub<1) = 1;
rowSub(rowSub>nPoints) = nPoints;
ind = sub2ind([nPoints, nRays], rowSub, 1:nRays);
score = -mean(ray(ind));
