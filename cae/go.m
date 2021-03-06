name = 'road_all_942*1*32_RGB_rdm.mat';
load(['/media/662CD4C02CD48D05/_backup/data/train_data/' name]);
% load('/media/662CD4C02CD48D05/_backup/data/train_data/ZCA_road_all_942*1*32_Gray_rdm.mat');
% train_x = pre_pro(train_x,U,S,avg,epsilon,para);

train_x = align_data(train_x);
% input channels | output channels | kernel size | pool size | noise
cae = cae_setup(3,32,5,2,0); %7 error 7*7 kernel %6 error 5*5 kernel

opts.alpha = 0.03;
opts.numepochs = 16;
opts.batchsize = 32;
opts.shuffle = 1;
cae = cae_train(cae, train_x, opts);
% random select, display
cae_vis(cae,train_x,10);
clear train_x;
save(['/media/662CD4C02CD48D05/_backup/data/train_res/32_5_2_CAE_s_' name]);