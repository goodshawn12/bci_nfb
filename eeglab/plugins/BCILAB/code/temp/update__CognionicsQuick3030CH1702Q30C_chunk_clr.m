CognionicsQuick3030CH1702Q30C_range = 1+mod(CognionicsQuick3030CH1702Q30C.smax:CognionicsQuick3030CH1702Q30C.smax+size(CognionicsQuick3030CH1702Q30C_chunk_clr,2)-1,CognionicsQuick3030CH1702Q30C.buffer_len);
CognionicsQuick3030CH1702Q30C.marker_pos(:,CognionicsQuick3030CH1702Q30C_range) = 0;
CognionicsQuick3030CH1702Q30C.buffer(:,CognionicsQuick3030CH1702Q30C_range) = CognionicsQuick3030CH1702Q30C_chunk_clr;
CognionicsQuick3030CH1702Q30C.smax = CognionicsQuick3030CH1702Q30C.smax + size(CognionicsQuick3030CH1702Q30C_chunk_clr,2);