REST_playback_data1_range = 1+mod(REST_playback_data1.smax:REST_playback_data1.smax+size(REST_playback_data1_chunk_clr,2)-1,REST_playback_data1.buffer_len);
REST_playback_data1.marker_pos(:,REST_playback_data1_range) = 0;
REST_playback_data1.buffer(:,REST_playback_data1_range) = REST_playback_data1_chunk_clr;
REST_playback_data1.smax = REST_playback_data1.smax + size(REST_playback_data1_chunk_clr,2);