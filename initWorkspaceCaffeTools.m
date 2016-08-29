function initWorkspaceCaffeTools
% function initWorkspaceCaffeTools
% 
% Author: Alexander Freytag
% 
% BRIEF:
%   Add local subfolders and 3rd party libraries to Matlabs work space.
%   NEEDS TO BE ADAPTED TO YOUR SYSTEM!
% 
% 
%   Exemplary call from external position:
%        CAFFETOOLDIR   = '/place/to/this/repository/';
%        currentDir = pwd;
%        cd ( CAFFETOOLDIR );
%        initWorkspaceCaffeTools;
%        cd ( currentDir );
% 
%   Provides s_path_to_caffe as global variable.
% 
%   Author: Alexander Freytag

    %% setup paths of 3rd-party libraries in a user-specific manner

    
    CAFFEDIR            = [];

        
    if strcmp( getenv('USER'), 'freytag')     
        [~, s_hostname]       = system( 'hostname' );
        s_hostname            = s_hostname ( 1:(length(s_hostname)-1) ) ;    
        
        s_dest_caffebuild     = sprintf( '/home/freytag/lib/caffe_%s/matlab/', s_hostname );  
        CAFFEDIR              = s_dest_caffebuild;       

        CAFFEDIR              = '/home/freytag/lib/caffe_pollux_2016_08_23/matlab/';

    elseif strcmp( getenv('USER'), 'rodner')
        [~, s_hostname]       = system( 'hostname' );
        s_hostname            = 'pollux';%s_hostname ( 1:(length(s_hostname)-1) ) ;

        s_dest_caffebuild     = sprintf( '/home/freytag/lib/caffe_%s/matlab/', s_hostname );
        CAFFEDIR              = s_dest_caffebuild;
    elseif strcmp( getenv('USER'), 'simon')     
        [~, s_hostname]       = system( 'hostname' );
        s_hostname            = s_hostname ( 1:(length(s_hostname)-1) ) ;         
                        
        s_dest_caffebuild     = sprintf( '/home/freytag/lib/caffe_%s/matlab/', s_hostname );    
        CAFFEDIR              = '/home/simon/Research/lib/caffe.current/matlab/';%s_dest_caffebuild;
    elseif strcmp( getenv('USER'), 'alex') 
        CAFFEDIR              = '/home/alex/lib/caffe/matlab/';
    else          
        fprintf('Unknown user %s and unknown default settings', getenv('USER') ); 
    end
    
    %% make path to caffe known as global variable
    global s_path_to_caffe;
    s_path_to_caffe     = CAFFEDIR;      

    %% add paths which come with this repository
    
    %%
    % add main path
    b_recursive = false; 
    b_overwrite = true;
    s_pathMain  = fullfile(pwd);
    addPathSafely ( s_pathMain, b_recursive, b_overwrite )
    clear ( 's_pathMain' );

        
    
    %% 3rd party, untouched   
    
    
    if ( isempty(CAFFEDIR) )
        fprintf('initWorkspaceCaffeTools-WARNING - no CAFFEDIR dir found on your machine. Code is available at http://caffe.berkeleyvision.org/installation.html \n');
    else
        b_recursive             = true; 
        b_overwrite             = true;
        addPathSafely ( CAFFEDIR, b_recursive, b_overwrite );        
    end      
        
    %% clean up    
    clear( 'CAFFEDIR' );    
        
end


function addPathSafely ( s_path, b_recursive, b_overwrite )
    if ( ~isempty(strfind(path, [s_path , pathsep])) )
        if ( b_overwrite )
            if ( b_recursive )
                rmpath( genpath( s_path ) );
            else
                rmpath( s_path );
            end
        else
            fprintf('initWorkspaceCaffeTools - %s already in your path but overwriting de-activated.\n', s_path);
            return;
        end
    end
    
    if ( b_recursive )
        addpath( genpath( s_path ) );
    else
        addpath( s_path );
    end
end
