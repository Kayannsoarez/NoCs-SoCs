/*
 *  *** NOT FOR SYNTHESIS ***
 * 
 * Random Packet Source for Open-Loop Measurement (see Dally/Towles p.450 and p.488)
 * 
 * - The injection time appended to packets is independent of activity in the network.
 *
 * - The random packet injection process is not paused while a packet is written to the
 *   input FIFO (which may take a number of cycles). If a new packet is generated 
 *   during this time it is copied to the FIFO as soon as possible.
 * 
 */

module NL_traffic_source(flit_out, 
						network_ready,
						network_empty_flag,
						packet_inj_per_router,
						clk, rst_n);

	parameter nv = 4; // number of virtual-channels available on entry to network

	parameter xdim = 4; // mesh network size
	parameter ydim = 4;

	parameter xpos = 0; // random source is connected to which router in mesh?
	parameter ypos = 0;

`ifdef DEBUG_PACK_SENT
	parameter packet_injected = 4;
`endif
	parameter packet_length = 3;
	parameter rate = 0.1234; // flit injection rate (flits/cycle/random source)
	parameter sel_traffic = 0; // Select traffic (Uniform (0), Transpose1 (1), Transpose2 (2), Bit-complement (3), Shuffle (4))
	//parameter fixed_length = 1;
	parameter p = 10000*rate/packet_length;

	output flit_t flit_out;
	input [nv-1:0] network_ready;
	input [nv-1:0] network_empty_flag;
	//output integer qtd_packet_injected;
	output integer packet_inj_per_router;

	//input fifo_flags_t [nv-1:0] network_ready;
	input clk, rst_n;

//==========================================================================================
	integer sys_time, i_time, seed, inject_count, flit_count;
	logic   fifo_ready;
	logic   push, pop;
	//logic [nv-1:0] network_ready_test;

	flit_t data_in, data_out, d; //routed, d;
	fifo_flags_t fifo_flags;

	//integer xdest, ydest, zdest;
	logic [2:0] xdest;
	logic [2:0] ydest;
	logic [5:0] router_id_src;
	logic [5:0] router_id_dst;
	
	integer injecting_packet;
	integer flits_buffered, flits_sent;
	integer length;
	integer current_vc; //, blocked;
	integer qtd_packet;
	

`ifndef DEBUG
   !!!! You must set the DEBUG switch if you are going to run a simulation !!!!
`endif
     
	//
	// FIFO connected to network input 
	//
	NL_traffic_source_fifo #(.size(packet_length*10), .fifo_elements_t(flit_t))
			source_fifo
					(.push(push),
					.pop(pop),  
					.data_in(data_in), 
					.data_out(data_out),
					.flags(fifo_flags), .clk, .rst_n);
	   
   
	always_comb begin
	

		flit_out = data_out;
		
		if (flit_out.control.head == 1'b1) begin
		
			flit_out.control.valid = ~network_ready[oh2bin(data_out.control.vc_id)] && network_empty_flag[oh2bin(data_out.control.vc_id)] && !fifo_flags.empty ;
			
			pop = !fifo_flags.empty && ~network_ready[oh2bin(data_out.control.vc_id)] && network_empty_flag[oh2bin(data_out.control.vc_id)] ;
				
		end else begin
		
			flit_out.control.valid = ~network_ready[oh2bin(data_out.control.vc_id)] && !fifo_flags.empty /*&& ~input_elf_stop_pop[oh2bin(data_out.control.vc_id)]*/;

			pop = 	!fifo_flags.empty && ~network_ready[oh2bin(data_out.control.vc_id)] ;
		
		end

	end

	//
	// Generate and Inject Packets at Random Intervals to Random Destinations
	//
	always@(posedge clk) begin
		if (!rst_n) begin

			current_vc=0;

			flits_buffered=0;
			flits_sent=0;

			injecting_packet=0;
			sys_time=0;
			i_time=0;
			inject_count=0;
			flit_count=0;

			fifo_ready=1;

			push=0;
			
			qtd_packet=0;

		end else begin

			if (~network_ready[current_vc]===1'bx) begin
				$write ("Error: network_ready FULL = %b", network_ready[current_vc]);
				$finish;
			end

		
			//if (!fifo_flags.empty && ~network_ready[oh2bin(data_out.control.vc_id)] && hotspot) flits_sent++;
			// Check the pop condition that I have put to modify this IF... in the end of the IF()
			if (!fifo_flags.empty && ~network_ready[oh2bin(data_out.control.vc_id)] && pop) begin
				flits_sent++;
				packet_inj_per_router = flits_sent/packet_length;
			end
			if (push) flits_buffered++;
		 
			//
			// start buffering next flit when there is room in FIFO
			//
		`ifdef DEBUG_PACK_SENT	
			if ((flits_buffered-flits_sent)<=packet_length && flits_sent < (packet_injected-1)*packet_length) begin
		`else
			if ((flits_buffered-flits_sent)<=packet_length) begin
		`endif
			fifo_ready = 1;
			end

			if (fifo_ready) begin
				while ((i_time!=sys_time)&&(injecting_packet==0)) begin
					// **********************************************************
					// Random Injection Process
					// **********************************************************
					// (1 and 10000 are possible random values)
					if ($dist_uniform(seed, 1, 10000)<= p) begin
						injecting_packet++;
					end

					i_time++;

				end // while (!injecting_packet && (i_time!=sys_time))
			end

			if (injecting_packet && !fifo_ready) begin
				assert (flit_count==0) else $fatal;
			end
	 
			if (fifo_ready && injecting_packet) begin

				// random source continues as we buffer flits in FIFO 
				if ($dist_uniform(seed, 1, 10000)<=p) begin
				   injecting_packet++;
				end
				i_time++;
				
				flit_count++;
				
				push<=1'b1;

				//
				// Send Head Flit
				//
				if (flit_count==1) begin
				   d='0;
				   
				   inject_count++;
				   
				   case (sel_traffic)
					0: // Uniform Random
						begin
							// set random displacement to random destination
							//$display("Uniform random");
							xdest = $dist_uniform (seed, 0, xdim-1);
							ydest = $dist_uniform (seed, 0, ydim-1);
							
							while ((xpos==xdest)&&(ypos==ydest)) begin
								// don't send to self...
								xdest = $dist_uniform (seed, 0, xdim-1);
								ydest = $dist_uniform (seed, 0, ydim-1);
							end
						end
					
					
					1: //Bit-complement
						begin

						end

						
					2: //Shuffle
						begin
							
						end	

					endcase

			   
				d.debug.xdest=xdest;
				d.debug.ydest=ydest;
				d.debug.xsrc=xpos;
				d.debug.ysrc=ypos;


				d.control.x_dest=xdest;//xdest-xpos;
				d.control.y_dest=ydest;//ydest-ypos;

`ifdef RT_NOCFT
				d.control.vn ='0;
				d.control.drop = 1'b0;				
`endif
		
				d.control.head=1'b1;

				// ************************************************************
				// Packets are injected on VCs selected in a round-robin fashion
				// (If router_num_vcs_on_entry==1, current_vc is always 0)
				// ************************************************************
`ifdef RT_NOCFT
				d.control.vc_id=2'b01;
				d.control.vcalloc_mask=2'b01; // obviously needs to be set by core/user
`else				
				current_vc++; if (current_vc==nv) current_vc=0;

				d.control.vc_id=1'b1 << current_vc;
						
				d.control.vcalloc_mask='1; // obviously needs to be set by core/user
`endif	   
				d.control.tail = 1'b0;

				// ************************************************************
				// determine packet length
				// for fixed length packets, length = 'packet_length' parameter (always)
				// ************************************************************
				length = packet_length;

	    end else begin
	        d.control.head = 1'b0;
	    end
	    
			//
			// add debug information to flit
			//
			d.debug.inject_time = i_time;
			d.debug.flit_id = flit_count;
			d.debug.packet_id = inject_count;
			d.debug.hops = 0;

			//
			// Send Tail Flit
			//
			if (flit_count==length) begin
				// inject tail
				d.control.tail = 1'b1;

				injecting_packet--;	       
				flit_count=0;
				
				qtd_packet++;
				//packet_inj_per_router = qtd_packet;
				//
				// wait for room in FIFO before generating next packet
				//
				// if ((flits_buffered-flits_sent)>=packet_length) begin
				fifo_ready = 0;
			end
	    
	 end else begin // if (injecting_packet)
	    push<=1'b0;
	 end
	 
	 sys_time++;
	 
	 data_in<=d;
	 
      end // else: !if(!rst_n)
   end

   initial begin
      // we don't want any traffic sources to have the same 
      // random number seed!
      seed = xpos*50+ypos;
	  //sending_flits = 0;
   end
   
endmodule // NW_random_source
