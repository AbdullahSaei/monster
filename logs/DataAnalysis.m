%% APIs
close all
clearvars 
clc 

resultsPath = './';
expName = 'Report';
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
fprintf('Number of Experiments found with name %s = %d :- \n',expName(1:end-1),length(listing));

if ~strncmpi(expName,'Report',length('Report'))
%% Extracting Data
 
clearvars -except listing simulationRounds expName

EnbSectors = 3;
res = struct(...
    'periodicity', 0, ...
    'numUsers', 0, ...
    'calcPower', 0, ...
    'power', 0, ...
    'buffPower', 0, ...
    'asmStates', zeros(1, simulationRounds, EnbSectors), ...
    'UserRequests', zeros(1, simulationRounds, EnbSectors), ...
    'asmUtil', zeros(1, simulationRounds, EnbSectors),...
    'service', zeros(1, simulationRounds, EnbSectors),...
    'delay',0 ...
    );

for iFile = 1:length(listing)
    fprintf('Experiment %d progress ',iFile);
    load(listing(iFile).name);
    res(iFile).periodicity  = Simulation.Config.ASM.Periodicity;
    res(iFile).numUsers     = length(Simulation.Users);
    res(iFile).power        = sum(mean(Simulation.Results.powerConsumed));
    res(iFile).UserRequests = Simulation.Results.util;
    res(iFile).asmUtil      = Simulation.Results.ASMUtilisation;
    res(iFile).asmStates    = Simulation.Results.ASMState;
    fprintf('is Completed \nPost proccessing ');
    
    %Calculate buffering effect on the power
    res(iFile).buffPower = calculatePowerEnB(res(iFile).asmUtil,...
        res(iFile).asmStates, Simulation.Cells(1, 1).Pactive,...
        Simulation.Cells(1, 1).Pidle, Simulation.Cells(1, 1).Psm);
    
    %Calculate power without ASM
    res(iFile).calcPower = calculatePowerEnB(res(iFile).UserRequests,...
        'No', Simulation.Cells(1, 1).Pactive,...
        Simulation.Cells(1, 1).Pidle, Simulation.Cells(1, 1).Psm);
    
    %Calculate delay of ASM
    [res(iFile).delay, res(iFile).service] = calculateDelay(res(iFile).UserRequests, res(iFile).asmUtil);
    
    fprintf('is Completed \n');
    if iFile ~= length(listing)
        clear Simulation;
    end
end
res = SortArrayofStruct(res, 'numUsers');
res = SortArrayofStruct(res, 'periodicity');



%%  test
for iFile = 1:length(res)
    
    %Calculate delay of ASM
    %res(iFile).calcPower = calculatePowerEnB(res(iFile).UserRequests,...
    %    'No', 250, 109, [1 1 1 1 1]);
    %res(iFile).delay = calculateDelay(res(iFile).UserRequests, res(iFile).asmUtil);
    %[res(iFile).delay, res(iFile).service] = calculateDelay(res(iFile).UserRequests, res(iFile).asmUtil);
    %if length(find(res(iFile).UserRequests))-length(find(res(iFile).service)) ~=0
    %    fprintf('in %d there is %d and %d then %d \n',iFile,length(find(res(iFile).UserRequests)),...
    %        length(find(res(iFile).delay)),(length(find(res(iFile).UserRequests))-length(find(res(iFile).delay))));
    %end
    %res(iFile).buffPower = calculatePowerEnB(res(iFile).UserRequests,...
    %    res(iFile).asmStates, Simulation.Cells(1, 1).Pactive,...
    %    Simulation.Cells(1, 1).Pidle, Simulation.Cells(1, 1).Psm);
    
    
    res(iFile).power = calculatePowerEnB(res(iFile).UserRequests,...
        res(iFile).asmStates, Simulation.Cells(1, 1).Pactive,...
        Simulation.Cells(1, 1).Pidle, Simulation.Cells(1, 1).Psm);

end
else
    load(listing.name);
end
%% Plotting
close all
fprintf('Summary of %s:\n',expName);
clearvars -except res

periods = unique([res.periodicity],'stable');
usrs= unique([res.numUsers],'stable');

%Power consumption for different periodicity
figure(1)
for per = 1:length(periods)
    pw = sort([res([res.periodicity]==periods(per)).power]);
    pwrf = sort([res([res.periodicity]==periods(per)).calcPower]);
    printSummary(pw, pwrf, usrs,periods(per));
    hold on;
    plot(usrs,pw,'LineWidth',2);
    xlim auto;
    ylim auto;
end
fprintf('Done\n');
lgd1 = legend(string(periods),'location', 'northeastoutside');
title(lgd1,'Periodicity');
xlabel('Traffic Load [num of users]','FontSize', 20);
xticks(usrs);
ylabel('Mean Power Consumption [W]','FontSize', 20);
axis tight
title('Power Consumption for different Periodicity','FontSize', 20);
grid on;

%Delay effect for different periodicity
periods = [5 10 40 80 160];
figure(2)
for per = 1:length(periods)
    delay = sort([res([res.periodicity]==periods(per)).delay],'descend');
    ci = getCI(delay);
    hold on
    plot(usrs,delay,'LineWidth',2);
    hold on
    %errorbar(usrs,delay)
    xlim auto;
    ylim auto;
end
lgd1 = legend(string(periods),'location', 'northeastoutside');
title(lgd1,'Periodicity');
xlabel('Traffic Load [num of users]','FontSize', 20);
xticks(usrs);
ylabel('Avg Time Delay in [msec]','FontSize', 20);
axis tight
title('Delay for different Periodicity','FontSize', 20);
grid on;


%buffer effect on power consumption
figure(3)
periods = [5, 10, 80, 160];
for per = 1:length(periods)
    subplot(2,2,per);
    for pw = 1:3
        switch pw
            case 1
                pc = [res([res.periodicity]==periods(per)).calcPower];
            case 2 
                pc = [res([res.periodicity]==periods(per)).power];
            case 3
                pc = [res([res.periodicity]==periods(per)).buffPower];
        end
        hold on;
        plot(usrs,pc,'LineWidth',2);
        xlim auto;
        ylim auto;
    end
    lgd1 = legend(["No ASM","ASM-No Buffer","ASM-Buffer"]);
    legend('boxoff')
    title(['Periodicity ' num2str(periods(per)) ' ms']);
    xlabel('Traffic Load [num of users]');
    xticks(usrs);
    ylabel('Mean Power Consumption [W]');
    axis tight
    grid on;
end
sgtitle('Buffering Effect on Power Consumption');

%% Functions

function [delay, service]= calculateDelay(req, serve)
   service = req - serve;
   delay = zeros(size(service));
   for i = 1:numel(service)
       if service(i) > 0
          temp = service(i);
          for j = i:numel(service(i:end))             
             if  temp + service(j) <=0
                 break;
             else
                 if service(j) < 0
                    temp = temp + service(j);
                 end
                 delay(i) = delay(i) + 1; 
             end
          end
       end
   end
   delay(delay == 0) = [];
   req(req==0) = [];
   delay = [delay zeros(1,(length(req)-length(delay)))];
   delay = mean(delay);
end

function pw = calculatePowerEnB(utils,states, Pactive,Pidle, Psm)
    % Values of power
    powerConsumed = zeros(1,length(states));
    if ischar(states)
        powerConsumed = Pactive*utils/100 + Pidle*((100-utils)/100);
    else
        for len = 1:length(states)
            if states(len) == -1
                powerConsumed(len) = Pidle;
            elseif abs(states(len)) > 0
                powerConsumed(len) = Psm(abs(states(len)));
            else
                powerConsumed(len) = Pactive*utils(len)/100 + Psm(1)*(100-utils(len))/100;
            end
        end
    end
    pw = sum(mean(powerConsumed));
end

function outStructArray = SortArrayofStruct( structArray, fieldName )
    %UNTITLED2 Summary of this function goes here
    %   Detailed explanation goes here
    if ( ~isempty(structArray) &&  ~isempty(structArray))
      [~,I] = sort(arrayfun (@(x) x.(fieldName), structArray)) ;
      outStructArray = structArray(I) ;        
    else 
        disp ('Array of struct is empty');
    end      
end

%Confidence Interval calculation
function CI = getCI(data)                      % Create Data
    SEM = std(data)/sqrt(length(data));               % Standard Error
    ts  = tinv([0.025  0.975],length(data)-1);      % T-Score
    avg = mean(data);
    CI  = avg + ts*SEM;                      % Confidence Intervals
    pos = avg - CI(1);
    neg = CI(2) - avg;
    CI = [avg pos neg];
end

%print summary of the results
function printSummary(pwc, pwrf, usrs,per)
    low = 100*(pwrf(1)-pwc(1))/pwrf(1);
    high = 100*(pwrf(end)-pwc(end))/pwrf(end);
    fprintf('Per= %d: PC at %d UE is = %2.2f%% and at %d UE = %2.2f%%\n',per,usrs(1),low,usrs(end),high);
end

%change marker symbol when plotting the graphs%
function marker = getMarker(i)
markers = {'+','o','*','.','x','s','d','^','v','>','<','p','h'};
marker = markers{mod(i,numel(markers))+1};
end