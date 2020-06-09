classdef MetricRecorder < matlab.mixin.Copyable
	% This is class is used for defining and recording statistics in the network
	properties
		infoUtilLo;
		infoUtilHi;
		util;
		powerConsumed;
		schedule;
		harqRtx;
		arqRtx;
		powerState;
        ASMState;
		ber;
		snrdB;
		wideBandSinrdB
		worstCaseSinrdB;
		bler;
		wideBandCqi;
		preEvm;
		postEvm;
		throughput;
		receivedPowerdBm;
		rsrqdB;
		rsrpdBm;
		rssidBm;
		Config;
	end
	
	methods
		% Constructor
		function obj = MetricRecorder(Config)
			% Store main config
			obj.Config = Config;
			% Store utilisation thresholds for information
			obj.infoUtilLo = Config.Son.utilLow;
			obj.infoUtilHi = Config.Son.utilHigh;
			% Initialise for eNodeB
			numEnodeBs = Config.MacroEnb.sitesNumber * Config.MacroEnb.cellsPerSite + Config.MicroEnb.sitesNumber * Config.MicroEnb.cellsPerSite;
			obj.util = zeros(Config.Runtime.simulationRounds, numEnodeBs);
			obj.powerConsumed = zeros(Config.Runtime.simulationRounds, numEnodeBs);
			temp(1:Config.Runtime.simulationRounds, numEnodeBs, 1:Config.MacroEnb.numPRBs) = struct('UeId', NaN, 'MCS', NaN, 'ModOrd', NaN);
			obj.schedule = temp;
			if Config.Harq.active
				obj.harqRtx = zeros(Config.Runtime.simulationRounds, numEnodeBs);
				obj.arqRtx = zeros(Config.Runtime.simulationRounds, numEnodeBs);
			end
			obj.powerState = zeros(Config.Runtime.simulationRounds, numEnodeBs);
            obj.ASMState = zeros(Config.Runtime.simulationRounds, numEnodeBs);
			
			% Initialise for UE
			obj.ber = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.snrdB = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.wideBandSinrdB = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.worstCaseSinrdB = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.bler = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.wideBandCqi = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.preEvm = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.postEvm = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.throughput = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.receivedPowerdBm = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.rsrpdBm = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.rssidBm = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
			obj.rsrqdB = zeros(Config.Runtime.simulationRounds, Config.Ue.number);
		end
		
		% eNodeB metrics
		function obj = recordEnbMetrics(obj, Cells, schRound, Config, Logger)
			obj = obj.recordUtil(Cells, schRound);
			obj = obj.recordPower(Cells, schRound, Config.Son.powerScale, Config.Son.utilLow, Logger);
			obj = obj.recordSchedule(Cells, schRound);
			obj = obj.recordPowerState(Cells, schRound);
			if Config.Harq.active
				obj = obj.recordHarqRtx(Cells, schRound);
				obj = obj.recordArqRtx(Cells, schRound);
			end
		end
		
		function obj = recordUtil(obj, Cells, schRound)
			for iCell = 1:length(Cells)
				sch = find([Cells(iCell).Mac.Schedulers.downlink.PRBsActive.UeId] ~= -1);
				utilPercent = 100*find(sch, 1, 'last' )/length(Cells(iCell).Mac.Schedulers.downlink.PRBsActive);
				
				% check utilPercent and change to 0 if null
				if isempty(utilPercent)
					utilPercent = 0;
				end
				
				obj.util(schRound, iCell) = utilPercent;
			end
		end
		
		function obj = recordPower(obj, Cells, schRound, otaPowerScale, utilLo, Logger)
			for iCell = 1:length(Cells)
				if ~isempty(obj.util(schRound, iCell))
                    Cells(iCell).evaluatePowerState(obj.Config, Cells);
					Cells(iCell) = Cells(iCell).calculatePowerIn(obj.util(schRound, iCell)/100, otaPowerScale, utilLo);
					obj.powerConsumed(schRound, iCell) = Cells(iCell).PowerIn;
				else
					Logger.log('(METRICS RECORDER - recordPower) metric cannot be recorded. Please call recordUtil first.','ERR')
				end
			end
		end
		
		function obj = recordSchedule(obj, Cells, schRound)
			for iCell = 1:length(Cells)
				numPrbs = length(Cells(iCell).Mac.Schedulers.downlink.PRBsActive);
				obj.schedule(schRound, iCell, 1:numPrbs) = Cells(iCell).Mac.Schedulers.downlink.PRBsActive;
			end
		end
		
		function obj = recordHarqRtx(obj, Cells, schRound)
			for iCell = 1:length(Cells)
				harqProcs = [Cells(iCell).Mac.HarqTxProcesses.processes];
				obj.harqRtx(schRound, iCell) = sum([harqProcs.rtxCount]);
			end
		end
		
		function obj = recordArqRtx(obj, Cells, schRound)
			for iCell = 1:length(Cells)
				arqProcs = [Cells(iCell).Rlc.ArqTxBuffers.tbBuffer];
				obj.arqRtx(schRound, iCell) = sum([arqProcs.rtxCount]);
			end
		end
		
		function obj = recordPowerState(obj, Cells, schRound)
			for iCell = 1:length(Cells)
                obj.ASMState(schRound, iCell) = Cells(iCell).ASMState;
				obj.powerState(schRound, iCell) = Cells(iCell).PowerState;
			end
        end
		
		% UE metrics
		function obj = recordUeMetrics(obj, Users, schRound, Logger)
			obj = obj.recordBer(Users, schRound);
			obj = obj.recordBler(Users, schRound);
			obj = obj.recordSnr(Users, schRound);
			obj = obj.recordSinr(Users, schRound);
			obj = obj.recordCqi(Users, schRound);
			obj = obj.recordEvm(Users, schRound);
			obj = obj.recordThroughput(Users, schRound);
			obj = obj.recordReceivedPowerdBm(Users, schRound);
			obj = obj.recordRSMeasurements(Users,schRound);
		end
		
		function obj = recordBer(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.Bits) && Users(iUser).Rx.Bits.tot ~= 0
					obj.ber(schRound, iUser) = Users(iUser).Rx.Bits.err/Users(iUser).Rx.Bits.tot;
				else
					obj.ber(schRound, iUser) = NaN;
				end
			end
		end
		
		function obj = recordBler(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.Blocks) && Users(iUser).Rx.Blocks.tot ~= 0
					obj.bler(schRound, iUser) = Users(iUser).Rx.Blocks.err/Users(iUser).Rx.Blocks.tot;
				else
					obj.bler(schRound, iUser) = NaN;
				end
			end
		end
		
		function obj = recordRSMeasurements(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.RSSIdBm)
					obj.rssidBm(schRound, iUser) = Users(iUser).Rx.RSSIdBm;
				end
				if ~isempty(Users(iUser).Rx.RSRPdBm)
					obj.rsrpdBm(schRound, iUser) = Users(iUser).Rx.RSRPdBm;
				end
				if ~isempty(Users(iUser).Rx.RSRQdB)
					obj.rsrqdB(schRound, iUser) = Users(iUser).Rx.RSRQdB;
				end
			end
		end
		
		function obj = recordSnr(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(fieldnames(Users(iUser).Rx.ChannelConditions))
					obj.snrdB(schRound, iUser) = Users(iUser).Rx.ChannelConditions.SNRdB;
				end
			end
		end
		
		function obj = recordSinr(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.SINRdB.wideBand)
					obj.wideBandSinrdB(schRound, iUser) = Users(iUser).Rx.SINRdB.wideBand;
				end
				if ~isempty(fieldnames(Users(iUser).Rx.ChannelConditions))
					obj.worstCaseSinrdB(schRound, iUser) = Users(iUser).Rx.ChannelConditions.SINRdB;
				end
			end
		end
		
		function obj = recordCqi(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.CQI.wideBand)
					obj.wideBandCqi(schRound, iUser) = Users(iUser).Rx.CQI.wideBand;
				end
			end
		end
		
		function obj = recordEvm(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.PreEvm)
					obj.preEvm(schRound, iUser) = Users(iUser).Rx.PreEvm;
				end
				if ~isempty(Users(iUser).Rx.PostEvm)
					obj.postEvm(schRound, iUser) = Users(iUser).Rx.PostEvm;
				end
			end
		end
		
		function obj = recordThroughput(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(Users(iUser).Rx.Bits) && Users(iUser).Rx.Bits.tot ~= 0
					obj.throughput(schRound, iUser) = Users(iUser).Rx.Bits.ok;
				else
					obj.throughput(schRound, iUser) = NaN;
				end
			end
		end
		
		function obj = recordReceivedPowerdBm(obj, Users, schRound)
			for iUser = 1:length(Users)
				if ~isempty(fieldnames(Users(iUser).Rx.ChannelConditions))
					obj.receivedPowerdBm(schRound, iUser) = Users(iUser).Rx.ChannelConditions.RxPwdBm;
				end
			end
        end
		
	end
end