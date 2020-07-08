%% APIs
close all
clearvars 
clc 

resultsPath = './';
expName = 'Rvseed_';
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

%% Extracting Data
 
clearvars -except listing simulationRounds expName
Results = struct(...
    'Seed', zeros(1, length(listing)),...
    'res', struct());
for r = 1:length(listing)
    fprintf('Experiment %d progress \n',r);
    Results(r).Seed = str2double(extractBetween(listing(r).name,'_','.'));
    temp = load(listing(r).name);
    Results(r).res = temp.res;
end

%% Plotting
close all
clearvars -except Results

%divide values to groups
vals = [Results.res];
[G, iPer, iUE] = findgroups([vals.periodicity],[vals.numUsers]);

%Prepare data for plotting
DelayCI = zeros(max(G), 3);
PowerCI = zeros(max(G), 3);
PWCrfCI = zeros(max(G), 3);
for s = 1:max(G)
    %prepare power
    pw = [vals(G==s).power];
    PowerCI(s,:) = getCI(pw);
    %power reference
    pwrf = [vals(G==s).calcPower];
    PWCrfCI(s,:) = getCI(pwrf); 
    %perpare delay
    delay = [vals(G==s).delay];
    delay(delay==0) = [];
    DelayCI(s,:) = getCI(delay);
end
DelayCI(isnan(DelayCI))=0;


periods = unique(iPer,'stable');
usrs = unique(iUE,'stable');

%Plot Delay
figure(1)
clf
for p= 1:length(periods)
    delay = DelayCI(periods(p)==iPer,:);
    %plot(usrs,delay(:,1),'LineWidth',2)
    hold on
    errorbar(usrs,delay(:,1),delay(:,2),delay(:,3),'LineWidth',1.5)
end
xlim auto;
ylim auto;
lgd1 = legend(string(periods),'location', 'northeastoutside');
title(lgd1,'Periodicity');
xlabel('Traffic Load [num of users]','FontSize', 20);
xticks(usrs);
ylabel('Avg Time Delay in [msec]','FontSize', 20);
axis tight
title('Delay for different Periodicity','FontSize', 20);
grid on;

%Plot power
figure(2)
clf
for p= 1:length(periods)
    pw = PowerCI(periods(p)==iPer,:);
    pwc = PWCrfCI(periods(p)==iPer,:);
    %plot(usrs,delay(:,1),'LineWidth',2)
    hold on
    errorbar(usrs,pw(:,1),pw(:,2),pw(:,3),'LineWidth',1.5)
end
%errorbar(usrs,pwc(:,1),pwc(:,2),pwc(:,3),'LineWidth',1.5)
lgd1 = legend(string(periods),'location', 'northeastoutside');
    title(lgd1,'Periodicity');
    xlabel('Traffic Load [num of users]','FontSize', 20);
    xticks(usrs);
    ylabel('Mean Power Consumption [W]','FontSize', 20);
    axis tight
    title('Power Consumption for different Periodicity','FontSize', 20);
    grid on;
    
%Print Summary    
for s = 1:length(Results)
    fprintf('\\multicolumn{3}{c}{Summary of Seed %d}\\\\\n',Results(s).Seed);
    res = Results(s).res;
    periods = unique([Results(s).res.periodicity],'stable');
    usrs= unique([Results(s).res.numUsers],'stable');

    for per = 1:length(periods)
        pw = sort([res([res.periodicity]==periods(per)).power]);
        pwrf = sort([res([res.periodicity]==periods(per)).calcPower]);
        printSummary(pw, pwrf, usrs,periods(per));
        hold on;
        %plot(usrs,pw,'LineWidth',2);
        %hold on
        %errorbar(usrs,[vals(G==counter(2)).power])
        %xlim auto;
        %ylim auto;
    end
    fprintf('\\hline\n');
end

%% Functions
%Confidence Interval calculation
function CI = getCI(data)                      % Create Data
    SEM = std(data)/sqrt(length(data));               % Standard Error
    ts  = tinv([0.025  0.975],length(data)-1);      % T-Score
    avg = mean(data);
    CI  = avg + ts*SEM;                      % Confidence Intervals
    neg = avg - CI(1);
    pos = CI(2) - avg;
    CI = [avg neg pos];
end

%print summary of the results
function printSummary(pwc, pwrf, ~,per)
    low = 100*(pwrf(1)-pwc(1))/pwrf(1);
    high = 100*(pwrf(end)-pwc(end))/pwrf(end);
    fprintf('%d & %2.2f\\%% & %2.2f\\%%\\\\\n',per,low,high);
end

%change marker symbol when plotting the graphs%
function marker = getMarker(i)
markers = {'+','o','*','.','x','s','d','^','v','>','<','p','h'};
marker = markers{mod(i,numel(markers))+1};
end