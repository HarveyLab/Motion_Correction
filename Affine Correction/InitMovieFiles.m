%% Change This: Create variable / filenames names and location
num_files = 9;
nameOffset = 0;
mouse_name = 'fast';
session_name = 'MCtest';
view_name = 'MCtest';
slice_name = 'slice002';
movie_file = sprintf('%s_%s_%s_%s',mouse_name,session_name,view_name,slice_name);
tiffPath = 'E:\TempData\processed_512';
filepath = 'E:\Data\Corrected Files\';


for j=1:num_files
    correct_filenames{j} = [tiffPath '\' sprintf('%s_%.3d_%s.tif',...
        mouse_name,j+nameOffset,slice_name)];
    apply_filenames{j} = [tiffPath '\' sprintf('%s_%.3d_%s.tif',...
        mouse_name,j+nameOffset,slice_name)];
end

%% Do Not Change This: Initialize File Variables
cd(filepath),
MovFile = matfile([movie_file '.mat'],'Writable',true);
MovFile.movie_mask = [];
MovFile.acqFrames=[];
MovFile.cated_xShift = [];
MovFile.cated_yShift = [];
MovFile.acqRef = zeros(0,0,0,'single');
MovFile.correct_filenames = correct_filenames;
MovFile.apply_filenames = apply_filenames;
MovFile.segPos = [];