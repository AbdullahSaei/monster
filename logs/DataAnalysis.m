%% APIs
close all
clearvars 
clc 

resultsPath = './';
expName = 'ASM_';
simulationRounds = 100;

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
clearvars -except listing simulationRounds

EnbSectors = 3;
combinedResults = struct(...
    'periodicity', 0, ...
    'numUsers', 0, ...
    'power', 0, ...
    'throughput', zeros(length(listing), simulationRounds, EnbSectors), ...
    'harqRtx', zeros(length(listing), simulationRounds, EnbSectors));

for iFile = 1:length(listing)
    load(listing(iFile).name);
    combinedResults.periodicity(iFile) = Simulation.Config.ASM.Periodicity;
    combinedResults.numUsers(iFile) = length(Simulation.Users);
    combinedResults.power(iFile) = sum(mean(Simulation.Results.powerConsumed));
    combinedResults.harqRtx(iFile, :, :) = Simulation.Results.harqRtx;
    %combinedResults.throughput(iFile, :, :) = Simulation.Results.throughput;
    if iFile == length(listing)
        % In the last iteration, save also the users and the eNodeB
        users = Simulation.Users;
        eNodeB = Simulation.Cells;
    end
    clear Simulation;
end
clearvars -except combinedResults
%{
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
%}