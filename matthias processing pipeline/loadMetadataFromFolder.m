function movMetadata = loadMetadataFromFolder(path)

list = dir(fullfile([path, '*.mat']));

folder = fileparts(path);

movMetadata = [];

for f = list'
    temp = load(fullfile(folder, f.name));
    movMetadata = cat(1, movMetadata, temp.movMetadata);
end