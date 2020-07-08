DelayCI = zeros(max(G), 3);

for s = 1:max(G)
    delay = [vals(G==s).delay];
    delay(delay==0) = [];
    DelayCI(s,:) = getCI(delay);
end
DelayCI(isnan(DelayCI))=0;

periods = unique(iPer,'stable');
usrs = unique(iUE,'stable');
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



  
    %buffer effect on power consumption
    figure(3)
    clf
    periods = [5, 10, 80, 160];
    for per = 1:length(periods)
        subplot(2,2,per);
        for pw = 1:2
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
        lgd1 = legend(["No ASM","Using ASM"]);
        legend('boxoff')
        title(['Periodicity ' num2str(periods(per)) ' ms']);
        xlabel('Traffic Load [num of users]');
        xticks(usrs);
        ylabel('Mean Power Consumption [W]');
        axis tight
        grid on;
    end
    sgtitle({'Power Consumption W/ and W/O ASM';['Seed = ' num2str(Results(s).Seed)]},'FontSize', 20);

function CI = getCI(data)                      % Create Data
    SEM = std(data)/sqrt(length(data));               % Standard Error
    ts  = tinv([0.025  0.975],length(data)-1);      % T-Score
    avg = mean(data);
    CI  = avg + ts*SEM;                      % Confidence Intervals
    neg = avg - CI(1);
    pos = CI(2) - avg;
    CI = [avg neg pos];
end

%change marker symbol when plotting the graphs%
function marker = getMarker(i)
markers = {'+','o','*','.','x','s','d','^','v','>','<','p','h'};
marker = markers{mod(i,numel(markers))+1};
end