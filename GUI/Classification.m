function varargout = Classification(varargin)
% CLASSIFICATION MATLAB code for Classification.fig
%      CLASSIFICATION, by itself, creates a new CLASSIFICATION or raises the existing
%      singleton*.
%
%      H = CLASSIFICATION returns the handle to a new CLASSIFICATION or the handle to
%      the existing singleton*.
%
%      CLASSIFICATION('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CLASSIFICATION.M with the given input arguments.
%
%      CLASSIFICATION('Property','Value',...) creates a new CLASSIFICATION or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Classification_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Classification_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Classification

% Last Modified by GUIDE v2.5 02-Sep-2020 01:15:50

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Classification_OpeningFcn, ...
                   'gui_OutputFcn',  @Classification_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Classification is made visible.
function Classification_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Classification (see VARARGIN)

% Choose default command line output for Classification
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Classification wait for user response (see UIRESUME)
% uiwait(handles.figure1);

handles.output = hObject;
ah = axes('unit','normalized','position',[0 0 1 1]);
bg = imread('bg2.jpeg');
imagesc(bg);
set(ah,'handlevisibility','off','visible','off')
uistack(ah,'bottom');
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = Classification_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

dname = uigetdir('C:\Dataset');%pilih directory
set(handles.alamatDirectory,'string',dname); %set directory

function alamatDirectory_Callback(hObject, eventdata, handles)
% hObject    handle to alamatDirectory (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of alamatDirectory as text
%        str2double(get(hObject,'String')) returns contents of alamatDirectory as a double


% --- Executes during object creation, after setting all properties.
function alamatDirectory_CreateFcn(hObject, eventdata, handles)
% hObject    handle to alamatDirectory (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

close
respon = GUI
handles.respon = handles;

% --- Executes on button press in btnRun.
function btnRun_Callback(hObject, eventdata, handles)
% hObject    handle to btnRun (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

datasetFolder = get(handles.alamatDirectory,'string');
ads = audioDatastore(datasetFolder, ...
    'IncludeSubfolders',true, ...
    'FileExtensions','.wav', ...
    'LabelSource','foldernames');
% ads0 = copy(ads);

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

doTraining = false;
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

% figure('Units','normalized','Position',[0.2 0.2 0.5 0.5]);
% cm = confusionchart(YValidation,YValPred);
% cm.Title = 'Confusion Matrix for Validation Data';
% cm.ColumnSummary = 'column-normalized';
% cm.RowSummary = 'row-normalized';
% sortClasses(cm, [commands])

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

function akurasivalue_Callback(hObject, eventdata, handles)
% hObject    handle to akurasivalue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of akurasivalue as text
%        str2double(get(hObject,'String')) returns contents of akurasivalue as a double


% --- Executes during object creation, after setting all properties.
function akurasivalue_CreateFcn(hObject, eventdata, handles)
% hObject    handle to akurasivalue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function precisionvalue_Callback(hObject, eventdata, handles)
% hObject    handle to precisionvalue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of precisionvalue as text
%        str2double(get(hObject,'String')) returns contents of precisionvalue as a double


% --- Executes during object creation, after setting all properties.
function precisionvalue_CreateFcn(hObject, eventdata, handles)
% hObject    handle to precisionvalue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function recallvalue_Callback(hObject, eventdata, handles)
% hObject    handle to recallvalue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of recallvalue as text
%        str2double(get(hObject,'String')) returns contents of recallvalue as a double


% --- Executes during object creation, after setting all properties.
function recallvalue_CreateFcn(hObject, eventdata, handles)
% hObject    handle to recallvalue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
