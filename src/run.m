clear all;
close all;
clc;

%% User setup

isPlot = true;

sequence = 0;

imageDir = ['dataset' filesep 'sequences' filesep num2str(sequence,'%02d') filesep 'image_0'];
imageExt = '.png';

calibFile = ['dataset' filesep 'sequences' filesep num2str(sequence,'%02d') filesep 'calib.txt'];
cameraID = 0;

codewords = load(['dataset' filesep 'codewords.mat']);
codewords = codewords.codewords;

%% Get feature vocabulary

% if no vocabulary exists
	% Load set of images
	% Create vocabulary
	% Save vocabulary
% else
	% Load vocabulary
% end


%% Setup Global variables

global Map;
Map.mapPoints = [];
	% Contains
	%	1) pose3D
	%	2) viewing direction (average of all viewing directions)
	%	3) Descriptor
	%	4) dmax and dmin, determined by invariance limits of SURF
	% and (I suggest) number of times observed (for viewing direction)
	%
	% Make a function to create new mapPoints

Map.keyFrames = [];
	% Contains
	%	1) Camera pose T_iw: rigid body transformation from world to camera
	%	2) Camera intrinsics: focal length, principal point)
	%	3) All features extracted in that frame, associated with or not to a map point
	%
	% Make a function to create new keyFrames

Map.covisibilityGraph = ourViewSet();
	% An undirected graph where nodes are keyframes and edges are shared
	% observations of map points (at least theta)

Map.spanningTree = []; % Subset of the essential graph that contains edges with high covisability (theta_min)

global State;
State.mu = [0;0;0];
State.Sigma = zeros(length(State.mu));

global Params;
Params.theta = 15; % Number of shared observations a keyframe must have to be considered the same map points
Params.theta_min = 100; % Defines high covisability for spanning tree
Params.keyFramePercentOfBestScoreThreshold = 75; % bag of words returns keyframes that are more than this percentage of the best match
Params.cameraParams = load_camera_params(calibFile, cameraID);
Params.minMatchesForConnection = 50;
% ADD number of features to say we didn't lose localization
% ADD angle threshold between v and n
% ADD scale invariance region - perhaps set from data set

Params.cullingSkip = 25;
Params.cullingThreshold = 0.9;

Params.kdtree = KDTreeSearcher(codewords);
Params.numCodewords = size(codewords, 1);
Params.numFramesApart = 20;

Params.numViewsToLookBack = 5;
Params.minMatchRatioRatio = 0.4;

Params.numSkip = 3;
Params.deletedframes = [];
% Don't know if we'll like it, figured I'd ask - Audrow
global Debug;
Debug.displayFeaturesOnImages = false;


%% Run ORB-SLAM

imagesFiles = dir([imageDir, filesep, '*', imageExt]);
framesToConsider = 1:Params.numSkip:length(imagesFiles);
frames = cell([1 length(framesToConsider)]);
for i = 1:length(framesToConsider)
	frameIdx = framesToConsider(i);
	frames{i} = imread([imagesFiles(frameIdx).folder, filesep, imagesFiles(frameIdx).name]);
end

for i = 1:length(framesToConsider)

	if iscell(frames)
		frame = frames{i};
	else
		frame = frames(i);
	end

	surf_slam(frame,i);

    fprintf('Sequence %02d [%4d/%4d]\n', ...
        sequence, i, length(framesToConsider))
end

save([num2str(sequence, 'data/0412_seq%02d'), ...
    num2str(Params.numSkip, '_skip%d.mat')], 'Map')

%% Display

if isPlot
    camPoses = poses(Map.covisibilityGraph);
	figure
	hold on
	traj = cell2mat(camPoses.Location);
    x = traj(:, 1);
    z = traj(:, 3);
    plot(x, z, 'x-')
    axis equal
	grid on

    %{
	validIdx = sqrt(xyzPoints(:, 1).^2 + xyzPoints(:, 2).^2 + xyzPoints(:, 3).^2) < 100;
	validIdx = validIdx & (xyzPoints(:, 3) > 0);

	pcshow(xyzPoints(validIdx, :), 'VerticalAxis', 'y', 'VerticalAxisDir', 'down', ...
		'MarkerSize', 45);
    %}

    %validIdx = sqrt(xyzPoints(:, 1).^2 + xyzPoints(:, 2).^2 + xyzPoints(:, 3).^2) < 500;
    %scatter(xyzPoints(validIdx, 1), xyzPoints(validIdx, 3), '.')
	hold off;
end
