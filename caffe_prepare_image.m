function im_data = caffe_prepare_image( i_img, f_mean )
% function crops_data = caffe_prepare_image( i_img, f_mean )
% 
%  BRIEF:
%   Bring Image into caffe-format for passing it through a deep neural
%   network. Assumes f_mean to be of the size of the network input
%   Based on prepare_image in classification_demo.m
%   Requires Caffe version from 17-07-2015 (hash: 6d92d8fcfe0eea9495ffbc)
%   
% 
    
    %% start processing of input image
    
    % Convert an image returned by Matlab's imread to im_data in caffe's data
    % format: W x H x C with BGR channels
    
    % produce correct ordering of three-channel image
    if (size(i_img,3)==1)
        % adapt gray scale images
        im_data = repmat(i_img,1,1,3);
    else
        % permute channels from RGB to BGR
        im_data = i_img(:, :, [3, 2, 1]);  
    end    
    
    % flip width and height
    im_data    = permute(im_data, [2, 1, 3]);  
    
    % make sure it's single type
    im_data    = single(im_data); % convert from uint8 to single
    
    % resize image to fit the network's input
    i_sizeMean = size( f_mean );
    im_data    = imresize(im_data, [i_sizeMean(1) i_sizeMean(2)], 'bilinear');  % resize im_data
    
    % caffe/matlab/+caffe/imagenet/ilsvrc_2012_mean.mat contains mean_data that
    % is already in W x H x C with BGR channels          
    
    % subtract mean_data (already in W x H x C, BGR)
    im_data = im_data - f_mean;   
    
end
    