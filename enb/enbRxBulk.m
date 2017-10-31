function Stations = enbRxBulk(Stations, Users, timeNow)

	%   ENODEB RX BULK performs bulk operations for eNodeB reception
	%
	%   Function fingerprint
	%   Stations	->  EvolvedNodeB array
	%   Users			->  UE objects
	% 	timeNow		-> 	current simulation time
	%
	%   Stations	-> updated eNodeB objects

  for iStation = 1:length(Stations)
		% TODO which User do we assign for demodulation to the eNodeB receiver???
		enb = Stations(iStation);
		user = Users(1);	

		% Demodulate received waveform
    [demodBool, enb.Rx] = enb.Rx.demod(user);
		if demodBool
			% Decode PUSCH 
		
			% For each TB, check the CRC and the HARQ PID

			% Call the correct HARQ process handler to take care of the reply

			% Depending on the return state, decode SQN and send to the correct RLC buffer group

		end
		
	end
end
