function sweepParameters = generateSweepParameters(Simulation, optimisationMetric) 
	% Constructs the sweep parameters structure to store sweep state for each user
	%
	% :param Simulation: Monster instance
	% :param optimisationMetric: string to choose over which metric the sweep should optimise
	% :returns sweepParameters: sweep parameters for each UE

	enbList(1:length(Simulation.Stations)) = struct('eNodeBId', -1, 'angle', 0, 'rxPowdBm', -realmax, 'sinr', -realmax); 

	sweepParameters(1: length(Simulation.Users)) = struct(...
		'ueId', 0,...
		'eNodeBList', enbList,...
		'metric', optimisationMetric,...
		'timeLastAssociation', 0,...
		'hysteresisTimer', 0,...
		'rotationIncrement', 90,...
		'currentAngle', 0,...
		'maxAngle', 360,...
		'minAngle', 10);
	for iUser = 1:length(Simulation.Users)
		% assign the id to an empty slot in the sweepParameters
		sweepParameters(iUser).ueId = Simulation.Users.NCellID;

		% TODO other initialisation?
	end

end