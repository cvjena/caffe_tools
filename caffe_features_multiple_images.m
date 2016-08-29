function [ features ] = caffe_features_multiple_images( s_filelist, f_mean, net, settings ) 
% function [ features ] = caffe_features_multiple_images( s_filelist, f_mean, net, settings ) 
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
%   settings    -- optional, (default []), struct with following possible fields
%     .s_layer     -- optional (default: 'relu7'), string, specifies the layer used for feature exatraction
%     .b_apply_bilinear_pooling
%                  -- optional (default: false),
%     .b_skip_normalization_in_bilinear_pooling
%                  -- optional (default: false),
%     .b_apply_log_M
%                  -- optional (default: false),
%     .f_sigma     -- optional (default: 1e-5),
%     .s_filename_prefix
%                  -- optional (default: ''), if not empty, this string
%                  will be appended to the filenames given in the filelist
%                  (useful if list contains only relative filenames)
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
    %
    s_filename_prefix        = getFieldWithDefault ( settings, 's_filename_prefix',        '');
    
    %% prepare list of filenames
    b_filelistmode = ischar( s_filelist );
     
    if (b_filelistmode)
        % load the file list
        fid                = fopen( s_filelist );
        s_filelist_to_use  = textscan(fid,'%s');
        s_filelist_to_use  = s_filelist_to_use{1};
        fclose(fid);
        
        if ( ~isempty( s_filename_prefix ) )
            s_filelist_to_use = strcat( s_filename_prefix, s_filelist_to_use );
%             s_filelist_to_use = cellfun(@(c)[s_filename_prefix, c],s_filelist_to_use, 'uni', false );
        end
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
        
        %% optional: bilinear pooling
        if ( b_apply_bilinear_pooling )    
            %% efficient version: reshape and sum
            %
            % compute outer product with sum pooling
            % this is consistent with the matlab code of liu et al. iccv 2015
            for i_img = 1:i_batch_size
                
                if ( i_batch_size ==1 )
                    b_has_spatial_support = ( ndims ( tmp_feat ) == 3 );
                else
                    b_has_spatial_support = ( ndims ( tmp_feat ) == 4 );
                end
                
                if ( b_has_spatial_support )
                    i_channelCount = size ( tmp_feat, 3);   
                    % reshape with [] automatically resizes to correct number of examples,
                    % this is equivalent to ...size(features,1)*size(features,2),size(features,3) );                    
                    featImg = reshape ( tmp_feat(:,:,:,i_img), [],i_channelCount );% size(features,1)*size(features,2),size(features,3) , 'forder');
                    
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
                        featImg = bsxfun(@times, featImg, 1./( max( 10e-8, sqrt(sum(featImg,2).^2) ) )      ); 
                    end
                    % compute outer product
                    featImg = featImg'*featImg;
                else
                    featImg = tmp_feat(:,i_img)*tmp_feat(:,i_img)';
                end                    

                if ( b_apply_log_M )
                    %channel_count = size(b(ismember(b_struct(3,:)',layer_image)).data,3);
                    %selection_matrix = logical(tril(ones(channel_count)));            
                    %
                    %features = logm(features'*features+1e-5*eye(channel_count));

                    featImg = logm( featImg + f_sigma*eye( size(featImg) ) );
                end

                % take lower tri-angle only to remove redundant information
                % -> logical automatically reshapes into vector
                featImg = featImg ( logical(tril(ones(size(featImg)))));     

                % pass through signed square root step  (see Lin et al 2015 ICCV)
                featImg = sign(featImg).*sqrt(abs(featImg));

                % apply L2 normalization (see Lin et al 2015 ICCV)
                featImg = featImg / sqrt(sum(featImg.^2));    
                
                % allocate enough space in first run       
                if ( ~exist('features','var') )
                    features = zeros( size(featImg,1), size(s_filelist_to_use,1), 'single');
                end  
                
                % store computed feature accordingly
                features( :, slices(i)+i_img-1 ) = featImg; 
            end
        else
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
        
       

    end
    
    % convert output to double precision
    features = double(features);
end

