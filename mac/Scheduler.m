classdef Scheduler < matlab.mixin.Copyable
	properties
		ScheduledUsers; % List of user objects
		enbObj; % Parent enodeB EvolvedNodeB object
		PRBsActive;% List of users and the respective PRBs allocated with MCS
		PRBSet; % PRBs used for user data, these can be allocated
		Logger;
		SchedulerType; % Type of scheduling algorithm used.
		HarqActive; % If Harq is enabled
		PRBSymbols; % Number of symbols for each PRB
		Mode; % Mode of operation (downlink or uplink)
	end
	
	properties(SetAccess='protected')
		RoundRobinQueue = []; % Prioritized list of users (FIFO)
	end
	
	
	methods
		% Constructor
		function obj = Scheduler(enbObj, Logger, Config, NRB, Mode)
			if ~isa(enbObj, 'EvolvedNodeB')
				Logger.log('The parent object is not of type EvolvedNodeB','ERR', 'Scheduler:NotEvolvedNodeB')
			end
			
			obj.enbObj = enbObj;
			obj.Logger = Logger;
			obj.SchedulerType = Config.Scheduling.type;
			obj.PRBSet = 1:NRB;
			obj.PRBsActive = struct('UeId', {}, 'MCS', {}, 'ModOrd', {});
			obj.PRBsActive(obj.PRBSet) = struct('UeId', -1, 'MCS', -1, 'ModOrd', -1);
			obj.HarqActive = Config.Harq.active;
			obj.PRBSymbols = Config.Phy.prbSymbols;
			obj.Mode = Mode;
		end
		
		
		function obj = scheduleUsers(obj, AllUsers)
			% Given the scheduler type and the users for scheduled, turn a list of PRBs for each user ID
			% Need access to user specific variables, thus users are given as input parameter
			
			% If no users are associated, nothing to do.
			if ~isempty(obj.enbObj.AssociatedUsers)
				% update userids for scheduling
				obj.updateUsers();
				% Filter AllUsers to only have eligible and associated Users
				queueIds = obj.getQueue();
				Users = AllUsers(ismember([AllUsers.NCellID],queueIds));
				
				% Run scheduling algorithm
				obj.allocateResources(Users);
				
			else
				obj.Logger.log('No Users associated, nothing to schedule.','WRN');
			end
		end
		
		function obj = clearRoundRobinQueue(obj)
			obj.RoundRobinQueue = [];
		end
		
		
		function obj = reset(obj)
			obj.ScheduledUsers = [];
			obj.PRBsActive(obj.PRBSet) = struct('UeId', -1, 'MCS', -1, 'ModOrd', -1);
		end
		
	end
	
	methods(Access='private')
		
		
		function queueIds = getQueue(obj)
			
			if ~isempty(obj.RoundRobinQueue)
				queueIds = [obj.RoundRobinQueue obj.ScheduledUsers(~ismember(obj.ScheduledUsers, obj.RoundRobinQueue))];
			else
				queueIds = obj.ScheduledUsers;
			end
			
		end
		
		function obj = allocateResources(obj, Users)
			% Call round robin scheduler script
			%
			% Array<Users> array of user objects.
			
			queueIds = obj.getQueue();
			if obj.HarqActive
				rtxInfo = obj.getUserRetransmissionQueues(queueIds);
			end
			
			PRBSNeeded = obj.getPRBSNeeded(Users, rtxInfo);
			
			switch obj.SchedulerType
				case 'roundRobin'
					
					switch obj.Mode
						case 'downlink'
							[obj.PRBsActive, obj.RoundRobinQueue] = obj.GreedyRoundRobinAlgorithm(queueIds, Users, PRBSNeeded);
						case 'uplink'
							[obj.PRBsActive, obj.RoundRobinQueue] = obj.MinimumRoundRobinAlgorithm(queueIds, Users, PRBSNeeded);
							
					end
				otherwise
					obj.Logger.log('Unknown scheduler type','ERR','MonsterScheduler:UnknownSchedulerType');
			end
			
			obj.setUserParam(Users);
			obj.setRetransmissionState(rtxInfo);
		end

		
		function obj = setUserParam(obj, Users)
			% Sets user specific parameters given the schedulers decisions
			% 1. A flag for being scheduled is set
			% 2. The traffic queue is updated
			scheduledUsers = unique([obj.PRBsActive.UeId]);
			scheduledUsers = scheduledUsers(scheduledUsers~=-1);
			for iUser = scheduledUsers
				user = Users([Users.NCellID] == iUser);

				% Set downlink flag
				switch obj.Mode
					case 'downlink'
						user.Scheduled.DL = true;

						% Find latest available wideband CQI value for this UE at the eNodeB 
						latestCqi = obj.getLatestUserCqi(user.NCellID);
						% Update traffic queue
						modOrd = ModOrdTable(latestCqi);
						numPRBS = length([obj.PRBsActive.UeId] == iUser);
						numBits = numPRBS * (modOrd*obj.PRBSymbols);
						% The number of bits to decrease the queue size has to be capped to 
						% at most the current queue size, as PRBs have to be assigned whole
						user.Queue.Size = max(user.Queue.Size - numBits, 0);
					case 'uplink'
						user.Scheduled.UL = true;
						
				end

			end
			
		end
		
		function [prbs, updatedqueue] = MinimumRoundRobinAlgorithm(obj, userIds, users, prbsNeeded)
				minPRBS = 5; % Minimum PRBs per user
				prbs = obj.PRBsActive; %Local copy
				% Compute number of available resources
				PRBAvailable = length(prbs);
				
				% Users needed to be scheduled
				numUsers = length(userIds);
				resourcesAvailable = 1;
				
				% Check if all users can be allocated given the minimum PRBs per
				% user
				if (numUsers*minPRBS) >= PRBAvailable
					% Serve users until no PRBs are available
					while resourcesAvailable
							iUserID = userIds(1); % Get first from userids
							user = users([users.NCellID] == iUserID);
							PRBScheduled = minPRBS;
							
							% Allocate PRBs
							% Update list of PRBs
							for iPrb = 1:length(prbs)
								if prbs(iPrb).UeId == -1
									% Find latest available wideband CQI value for this UE at the eNodeB 
									latestCqi = obj.getLatestUserCqi(user.NCellID);
									mcs = MCSTable(latestCqi);
									modOrd = ModOrdTable(latestCqi);
									for iSch = 0:PRBScheduled-1
										prbs(iPrb + iSch).UeId = user.NCellID;
										prbs(iPrb + iSch).MCS = mcs;
										prbs(iPrb + iSch).ModOrd = modOrd;
									end
									break;
								end
							end
					

							
							PRBAvailable = PRBAvailable - PRBScheduled;
							if PRBAvailable == 0
								resourcesAvailable = 0;
								break;
							end
							
							% pop user from list
							if length(userIds) > 1
								userIds = userIds(2:end);
								prbsNeeded = prbsNeeded(2:end);
							else
								userIds = [];
								prbsNeeded = [];
							end
							
							
					end
				% Add remaining users to queue
				updatedqueue = userIds;
				
				elseif (numUsers*minPRBS) < PRBAvailable
					% compute how many extra resources can be allocated
					minPRBS = floor(PRBAvailable/numUsers);
					
					% Get the remainder such it can be added to the PRBsets
					remainderPRB = mod(PRBAvailable,minPRBS); 
					PRBset  = 0:minPRBS:PRBAvailable;
					PRBset(length(PRBset)) = PRBset(length(PRBset))+remainderPRB; % Add remaining resources to the last PRBset
					
					% Loop each PRB set, use +1 as the end of the PRBset
					for iPRBset = 1:length(PRBset)-1
						startPRB = PRBset(iPRBset);
						endPRB = PRBset(iPRBset+1)-1; % exluding the last 
						iUserID = userIds(iPRBset); % Get first from userids
						user = users([users.NCellID] == iUserID);
						% Find latest available wideband CQI value for this UE at the eNodeB 
						latestCqi = obj.getLatestUserCqi(user.NCellID);
						mcs = MCSTable(latestCqi);
						modOrd = ModOrdTable(latestCqi);
						for iSch = startPRB:endPRB
								prbs(iSch+1).UeId = user.NCellID;
								prbs(iSch+1).MCS = mcs;
								prbs(iSch+1).ModOrd = modOrd;
						end
					end
					
					updatedqueue = []; % All users can be served
				end
		end
		
		function [prbs, updatedqueue] = GreedyRoundRobinAlgorithm(obj, userIds, users, prbsNeeded)
			% Standard implementation of the roundrobin algorithm.
			% It seeks to fill the resources available, serving the users first who has not been served in the last round of scheduling.
			%
			% <userIds> is a prioritized list of users, with queued users (from last round) placed first
			% <users> is a list of the user objects
			% <prbsNeeded> struct of prbs needed for each user in userIds
			
			prbs = obj.PRBsActive; %Local copy
			% Compute number of available resources
			PRBAvailable = length(prbs);
			
			
			resourcesAvailable = 1;
			
			while resourcesAvailable
				iUserID = userIds(1); % Get first from userids
				user = users([users.NCellID] == iUserID);
				
				% If there are still PRBs available, then we can schedule either a new TB or a RTX
				if PRBAvailable > 0
					
					PRBNeed = prbsNeeded(1);
					
					% Check if the PRBs needed are more than what is available
					if PRBNeed >= PRBAvailable
						PRBScheduled = PRBAvailable;
					else
						PRBScheduled = PRBNeed;
					end
					
					PRBAvailable = PRBAvailable - PRBScheduled;
					
					% Update list of PRBs
					for iPrb = 1:length(prbs)
						if prbs(iPrb).UeId == -1
							% Find latest available wideband CQI value for this UE at the eNodeB 
							latestCqi = obj.getLatestUserCqi(user.NCellID);
							mcs = MCSTable(latestCqi);
							modOrd = ModOrdTable(latestCqi);
							for iSch = 0:PRBScheduled-1
								prbs(iPrb + iSch).UeId = user.NCellID;
								prbs(iPrb + iSch).MCS = mcs;
								prbs(iPrb + iSch).ModOrd = modOrd;
							end
							break;
						end
					end
					
					% pop user from list
					if length(userIds) > 1
						userIds = userIds(2:end);
						prbsNeeded = prbsNeeded(2:end);
					else
						userIds = [];
						prbsNeeded = [];
						resourcesAvailable = 0; % No more users to schedule
					end
					
				else
					% There are no more PRBs available, this will be the first UE to be scheduled
					% in the next round.
					resourcesAvailable = 0;
				end
			end
			
			% Add remaining users to the queue
			updatedqueue = userIds;
		end
		
		function obj = setRetransmissionState(obj, rtxInfo)
			% Update the retransmission state if either the harq or arq is scheduled for transmission
			% Get unique scheduled users
			scheduledUsers = unique([obj.PRBsActive.UeId]);
			scheduledUsers = scheduledUsers(scheduledUsers~=-1);
			for iUser = scheduledUsers
				% Find users rtx info
				rtx = rtxInfo([rtxInfo.UeId] == iUser);
				if ~isempty(rtx)
					% set retransmission state if the scheduled is a retransmission
					switch rtx.proto
						case 1
							obj.enbObj.Mac.HarqTxBuffers.setRetransmissionState(rtx.identifier);
						case 2
							obj.enbObj.Rlc.ArqTxBuffers.setRetransmissionState(rtx.identifier);
					end
				end
				
			end
			
		end
		
		function rtxInfo = getUserRetransmissionQueues(obj, UserIds)
			% Get the retransmission queues for each userid
			%
			% <UserIds> List of userids
			% Returns
			% rtxInfo with fields of
			% rtxInfo.proto (Harq = 1, Arq = 2)
			% rtxInfo.UeId (User ID)
			% rtxInfo.identifier (buffer index)
			
			rtxInfo = struct('proto', [], 'identifier', [], 'UeId', []);
			rtxInfo(1:length(UserIds)) = struct('proto', -1, 'identifier', -1, 'UeId', -1);
			for iUser = 1:length(UserIds)
				userId = UserIds(iUser);
				% RLC queue check
				iUserRlc = find([obj.enbObj.Rlc.ArqTxBuffers.rxId] == userId);
				arqRtxInfo = obj.enbObj.Rlc.ArqTxBuffers(iUserRlc).getRetransmissionState();
				
				% MAC queues check
				iUserMac = find([obj.enbObj.Mac.HarqTxProcesses.rxId] == userId);
				harqRtxInfo = obj.enbObj.Mac.HarqTxProcesses(iUserMac).getRetransmissionState();
				if harqRtxInfo.flag
					rtxInfo(iUser).proto = 1;
					rtxInfo(iUser).identifier = harqRtxInfo.procIndex;
					rtxInfo(iUser).UeId = userId;
				elseif arqRtxInfo.flag
					rtxInfo(iUser).proto = 2;
					rtxInfo(iUser).identifier = arqRtxInfo.bufferIndex;
					rtxInfo(iUser).UeId = userId;
				else
					rtxInfo(iUser).proto = 0;
					rtxInfo(iUser).identifier = [];
				end
			end
			
		end
		
		function PRBNeed = getPRBSNeeded(obj, Users, rtxInfo)
			switch obj.Mode
				case 'downlink'
					PRBNeed = obj.getPRBSNeededDownlink(Users, rtxInfo);
				case 'uplink'
					PRBNeed = obj.getPRBSNeededUplink(Users);	
			end
		end
		
		function PRBNeed = getPRBSNeededUplink(obj, Users)
			% TODO: Make this dependent on a traffic generator
			% Always PRBS needed for each user (fullbuffer)
			
			PRBNeed = zeros(length(Users),1);
			
			for iUser = 1:length(Users)
				PRBNeed(iUser) = 100000;
			end
			
		end
		
		function PRBNeed = getPRBSNeededDownlink(obj, Users, rtxInfo)
			% Get the number of PRBS required for each user given either 1. the transmission queue or 2. HARQ/ARQ
			%
			% <Users> array of user objects
			% <rtxInfo> Info of retransmission HARQ/ARQ queues. Requires fields of
			%									.proto (Harq = 1, Arq = 2),
			%									.identifier (buffer index)
			PRBNeed = zeros(length(Users),1);
			for iUser = 1:length(Users)
				user = Users(iUser);
				% Find latest available wideband CQI value for this UE at the eNodeB 
				latestCqi = obj.getLatestUserCqi(user.NCellID);
				modOrd = ModOrdTable(latestCqi);
				rtxSchedulingFlag = obj.HarqActive && rtxInfo(iUser).proto ~= 0;
				
				if ~rtxSchedulingFlag
					PRBNeed(iUser) = ceil(double(user.Queue.Size)/(modOrd * obj.PRBSymbols));
				else
					% Otherwise, use the HARQ and ARQ queues for PRBS
					tb = [];
					switch rtxInfo(iUser).proto
						case 1
							tb = obj.enbObj.Mac.HarqTxProcesses.processes(rtxInfo.identifier).tb;
						case 2
							tb = obj.enbObj.Mac.ArqTxProcesses.tbBuffer(rtxInfo.identifier).tb;
					end
					PRBNeed(iUser) = ceil(length(tb)/(modOrd * obj.PRBSymbols));
				end
			end
			
		end
		
		function obj = updateUsers(obj)
			% Synchronize the list of scheduled users to that of the associated users of the eNodeB.
			associatedUsers = [obj.enbObj.AssociatedUsers];
			associatedUsersCQI = [associatedUsers.CQI];
			eligibleUsers = [associatedUsers([associatedUsersCQI.wideBand] > 0).UeId];
			
			% If the list of scheduled users is empty, add all associated users
			if isempty(obj.ScheduledUsers)
				% Add users
				for UeIdx = 1:length(eligibleUsers)
					obj.addUser(eligibleUsers(UeIdx));
				end
				
				% If not empty, find out which ones to add
			elseif any(~ismember(eligibleUsers, obj.ScheduledUsers))
				toAdd = eligibleUsers(~ismember(eligibleUsers, obj.ScheduledUsers));
				for UeIdx = 1:length(toAdd)
					obj.addUser(toAdd(UeIdx))
				end
			end
			
			% Check if any associated Users are no longer associated, thus remove them from the scheduler
			if any(~ismember(obj.ScheduledUsers, eligibleUsers))
				toRemove = obj.ScheduledUsers(~ismember(obj.ScheduledUsers, eligibleUsers));
				for UeIdx = 1:length(toRemove)
					obj.removeUser(toRemove(UeIdx))
				end
			end
		end
		
		function obj = addUser(obj, UserId)
			obj.ScheduledUsers = [obj.ScheduledUsers UserId];
		end
		
		function obj = removeUser(obj, UserId)
			obj.ScheduledUsers = obj.ScheduledUsers(obj.ScheduledUsers ~= UserId);
		end
		
		function obj = updateActivePRBs(obj, AbsMask)
			% Update the number of active PRBs based on the mask
			% TODO: add mask
			
		end

		function cqi = getLatestUserCqi(obj, userId)
			associatedUserInfo = obj.enbObj.AssociatedUsers([obj.enbObj.AssociatedUsers.UeId] == userId);
			cqi = associatedUserInfo.CQI.wideBand; 
		end
		
	end
end
