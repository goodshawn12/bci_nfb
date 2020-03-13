EEG2LSL_range = 1+mod(EEG2LSL.smax:EEG2LSL.smax+size(EEG2LSL_chunk_clr,2)-1,EEG2LSL.buffer_len);
EEG2LSL.marker_pos(:,EEG2LSL_range) = 0;
EEG2LSL.buffer(:,EEG2LSL_range) = EEG2LSL_chunk_clr;
EEG2LSL.smax = EEG2LSL.smax + size(EEG2LSL_chunk_clr,2);