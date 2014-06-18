function score = sinObjectiveFun(x, bound)
t = linspace(1, 2*pi, numel(bound));
out = x(1) + x(2)*sin(t+x(3));
score = sum((bound-out).^2);
