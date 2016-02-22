function [net, mean_data] = caffe_load_network ( s_pathtodeployfile, s_pathtomodel, s_phase, s_meanfile, b_reshape_for_single_image_processing)
% function [net, mean_data] = caffe_load_network ( s_pathtodeployfile, s_pathtomodel, s_phase, s_meanfile, b_reshape_for_single_image_processing)
% 
%  BRIEF 
%   Load a specified network with mean image for train or test. 
%   Requires Caffe version from 17-07-2015 (hash: 6d92d8fcfe0eea9495ffbc)
% 
%  INPUT
%   s_pathtodeployfile     -- string, path to file describing the network's 
%                             architecture, e.g., deploy.prototxt
%   s_pathtomodel          -- string, path to file describing the network's 
%                             learned parameters, e.g. bvlc_reference_caffenet.caffemodel
%   s_phase                -- string, 'test' or 'train'. 'test' will de-activate dropout
%   s_meanfile             -- string, path to file which contains the mean 
%                             image of a dataset, e.g., imagenet_mean.binaryproto
%   b_reshape_for_single_image_processing 
%                           -- bool, true of the network shall
%                              operate on single images instead of image batches


    %% load network
    net = caffe.Net(s_pathtodeployfile, s_pathtomodel, s_phase); % create net and load weights
    
    % for which input sizes has the network been trained?
    i_currentNetInputSize = net.blobs('data').shape;    

    %% reshape network input for batch or single-image processing
    if ( b_reshape_for_single_image_processing )
        %
        % reshape network to run only a single image in a forward pass instead
        % of 10 (for which it was trained)
        net.blobs('data').reshape([i_currentNetInputSize(1) ...
                                   i_currentNetInputSize(2) ...
                                   i_currentNetInputSize(3) ...
                                   1 ...
                                  ]); % reshape blob 'data'
        net.reshape();
    end
    
    %% load mean image and adapt to network input size
    mean_data  = caffe.io.read_mean( s_meanfile );
    % crop center from mean file according to network size
    i_sizeMean = size( mean_data );
    offset_row = floor ( int32( i_sizeMean(1)-i_currentNetInputSize(1) ) / 2 ) + 1;
    offset_col = floor ( int32( i_sizeMean(2)-i_currentNetInputSize(2) ) / 2 ) + 1;
    mean_data  = mean_data( offset_row:offset_row+i_currentNetInputSize(1)-1, ...
                            offset_col:offset_col+i_currentNetInputSize(2)-1, ...
                            : ...
                          );       
end