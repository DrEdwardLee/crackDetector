

clc
clear 
close all;
%% load paths
currentFolder = pwd;
addpath(genpath(currentFolder))
run dipstart.m 

%% Choise a Image for detection 
[filename,pathname]=uigetfile({'*.jpg;*.bmp;*.tif;*.pgm;*.png;*.gif','All Image Files';'*.*','All Files'});
Img = imread([pathname,filename]);
imgPath=strcat(pathname,filename);
disp(['The processing image path is - ',  imgPath ]);
% clear filename pathname imgPath

%% step 1: Percolating the  input Image
if ~isequal(ndims(Img), 2)
    Img = rgb2gray(Img);
end
Img = double(Img);  
  

%% step 1: Preprocessing (including illumination Balance, denoising, downsampling)
% illumination correct
[ Imgcorrected ] = illuminationBalance( Img ); 

% neighboor minimal based denoising and downsampling
if min(size(Img,1), size(Img,2)) < 1000
    adviceSize = 2;
end
if min(size(Img,1), size(Img,2)) > 1000
    adviceSize = 3;
end 
ParamInfor.winSize = adviceSize;   % winSize = 2 or 3, can be good,  without too much resolution
ParamInfor.MapType = 'MinValue';   % ParamInfor.MapType = 'MaxValue';
ParamInfor.verbose = true;
CellMap = preProcessing_GCA(Img, ParamInfor);
ImgCell = uint8(CellMap.minimum);  % ImgCell = uint8(CellMap.maximum);


%% step 2: multi-scale curvilinear enhancement  
Options.sigma1 = [2 7];         Options.sigma1_step = 1;
Options.sigma2 =  1.5;       
Options.k = [0 0.1];         Options.k_step = 0.025;
Options.angle = [0 180];        Options.angle_step = 15;  
OutEnhenced = CurvilinearEnhance( ImgCell, Options );
 
figure,
subplot(2, 2, 1),  imshow(Img,[]),              title('Input Image');
subplot(2, 2, 2),  imshow(Imgcorrected,[]),     title('Illumination Balanced');
subplot(2, 2, 3),  imshow(ImgCell,[]),          title('Denoised & Downsamped');
subplot(2, 2, 4),  imshow(OutEnhenced.A,[]),    title('Curvilinear Response Map');

%% step 3: Graph Extraction 
% seed points selection  
N_size = 5;    
Imgseed = SeedFinding(OutEnhenced, N_size) ;
[x, y] = find( Imgseed==1 ); 
seedList = [x, y];
% geodetic distance transformation and seeded topological watershed transformation
[ ImgGraph, DistanceMap ] = GraphExtract( OutEnhenced, seedList );

figure( ), imshow( ImgCell ,[]); title('overcomplete Graph network'), hold on
[x1, y1] = find( ImgGraph==1 );       EdgeList = [x1, y1];  
plot(EdgeList(:,2), EdgeList(:,1), 'r.', 'MarkerSize', 5);     



%% step 4: Graph network refinement using Path Classify  
% all candidate crack paths's features extract: path saliency & path contrast features
[ PathList, PathSaliency, PathContrast, ImgJunct ] = PathFeatures( OutEnhenced, ImgGraph );

% classify each path using K-means, and remove path whose "path contrast feature"
% small than Tcontrast
Tcontrast = 0.28;
[ CrackPath ] = PathClassify( PathList, PathSaliency, PathContrast, ImgJunct, Tcontrast );

% remove isolated short path---(postprocess)
 
Options.minArea = 15; 
Options.minDist = 25;
CrackPath = RemoveIsolatePath( CrackPath, Options ); 

figure( ), imshow( ImgCell ,[]); title('Crack  network'), hold on
[x1, y1] = find( CrackPath==1 );       EdgeList = [x1, y1];  
plot(EdgeList(:,2), EdgeList(:,1), 'r.', 'MarkerSize', 5);   


%% step 5: iterative path growing to obtain 'pixel-level' cracks
minLength = 10;
neighDist = 15;
Tp = 1.0; 
ImgCrack = IterPathGrowing( uint8(ImgCell), CrackPath, minLength, neighDist, Tp ); 

figure( ), 
imshow( ImgCell ,[]), title('Pixel-level Cracks'), hold on
[x, y] = find( ImgCrack==1 ); pointList = [x, y];
plot(pointList(:,2), pointList(:,1), 'r.', 'MarkerSize', 6); 
 




 