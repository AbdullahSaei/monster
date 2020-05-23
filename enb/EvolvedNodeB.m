classdef EvolvedNodeB < matlab.mixin.Copyable
	%   EVOLVED NODE B defines a value class for creating and working with eNodeBs
	properties
		NCellID;
		SiteId;
		MacroCellId;
		DuplexMode;
		Position;
		NDLRB;
		NULRB;
		CellRefP;
		CyclicPrefix;
		CFI;
		DlFreq;
		PHICHDuration;
		Ng;
		TotSubframes;
		OCNG;
		Windowing;
		AssociatedUsers = [];
		Channel;
		NSubframe;
		BsClass;
		PowerState;
		HystCount;
		SwitchCount;
		Pmax;
		P0;
		DeltaP;
		Psleep;
        %ASM parameters
        ASMState;
        Pactive;
        Pidle;
        Psm;
        ASMCount;
        %END
		Tx;
		Rx;
		Mac;
		Rlc;
		Seed;
		PowerIn;
		Utilisation;
		Mimo;
		Logger;
	end
	
	methods
		% Constructor
		function obj = EvolvedNodeB(Config, Logger, CellConfig, cellId, antennaBearing)
			obj.Logger = Logger;
			obj.SiteId = CellConfig.siteId;
			obj.MacroCellId = CellConfig.macroCellId;
			obj.BsClass = CellConfig.class;
			% Set the cell position that corresponds to the site position
			obj.Position = CellConfig.position;
			obj.NCellID = cellId;
			obj.Seed = cellId*Config.Runtime.seed;
			
			switch obj.BsClass
				case 'macro'
					obj.NDLRB = Config.MacroEnb.numPRBs;
					obj.Pmax = Config.MacroEnb.Pmax; % W
					obj.P0 = 130; % W
                    obj.DeltaP = 4.7;
					obj.Psleep = 75; % W
                    %ASM parameters
                    obj.Pactive = 750; % W
                    obj.Pidle = 328; % W
                    obj.Psm   = [157 42.9 28.5 24.3]; % sm1 2 3 4 in (W)
                    %END
					obj.Mimo = generateMimoConfig(Config);
				case 'micro'
					obj.NDLRB = Config.MicroEnb.numPRBs;
					obj.Pmax = Config.MicroEnb.Pmax; % W
					obj.P0 = 56; % W
					obj.DeltaP = 2.6;
					obj.Psleep = 39.0; % W
					obj.Mimo = generateMimoConfig(Config, 'micro');
			end
			obj.NULRB = Config.Ue.numPRBs;
			obj.CellRefP = obj.Mimo.numAntennas;
			obj.CyclicPrefix = 'Normal';
			obj.CFI = 1;
			obj.PHICHDuration = 'Normal';
			obj.Ng = 'Sixth';
			obj.TotSubframes = Config.Runtime.simulationRounds;
			obj.NSubframe = 0;
			obj.OCNG = 'On';
			obj.Windowing = 0;
			obj.DuplexMode = 'FDD';
			obj.PowerState = 1;
            obj.ASMState = 0; %0 for normal, from 1 to 4 for SM#
            obj.ASMCount = 0; % counts idle time in ms
			obj.HystCount = 0;
			obj.SwitchCount = 0;
			obj.DlFreq = Config.Phy.downlinkFrequency;
			if Config.Harq.active
				obj.Mac = struct('HarqTxProcesses', arrayfun(@(x) HarqTx(0, cellId, x, Config), 1:Config.Ue.number));
				obj.Rlc = struct('ArqTxBuffers', arrayfun(@(x) ArqTx(cellId, x), 1:Config.Ue.number));
			end
			obj.Mac.Schedulers = struct();
			obj.Mac.Schedulers.downlink = Scheduler(obj, Logger, Config, obj.NDLRB, 'downlink');
			obj.Mac.Schedulers.uplink = Scheduler(obj, Logger, Config, obj.NULRB, 'uplink');
			obj.Mac.ShouldSchedule = 0;
			obj.Tx = enbTransmitterModule(obj, Config, antennaBearing);
			obj.Rx = enbReceiverModule(obj, Config);
			obj.PowerIn = 0;
			obj.Utilisation = 0;
		end

		function obj = associateUser(obj, User)
			% Add user to list of users associated
			
			CQI = User.Rx.CQI;

			if isempty(obj.AssociatedUsers)
					obj.AssociatedUsers = [struct('UeId', User.NCellID, 'CQI', CQI)];
			else
			% check if user is in the list
			if ismember(User.NCellID, [obj.AssociatedUsers.UeId])
				% If it is, just update CQI
				obj.updateUserCQI(User, CQI);
			else
				% Add user to the list
				obj.AssociatedUsers = [obj.AssociatedUsers struct('UeId', User.NCellID, 'CQI', CQI)];

			end
			end

		end

		function obj = deassociateUser(obj, User)
			% Remove user from list of users
			if isempty(obj.AssociatedUsers)
				obj.Logger.log('No users associated, cannot deassociate','ERR','EvolvedNodeB:DeassociationOfUser');
			end

			if ~ismember(User.NCellID, [obj.AssociatedUsers.UeId])
				obj.Logger.log('No user with that ID associated.','WRN');
			end

			obj.AssociatedUsers([obj.AssociatedUsers.UeId] == User.NCellID) = [];
		end

		function obj = updateUserCQI(obj, User, CQI)
			% Update CQI of user associated
			obj.AssociatedUsers([obj.AssociatedUsers.UeId] == User.NCellID).CQI = CQI;
		end
		
		function s = struct(obj)
			% Overwrites struct on object. Used primarly for lte Library methods of Matlab.
			s = struct();
			s.NDLRB = obj.NDLRB;
			s.CellRefP = obj.CellRefP;
			s.NCellID = obj.NCellID;
			s.NSubframe = obj.NSubframe;
			s.CFI = obj.CFI;
			s.Ng = obj.Ng;
			s.CyclicPrefix = obj.CyclicPrefix;
			s.PHICHDuration = obj.PHICHDuration;
			s.DuplexMode = obj.DuplexMode;
		end
		
		function TxPw = getTransmissionPower(obj)
			% TODO: Move this to TransmitterModule?
			% Function computes transmission power based on NDLRB
			% Return power per subcarrier. (OFDM symbol)
			totalPower = obj.Pmax;
			TxPw = totalPower/(12*obj.NDLRB);
		end
		
		% reset users
		function obj = resetUsers(obj, Config)
			obj.Users(1:Config.Ue.number) = struct('UeId', -1, 'CQI', -1, 'RSSI', -1);
		end
		
		% reset schedule
		function obj = resetScheduleDL(obj)
			obj.Mac.Schedulers.downlink.reset();
		end
		
		function obj = resetScheduleUL(obj)
			obj.Mac.Schedulers.uplink.reset();
		end
		
		function [indPdsch, info] = getPDSCHindicies(obj)
            enbObj = obj;
			enb = struct(obj);
			% get PDSCH indexes
			[indPdsch, info] = ltePDSCHIndices(enb, enbObj.Tx.PDSCH, enbObj.Tx.PDSCH.PRBSet);
		end

		function [minMCS, varargout] = getMCSDL(obj, ue)
			% Get MCS in DL, returns minimum MCS and list of MCS.
			%
			% Returns minimum MCS 
			% Optional: returns list of MCS
			idxUE = obj.getPRBSetDL(ue);
			listMCS = [obj.Mac.Schedulers.downlink.PRBsActive(idxUE).MCS];
			minMCS = min(listMCS);
			varargout{1} = listMCS;
		end
		
		function mod = getModulationDL(obj, ue)
			% Get modulation from lowest MCS given the DL schedule
			%
			% Returns modulation format
			[~, mod, ~] = lteMCS(obj.getMCSDL(ue));
		end
        
		function PRBSet = getPRBSetDL(obj, ue)
			% Return list of PRBs assigned to a specific user
			%
			% Return PRB set of specific user
    	PRBSet = find([obj.Mac.Schedulers.downlink.PRBsActive.UeId] == ue.NCellID);
		end
				
		
		function obj = setupPdsch(obj, Users)
			% setupPdsch
			%
			% :param obj: EvolvedNodeB instance
			% :param Users: UserEquipment instances
			% :returns obj: EvolvedNodeB instance
			%
			
			% Filter the overall list of Users and only take those associated
			% with this eNodeB
			enbUsers = Users(find([Users.ENodeBID] == obj.NCellID));
			for iUser = 1:length(enbUsers)
				ue = enbUsers(iUser);
				% Check for empty codewords
				if ~isempty(ue.Codeword)
					% find all the PRBs assigned to this UE 
					ixPRBs = obj.getPRBSetDL(ue);
					if ~isempty(ixPRBs)
						% get the correct Parameters for this UE
                        
          	% find the most conservative modulation
						mod = obj.getModulationDL(ue);
						
						% get the codeword
						cwd = ue.Codeword;
						
						% setup the PDSCH for this UE with a local copy for mutation
						enb = struct(obj);
						pdsch = obj.Tx.PDSCH;
						pdsch.Modulation = mod;	% conservative modulation choice from above
						pdsch.PRBSet = (ixPRBs - 1).';	% set of assigned PRBs
						
						% Get info and indexes
						[pdschIxs, SymInfo] = ltePDSCHIndices(enb, pdsch, pdsch.PRBSet);
						
						if length(cwd) ~= SymInfo.G
							% In this case seomthing went wrong with the rate maching and in the
							% creation of the codeword, so we need to flag it
							obj.Logger.log('(EVOLVED NODE B - setupPdsch) Something went wrong in the codeword creation and rate matching. Size mismatch','WRN');
						end
						
						% error handling for symbol creation
						try
							sym = ltePDSCH(enb, pdsch, cwd);
						catch ME
							fSpec = '(EVOLVED NODE B - setupPdsch) generation failed for codeword with length %i\n';
							s=sprintf(fSpec, length(cwd));
							obj.Logger.log(s,'WRN')
							sym = [];
						end
						
						SymInfo.symSize = length(sym);
						SymInfo.pdschIxs = pdschIxs;
						SymInfo.PRBSet = pdsch.PRBSet;
						ue.SymbolsInfo = SymInfo;
						
						% Set the symbols into the grid of the eNodeB in the main object to preserve it at function exit
						obj.Tx.setPDSCHGrid(sym, pdschIxs);
					else
						SymInfo = struct();
						SymInfo.symSize = 0;
						SymInfo.pdschIxs = [];
						SymInfo.PRBSet = [];
						ue.SymbolsInfo = SymInfo;
					end
				end
			end
		end
		
		function userIds = getUserIDsScheduledDL(obj)
			userIds = unique([obj.Mac.Schedulers.downlink.ScheduledUsers]);
		end
		
		function userIds = getUserIDsScheduledUL(obj)
			userIds = unique([obj.Mac.Schedulers.uplink.ScheduledUsers]);
		end
		
		function Users = getUsersScheduledUL(obj, Users)
			% Helper function for returning a list of user objects that are scheduled in UL for a given Cell
			%
			% :obj: eNB instance
			%	:Users: Users

			UserIds = obj.getUserIDsScheduledUL();
			Users = Users(ismember([Users.NCellID],UserIds));
		end

		function Users = getUsersScheduledDL(obj, Users)
			% Helper function for returning a list of user objects that are scheduled in DL for a given Cell
			%
			% :obj: eNB instance
			%	:Users: Users

			UserIds = obj.getUserIDsScheduledDL();
			Users = Users(ismember([Users.NCellID],UserIds));
		end
		
		function obj = evaluatePowerState(obj, Config, Cells)
			% evaluatePowerState checks the utilisation of an EvolvedNodeB to evaluate the power state
			%
			% :obj: EvolvedNodeB instance
			% :Config: MonsterConfig instance
			% :Cells: Array<EvolvedNodeB> instances in case neighbours are needed
			%
			
			% overload
			if obj.Utilisation > Config.Son.utilHigh && Config.Son.utilHigh ~= 100
				obj.PowerState = 2;
				obj.HystCount = obj.HystCount + 1;
				if obj.HystCount >= Config.Son.hysteresisTimer/10^-3
					% The overload has exceeded the hysteresis timer, so find an inactive
					% neighbour that is micro to activate
					nboMicroIxs = find([obj.Cells.NCellID] ~= Cells(1).NCellID);
					
					% Loop the neighbours to find an inactive one
					for iNbo = 1:length(nboMicroIxs)
						if nboMicroIxs(iNbo) ~= 0							
							% Check if it can be activated
							if (~isempty(nboIx) && Cells(iNbo).PowerState == 5)
								% in this case change the PowerState of the target neighbour to "boot"
								% and reset the hysteresis and the switching on/off counters
								Cells(nboIx).PowerState = 6;
								Cells(nboIx).HystCount = 0;
								Cells(nboIx).SwitchCount = 0;
								break;
							end
						end
					end
				end
				
				% underload, shutdown, inactive or boot
			elseif obj.Utilisation < Config.Son.utilLow && Config.Son.utilLow ~= 1
				switch obj.PowerState
					case 1
						% eNodeB active and going in underload for the first time
						obj.PowerState = 3;
						obj.HystCount = 1;
					case 3
						% eNodeB already in underload
						obj.HystCount = obj.HystCount + 1;
						if obj.HystCount >= Config.Son.hysteresisTimer/10^-3
							% the underload has exceeded the hysteresis timer, so start switching
							obj.PowerState = 4;
							obj.SwitchCount = 1;
						end
					case 4
						obj.SwitchCount = obj.SwitchCount + 1;
						if obj.SwitchCount >= Config.Son.hysteresisTimer/10^-3
							% the shutdown is completed
							obj.PowerState = 5;
							obj.SwitchCount = 0;
							obj.HystCount = 0;
						end
					case 6
						obj.SwitchCount = obj.SwitchCount + 1;
						if obj.SwitchCount >= Config.Son.switchTimer/10^-3
							% the boot is completed
							obj.PowerState = 1;
							obj.SwitchCount = 0;
							obj.HystCount = 0;
						end
				end
				
				% normal operative range
                % TODO: All the work
            else
				obj.PowerState = 1;
				obj.HystCount = 0;
				obj.SwitchCount = 0;
                
                %ASM active
                if Config.ASM.Enabled 
                    % ASM check active sleeping modes
                    obj = evaluateSleepState(obj, Config);
                end
			end
        end
        
        % ASM Evaluate Advanced Sleeping State
        function obj = evaluateSleepState(obj, Config)
            obj.ASMState = 1; %sm1 is already included in avg DTX
            %DTX provide 5% reduction in average power
            if obj.Utilisation == 0
               obj.ASMCount = obj.ASMCount +1;
               if obj.ASMCount == Config.ASM.tSM2 %sm2
                   obj.ASMState = obj.ASMState +1;
               end
               if obj.ASMCount == Config.ASM.tSM3 %sm3
                   obj.ASMState = obj.ASMState +1;
               end
               if obj.ASMCount == Config.ASM.tSM4 %sm4
                   obj.ASMState = obj.ASMState +1;
               end
            else
               obj.ASMCount = 0;
               obj.ASMState = 0;
               %Check the buffer queue
            end
            % if buffering is enabled
            if Config.ASM.Buffering
                
            end
        end

		function obj = uplinkSchedule(obj, Users)
			if obj.Mac.ShouldSchedule
				obj.Mac.Schedulers.uplink.scheduleUsers(Users);
			elseif ~isempty(obj.AssociatedUsers)
				obj.Logger.log('Could not schedule in uplinkSchedule: no data in associated users queues or cell sleeping','WRN');
			end
		end
	
		
		% used to calculate the power in based on the BS class
		function obj = calculatePowerIn(obj, enbCurrentUtil, otaPowerScale, utilLoThr)
			% The output power over the air depends on the utilisation, if energy saving is enabled
			if utilLoThr > 1
				Pout = obj.Pmax*enbCurrentUtil*otaPowerScale;
			else
				Pout = obj.Pmax;
			end
			
			% Now check power state of the eNodeB
			if obj.PowerState == 1 || obj.PowerState == 2 || obj.PowerState == 3
				% active, overload and underload state
				obj.PowerIn = obj.CellRefP*obj.P0 + obj.DeltaP*Pout;
                
                % ASM if active override power with Psm
                if obj.PowerState == 1
                    if obj.ASMState > 0
                        obj.PowerIn = obj.Psm(obj.ASMState);
                    else
                        obj.PowerIn = obj.Pactive;
                    end
                else
                    obj.PowerIn = obj.Pidle;
                end
			else
				% shutodwn, inactive and boot
				obj.PowerIn = obj.Psleep;
			end
        end
        
		% Reset an eNodeB at the end of a scheduling round
		function obj = reset(obj, nextSchRound)
			% First off, set the number of the next subframe within the frame
			% this is the scheduling round modulo 10 (the frame is 10ms)
			obj.NSubframe = mod(nextSchRound,10);
			
			% Reset the DL schedule
			obj.resetScheduleDL();
			
			% Reset the transmitter
			obj.Tx.reset();
			
			% Reset the receiver
			obj.Rx.reset();
			
		end
		
		function obj = evaluateScheduling(obj, Users)
			% evaluateScheduling sets the Mac.ShouldSchedule flag depending on attached UEs and their queues
			%
			% :obj: EvolvedNodeB instance
			% :Users: Array<UserEquipment> instances
			%
			
			schFlag = false;
			if ~isempty(obj.AssociatedUsers)
				% There are users connected, filter them from the Users list and check the queue
				enbUsers = Users(find([Users.ENodeBID] == obj.NCellID));
				usersQueues = [enbUsers.Queue];
				if any([usersQueues.Size])
					% Now check the power status of the eNodeB
					if ~isempty(find([1, 2, 3] == obj.PowerState, 1))
						% Normal, underload and overload => the eNodeB can schedule
						schFlag = true;
					elseif ~isempty(find([4, 6] == obj.PowerState, 1))
						% The eNodeB is shutting down or booting up => the eNodeB cannot schedule
						schFlag = false;
					elseif enb.PowerState == 5
						% The eNodeB is inactive, but should be restarted
						obj.PowerState = 6;
						obj.SwitchCount = 0;
					end
				end
			end
			
			% Finally, assign the result of the scheduling check to the object property
			obj.Mac.ShouldSchedule = schFlag;
		end
		
		function obj = downlinkSchedule(obj, Users, Config)
			% downlinkSchedule is wrapper method for calling the scheduling function
			%
			% :obj: EvolvedNodeB instance
			% :Users: Array<UserEquipment> instances
			% :Config: MonsterConfig instance
			
			if obj.Mac.ShouldSchedule
				obj.Mac.Schedulers.downlink.scheduleUsers(Users);
				% Check utilisation
				sch = find([obj.Mac.Schedulers.downlink.PRBsActive.UeId] ~= -1);
				obj.Utilisation = 100*find(sch, 1, 'last' )/length([obj.Mac.Schedulers.downlink.PRBsActive]);
				
				if isempty(obj.Utilisation)
					obj.Utilisation = 0;
				end
			elseif length(obj.AssociatedUsers) > 0
				obj.Logger.log('Could not schedule in downlinkSchedule: no data in associated users queues or cell sleeping','WRN');
				obj.Utilisation = 0;
			end
		end
		
		function obj = uplinkReception(obj, Users, timeNow, ChannelEstimator)
			% uplinkReception performs uplink demodulation and decoding
			%
			% :obj: EvolvedNodeB instance
			% :Users: Array<UserEquipment> UEs instances
			% :timeNow: Float current simulation time in seconds
			% :ChannelEstimator: Struct Channel.Estimator property
			%
			
			% If the eNodeB has an empty received waveform, skip it (no UEs associated)
			if isempty(obj.Rx.Waveform)
				obj.Logger.log(sprintf('(EVOLVED NODE B - uplinkReception) eNodeB %i has an empty received waveform', obj.NCellID), 'DBG');
			else				
				enbUsers = obj.getUsersScheduledUL(Users);
				
				% Parse received waveform
				obj.Rx.parseWaveform();
				
				% Demodulate received waveforms
				obj.Rx.demodulateWaveforms(enbUsers);
				
				% Estimate Channel
				obj.Rx.estimateChannels(enbUsers, ChannelEstimator);
				
				% Equalise
				obj.Rx.equaliseSubframes(enbUsers);
				
				% Estimate PUCCH (Main UL control channel) for UEs
				obj.Rx.estimatePucch(obj, enbUsers, timeNow);
				
				% Estimate PUSCH (Main UL control channel) for UEs
				%obj.Rx.estimatePusch(obj, enbUsers, timeNow);
			end
			
			
		end
		
		function obj = uplinkDataDecoding(obj, Users, Config, timeNow)
			% uplinkDataDecoding performs decoding of the demodoulated data in the waveform
			%
			% :param obj: EvolvedNodeB instance
			% :param Users: Array<UserEquipment> UEs instances
			% :param Config: MonsterConfig instance
			
			% Filter UEs linked to this eNodeB
			ueGroup = find([Users.ENodeBID] == enb.NCellID);
			enbUsers = Users(ueGroup);
			
			for iUser = 1:length(obj.Rx.UeData)
				% If empty, no uplink UE data has been received in this round and skip
				if ~isempty(obj.Rx.UeData(iUser).PUCCH)
					% CQI reporting and PUCCH payload detection are simplified from TS36.212
					cqiBits = obj.Rx.UeData(iUser).PUCCH(12:16,1);
					cqi = bi2de(cqiBits', 'left-msb');
					ueEnodeBIx= find([obj.Users.UeId] == obj.Rx.UeData(iUser).UeId);
					if ~isempty(ueEnodeBIx)
						obj.Users(ueEnodeBIx).CQI = cqi;
					end
					
					if Config.Harq.active
						% Decode HARQ feedback
						[harqPid, harqAck] = obj.Mac.HarqTxProcesses(harqIndex).decodeHarqFeedback(obj.Rx.UeData(iUser).PUCCH);
						
						if ~isempty(harqPid)
							[obj.Mac.HarqTxProcesses(harqIndex), state, sqn] = obj.Mac.HarqTxProcesses(harqIndex).handleReply(harqPid, harqAck, timeNow, Config, obj.Logger);
							
							% Contact ARQ based on the feedback
							if Config.Arq.active && ~isempty(sqn)
								arqIndex = find([obj.Rlc.ArqTxBuffers.rxId] == obj.Rx.UeData(iUser).UeId);
								
								if state == 0
									% The process has been acknowledged
									obj.Rlc.ArqTxBuffers(arqIndex) = obj.Rlc.ArqTxBuffers(arqIndex).handleAck(1, sqn, timeNow, Config);
								elseif state == 4
									% The process has failed
									obj.Rlc.ArqTxBuffers(arqIndex) = obj.Rlc.ArqTxBuffers(arqIndex).handleAck(0, sqn, timeNow, Config);
								else
									% No action to be taken by ARQ
								end
							end
						end
					end
				end
			end
		end
		
	end
end
