function [ features ] = caffe_features_single_image( i_image, f_mean, net, s_layer)
% function [ features ] = caffe_features_single_image( i_image, f_mean, net, s_layer)
% 
%  BRIEF:
%   Run a forward pass of a given net on a single image and grep features of a specified layer
%   Requires Caffe version from 17-07-2015 (hash: 6d92d8fcfe0eea9495ffbc)
% 
%  INPUT
%   i_image     -- 2d or 3d matrix
%   f_mean      -- The average image of your dataset. This should be the same that was used during training of the CNN model.
%                  Required to be cropped to the input size of your
%                  network! See caffe_load_network.m
%   net         -- a previously loaded network, see caffe_load_network.m
%   s_layer     -- optional (default: 'relu7'), string, specifies the layer used for feature exatraction
%

    %% parse inputs
    if (nargin<2)
        error ( 'no mean passed');
    end
    if (nargin<3)
        error ( 'no network passed');
    end
    if (nargin<4)
        s_layer = 'relu7';
    end    
    


    %% old caffe layout
%     % prepare image for caffe format
%     batch_data          = zeros(i_width,i_width,3,1,'single');
%     batch_data(:,:,:,1) = caffe_prepare_image(i_image,f_mean,i_width);
%     batch_data          = repmat(batch_data, [1,1,1, batch_size] );
%     
% 
%     %% grep output and adjust desired format
%     features = caffe_('get_features',{batch_data},layer);
%     features = reshape(features{1},size(features{1},1)*size(features{1},2)*size(features{1},3),size(features{1},4))';
%     
%     features = double(features(1,:)');

    %% new caffe layout
    % scale, permute dimensions, subtract mean
    data         = caffe_prepare_image( i_image, f_mean );
    
    % check that network was prepared to work on single images
    tmp_netshape = net.blobs('prob').shape;
    assert (  tmp_netshape(2) == 1, 'network not reshaped for passing only a single image' );
    
    % run a single forward pass
    [~] = net.forward({data});    
    
    % fetch activations from specified layer
    features = net.blobs( s_layer ).get_data();
    
    % vectorize and concatenate activation maps
    features = reshape( features, ...
                        size(features,1)*size(features,2)*size(features,3), ...
                        size(features,4)...
                      );
    
    % convert output to double precision
    features = double(features);
end

