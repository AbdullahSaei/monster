% batchMain
%
% Main batch manager to parallelise the execution of the various instances
%

numUE = 31;
periods = [5, 10, 20, 40, 80, 160];
seeds = 126;%[5, 8, 42, 53, 79];%126 done

for UE = 1:length(numUE)
    for pers = 1:length(periods)
        for seed = 1:length(seeds)
                batchASMSimulation(numUE(UE), periods(pers),seeds(seed));
        end
    end
end

