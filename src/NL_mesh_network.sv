module NL_mesh_network (x_cur, y_cur, din, dout, 
						input_full_flag, 
						cntrl_in, 
						input_empty_flag,
						clk, rst_n);
   
	parameter XS=4;
	parameter YS=4;
	parameter NP=5;
	parameter NV=2;
	
	`include "parameters.sv"

	input   clk, rst_n;
	input   chan_cntrl_t cntrl_in [XS-1:0][YS-1:0]; 
	input   flit_t din[XS-1:0][YS-1:0];

	output	flit_t dout[XS-1:0][YS-1:0];
	output	logic [router_num_vcs_on_entry-1:0] input_full_flag [XS-1:0][YS-1:0];
	output	logic [router_num_vcs_on_entry-1:0] input_empty_flag [XS-1:0][YS-1:0];	
	
	
`ifdef DEBUG	
	// record link utilisation
	// link_util[x][y][n] records activity of link attached to output port N of router at position (X, Y, Z)  
	integer link_util [XS-1:0][YS-1:0][NP-1:0];
	
	integer expected [XS-1:0][YS-1:0][NP-1:0][NV-1:0];
`endif

	// X, Y position
	input x_coord_t x_cur [XS-1:0][YS-1:0];
	input y_coord_t y_cur [XS-1:0][YS-1:0];

	// network connections
	flit_t	 i_flit_in   [XS-1:0][YS-1:0][NP-1:0];
	flit_t	 i_flit_in_  [XS-1:0][YS-1:0][NP-1:0];  
	flit_t	 i_flit_out  [XS-1:0][YS-1:0][NP-1:0];
	flit_t	 i_flit_out_ [XS-1:0][YS-1:0][NP-1:0];


	chan_cntrl_t  i_cntrl_in  [XS-1:0][YS-1:0][NP-1:0];
	chan_cntrl_t  i_cntrl_out [XS-1:0][YS-1:0][NP-1:0];

	reg clk_g [XS-1:0][YS-1:0];

	integer i,j,k,l;
	genvar x,y,p;//,b;
	
   
	
	// *********************************************************
	// implement router-level clock gating if requested
	// *********************************************************
	//
	generate
		for (y=0; y<YS; y=y+1) begin:ycg
			for (x=0; x<XS; x=x+1) begin:xcg
				// no router level clock gating, router clock = global clock
				always@(clk) begin
					clk_g[x][y]<=clk;
				end
			end // block: xcg
		end // block: ycg
	endgenerate
	// *********************************************************

	
	generate
		for (y=0; y<YS; y=y+1) begin:yl
			for (x=0; x<XS; x=x+1) begin:xl
				//###########################
				// make network connections
				//###########################

				// tile port - external interface
				assign i_flit_in[x][y][`TILE] = din[x][y]; 

				// START CREDIT_FLOW_CONTROL
				assign i_cntrl_in[x][y][`TILE].credit = cntrl_in[x][y].credit; //'0; 
				// dequeue of tile input FIFO
				assign i_cntrl_in[x][y][`TILE].credit_valid = cntrl_in[x][y].credit_valid; 
				//END CREDIT_FLOW_CONTROL	
				 
				assign dout[x][y]=i_flit_out[x][y][`TILE];

				// north port
				if (y==0) begin
					assign i_flit_in[x][y][`NORTH]  = '0; 
					assign i_cntrl_in[x][y][`NORTH] = '0; 
				end else begin	    
					assign i_flit_in[x][y][`NORTH]  = i_flit_out[x][y-1][`SOUTH];
					assign i_cntrl_in[x][y][`NORTH] = i_cntrl_out[x][y-1][`SOUTH];
				end

				// east port
				if (x==XS-1) begin
					assign i_flit_in[x][y][`EAST]   = '0; 
					assign i_cntrl_in[x][y][`EAST]  = '0; 
				end else begin
					assign i_flit_in[x][y][`EAST]   = i_flit_out[x+1][y][`WEST];
					assign i_cntrl_in[x][y][`EAST]  = i_cntrl_out[x+1][y][`WEST];
				end

				// south port
				if (y==YS-1) begin
					assign i_flit_in[x][y][`SOUTH]  = '0;
					assign i_cntrl_in[x][y][`SOUTH] = '0;
				end else begin
					assign i_flit_in[x][y][`SOUTH]  = i_flit_out[x][y+1][`NORTH];
					assign i_cntrl_in[x][y][`SOUTH] = i_cntrl_out[x][y+1][`NORTH];
				end

				// west port
				if (x==0) begin
					assign i_flit_in[x][y][`WEST]   = '0;
					assign i_cntrl_in[x][y][`WEST]  = '0;
				end else begin
					assign i_flit_in[x][y][`WEST]   = i_flit_out[x-1][y][`EAST];
					assign i_cntrl_in[x][y][`WEST]  = i_cntrl_out[x-1][y][`EAST];
				end


				for (p=0; p<NP; p++) begin:prts
					always_comb begin
						i_flit_in_[x][y][p] = i_flit_in[x][y][p];
						// Add one to hop count as flit enters router
						if (i_flit_in[x][y][p].control.valid) begin
						`ifdef DEBUG
							i_flit_in_[x][y][p].debug.hops = i_flit_in[x][y][p].debug.hops+1;
						`endif
						end
					end
				end

				// ###################################
				// Channel (link) between routers -    ** NOT FROM ROUTER TO TILE **
				// ###################################
				// i_flit_out_ -> CHANNEL -> i_flit_out
				//
				for (p=0; p<NP; p++) begin:prts2
					if (p==`TILE) begin
						// router to tile is a local connection
						assign i_flit_out[x][y][p]=i_flit_out_[x][y][p];
					end else begin
						NL_pipelined_channel #(.reg_t(flit_t), .stages(channel_latency)) channel 
						(.data_in(i_flit_out_[x][y][p]), 
						.data_out(i_flit_out[x][y][p]), 
						.clk, .rst_n);
					end
				end
	 
				// ###################################
				// Router
				// ###################################
				// # parameters for router are read from parameters.v
					NL_router #(.NP(5))
						node_2d
							(x_cur[x][y],
							y_cur[x][y],
							i_flit_in_[x][y][4:0], 
							i_flit_out_[x][y][4:0], 
							i_cntrl_in[x][y][4:0], 
							i_cntrl_out[x][y][4:0],
							input_full_flag[x][y],
							input_empty_flag[x][y],
							clk_g[x][y],
							rst_n);

`ifdef DEBUG
				// START Debug
				for (p=0; p<NP; p++) begin:prts3
					always@(posedge clk) begin
						if (!rst_n) begin
						
						end else begin
							if (i_flit_out_[x][y][p].control.valid) begin
								// link utilised
								link_util[x][y][p]++;
							end

						`ifdef VERBOSE
							if (i_flit_out_[x][y][p].control.valid) begin
								$display ("%1d: Router(%1d, %1d, OUT port=%1d) : Packet (%1d), flit (%1d) from (%1d, %1d) destined for (%1d, %1d), NEW_DEST=(%1d, %1d), HOPS=%1d, VALID=%1d, HEAD=%1d, TAIL=%1d, VN=%1d, VC=%1d",
									$time, x,y,p, 
									i_flit_out_[x][y][p].debug.packet_id,
									i_flit_out_[x][y][p].debug.flit_id,
									i_flit_out_[x][y][p].debug.xsrc,
									i_flit_out_[x][y][p].debug.ysrc,
									i_flit_out_[x][y][p].debug.xdest,
									i_flit_out_[x][y][p].debug.ydest,
									i_flit_out_[x][y][p].control.x_dest,
									i_flit_out_[x][y][p].control.y_dest,
									i_flit_out_[x][y][p].debug.hops,
									i_flit_out_[x][y][p].control.valid,			
									i_flit_out_[x][y][p].control.head,
									i_flit_out_[x][y][p].control.tail,
									i_flit_out_[x][y][p].control.vn,
									oh2bin(i_flit_out_[x][y][p].control.vc_id));
							end
						`endif		     
							if (i_flit_in_[x][y][p].control.valid) begin
						`ifdef VERBOSE							
								$display ("%1d: Router(%1d, %1d, IN  port=%1d) : Packet (%1d), flit (%1d) from (%1d, %1d) destined for (%1d, %1d), NEW_DEST=(%1d, %1d), HOPS=%1d, VALID=%1d, HEAD=%1d, TAIL=%1d, VN=%1d, VC=%1d",
									$time, x,y,p, 
									i_flit_in_[x][y][p].debug.packet_id,
									i_flit_in_[x][y][p].debug.flit_id,
									i_flit_in_[x][y][p].debug.xsrc,
									i_flit_in_[x][y][p].debug.ysrc,
									i_flit_in_[x][y][p].debug.xdest,
									i_flit_in_[x][y][p].debug.ydest,
									i_flit_in_[x][y][p].control.x_dest,
									i_flit_in_[x][y][p].control.y_dest,
									i_flit_in_[x][y][p].debug.hops,
									i_flit_in_[x][y][p].control.valid,								
									i_flit_in_[x][y][p].control.head,
									i_flit_in_[x][y][p].control.tail,
									i_flit_in_[x][y][p].control.vn,
									oh2bin(i_flit_in_[x][y][p].control.vc_id));
						`endif
		     
								// check flit id. sequences are valid for each VC		     
								if (i_flit_in_[x][y][p].debug.flit_id !=expected[x][y][p][oh2bin(i_flit_in_[x][y][p].control.vc_id)]) begin
									$display ("%1d: Error: x=%1d, y=%1d, p=%1d, vc=%1d: flit_id=%1d, expected=%1d", $time, 
										x,y,p, oh2bin(i_flit_in_[x][y][p].control.vc_id), 
										i_flit_in_[x][y][p].debug.flit_id,
										expected[x][y][p][oh2bin(i_flit_in_[x][y][p].control.vc_id)]);
						
									$display ("Flit originated from (%1d, %1d) and was destined for (%1d, %1d), HOPS=%1d, VALID=%1d, HEAD=%1d, TAIL=%1d, VC=%1d",
										i_flit_in_[x][y][p].debug.xsrc,
										i_flit_in_[x][y][p].debug.ysrc,
										i_flit_in_[x][y][p].debug.xdest,
										i_flit_in_[x][y][p].debug.ydest,
										i_flit_in_[x][y][p].debug.hops,
										i_flit_in_[x][y][p].control.valid,
										i_flit_in_[x][y][p].control.head,
										i_flit_in_[x][y][p].control.tail,
										oh2bin(i_flit_in_[x][y][p].control.vc_id)									
										);
									$finish;
								end
		     
								if (i_flit_in_[x][y][p].control.tail) begin
									expected[x][y][p][oh2bin(i_flit_in_[x][y][p].control.vc_id)]=1;
								end else begin
									expected[x][y][p][oh2bin(i_flit_in_[x][y][p].control.vc_id)]++;
								end
							end //(i_flit_in_[x][y][p].control.valid)
						end // if (!rst_n) begin
					end // always@(posedge clk) begin
				end // for prts3
	`endif
			end // for x
		end // for y 
	endgenerate
   
`ifdef DEBUG
	initial begin
		for (i=0; i<XS; i++) begin
			for (j=0; j<YS; j++) begin
				for (k=0; k<NP; k++) begin
					link_util[i][j][k]=0;
					for (l=0; l<NV; l++) begin
						expected[i][j][k][l]=1;
					end
				end
			end
		end
		
		assert (output_port_radix==5) else begin
			$display ("\n\nError: You must configure a 7 output_port_radix router in order to build a mesh 2D/3D network!");
			$display ("Parameter 'output_port_radix=%1d'\n\n", output_port_radix);
			$fatal;
		end
	end // initial begin
`endif
      
endmodule 
