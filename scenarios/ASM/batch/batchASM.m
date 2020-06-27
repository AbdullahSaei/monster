% batchMain
%
% Main batch manager to parallelise the execution of the various instances
%

numUE = [1 11 21];
periods = [5 10 20 40 80 160];
if isempty(gcp('nocreate'))
    cluster = parcluster;
    parpool(cluster);
end

parfor UE = 1:length(numUE)
    for pers = 1:length(periods)
            try
                batchASMSimulation(numUE(UE), periods(pers), pers);
            catch ME
                fprintf('(BATCH MAIN) Error in batch for simulation index %i\n', pers);
                ME
            end
    end
end