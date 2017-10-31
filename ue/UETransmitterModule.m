classdef ueTransmitterModule
  properties
    NULRB;
    DuplexMode;
    CyclicPrefixUL
    NTxAnts;
    prach;
    prachinfo;
    Waveform;
    NSubframe;
    NFrame;
    ReGrid;
    pucch;
    NCellID;
    RNTI;
  end
  
  methods
    
    function obj = ueTransmitterModule(Param)
      
      obj.NULRB = 6;                   % 6 Resource Blocks
      obj.DuplexMode = 'FDD';          % Frequency Division Duplexing (FDD)
      obj.CyclicPrefixUL = 'Normal';   % Normal cyclic prefix length
      obj.NTxAnts = 1;                 % Number of transmission antennas
      obj.RNTI = 1;
      obj.pucch.format = 1;
      obj.prach.Interval = Param.PRACHInterval;
      obj.prach.Format = 0;          % PRACH format: TS36.104, Table 8.4.2.1-1, CP length of 0.10 ms, typical cell range of 15km
      obj.prach.SeqIdx = 22;         % Logical sequence index: TS36.141, Table A.6-1
      obj.prach.CyclicShiftIdx = 1;  % Cyclic shift index: TS36.141, Table A.6-1
      obj.prach.HighSpeed = 0;       % Normal mode: TS36.104, Table 8.4.2.1-1
      obj.prach.FreqOffset = 0;      % Default frequency location
      obj.prach.PreambleIdx = 32;    % Preamble index: TS36.141, Table A.6-1
      obj.prachinfo = ltePRACHInfo(obj, obj.prach);      
    end
    
    function obj = setPRACH(obj)
      obj.prach.TimingOffset = obj.prachinfo.BaseOffset + obj.NSubframe/10.0;
      obj.Waveform = ltePRACH(obj, obj.prach);
    end

    function obj = mapGridAndModulate(obj, User, NSubframe, NFrame)

      obj.NSubframe = NSubframe;
      obj.NFrame = NFrame;
      obj.NCellID = User.NCellID;
      % Check if upllink needs to consist of PRACH
      % TODO: changes to sequence and preambleidx given unique user ids
      if mod(obj.NSubframe,obj.prach.Interval) == 0
    
         obj = obj.setPRACH;
        
      else
        % Get size of resource grid and map channels.
        dims = lteULResourceGridSize(obj);
         
        %% Decide on format of PUCCH (1, 2 or 3)
        % Format 1 is Scheduling request with/without bits for HARQ
        % Format 2 is CQI with/without bits for HARQ
        % Format 3 Bits for HARQ

        % Get HARQ and CQI info for this report from the MAC layer bits
        harqAck = User.Mac.HarqReport.ack;
        harqPid = User.Mac.HarqReport.pid;
        harqBits = cat(1, harqPid, harqAck);
        cqiBits = de2bi(User.Rx.WCQI)';
        if length(cqiBits) ~= 4
          cqiBits = cat(1, zeros(4- length(cqiBits), 1), cqiBits);
        end
        chs.ResourceIdx = 0;
        switch obj.pucchformat
          case 1
            pucchsym = ltePUCCH1(obj,chs,harqAck);
            pucchind = ltePUCCH1Indices(obj,chs);
            drsSeq = ltePUCCH1DRS(obj,chs);
            drsSeqind = ltePUCCH1DRSIndices(obj,chs);
          case 2
            pucch2Bits = cat(1, cqiBits, harqBits);
            if length(pucch2Bits ~= 20)
              pucch2Bits = cat(1, zeros(20-length(pucch2Bits), 1), pucch2Bits);
            end         
            pucchsym = ltePUCCH2(obj,chs,pucch2Bits);
            pucchind = ltePUCCH2Indices(obj,chs);
            drsSeq = ltePUCCH2DRS(obj,chs);
            drsSeqind = ltePUCCH2DRSIndices(obj,chs);            
          case 3
            pucchsym = ltePUCCH3(obj,chs,harqBits)
            pucchind = ltePUCCH3Indices(obj,chs);
            drsSeq = ltePUCCH3DRS(obj,chs);
            drsSeqind = ltePUCCH3DRSIndices(obj,chs);
        end
        
        %% Configure PUSCH
        % TODO If we use RNTI

        chs.Modulation = 'QPSK';
        chs.PRBSet = [0:obj.NULRB-1].';
        chs.RV = 0; %	Redundancy version (RV) indicator in initial subframe
        
        % Reference data
        % TODO replace this with actual data
        frc = lteRMCUL('A1-1');
        trBlk  = randi([0,1],frc.PUSCH.TrBlkSizes(1),1);
        cw = lteULSCH(obj,chs,trBlk );
        
        puschsym = ltePUSCH(obj,chs,cw);
        puschind = ltePUSCHIndices(obj,chs);
        puschdrsSeq = ltePUSCHDRS(obj,chs);
        puschdrsSeqind = ltePUSCHDRSIndices(obj,chs);
        
        %% Configure SRS
        srssym = lteSRS(obj,chs);
        srsind = lteSRSIndices(obj,chs);
        
        % Modulate SCFDMA
        obj.ReGrid = lteULResourceGrid(obj);
        obj.ReGrid(pucchind) = pucchsym;
        obj.ReGrid(drsSeqind) = drsSeq;
        obj.ReGrid(puschind) = puschsym;
        obj.ReGrid(puschdrsSeqind) = puschdrsSeq;
        obj.ReGrid(srsind) = srssym;
        
        % filler symbols
        %obj.ReGrid = reshape(lteSymbolModulate(randi([0,1],prod(dims)*2,1), ...
        %  'QPSK'),dims);
        
        obj.Waveform = lteSCFDMAModulate(obj,obj.ReGrid);
        
      end
    end
  end
  
end
