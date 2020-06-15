close all

% Disable cast to struct warnings
w = warning ('off','all');

%% Get configuration
Config = MonsterConfig(); % Get template config parameters

Config.Logs.logToFile = 0; % 0 only console | 1 only file | 2 both
Config.SimulationPlot.runtimePlot = 0; 
Config.Runtime.simulationRounds = 14; % each round TTI (subframe 1 ms)

%ASM parameters:
Config.ASM.Periodicity = 4000;
Config.Ue.number = 9;
Config.Scenario = strcat('ASM_p',num2str(Config.ASM.Periodicity),'u',num2str(Config.Ue.number),'_');


%ASM paper duplication
Config.MacroEnb.sitesNumber = 1;
Config.MacroEnb.cellsPerSite = 3;
Config.MacroEnb.numPRBs = 100; %50 corresponds to a bandwidth of 10MHz
Config.MacroEnb.height = 30;
Config.MacroEnb.positioning = 'centre';
Config.MacroEnb.ISD = 500; %intersite distance in meters
Config.MacroEnb.Pmax = 10^(46/10)/1e3; %46dBm converted to W ~ 40W

%Thermal noise = -174dBm/Hz
Config.MacroEnb.noiseFigure = 5; %dB
Config.Ue.noiseFigure = 7; %dB
Config.MacroEnb.antennaGain = 8; % dBi
Config.Ue.antennaGain = 0; %dBi

%Ue Transmit power in dBm = 23. 
%Percentage of high loss and low loss: 20/80 (high/low)

%off all other BS
Config.MicroEnb.sitesNumber = 0;

%Number of antenna elements per TRxP: up to 256 Tx/Rx
%Number of Ue antenna element: Up to 8 Tx/Rx
%Device deployment: 80/20 (indoor/outdoor - in car)
%Mobility modelling: Fixed and idential speed v of all UEs, random direction
%UE speed: indoor: 3km/h    outdoor: 30km/h (in car)
Config.Mobility.scenario = 'pedestrian';
Config.Mobility.Velocity = 0;

% Traffic types: fullBuffer | videoStreaming | webBrowsing 
Config.Traffic.primary = 'videoStreaming';
Config.Traffic.mix = 0; %0-> no mix, only primary

%Simulation bandwidth: 20 MHz for TDD, 10 MHz+10 MHz for FDD

Logger = MonsterLog(Config);
Logger.log('(MAIN) configured simulations and started initialisation', 'NFO');
    
% Setup objects

Logger.log('(MAIN) creating main simulation instance', 'NFO');
Simulation = Monster(Config, Logger);
Simulation.Logger.log('(MAIN) main simulation instance created', 'NFO');

for iRound = 0:(Simulation.Runtime.totalRounds - 1)
    Simulation.setupRound(iRound);
    
	Simulation.Logger.log(sprintf('(MAIN) simulation round %i, time elapsed %f s, time left %f s',...
		Simulation.Runtime.currentRound, Simulation.Runtime.currentTime, ...
		Simulation.Runtime.remainingTime ), 'NFO');	
    
    Simulation.run();
    
	Simulation.Logger.log(sprintf('(MAIN) completed simulation round %i. %i rounds left' ,....
		Simulation.Runtime.currentRound, Simulation.Runtime.remainingRounds), 'NFO');
    
    Simulation.collectResults();
    
	Simulation.Logger.log('(MAIN) collected simulation round results', 'NFO');
    
    Simulation.clean();
    
	if iRound ~= Simulation.Runtime.totalRounds - 1
		Simulation.Logger.log('(MAIN) cleaned parameters for next round', 'NFO');
	else
		Simulation.Logger.log('(MAIN) simulation completed', 'NFO');
        Simulation.exportToMAT(Simulation);
	end
end

