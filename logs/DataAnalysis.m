%% APIs
close all
clc 

resultsPath = './';
expName = 'ASM';
simulationRounds = 14;
numberUsers = 9;

%% Opening files
%**Validating the inputs**********************%
listing = dir([resultsPath '**/*' expName '*.mat']);
if length(listing)<= 0
    disp('No such experiments in this directory.. please recheck the name or the directory');
    return;
end

%removing duplicated files
[~,ii] = unique({listing.name},'stable');
listing = listing(ii);

%**printing preliminary results*****%
fprintf('Number of Experiments found with name %s = %d :- \n',expName,length(listing));


%% Extracting Data
EnbSectors = 3;
combinedResults = struct(...
    'power', zeros(length(listing), simulationRounds, EnbSectors), ...
    'sinr', zeros(length(listing), simulationRounds, numberUsers), ...
    'meanSinr', zeros(length(listing), numberUsers),...
    'rxPower', zeros(length(listing), simulationRounds, numberUsers), ...
    'meanRxPower', zeros(length(listing), numberUsers));

for iFile = 1:length(listing)
    load(listing(iFile).name);
    combinedResults.power(iFile, :,:) = Simulation.Results.powerConsumed;
    combinedResults.sinr(iFile, :, :) = Simulation.Results.wideBandSinrdB;
    combinedResults.meanSinr(iFile, :) = mean(Simulation.Results.wideBandSinrdB, 1);
    combinedResults.rxPower(iFile, :, :) = Simulation.Results.receivedPowerdBm;
    combinedResults.meanRxPower(iFile, :) = mean(Simulation.Results.receivedPowerdBm, 1);
    if iFile == length(listing)
        % In the last iteration, save also the users and the eNodeB
        users = Simulation.Users;
        eNodeB = Simulation.Cells;
    end
    clear Simulation;
end

%% Plotting
seriesColoursHex = {'#C1232B', '#27727B', '#FCCE10'};
seriesColoursRgb = [0.7569 0.1373 0.1686; 0.1529 0.4471 0.4824; 0.9882 0.8078 0.0627];
meanPower = mean(combinedResults.power, 2);
figure
xBar = categorical({'5 W', '20 W', '80 W'});
xBar = reordercats(xBar, {'5 W', '20 W', '80 W'});
barChart = bar(xBar, meanPower);
barChart.FaceColor = 'flat';
barChart.CData = seriesColoursRgb;
drawnow
xlabel('eNodeB max TX power [W]')
ylabel('Average network power consumed [W]')
title('Network power consumption')