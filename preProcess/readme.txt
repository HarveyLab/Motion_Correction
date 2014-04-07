The preProcess.m function does the following:

    1. Correct misalignment of image lines due to bidirectional scanning (up to 3 pixels shift).
    2. Split channels into separate files.
    3. Split slices into separate files.
    4. Optionally, apply spatial pixel binning.

The function should be applied to the raw tiff files saved by scanimage, before any motion correction etc. When calling the function, you simply supply a path, and the function will process all files at that path and save the processed files in a subdirectory called "processed".

The path may contain a wildcard, allowing you to specify a particular acquisition. Say you want to pre-process the files XX001_140307_001, XX001_140307_002, XX001_140307_003 and so on, and the files are at the path C:\data. Then you can supply the path C:\data\XX001_140307_* (note the asterisk at the end) and the function will process all files at the specified path that start with the specified partial file name. For example:

preProcess('C:\data\XX001_140307_*');

In this way, you can apply the function to all files in the folder ("'C:\data\*"), just a single file ('C:\data\XX001_140307_001.tiff'), or a selection of files.

The function uses information attached by scanimage to the tiff files to find out how many channels, slices, frames, etc. there are.

If you'll use this function, please check the output carefully...I tested it but there might still be bugs.

The function has some additional abilities:

preProcess(path, suffix): You can specify a "suffix" as the second input argument. This is a string that will be attached to the file names of the processed files, to make identification easier.

preProcess(path, suffix, binFactor): You can specify a spatial binning factor to pin pixels spatially. E.g., if binFactor==2, then 2x2 blocks of pixels will be averaged and the width and height of the movie will be divided by two.

Processing of anatomical Z-stacks: In scanimage, it is possible to acquire Z-stacks using the slow Z-stage (rather than the piezo). This is useful for acquiring a Z-stack of still images, e.g. to have an anatomical record of cell positions across the entire depth of cortex. It makes sense to acquire several frames at each depth and average them to improve signal to noise. But if you do the averaging directly in scanimage, you'll get blurry images if the mouse moves. If you provide preProcess with files that contain an anatomical Z-stack (acquired with the slow Z-drive), then it will motion-correct and average the frames within each slice, and save a tiff-stack containing one average image for each depth. This will take a long time due to the motion correction.