/*
 *   *** NOT FOR SYNTHESIS ***
 * 
 * Traffic Sink
 * 
 * Collects incoming packets and produces statistics. 
 * 
 *  - check flit id's are sequential
 * 
 */

module NL_traffic_sink (flit_in, cntrl_out, rec_count, rec_count_dropped, stats, clk, rst_n);
   
	parameter xdim = 4;
	parameter ydim = 4; 

	parameter xpos = 0;
	parameter ypos = 0;

	parameter warmup_packets = 100;
`ifdef VERBOSE	
	parameter measurement_packets = 1000;
`endif
	parameter router_num_vcs_on_exit = 2;
	
	parameter MAXINT = 2^32-1;

	input     flit_t flit_in;
	output    chan_cntrl_t cntrl_out;
	output    sim_stats_t stats;
	input     clk, rst_n;
	output    integer rec_count;
	output    integer rec_count_dropped;

	integer   expected_flit_id [router_num_vcs_on_exit-1:0];
	integer   head_injection_time [router_num_vcs_on_exit-1:0];
	integer   latency, sys_time;
	integer   i, current_vc; //j, 
   
	always@(posedge clk) begin
		if (!rst_n) begin
			cntrl_out.credit<='0;
			cntrl_out.credit_valid<=1'b0;
			
			rec_count=0;
			rec_count_dropped = 0;
			stats.total_dropped_flits=0; //TIMA
			stats.total_latency=0;
			stats.total_hops=0;
			stats.max_hops=0;
			stats.min_hops=MAXINT;
			stats.max_latency=0;
			stats.min_latency=MAXINT;
			stats.measure_start=-1;
			stats.measure_end=-1;
			stats.flit_count=0;

			sys_time=0;

			for (i=0; i<router_num_vcs_on_exit; i++) begin
				expected_flit_id[i]=1;
				head_injection_time[i]=-1;
			end

			for (i=0; i<(xdim+ydim); i++) begin
				stats.total_lat_for_hop_count[i]=0;
				stats.total_packets_with_hop_count[i]=0;
			end

			for (i=0; i<=100; i++) begin
				stats.lat_freq[i]=0;
			end
	 
		end else begin // if (!rst_n)

			sys_time++;
	 
			if (flit_in.control.valid) begin

				cntrl_out.credit_valid<=1'b1;

				current_vc = oh2bin(flit_in.control.vc_id);

				cntrl_out.credit <= current_vc;

				//
				// check VC id is in range
				//
				if (!((current_vc>=0)&&(current_vc<router_num_vcs_on_exit))) begin
					$display ("%m: Error: Flit VC ID is out-of-range for exit from network!");
					$display ("VC ID = %1d (router_num_vcs_on_exit=%1d)", current_vc, router_num_vcs_on_exit);
					$finish;
				end
			
				//
				// check flit was destined for this node!
				//
				if (((flit_in.debug.xdest!=xpos)||(flit_in.debug.ydest!=ypos)) && !flit_in.control.drop) begin
					$display ("%m: Error: Flit arrived at wrong destination!");

					$display ("%m: %1d, ALEX_ERROR_ROUTER = x_dest(%1d), y_dest(%1d), Packet(%1d), Flit(%1d), from (%1d, %1d) destined for (%1d, %1d), Hops(%1d), Port(%1d), VC(%1d), V(%1d), Drop(%1d).", 
					$time, flit_in.control.x_dest, flit_in.control.y_dest, flit_in.debug.packet_id, flit_in.debug.flit_id, 
					flit_in.debug.xsrc, flit_in.debug.ysrc, flit_in.debug.xdest, flit_in.debug.ydest, flit_in.debug.hops, 
					oh2bin(flit_in.control.output_port), oh2bin(flit_in.control.vc_id), flit_in.control.valid, flit_in.control.drop);
					
					$finish;
				end

				//
				// check flit didn't originate at this node
				//
				if ((flit_in.debug.xdest==flit_in.debug.xsrc)&&
					(flit_in.debug.ydest==flit_in.debug.ysrc)&&
					!flit_in.control.drop) begin
						$display ("%m: Error: Received flit originated from this node?");
						$finish;
				end
			
				//
				// check flits for each packet are received in order
				//
				if (flit_in.debug.flit_id!=expected_flit_id[current_vc]) begin
					$display ("%m: Error: Out of sequence flit received? (packet generated at %1d,%1d)",
					flit_in.debug.xsrc, flit_in.debug.ysrc);
					$display ("-- Flit ID = %1d, Expected = %1d", flit_in.debug.flit_id, expected_flit_id[current_vc]);
					$display ("-- Packet ID = %1d", flit_in.debug.packet_id);
					$finish;
				end else begin
					//$display ("%m: Rec: Flit ID = %1d, Packet ID = %1d, VC ID=%1d", 
					//flit_in.debug.flit_id, flit_in.debug.packet_id, flit_in.control.vc_id);
				end

				expected_flit_id[current_vc]++;
			

				// count all flits received in measurement period
				if ((flit_in.debug.packet_id>warmup_packets) && (stats.measure_start==-1))  stats.measure_start= sys_time;
				//if (flit_in.debug.packet_id<=warmup_packets+measurement_packets)
				if (stats.measure_start!=-1) stats.flit_count++;

				
				if (flit_in.control.drop == 1'b1) begin

					if (flit_in.control.tail) begin
						// $display ("%m: Tail Rec, Expected = 1");
						expected_flit_id[current_vc]=1;

						if ((flit_in.debug.packet_id>warmup_packets)) begin
							rec_count_dropped++;
						end
					end // if (flit_in.control.tail)				
				end else begin
					// #####################################################################
					// Head of new packet has arrived
					// #####################################################################
					if (flit_in.debug.flit_id==1) begin
						//$display ("%m: new head, current_vc=%1d, inject_time=%1d", current_vc, flit_in.debug.inject_time);
						head_injection_time[current_vc] = flit_in.debug.inject_time;
					end
				  
				  
					// #####################################################################
					// Tail of packet has arrived
					// Remember, latency = (tail arrival time) - (head injection time)
					// #####################################################################
					if (flit_in.control.tail) begin

						// $display ("%m: Tail Rec, Expected = 1");
						expected_flit_id[current_vc]=1;

						if ((flit_in.debug.packet_id>warmup_packets)) begin

							rec_count++;

							// time last measurement packet was received
							stats.measure_end = sys_time;

							//
							// gather latency stats.
							//
							latency = sys_time - head_injection_time[current_vc]; 
							stats.total_latency = stats.total_latency + latency;

							stats.min_latency = min (stats.min_latency, latency);
							stats.max_latency = max (stats.max_latency, latency);

							//TIMA: Display the packets progress
						`ifdef VERBOSE	
							$display ("%m: latency=%1d, sys_time=%1d, head_time[%1d]=%1d", latency, sys_time, current_vc, head_injection_time[current_vc]);
						`endif	
							//
							// display progress estimate
							//
						`ifdef VERBOSE							
							if (rec_count%(measurement_packets/100)==0) 
							$display ("%1d: %m: %1.2f%% complete (this packet's latency was %1d)", sys_time, $itor(rec_count*100)/$itor(measurement_packets), latency);
						`endif
							//
							// sum latencies for different packet distances (and keep total distance travelled by all packets)
							//
							//		  $display ("This packet travelled %1d hops", flit_in.debug.hops);
							stats.total_hops = stats.total_hops + flit_in.debug.hops;

							stats.min_hops = min (stats.min_hops, flit_in.debug.hops);
							stats.max_hops = max (stats.max_hops, flit_in.debug.hops);

							stats.total_lat_for_hop_count[flit_in.debug.hops]=
							stats.total_lat_for_hop_count[flit_in.debug.hops]+latency;
							stats.total_packets_with_hop_count[flit_in.debug.hops]++;

							//
							// bin latencies
							//	
							stats.lat_freq[min(latency, 100)]++;
						end
					end // if (flit_in.control.tail)
				end // (flit_in.control.drop == 1'b1)
			end else begin
				cntrl_out.credit_valid<=1'b0;
			end //if (flit_in.control.valid) begin
		end // if (!rst_n) begin
	end //always@(posedge clk) begin
endmodule
