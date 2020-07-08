%% APIs
close all
clearvars 
clc 

resultsPath = './';
expName = 'Seed_';
simulationRounds = 100;

%% Opening files
%**Validating the inputs**********************%
listing = dir([resultsPath '**/*' expName '*.mat']);
if length(listing)<= 0
    disp('No such experiments in this directory.. please recheck the name or the directory');
    return;
end

%removing duplicated files
listing = listing(startsWith({listing.name},expName));
[~,ii] = unique({listing.name},'stable');
listing = listing(ii);
%Sorting
% extract the numbers
filenum = cellfun(@(x)sscanf(x,strcat(expName,'%d','*.mat')), {listing.name});
[G,Seeds] = findgroups(filenum);

%**printing preliminary results*****%
fprintf('Number of Experiments found with name %s = %d :- \n',expName(1:end-1),length(listing));
fprintf('Number of Seeds = %d :- \n',length(Seeds));

%% Extracting Data
 
clearvars -except listing simulationRounds expName G Seeds

EnbSectors = 3;

for s = 1:length(Seeds)
    fprintf('Seed %d has',Seeds(s));
    %initialization
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
    dataIn = find(G==s);
    fprintf(' %d files: ',length(dataIn));
    for iFile = 1:length(dataIn)
        fprintf('1');
        load(listing(dataIn(iFile)).name);
        res(iFile).periodicity  = Simulation.Config.ASM.Periodicity;
        res(iFile).numUsers     = length(Simulation.Users);
        res(iFile).power        = sum(mean(Simulation.Results.powerConsumed));
        res(iFile).UserRequests = Simulation.Results.util;
        res(iFile).asmUtil      = Simulation.Results.ASMUtilisation;
        res(iFile).asmStates    = Simulation.Results.ASMState;

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
    end
    fprintf(' Done ');
    res = SortArrayofStruct(res, 'numUsers');
    res = SortArrayofStruct(res, 'periodicity');
    %store data
    MATFile = strcat('Rfseed_',num2str(Seeds(s)), '.mat');
    save(MATFile,'res');
    fprintf(' Completed\n');
end


%{
%  test
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
    
    
    %res(iFile).power = calculatePowerEnB(res(iFile).UserRequests,...
    %    res(iFile).asmStates, Simulation.Cells(1, 1).Pactive,...
    %    Simulation.Cells(1, 1).Pidle, Simulation.Cells(1, 1).Psm);

end
%}
    
%% Functions

function [delay, service]= calculateDelay(req, serve)
   service = serve;
   delay = zeros(size(service));
   for i = 1:numel(req)
       if req(i) > 0
          for j = i:numel(serve(i:end))             
             if  req(i) - serve(j) <=0
                 serve(j) = serve(j) - req(i);
                 break;
             else
                 req(i) = req(i) - serve(j);
                 delay(i) = delay(i) + 1; 
             end
          end
       end
   end
   delay(delay == 0) = [];
   req(req==0) = [];
   if sum(sum(req)) == sum(sum(service))
       delay = [delay zeros(1,(length(req)-length(delay)))];
   else %buffer needs to flush
      stillinBuff = nnz(req)-length(delay);
      delay = stillinBuff;
      %delay = [zeros(1,stillinBuff) delay(1)*ones(1,length(delay))];
   end
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