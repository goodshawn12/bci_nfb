CGXQuick20rQ20rDemo_range = 1+mod(CGXQuick20rQ20rDemo.smax:CGXQuick20rQ20rDemo.smax+size(CGXQuick20rQ20rDemo_chunk_clr,2)-1,CGXQuick20rQ20rDemo.buffer_len);
CGXQuick20rQ20rDemo.marker_pos(:,CGXQuick20rQ20rDemo_range) = 0;
CGXQuick20rQ20rDemo.buffer(:,CGXQuick20rQ20rDemo_range) = CGXQuick20rQ20rDemo_chunk_clr;
CGXQuick20rQ20rDemo.smax = CGXQuick20rQ20rDemo.smax + size(CGXQuick20rQ20rDemo_chunk_clr,2);