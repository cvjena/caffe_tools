function [ features ] = caffe_features_single_image( i_image, f_mean, net, settings ) 
% function [ features ] = caffe_features_single_image( i_image, f_mean, net, settings ) 
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
%   settings    -- optional, (default []), struct with following possible fields
%     .s_layer     -- optional (default: 'relu7'), string, specifies the layer used for feature exatraction
%     .b_apply_bilinear_pooling
%                  -- optional (default: false),
%     .b_skip_normalization_in_bilinear_pooling
%                  -- optional (default: false),
%     .b_apply_log_M
%                  -- optional (default: false),
%     .f_sigma     -- optional (default: 1e-5),
%

    %% parse inputs
    if (nargin<2)
        error ( 'no mean passed');
    end
    if (nargin<3)
        error ( 'no network passed');
    end
    if (nargin<4)
        settings = [];
    end    
    
    
    s_layer                  = getFieldWithDefault ( settings, 's_layer',                  'relu7');
    b_apply_bilinear_pooling = getFieldWithDefault ( settings, 'b_apply_bilinear_pooling', false );
    b_skip_normalization_in_bilinear_pooling ...
                             = getFieldWithDefault ( settings, 'b_skip_normalization_in_bilinear_pooling', false );
    b_apply_log_M            = getFieldWithDefault ( settings, 'b_apply_log_M',            false );
    f_sigma                  = getFieldWithDefault ( settings, 'f_sigma',                  1e-5 );
    

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
    data             = caffe_prepare_image( i_image, f_mean );
    
    % check that network was prepared to work on single images
    net_input_shape  = net.blobs('data').shape;    
    i_batch_size     = net_input_shape(4);
    
    assert (  i_batch_size == 1, 'network not reshaped for passing only a single image' );
    
    % run a single forward pass
    [~] = net.forward({data});    
    
    % fetch activations from specified layer
    features = net.blobs( s_layer ).get_data();
    
    %% optional: bilinear pooling
    if ( b_apply_bilinear_pooling )
               
        %% efficient version: reshape and sum
        %
        % compute outer product with sum pooling
        % this is consistent with the matlab code of liu et al. iccv 2015
        if ( ndims ( features ) == 3 )
            i_channelCount = size ( features, 3);            
            % reshape with [] automatically resizes to correct number of examples,
            % this is equivalent to ...size(features,1)*size(features,2),size(features,3) );
            features  = reshape ( features, [],i_channelCount);
            
            % response normalization to increase comparability of features 
            % this improves the condition of the bilinear matrix 
            %
            if ( ~b_skip_normalization_in_bilinear_pooling )
                %this equals 1/abs(sum(features,2))...         
                %
                % note: the max... is just for security reasons to
                % prevent division by zero in case that *all*
                % values should be zero or the signed sum equals zero
                %
                features = bsxfun(@times, features, 1./( max( 10e-8, sqrt(sum(features,2).^2) ) )      );                 
            end
            % compute outer product
            features = features'*features;
        else
            features = features / sqrt(sum(features)^2); 
            features = features*features';
        end                    
                    

        if ( b_apply_log_M )
            features = logm( features + f_sigma*eye( size(features) ) );
        end
        
        % take lower tri-angle only to remove redundant information
        % -> logical automatically reshapes into vector
        features     = features ( logical(tril(ones(size(features)))));     
        
        % pass through signed square root step  (see Lin et al 2015 ICCV)
        features     = sign(features).*sqrt(abs(features));
        
        % apply L2 normalization (see Lin et al 2015 ICCV)
        features     = features / sqrt(sum(features.^2));
        
        

    else
        % vectorize and concatenate activation maps
        features = reshape( features, ...
                            size(features,1)*size(features,2)*size(features,3), ...
                            size(features,4)...
                          );        
    end
    

    
    % convert output to double precision
    features = double(features);
end

