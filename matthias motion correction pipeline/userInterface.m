% String or cell array of strings with one or more folders:
tiffDirList = {'C:\Users\Matthias\Local\Storage\labdata\imaging\MM021\MM021_140518', ...
               'C:\Users\Matthias\Local\Storage\labdata\imaging\MM018\MM018_140518'};

channelForMotionCorrection = 'green'; % green, red
darkOrBrightRois = 'both'; %dark, bright, both
alignmentScope = 'acquisition'; % acquisition, file, manual

% Create processing pipeline struct with all necessary information:
pp.channelForMotionCorrection = channelForMotionCorrection;
pp.darkOrBrightRois = darkOrBrightRois;
pp.alignmentScope = alignmentScope;

imageProcessingPipeline(pp);
