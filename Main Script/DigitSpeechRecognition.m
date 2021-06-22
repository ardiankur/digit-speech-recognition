url = 'https://ssd.mathworks.com/supportfiles/audio/google_speech.zip';
downloadFolder = tempdir;
datasetFolder = fullfile(downloadFolder,'google_speech');

if ~exist(datasetFolder,'dir')
    disp('Downloading data set (1.4 GB) ...')
    unzip(url,downloadFolder)
end

ads = audioDatastore(datasetFolder, ...
    'IncludeSubfolders',true, ...
    'FileExtensions','.wav', ...
    'LabelSource','foldernames');

%% Choose Words to Recognize

commands = categorical(["zero","one","two","three","four","five","six","seven","eight","nine"]);

isCommand = ismember(ads.Labels,commands);
adsSubset = subset(ads,isCommand);
countEachLabel(adsSubset);

%% Split Data

c = importdata(fullfile(datasetFolder,'validation_list.txt'));
filesValidation = string(c);

%%
c = importdata(fullfile(datasetFolder,'testing_list.txt'));
filesTest = string(c);

%%
files = adsSubset.Files;
sf = split(files,filesep);
isValidation = ismember(sf(:,end-1) + "/" + sf(:,end),filesValidation);
isTest = ismember(sf(:,end-1) + "/" + sf(:,end),filesTest);

adsValidation = subset(adsSubset,isValidation);
adsTrain = subset(adsSubset,isTest);

%%
reduceDataset = false;
if reduceDataset
    numUniqueLabels = numel(unique(adsTrain.Labels));
    % Reduce the dataset by a factor of 20
    adsTrain = splitEachLabel(adsTrain,round(numel(adsTrain.Files) / numUniqueLabels / 20));
    adsValidation = splitEachLabel(adsValidation,round(numel(adsValidation.Files) / numUniqueLabels / 20));
end

%% Compute Auditory Spectrograms

fs = 16e3; % Known sample rate of the data set.

segmentDuration = 1;
frameDuration = 0.025;
hopDuration = 0.010;

segmentSamples = round(segmentDuration*fs);
frameSamples = round(frameDuration*fs);
hopSamples = round(hopDuration*fs);
overlapSamples = frameSamples - hopSamples;

FFTLength = 512;
numBands = 50;

afe = audioFeatureExtractor( ...
    'SampleRate',fs, ...
    'FFTLength',FFTLength, ...
    'Window',hann(frameSamples,'periodic'), ...
    'OverlapLength',overlapSamples, ...
    'barkSpectrum',true);
%Merubah nilai default numBands (32) menjadi (50)
setExtractorParams(afe,'barkSpectrum','NumBands',numBands); 

%%
x = read(adsTrain);

numSamples = size(x,1);

numToPadFront = floor( (segmentSamples - numSamples)/2 );
numToPadBack = ceil( (segmentSamples - numSamples)/2 );

xPadded = [zeros(numToPadFront,1,'like',x);x;zeros(numToPadBack,1,'like',x)];

%%
features = extract(afe,xPadded);
[numHops,numFeatures] = size(features);

%%

unNorm = 2/(sum(afe.Window)^2); %Hasil = 5.0000e-05

%%
if ~isempty(ver('parallel')) && ~reduceDataset
    pool = gcp;
    numPar = numpartitions(adsTrain,pool);
else
    numPar = 1;
end

%%

parfor ii = 1:numPar
    subds = partition(adsTrain,numPar,ii);
    XTrain = zeros(numHops,numBands,1,numel(subds.Files));
    for idx = 1:numel(subds.Files)
        x = read(subds);
        xPadded = [zeros(floor((segmentSamples-size(x,1))/2),1);x;zeros(ceil((segmentSamples-size(x,1))/2),1)];
        XTrain(:,:,:,idx) = extract(afe,xPadded);
    end
    XTrainC{ii} = XTrain;
end

%%

XTrain = cat(4,XTrainC{:});

[numHops,numBands,numChannels,numSpec] = size(XTrain);

%%

XTrain = XTrain/unNorm;
epsil = 1e-6;
XTrain = log10(XTrain + epsil);

%%

if ~isempty(ver('parallel'))
    pool = gcp;
    numPar = numpartitions(adsValidation,pool);
else
    numPar = 1;
end
parfor ii = 1:numPar
    subds = partition(adsValidation,numPar,ii);
    XValidation = zeros(numHops,numBands,1,numel(subds.Files));
    for idx = 1:numel(subds.Files)
        x = read(subds);
        xPadded = [zeros(floor((segmentSamples-size(x,1))/2),1);x;zeros(ceil((segmentSamples-size(x,1))/2),1)];
        XValidation(:,:,:,idx) = extract(afe,xPadded);
    end
    XValidationC{ii} = XValidation;
end
XValidation = cat(4,XValidationC{:});
XValidation = XValidation/unNorm;
XValidation = log10(XValidation + epsil);

%%

YTrain = removecats(adsTrain.Labels); 
YValidation = removecats(adsValidation.Labels);

%% Define Neural Network Architecture

classWeights = 1./countcats(YTrain);
classWeights = classWeights'/mean(classWeights);
numClasses = numel(categories(YTrain));

timePoolSize = ceil(numHops/8);

dropoutProb = 0.2;
numF = 12;
layers = [
    imageInputLayer([numHops numBands])
    
    convolution2dLayer(3,numF,'Padding','same')
    batchNormalizationLayer
    reluLayer
    
    maxPooling2dLayer(3,'Stride',2,'Padding','same')
    
    convolution2dLayer(3,2*numF,'Padding','same')
    batchNormalizationLayer
    reluLayer
    
    maxPooling2dLayer(3,'Stride',2,'Padding','same')
    
    convolution2dLayer(3,4*numF,'Padding','same')
    batchNormalizationLayer
    reluLayer
    
    maxPooling2dLayer(3,'Stride',2,'Padding','same')
    
    convolution2dLayer(3,4*numF,'Padding','same')
    batchNormalizationLayer
    reluLayer
    convolution2dLayer(3,4*numF,'Padding','same')
    batchNormalizationLayer
    reluLayer
    
    maxPooling2dLayer([timePoolSize,1])
    
    dropoutLayer(dropoutProb)
    fullyConnectedLayer(numClasses)
    softmaxLayer
    weightedClassificationLayer(classWeights)];

%% Train Network

miniBatchSize = 128;
%validationFrequency = floor(numel(YTrain)/miniBatchSize);
options = trainingOptions('adam', ...
    'InitialLearnRate',0.001, ...
    'MaxEpochs',25, ...
    'MiniBatchSize',miniBatchSize, ...
    'Shuffle','every-epoch', ...
    'Plots','training-progress', ...
    'Verbose',true, ...
    'ValidationData',{XValidation,YValidation}, ...
    'ValidationFrequency',200, ...
    'LearnRateSchedule','piecewise', ...
    'LearnRateDropFactor',0.1, ...
    'LearnRateDropPeriod',20);

%% Evaluate Trained Network

doTraining = true;
if doTraining
    trainedNet = trainNetwork(XTrain,YTrain,layers,options);
    save('MODEL_1.mat','trainedNet');
else
    load('MODEL_12.mat','trainedNet');
end

 YValPred = classify(trainedNet,XValidation);
 validationError = mean(YValPred ~= YValidation);
 YTrainPred = classify(trainedNet,XTrain);
 trainError = mean(YTrainPred ~= YTrain);
 disp("Training error: " + trainError*100 + "%")
 disp("Validation error: " + validationError*100 + "%")

%%

m = confusionmat(YValidation,YValPred);
% save('CM_1.mat','m');

Akurasi = sum(YValPred == YValidation)/numel(YValidation)*100;
precision = diag(m)./sum(m,2);
Precision = mean(precision)*100;
recall = diag(m)./sum(m,1).';
Recall = mean(recall)*100;

set(handles.akurasivalue,'string',Akurasi);
set(handles.precisionvalue,'string',Precision);
set(handles.recallvalue,'string',Recall);

properti = [Akurasi;Precision;Recall];
save('properti_layers.mat','properti')

%%
info = whos('trainedNet');
disp("Network size: " + info.bytes/1024 + " kB")

for i = 1:100
    x = randn([numHops,numBands]);
    tic
    [YPredicted,probs] = classify(trainedNet,x,"ExecutionEnvironment",'cpu');
    time(i) = toc;
end
disp("Single-image prediction time on CPU: " + mean(time(11:end))*1000 + " ms")
