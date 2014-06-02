sk = zeros(size(movMetadata(1).slice.channel.skewness));
for i = 1:numel(movMetadata)
    sk = sk+scaleArray(movMetadata(i).slice.channel.skewness);
    i
end
sk(isnan(sk)) = 0;

md = zeros(size(movMetadata(1).slice.channel.skewness));
for i = 1:numel(movMetadata)
    md = md+movMetadata(i).slice.channel.median;
    i
end
md(isnan(md)) = 0;