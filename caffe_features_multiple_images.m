function [ features ] = caffe_features_multiple_images( s_filelist, f_mean, net, s_layer)
% function [ features ] = caffe_features_multiple_images( s_filelist, f_mean, net, s_layer)
% 
%  BRIEF:
%   Run a forward pass of a given net on a set of images which are 
%   listed in an external file and grep features of a specified layer.
%   Requires Caffe version from 17-07-2015 (hash: 6d92d8fcfe0eea9495ffbc)
% 
%  INPUT
%   s_filelist  -- string, filename to an external list which contains
%                  image names in each line. Alternatively, the variable is
%                  given as cell array where each entry contains a loaded
%                  image.
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
    
    %% prepare list of filenames
    b_filelistmode = ischar( s_filelist );
     
    if (b_filelistmode)
        % load the file list
        fid                = fopen( s_filelist );
        s_filelist_to_use  = textscan(fid,'%s');
        s_filelist_to_use  = s_filelist_to_use{1};
        fclose(fid);
    else
        % use the passed filelist
        s_filelist_to_use  = s_filelist;
    end
    
    %% new caffe layout        
    net_input_shape  = net.blobs('data').shape;    
    i_batch_size     = net_input_shape(4);
    
    % create tmp for batch
    batch_data = {zeros(net_input_shape(1),... %height
                        net_input_shape(2),... %width
                        net_input_shape(3),... %width, ...%RGB
                        i_batch_size,...
                        'single')};
    
    % Calculate the starting indices of every batch
    slices = 1:i_batch_size:size(s_filelist_to_use,1);
    slices(end+1)=size(s_filelist_to_use,1)+1;
    
    % crop the list of files into batches of adequate size 
    % then run over every batch
    for i=1:numel(slices)-1
        
        % debug information for progress
        if ( ( i > 1 ) && ( mod(i,10) == 0 )  )
            fprintf('Running batch number %i of %i\n',i, numel(slices)-1);
        end
        
        % load the images of the next slice
        for j=slices(i):slices(i+1)-1;
            if (b_filelistmode)
                batch_data{1}(:,:,:,j-slices(i)+1) = caffe_prepare_image(imread( s_filelist_to_use{j} ), f_mean );
            else
                batch_data{1}(:,:,:,j-slices(i)+1) = caffe_prepare_image(s_filelist_to_use{j}, f_mean );
            end
        end
        
        % run a single forward pass
        [~] = net.forward( batch_data );
        
        % fetch activations from specified layer
        tmp_feat = net.blobs( s_layer ).get_data();    
        
        % vectorize and concatenate activation maps
        if ( ndims( tmp_feat ) > 2 )
            tmp_feat = reshape( tmp_feat, ...
                                size(tmp_feat,1)*size(tmp_feat,2)*size(tmp_feat,3), ...
                                size(tmp_feat,4)...
                              );    
        end
                      
        % allocate enough space in first run       
        if ( ~exist('features','var') )
            features = zeros( size(tmp_feat,1), size(s_filelist_to_use,1), 'single');
        end
        
        % store computed feature accordingly
        features( :, slices(i):(slices(i+1)-1) ) = tmp_feat( :, 1:(slices(i+1)-slices(i)) );
    end
    
    % convert output to double precision
    features = double(features);
end

