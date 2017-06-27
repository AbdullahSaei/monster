function simulate(Param, DataIn, utilLo, utilHi)

	%   SIMULATE is used to run a single simulation
	%
	%   Function fingerprint
	%   Param			->  general simulation parameters
	%		DataIn		-> 	input data as struct
	%   utilLo		-> 	value of low utilisation for this simulation
	%		utilHi		->	value for high utilisation for this simulation

	trSource = DataIn.trSource;
	Stations = DataIn.Stations;
	Users = DataIn.Users;
	Channel = DataIn.Channel;
	ChannelEstimator = DataIn.ChannelEstimator;

	% Create structures to hold transmission data
	if (Param.storeTxData)
		[tbMatrix, tbMatrixInfo] = initTbMatrix(Param);
		[cwdMatrix, cwdMatrixInfo] = initCwdMatrix(Param);
	end
	[symMatrix, symMatrixInfo] = initSymMatrix(Param);

	% create a string to mark the output of this simulation
	outPrexif = strcat('utilLo_', num2str(utilLo), '-utilHi_', num2str(utilHi));

	Results = struct(...
		'sinr', zeros(Param.numUsers,Param.schRounds),...
		'cqi', 	zeros(Param.numUsers,Param.schRounds), ...
		'util', zeros(Param.numMacro + Param.numMicro, Param.schRounds),...
		'power', zeros(Param.numMacro + Param.numMicro, Param.schRounds),...
		'info', struct('utilLo', utilLo, 'utilHi', utilHi));

	for iRound = 0:Param.schRounds
		% In each scheduling round, check UEs associated with each station and
		% allocate PRBs through the scheduling function per each station

		% check which UEs are associated to which eNB
		[Users, Stations] = refreshUsersAssociation(Users, Stations, Param);
		simTime = iRound*10^-3;

		% Update RLC transmission queues for the users and reset the scheduled flag
		for iUser = 1:length(Users)
			queue = updateTrQueue(trSource, simTime, Users(iUser));
			Users(iUser) = setQueue(Users(iUser), queue);
			Users(iUser) = setScheduled(Users(iUser), false);
		end;

		% ---------------------
		% ENODEB SCHEDULE START
		% ---------------------
		for iStation = 1:length(Stations)
			% First off, set the number of the current subframe withing the frame
			% this is the scheduling round modulo 10 (the frame is 10ms)
			Stations(iStation).NSubframe = mod(iRound,10);

			% Reset teh grid and put in the grid RS, PSS and SSS
			Stations(iStation) = resetResourceGrid(Stations(iStation));

			% schedule only if at least 1 user is associated
			if Stations(iStation).Users(1) ~= 0
				Stations(iStation) = schedule(Stations(iStation), Users, Param);
			end

			% Check utilisation
			sch = [Stations(iStation).Schedule.UeId];
			utilPercent = 100*find(sch, 1, 'last' )/length(sch);

			% check utilPercent and cahnge to 0 if null
			if isempty(utilPercent)
				utilPercent = 0;
			end

			% calculate the power that will be used in this round by this eNodeB
			pIn = getPowerIn(Stations(iStation), utilPercent/100);

			% store eNodeB-space results
			Results.util(iStation, iRound + 1) = utilPercent;
			Results.power(iStation, iRound + 1) = pIn;

			% Check utilisation metrics and change status if needed
			Stations(iStation) = checkUtilisation(Stations(iStation), utilPercent,...
				Param, utilLo, utilHi, Stations);
		end
		% -------------------
		% ENODEB SCHEDULE END
		% -------------------

		% ----------------------------------------------
		% ENODEB CREATE DL-SCH TB TO PDSCH SYMBOLS START
		% ----------------------------------------------
		for iUser = 1:length(Users)
			% get the eNodeB thie UE is connected to
			iServingStation = find([Stations.NCellID] == Users(iUser).ENodeB);

			% Check if this UE is scheduled otherwise skip
			if checkUserSchedule(Users(iUser), Stations(iServingStation))
				% generate transport block for the user
				[tb, TbInfo] = createTransportBlock(Stations(iServingStation), Users(iUser), ...
					Param);

				% generate codeword (RV defaulted to 0)
				[cwd, CwdInfo] = createCodeword(tb, TbInfo, Param);

				% finally, generate the arrays of complex symbols by setting the
				% correspondent values per each eNodeB-UE pair
				% setup current subframe for serving eNodeB
				if CwdInfo.cwdSize ~= 0 % is this even necessary?
					[sym, SymInfo] = createSymbols(Stations(iServingStation), Users(iUser), cwd, ...
						CwdInfo, Param);
				end

				if SymInfo.symSize > 0
					symMatrix(iServingStation, iUser, :) = sym;
					symMatrixInfo(iServingStation, iUser) = SymInfo;
				end

				% Save to data structures
				if Param.storeTxData
					tbMatrix(iServingStation, iUser, :) = tb;
					tbMatrixInfo(iServingStation, iUser) = TbInfo;
					cwdMatrix(iServingStation, iUser, :) = cwd;
					cwdMatrixInfo(iServingStation, iUser) = CwdInfo;
				end

			end
		end
		% --------------------------------------------
		% ENODEB CREATE DL-SCH TB TO PDSCH SYMBOLS END
		% --------------------------------------------

		% -------------------------
		% ENODEB GRID MAPPING START
		% -------------------------
		for iStation = 1:length(Stations)
			% the last step in the DL transmisison chain is to map the symbols to the
			% resource grid and modulate the grid to get the TX waveform

			% extract all the symbols this eNodeB has to transmit
			syms = extractStationSyms(Stations(iStation), iStation, symMatrix, Param);

			% insert the symbols of the PDSCH into the grid
			Stations(iStation) = setPDSCHGrid(Stations(iStation), syms);

			% with the grid ready, generate the TX waveform
			Stations(iStation) = modulateTxWaveform(Stations(iStation));
		end
		% -----------------------
		% ENODEB GRID MAPPING END
		% -----------------------

		if Param.draw
			% Plot OFDM spectrum of first station
			spectrumAnalyser(Stations(1).TxWaveform, Stations(1).WaveformInfo.SamplingRate);

			% Plot conestellation diagram of first station
			enb = cast2Struct(Stations(1));
			grid = lteOFDMDemodulate(enb,enb.TxWaveform);
			grid_r = reshape(grid,length(grid(:,1))*length(grid(1,:)),1);
			constellationDiagram(grid_r,1);
		end

		% Once all eNodeBs have created and stored their txWaveforms, we can go
		% through the UEs and compute the rxWaveforms
		if ~strcmp(Param.channel.mode,'B2B')
			[Stations, Users] = Channel.traverse(Stations,Users);
		end

		% ------------------
		% UE RECEPTION START
		% ------------------
		for iUser = 1:length(Users)
			% find serving eNodeB
			iServingStation = find([Stations.NCellID] == Users(iUser).ENodeB);

			% TODO remove B2B testing
			if strcmp(Param.channel.mode,'B2B')
				Users(iUser).RxWaveform = Stations(iServingStation).TxWaveform;
			end

			% Achieve synchronization
			% TODO; Offset not computed correctly. Check eNB settings and
			% how the synchronization signals are set (see 'edit
			% DownlinkChannelEstimationEqualizationExample')

			%offset = lteDLFrameOffset(cast2Struct(Stations(iServingStation)), ...
			%	cast2Struct(Users(iUser)).RxWaveform);
			%

			[offset, offset_auto] = calcFrameOffset(Stations(iStation), Users(iUser));
            if offset > offset_auto && strcmp(Param.channel.mode,'B2B')
                sonohilog('Signaling error, offset not computed correctly, using autocorrelation.','WRN')
                offset = offset_auto-1;
            end

            if offset > 0 && strcmp(Param.channel.mode,'B2B')
                sonohilog('Offset error, supposed to be 0 in B2B mode.','ERR')
            end

            Users(iUser).RxWaveform= Users(iUser).RxWaveform(1+offset:end,:);

			% Now, demodulate the overall received waveform for users that should
			% receive a TB
			if checkUserSchedule(Users(iUser), Stations(iServingStation))
				Users(iUser) = demodulateRxWaveform(Users(iUser), Stations(iServingStation));

				% Estimate channel for the received subframe
				Users(iUser) = estimateChannel(Users(iUser), Stations(iServingStation),...
					ChannelEstimator);

				% Calculate error
				rxError = Stations(iServingStation).ReGrid - Users(iUser).RxSubFrame;

				% Perform equalization to account for phase noise (needs
				% SNR)
				if ~strcmp(Param.channel.mode,'B2B')
					Users(iUser) = equalize(Users(iUser));
					eqError = Stations(iServingStation).ReGrid - Users(iUser).EqSubFrame;
				end

				EVM = comm.EVM;
				EVM.AveragingDimensions = [1 2];
				preEqualisedEVM = EVM(Stations(iServingStation).ReGrid,Users(iUser).RxSubFrame);
				s = sprintf('User %i: Percentage RMS EVM of Pre-Equalized signal: %0.3f%%\n', ...
					Users(iUser).UeId,preEqualisedEVM);
                sonohilog(s,'NFO')
				if Param.draw

				end

				% finally, get the value of the sinr for this subframe and the corresponing
				% CQI that should be used for the next round

				Users(iUser) = selectCqi(Users(iUser), Stations(iServingStation));

				% store UE-space results
				Results.sinr(iUser, iRound + 1) = Users(iUser).Sinr;
				Results.cqi(iUser, iRound + 1) = Users(iUser).WCqi;
			end
		end
		% -----------------
		% UE RECEPTION END
		% -----------------

		% Plot resource grids for all users
		if Param.draw
		  hScatter = plotConstDiagram_rx(Users);
		  hGrids = plotReGrids(Users);
		end

	end % end round

	% Once this simulation set is done, save the output
  save(strcat('results/', outPrexif, '.mat'), 'Results');
end
