CognionicsQuick301701Q30E_range = 1+mod(CognionicsQuick301701Q30E.smax:CognionicsQuick301701Q30E.smax+size(CognionicsQuick301701Q30E_chunk_clr,2)-1,CognionicsQuick301701Q30E.buffer_len);
CognionicsQuick301701Q30E.marker_pos(:,CognionicsQuick301701Q30E_range) = 0;
CognionicsQuick301701Q30E.buffer(:,CognionicsQuick301701Q30E_range) = CognionicsQuick301701Q30E_chunk_clr;
CognionicsQuick301701Q30E.smax = CognionicsQuick301701Q30E.smax + size(CognionicsQuick301701Q30E_chunk_clr,2);