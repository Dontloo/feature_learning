% data_dir = '/home/dontloo/Desktop/re/raw_data/2011_09_26/2011_09_26_drive_0002_sync/image_03/data/';
% data_dir = '/home/dontloo/Desktop/re/raw_data/2011_09_26/2011_09_26_drive_0005_sync/image_03/data/';
data_dir = '/home/dontloo/Desktop/re/raw_data/test_643/';

% output_dir = '/home/dontloo/Desktop/re/data/2011_09_26_drive_0002_mix/';
output_dir = '/home/dontloo/Desktop/re/data/test_643_mix/';

tmp_dir = '/home/dontloo/Desktop/re/tmp/';
all_files = dir(data_dir);
for idx = 3:length(all_files)
    file_name = all_files(idx).name;
    prefix = file_name(1,1:end-4);
    out_name = [prefix '.ppm'];
    tmp = imread([data_dir file_name], 'PNG');
    imwrite(tmp,[tmp_dir out_name]);
    cmd = ['/home/dontloo/Desktop/re/segment/segment 0.8 100 100 ' tmp_dir out_name ' ' output_dir out_name];
    [status,cmdout] = system(cmd);
    delete([tmp_dir '*'])
end

for idx = 3:length(all_files)
    file_name = all_files(idx).name;
    prefix = file_name(1:end-4);
    im = imread([data_dir file_name], 'PNG');
    imwrite(im, [output_dir prefix '.jpg']);
end
