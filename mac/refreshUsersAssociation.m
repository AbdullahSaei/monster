function [Users, Stations] = refreshUsersAssociation(Users,Stations,Channel,Param)

%   REFRESH USERS ASSOCIATION links UEs to a eNodeB
%
%   Function fingerprint
%   Users   		->  array of UEs
%   Stations		->  array of eNodeBs
%
%   nodeUsers ->  Users indexes associated with node

	% reset stations
	for (iStation = 1:length(Stations))
		Stations(iStation) = resetUsers(Stations(iStation), Param);
    end

    % Create copy of stations that is used computing associating, e.g. 
    % no users associated but the one in the loop. No UeId should be saved
    % to this one.
    StationsC = Stations;
    
    
	d0=1; % m
	for (iUser = 1:length(Users))
		% get UE position
		uePos = Users(iUser).Position;
		minLossDb = 200;
        
        
        stationCellID = Channel.getAssociation(StationsC,Users(iUser));
        
        Users(iUser).ENodeB = stationCellID;
        
		%for (iStation = 1:length(Stations))
		%	bs = Stations(iStation);
		%	if (bs.Status == 1 || bs.Status == 2 || bs.Status == 3)
		%		bsPos = bs.Position;
		%		dist = sqrt((bsPos(1)-uePos(1))^2 + (bsPos(2)-uePos(2))^2 );
		%		[lossDb, ~] = ExtendedHata_MedianBasicPropLoss(Stations(iStation).DlFreq, ...
		%			dist/1e3, bsPos(3), uePos(3), Param.channel.region);
		%		% check if this is the minimum so far
		%		if (lossDb < minLossDb)
		%			Users(iUser).ENodeB = Stations(iStation).NCellID;
		%			minLossDb = lossDb;
		%		end
		%	end
		%end
		% Now that the assignement is done, write also on the side of the station
		% TODO replace with matrix operation
		for iStation = 1:length(Stations)
			if Stations(iStation).NCellID == Users(iUser).ENodeB
				for ix = 1:Param.numUsers
					if Stations(iStation).Users(ix) == 0
						Stations(iStation).Users(ix) = Users(iUser).UeId;
						break;
					end
				end
				break;
			end
	end
end
