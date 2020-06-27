getCI(delay)

function CI = getCI(data)                      % Create Data
    SEM = std(data)/sqrt(length(data));               % Standard Error
    ts  = tinv([0.025  0.975],length(data)-1);      % T-Score
    avg = mean(data);
    CI  = avg + ts*SEM;                      % Confidence Intervals
    pos = avg - CI(1);
    neg = CI(2) - avg;
    CI = [avg pos neg];
end