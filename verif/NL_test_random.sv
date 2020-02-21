/*
 * Uniform random traffic testbench
 * 
 * Instantiates network and random traffic sources
 * 
 */

module NL_test_random ();

	`include "parameters.sv"


	parameter CLOCK_PERIOD = 10;
	

	flit_t flit_in[network_x-1:0][network_y-1:0];
	flit_t flit_out[network_x-1:0][network_y-1:0];
	logic [router_num_vcs_on_entry-1:0] input_full_flag [network_x-1:0][network_y-1:0];
	logic [router_num_vcs_on_entry-1:0] input_empty_flag [network_x-1:0][network_y-1:0];
	chan_cntrl_t cntrl_in [network_x-1:0][network_y-1:0];
	integer rec_count [network_x-1:0][network_y-1:0];
	integer rec_count_dropped [network_x-1:0][network_y-1:0];
	sim_stats_t stats [network_x-1:0][network_y-1:0];
	
	integer packet_inj_per_router [network_x-1:0][network_y-1:0];

	integer tima_packet_receive;// = 0;
	integer tima_packet_dropped;
	integer tima_count_cycle = 0;

	//real    av_lat[network_x-1:0][network_y-1:0];

	genvar  x,y;
	integer i,j,k;
	integer sys_time, total_packets, total_hops, min_latency, max_latency, total_latency;
	integer min_hops, max_hops;
	integer total_rec_count;
	integer total_packet_inj_per_router;

	integer total_lat_for_hop_count [(network_x+network_y):0];
	integer total_packets_with_hop_count[(network_x+network_y):0];
	integer hc_total_packets, hc_total_latency;

	integer lat_freq[1000:0];

	x_coord_t x_cur [network_x-1:0][network_y-1:0];
	y_coord_t y_cur [network_x-1:0][network_y-1:0];
	
	logic clk, rst_n;

	
	
//################################################
//# Clock generator
//################################################	
	initial begin
		clk=0;
	end
	
	always #(CLOCK_PERIOD/2) clk = ~clk;

	always@(posedge clk) begin
		if (!rst_n) begin
			sys_time=0;
		end else begin
			sys_time++;
		end
	end
//################################################  




//#################################################
//# TIMA: Set x_cur, y_cur, and z_cur
//#################################################
	generate
		for (x = 0; x < network_x; x++) begin
			for (y = 0; y < network_y; y++) begin
				initial begin
					x_cur[x][y] = set_x_cur(x);
					y_cur[x][y] = set_y_cur(y);
				end
			end  
		end
	endgenerate
	



//#################################################
//# Network Connection Mesh Architecture
//#################################################
	NL_mesh_network #(.XS(network_x), .YS(network_y), .NP(output_port_radix), .NV(router_num_max_vcs), 
					/*.NVS(router_num_vcs),*/ .channel_latency(channel_latency))
			network 
				(x_cur, 
				y_cur,
				flit_in, 
				flit_out,
				input_full_flag,
				cntrl_in,
				input_empty_flag,
				clk, rst_n);
 
 
 
//#################################################
//# Traffic Sources Generation
//#################################################
	generate
	  for (x=0; x<network_x; x++) begin:xl
		 for (y=0; y<network_y; y++) begin:yl

		 NL_traffic_source #(.nv(router_num_vcs_on_entry),
						   .sel_traffic(sim_traffic_type),	    
						   .xdim(network_x), .ydim(network_y), 
						   .xpos(x), .ypos(y),
					`ifdef DEBUG_PACK_SENT
						   .packet_injected(sim_packet_injected),
					`endif
						   .packet_length(sim_packet_length),
						   //.fixed_length(sim_packet_fixed_length),
						   .rate(sim_injection_rate)
						   )
			  traf_src (.flit_out(flit_in[x][y]), 
						.network_ready(input_full_flag[x][y]),
						.network_empty_flag(input_empty_flag[x][y]),
						.packet_inj_per_router(packet_inj_per_router[x][y]),
						.clk, .rst_n);

		end
	  end
	endgenerate

	
	
// ################################################
// Traffic Sinks analysis
// ################################################
	generate
		for (x=0; x<network_x; x++) begin:xl2
			for (y=0; y<network_y; y++) begin:yl2

				NL_traffic_sink #(.xdim(network_x), .ydim(network_y), .xpos(x), .ypos(y),
								.warmup_packets(sim_warmup_packets), 
							`ifdef DEBUG_PACK_SENT
								.measurement_packets(sim_packet_injected),
							//`else
							//	.measurement_packets(sim_measurement_packets),
							`endif
								.router_num_vcs_on_exit(router_num_vcs_on_exit))
					traf_sink (.flit_in(flit_out[x][y]), 
								.cntrl_out(cntrl_in[x][y]), 
								.rec_count(rec_count[x][y]),
								.rec_count_dropped(rec_count_dropped[x][y]),
								.stats(stats[x][y]), 
								.clk, .rst_n);

			end
		end
	endgenerate

	

//################################################
// All measurement packets must be received before 
// we end the simulation (this includes a drain phase)
//################################################
`ifdef VERBOSE_COUNT
	always@(posedge clk) begin
		//$display("router_num_vcs[`NORTH] = %1d.", router_num_vcs[`NORTH]);
		total_rec_count=0;
		total_packet_inj_per_router=0;
		
		for (i=0; i<network_x; i++) begin
			for (j=0; j<network_y; j++) begin
				total_rec_count=total_rec_count+rec_count[i][j];
				total_packet_inj_per_router = total_packet_inj_per_router+packet_inj_per_router[i][j];
			end
		end
		
		if ((total_rec_count % 64) == 0) begin
			$display("\n\n\n============================================");
			for (i=0; i<network_x; i++) begin
				for (j=0; j<network_y; j++) begin
					$display("REC_COUNT[%1d][%1d] = %1d", i, j, rec_count[i][j]);
				end
			end
			$display("TOTAL: %1d.", total_rec_count);
		end
		
		if ((total_packet_inj_per_router % 64) == 0) begin
			$display("\n\n\n============================================");
				for (i=0; i<network_x; i++) begin
					for (j=0; j<network_y; j++) begin
						$display("SEND_COUNT[%1d][%1d] = %1d", i, j, packet_inj_per_router[i][j]);
					end
				end
			$display("TOTAL: %1d.", total_packet_inj_per_router);
		end
	end
`else
	always@(posedge clk) begin
		//$display("router_num_vcs[`NORTH] = %1d.", router_num_vcs[`NORTH]);
		total_rec_count=0;
		for (i=0; i<network_x; i++) begin
			for (j=0; j<network_y; j++) begin
			//$display("REC_COUNT[%1d][%1d][%1d] = %1d", i, j, m, rec_count[i][j][m]);
			total_rec_count=total_rec_count+rec_count[i][j];
			end
		end
	end
`endif

//`ifdef DEBUG_CC // TIMA Cycle count
	always@(posedge clk) begin
		tima_count_cycle <= tima_count_cycle + 1;
		if (tima_count_cycle % 100 == 0) begin
			//$display ("Total CC: tima_count_cycle = %1d", tima_count_cycle);
		end 
		
		tima_packet_receive=0;
		tima_packet_dropped=0;
		
		for (i=0; i<network_x; i++) begin
			for (j=0; j<network_y; j++) begin
				//$display("REC_COUNT[%1d][%1d][%1d] = %1d", i, j, m, rec_count[i][j][m]);
				tima_packet_receive = tima_packet_receive + rec_count[i][j];
				tima_packet_dropped = tima_packet_dropped + rec_count_dropped[i][j];
			end
		end
	end
//`endif
	
	initial begin

		$display ("******************************************");
		$display ("* Netmaker - Uniform Random Traffic Test *");
		$display ("******************************************");

		total_hops=0;
		total_latency=0;

		//
		// reset
		//
		rst_n=0;
		// reset
		#(CLOCK_PERIOD*20);
		rst_n=1;

		$display ("-- Reset Complete");
		$display ("-- Entering warmup phase (%1d packets per node)", sim_warmup_packets);

`ifdef DUMPTRACE      
		$dumpfile ("/tmp/trace.vcd");
		$dumpvars;
`endif      
      
		// #################################################################
		// wait for all traffic sinks to rec. all measurement packets
		// #################################################################
`ifdef DEBUG_CC
		$display ("** Simulation START %1d **\n", sim_stop_cycle);
		wait (tima_count_cycle>=sim_stop_cycle);
`elsif DEBUG_PACK_SENT
		$display ("** Simulation START %1d **\n", sim_packet_injected);
		wait (((total_rec_count + tima_packet_dropped)>=sim_packet_injected*network_x*network_y) || (tima_count_cycle>=sim_stop_cycle));
`else
		$display ("** Simulation START %1d **\n", sim_measurement_packets);
		wait ((total_rec_count + tima_packet_dropped) >=sim_measurement_packets*network_x*network_y);
`endif

		$display ("** Simulation End **\n");

`ifdef DEBUG_PACK_SENT
		total_packets = sim_packet_injected*network_x*network_y;
`else		
		total_packets = sim_measurement_packets*network_x*network_y;
`endif
		min_latency=stats[0][0].min_latency;
		max_latency=stats[0][0].max_latency;
		min_hops=stats[0][0].min_hops;
		max_hops=stats[0][0].max_hops;

		for (i=0; i<network_x; i++) begin
			for (j=0; j<network_y; j++) begin
				//av_lat[i][j] = $itor(stats[i][j].total_latency)/$itor(rec_count[i][j]);

				total_latency = total_latency + stats[i][j].total_latency;

				total_hops=total_hops+stats[i][j].total_hops;

				min_latency = min(min_latency, stats[i][j].min_latency);
				max_latency = max(max_latency, stats[i][j].max_latency);
				min_hops = min(min_hops, stats[i][j].min_hops);
				max_hops = max(max_hops, stats[i][j].max_hops);
			end
		end

		for (k=min_hops;k<=max_hops;k++) begin
			total_lat_for_hop_count[k] = 0;
			total_packets_with_hop_count[k] = 0;
		end
		
		for (k=0; k<=100; k++) lat_freq[k]=0;
      
		for (i=0; i<network_x; i++) begin
			for (j=0; j<network_y; j++) begin
				for (k=min_hops;k<=max_hops;k++) begin
					total_lat_for_hop_count[k] = total_lat_for_hop_count[k]+stats[i][j].total_lat_for_hop_count[k];
					total_packets_with_hop_count[k] = total_packets_with_hop_count[k]+stats[i][j].total_packets_with_hop_count[k];
				end
				
				for (k=0; k<=100; k++) begin
					lat_freq[k]=lat_freq[k]+stats[i][j].lat_freq[k];
				end
			end
		end


		$display ("");
		$display ("Journey length (hops) :  Av.Latency ");
		$display ("----------------------------------- ");
		hc_total_packets=0;
		hc_total_latency=0;
		for (i=min_hops; i<=max_hops; i++) begin
			$display ("%1d %1.2f => total_lat_for_hop_count = %1d, total_packets_with_hop_count = %1d.", i, $itor(total_lat_for_hop_count[i])/$itor(total_packets_with_hop_count[i]), $itor(total_lat_for_hop_count[i]), $itor(total_packets_with_hop_count[i]));
			hc_total_packets=hc_total_packets+total_packets_with_hop_count[i];
			hc_total_latency=hc_total_latency+total_lat_for_hop_count[i];
		end

		$display ("\n\n");
		$display ("***********************************************************************************");
		$display ("-- Router Parameters NV(%1d), X(%1d), Y(%1d).", router_num_max_vcs, network_x, network_y);	
		$display ("-- Router Parameters NV_N(%1d), NV_E(%1d), NV_S(%1d), NV_W(%1d).", router_num_vcs[`NORTH], router_num_vcs[`EAST], router_num_vcs[`SOUTH], router_num_vcs[`WEST]);	
		$display ("-- Channel Latency = %1d", channel_latency);
		$display ("***********************************************************************************");
		$display ("-- Traffic partner = %1d", sim_traffic_type);
`ifdef	DEBUG_PACK_SENT	
		$display ("-- Measur. packet  = %1d", sim_packet_injected*network_x*network_y);
`else
		$display ("-- Measur. packet  = %1d", sim_measurement_packets*network_x*network_y);
`endif
		$display ("-- Packet Length   = %1d", sim_packet_length);
		$display ("-- Injection Rate  = %1.4f (flits/cycle/node)", sim_injection_rate);
		$display ("-- Average Latency = %1.2f (cycles)", $itor(total_latency)/$itor(total_packets));
		$display ("-- Min. Latency    = %1d, Max. Latency = %1d", min_latency, max_latency);
		$display ("-- Packets Dropped = %1d", tima_packet_dropped);
		$display ("-- Average no. of hops taken by packet = %1.2f hops (min=%1d, max=%1d)", 
					$itor(total_hops)/$itor(total_packets), min_hops, max_hops);
		$display ("***********************************************************************************");
//`ifdef DEBUG_CC
		$display ("-- DEBUG_CC AverageLatency = %1.2f (cycles)", $itor(total_latency)/$itor(tima_packet_receive));
		$display ("-- DEBUG_CC TotalLatency = %1d", total_latency);
		$display ("-- DEBUG_CC PacketReceived = %1d", tima_packet_receive);
		$display ("-- DEBUG_CC PacketsDropped = %1d", tima_packet_dropped);
		$display ("-- DEBUG_CC PacketsSended = %1d", total_packet_inj_per_router);
		$display ("-- DEBUG_CC ClockCycle = %1d", tima_count_cycle);
		
//`endif
		$display ("***********************************************************************************");
		$display ("\n\n");

		// sanity checks
		if (hc_total_packets!=total_packets) begin
			$display ("Error: hc_total_packets=%1d, total_packets=%1d (should be equal)", hc_total_packets, total_packets);
		end else begin
			$display ("Correct: hc_total_packets=%1d, total_packets=%1d (should be equal)", hc_total_packets, total_packets);
		end
		if (hc_total_latency!=total_latency) begin
			$display ("Error: hc_total_latency=%1d, total_latency=%1d (should be equal)", hc_total_latency, total_latency);
		end else begin
			$display ("Correct: hc_total_latency=%1d, total_latency=%1d (should be equal)", hc_total_latency, total_latency);
		end
     
	 
`ifdef MODELSIM
		$stop;
`endif

		$finish;
	end
   
endmodule // NW_test_random
