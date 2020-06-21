% batchMain
%
% Main batch manager to parallelise the execution of the various instances
%

numUE = [9 19 29 39];
periods = [10 20 40 80];

parfor UEs = 1:length(numUE)
    for pers = 1:length(periods)
        try
            batchASMSimulation(numUE(UEs), periods(pers), pers);
            %batchSimulation(batchSeeds(iSeed), toggleSweep, folderPath);
        catch ME
            fprintf('(BATCH MAIN) Error in batch for simulation index %i\n', iSeed);
            ME
        end
    end
end