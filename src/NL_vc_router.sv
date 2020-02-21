/* 
 * VC router
 * 
 */

module NL_vc_router (x_cur, y_cur,
				i_flit_in, i_flit_out,
				i_cntrl_in, i_cntrl_out,
				i_input_full_flag,
				i_input_empty_flag,
				clk, rst_n);


	parameter buf_len = 4;
	parameter NP = 5;
	parameter NV = 1;
	parameter [2:0] NVS [0:4] = '{1, 1, 1, 1, 1}; //{N, E, S, W, T/L}
	
	// numbers of virtual-channels on entry/exit to network?
	parameter router_num_vcs_on_entry = 1;
	parameter router_num_vcs_on_exit = 1;

	
	input x_coord_t x_cur /* synthesis syn_keep = 1 */;
	input y_coord_t y_cur /* synthesis syn_keep = 1 */;



//==================================================================


	// FIFO rec. data from tile/core is full?
	//output  fifo_flags_t [router_num_vcs_on_entry-1:0] i_input_full_flag;
	output  logic [router_num_vcs_on_entry-1:0] i_input_full_flag;
	output  logic [router_num_vcs_on_entry-1:0] i_input_empty_flag;

	// link data and control
	input   flit_t i_flit_in [NP-1:0];
	output  flit_t i_flit_out [NP-1:0];
	input   chan_cntrl_t i_cntrl_in [NP-1:0];
	output  chan_cntrl_t i_cntrl_out [NP-1:0];
	input   clk, rst_n;


	// Credit count for each VC at each output port
	//logic [NP-1:0][NV-1:0][clogb2(buf_len+1)-1:0] vc_credits;

	logic [NP-1:0][NV-1:0] switch_req;//, spec_switch_req;
	logic [NP-1:0][NV-1:0] x_vc_status;
	logic [NP-1:0] x_push;
	logic [NP-1:0][NV-1:0] x_pop;


	flit_t x_flit_xbarin[NP-1:0];
	//flit_t x_flit_xbarin_pipe[NP-1:0];
	flit_t x_flit_xbarout[NP-1:0];


	vc_index_t x_vc_id [NP-1:0];
	vc_index_t x_select [NP-1:0];

	//flit_t [NP-1:0] x_flit_bufout;
	fifo_flags_t [NV-1:0] x_flags [NP-1:0];

	logic [NV-1:0] 	  x_allocated_vc [NP-1:0][NV-1:0];
	logic [NV-1:0] 	  vc_for_blocked_check [NP-1:0][NV-1:0];
	logic [NP-1:0][NV-1:0] x_allocated_vc_valid;
	//logic  x_route_valid[NP-1:0][NV-1:0];   
	logic [NP-1:0][NV-1:0][NV-1:0] x_vc_new;
	logic [NP-1:0][NV-1:0] 	  x_vc_new_valid;

	output_port_t x_output_port_for_vc [NP-1:0][NV-1:0];
	output_port_t x_output_port_for_sw [NP-1:0][NV-1:0];
	//vc_t [NP-1:0] x_free_vc;

	logic [NP-1:0][NP-1:0] xbar_select; 
	logic [NP-1:0][NV-1:0] vc_request;             // VC request from each input VC
	//logic [NP-1:0] 	 vc_allocated_at_output;            // for each output port, has a VC been allocated?
	logic [NP-1:0][NV-1:0] allocated_vc_blocked, check_full_vc;
	logic [NP-1:0][NV-1:0] switch_grant;
	logic [NP-1:0][NV-1:0] input_vc_mux_sel;
	logic [NP-1:0] 	 output_used; // output channel used on this cycle?
	logic [NP-1:0] 	 output_requested; //outgoing_blocked, output_requested;
	//logic [NP-1:0][NV-1:0] pipereg_ready, pipereg_valid, pipereg_push, pipereg_pop;

	//flit_t [NP-1:0][NV-1:0] pipereg_data_in, pipereg_data_out;
	//flit_t [NP-1:0][NV-1:0] routed_flit_buffer_out, flit_buffer_out;
	flit_t [NP-1:0][NV-1:0] flit_buffer_out;


	// **** unrestricted VC free pool/allocation ****
	logic [NP-1:0][NV-1:0] vc_alloc_status;         // which output VCs are free to be allocated
	logic [NP-1:0][NV-1:0] vc_allocated;            // indicates which VCs were allocated on this clock cycle
	logic [NP-1:0][NV-1:0][NV-1:0] vc_requested;    // which VCs were selected to be requested at each input VC?
	logic [NP-1:0][NV-1:0] vc_empty;        // is downstream FIFO associated with VC empty?
	logic [NP-1:0][NV-1:0][NV-1:0] flit_vcalloc_mask;

		
	genvar 		  i,j;

	integer db_out_used, db_in_popped, p,v;

	logic rt_presel_sel[3:0];
//-------------------------------------------------------------------------------------------------------------------------
	// INSTANCIACAO DO PRESELECT DA CONGESTAO
	NL_route_preselect #(.NV(NV), .NP(NP))
		rt_presel (.credit_valid(i_cntrl_in),
				   .flit_valid(output_used),
				   .flit(x_flit_xbarout),
				   .select(rt_presel_sel),
				   .clk,
				   .rst_n );



// *******************************************************************************
// output ports (Credit-Based Flow Control)
// *******************************************************************************
	generate
		for (i=0; i<NP; i++) begin:output_ports
			//      
			// Free VC pools 
			//
			if (i==`TILE) begin
				//
				// may have less than a full complement of VCs on exit from network
				//
				NL_vc_free_pool #(.num_vcs_local(router_num_vcs_on_exit), .num_vcs_global(NV)) 
					vcfreepool
							(.flit(x_flit_xbarout[i]), 
							.valid(output_used[i]),
							.vc_alloc_status(vc_alloc_status[i]),
							.vc_allocated(vc_allocated[i]),
							.vc_empty(vc_empty[i]),
							.clk, .rst_n);
			end else begin
				NL_vc_free_pool #(.num_vcs_local(NVS[i]), .num_vcs_global(NV)) 
					vcfreepool
							(.flit(x_flit_xbarout[i]), 
							.valid(output_used[i]),
							.vc_alloc_status(vc_alloc_status[i]),
							.vc_allocated(vc_allocated[i]),
							.vc_empty(vc_empty[i]),
							.clk, .rst_n);
			end // else: !if(i==`TILE)

			//
			// Flow Control 
			//
			NL_vc_fc_out #(.num_vcs(NV), .nvs(NVS[i]), .init_credits(buf_len))
				fcout 
					(.flit(x_flit_xbarout[i]), 
					.flit_valid(output_used[i]),
					.channel_cntrl_in(i_cntrl_in[i]),
					.vc_status(x_vc_status[i]),
					.vc_empty(vc_empty[i]),
					//.vc_credits(vc_credits[i]), 
					.clk, .rst_n);

			// indicate to upstream router that new buffer is free when
			// we remove flit from an input FIFO (credit-based flow-control)
			//CREDIT_FLOW_CONTROL
			always@(posedge clk) begin
				if (!rst_n) begin
					i_cntrl_out[i].credit_valid<=1'b0;
				end else begin
					//
					// ensure 'credit' is registered before it is sent to the upstream router
					//
					// send credit corresponding to flit sent from this input port
					i_cntrl_out[i].credit<=x_select[i];
					i_cntrl_out[i].credit_valid<=|x_pop[i];
				end
			end
		end
	endgenerate
// *******************************************************************************




// *******************************************************************************
// input ports (VC buffers and VC registers)
// *******************************************************************************
	generate
		for (i=0; i<router_num_vcs_on_entry; i++) begin:vcsx
			assign i_input_full_flag[i]  = x_flags[`TILE][i].full;//x_flags[`TILE][i].full; // TILE input FIFO[i] is full?
			assign i_input_empty_flag[i]  = x_flags[`TILE][i].empty;//x_flags[`TILE][i].full; // TILE input FIFO[i] is full?
		end

		for (i=0; i<NP; i++) begin:input_ports

			// should support .nv and .num_vcs (e.g. for tile input that may only
			// support a single input VC)
			// input port 'i'
				NL_vc_input_port #(.num_vcs(NV),
								.NV(NV),
								.nvs(NVS[i]),							
								.buffer_length(buf_len)) 
					inport
						   (.x_cur(x_cur), 
							.y_cur(y_cur), 
							.push(x_push[i]), 
							.pop(x_pop[i]),
							.data_in(i_flit_in[i]), 
							.vc_id(x_vc_id[i]),
							.select(input_vc_mux_sel[i]),
							.data_out(x_flit_xbarin[i]),
							.flags(x_flags[i]),
							.allocated_vc(x_allocated_vc[i]), 
							.allocated_vc_valid(x_allocated_vc_valid[i]),  
							.vc_new(x_vc_new[i]), 
							.vc_new_valid(x_vc_new_valid[i]),
							.flit_buffer_out(flit_buffer_out[i]),
							.rt_presel_sel(rt_presel_sel),  // INSTANCIADO PARA TESTES			
							.clk, .rst_n);

      //
      // output port fields 
      //
      for (j=0; j<NV; j++) begin:allvcs2
		assign x_output_port_for_vc[i][j] = flit_buffer_out[i][j].control.output_port;
		assign x_output_port_for_sw[i][j] = flit_buffer_out[i][j].control.output_port;
      end
      
      // *** DATA IN *** //
	  //assign x_push[i]=i_flit_in[i].control.valid
      assign x_push[i]=i_flit_in[i].control.valid;// & (elf_stop_pop[i][0] | elf_stop_pop[i][1]);
      
      // cast result of oh2bin to type of x_vc_id[i]
      assign x_vc_id[i]= vc_index_t'(oh2bin(i_flit_in[i].control.vc_id));

	  // VC blocked check already made before request
	  assign x_pop[i] = switch_grant[i];// & !elf_stop_pop[i][0] & !elf_stop_pop[i][1]; /*& stop_x_pop[i];*/
	  
      // convert one-hot select at input port 'i' to binary for vc_input_port
      assign x_select[i]= vc_index_t'(oh2bin(input_vc_mux_sel[i]));
      
      
      //**************************************************************************
      // Switch and Virtual-Channel allocation requests
      //**************************************************************************
      for (j=0; j<NV/*NVS[i]*/; j++) begin:reqs
		 //
		 // VIRTUAL-CHANNEL ALLOCATION REQUESTS
		 //
		assign vc_request[i][j]= (NL_route_valid_input_vc(i,j)) ? 
						!x_flags[i][j].empty & !x_allocated_vc_valid[i][j] : 1'b0;
			  
		//
		// SWITCH ALLOCATION REQUESTS
		//

		// Full VC buffer check. Perform check prior to making a switch request or
		// later at output port. Schedule-quality/clock-cycle trade-off
		assign check_full_vc[i][j]=!allocated_vc_blocked[i][j];

		assign switch_req[i][j] = (NL_route_valid_input_vc(i,j)) ? 
									!x_flags[i][j].empty && 
									x_allocated_vc_valid[i][j] &&
									check_full_vc[i][j] : 1'b0;

		assign vc_for_blocked_check[i][j] = x_allocated_vc[i][j];

		// is current VC blocked?
		// - VC allocation happened in previous clock cycle so don't have to
		//   worry about new VCs. Just look at status of allocated VC.
		NL_unary_select_pair #(i, NP, NV) 
			blocked_mux 
						(.output_port_sw(x_output_port_for_sw[i][j]),
						.vc_blocked_chk(vc_for_blocked_check[i][j]),
						.vc_status_chk(x_vc_status), 
						.vc_full_blocked(allocated_vc_blocked[i][j]));
	       
      end // block: reqs
      
	end // block: input_ports
      
   endgenerate
// *******************************************************************************




// *******************************************************************************
// virtual-channel allocation logic
// *******************************************************************************
	generate
		NL_vc_unrestricted_allocator #(.np(NP), .nv(NV))
				vcalloc
						(.req(vc_request),
						.output_port(x_output_port_for_vc),
						.vc_status(vc_alloc_status),
						.vc_new(x_vc_new),
						.vc_new_valid(x_vc_new_valid),
						.vc_allocated(vc_allocated),
						.vc_requested(vc_requested),
						//.flit(flit_buffer_out),
						.flit_vcalloc_mask(flit_vcalloc_mask),
						.clk, .rst_n);
					
		for (i=0; i<NP; i++) begin
			for (j=0; j<NV; j++) begin
				assign flit_vcalloc_mask[i][j] = flit_buffer_out[i][j].control.vcalloc_mask;
			end
		end
	endgenerate	
// *******************************************************************************
	

	

// *******************************************************************************
// switch-allocation logic
// *******************************************************************************	
	generate
		// for pipelined VC/switch allocation 
		NL_vc_switch_allocator #(.NP(NP), .NV(NV))
			swalloc
					(.req(switch_req), 
					.output_port(x_output_port_for_sw),
					.grant(switch_grant), 
					.vc_mux_sel(input_vc_mux_sel),
					.xbar_select(xbar_select),
					.any_request_for_output(output_requested), 
					.clk, .rst_n);
	endgenerate
// *******************************************************************************




// *******************************************************************************
// Crossbar
// *******************************************************************************	      
	generate
		NL_crossbar #(.dtype_t(flit_t), .n(NP)) 
			myxbar 
				(x_flit_xbarin, xbar_select, x_flit_xbarout); 
	endgenerate
// *******************************************************************************




// *******************************************************************************
// Output port logic
// *******************************************************************************
	generate
		for (i=0; i<NP; i++) begin:outports

			// output is valid if any request for this output was made
			// (request can only be made if 1. VC is already allocated
			//  and 2. vc is not blocked (full).
			//
			// What about two requests at same input port (different VCs)
			// to different output ports?
			// - 'output_requested' is request to second stage of arbiters
			//   in switch allocator so this is OK.
			assign output_used[i] = output_requested[i];

			always_comb 
			begin
				i_flit_out[i]=x_flit_xbarout[i];
				i_flit_out[i].control.valid=output_used[i];
			end

		end // block: outports
	endgenerate
// *******************************************************************************


`ifdef DEBUG
// synopsys translate_off
/*  ----------------------------------------------------------------------------------
*  assert (only unallocated VCs are allocated to waiting packets)
*  -----------------------------------------------------------------------------------
*/
	always@(posedge clk) begin
		if (!rst_n) begin
			//TO DO ...
		end else begin
			for (p=0; p<NP; p++) begin
				for (v=0; v<NV; v++) begin
					if (x_vc_new_valid[p][v]) begin
					// check x_vc_new is free to be allocated
						if (!vc_alloc_status[oh2bin(x_output_port_for_vc[p][v])][oh2bin(x_vc_new[p][v])]) begin
							$display ("%m: Error: Newly allocated VC is already allocated to another packet");
							$display ("Input port=%1d, VC=%1d", p,v);
							$display ("Requesting Output Port %b (%1d)", x_output_port_for_vc[p][v], oh2bin(x_output_port_for_vc[p][v]));
							$display ("VC requested  %b ", vc_requested[p][v]);
							$display ("x_vc_new      %b ", x_vc_new[p][v]);
							$finish;
						end
					end
				end
			end
		end
	end
// synopsys translate_on

   
// synopsys translate_off
/*  ----------------------------------------------------------------------------------
*  assert (no. of flits leaving router == no. of flits dequeued from input FIFOs)
*  -----------------------------------------------------------------------------------
*/
   always@(posedge clk) begin
      if (!rst_n) begin
      end else begin
	 db_out_used = 0;
	 db_in_popped = 0;
	 // count number of outputs used.
	 for (p=0; p<NP; p++) begin
	    if (output_used[p]) db_out_used++;
	 end
	 // count number of flits removed from input fifos
	 for (p=0; p<NP; p++) begin
	    for (v=0; v<NV; v++) begin
	       if (x_pop[p][v]) db_in_popped++;
	    end
	 end
	 if (db_out_used!=db_in_popped) begin
	    $display ("%m: Error: more flits sent on output than dequeued from input FIFOs!");
	    for (p=0; p<NP; p++) begin
	       $display ("-------------------------------------------------");
	       $display ("Input Port=%1d", p);
	       $display ("-------------------------------------------------");
	       for (v=0; v<NV; v++) begin
		  $write ("VC=%1d: ", v);
		  if ((switch_req[p][v])||/*(spec_switch_req[p][v])||*/(switch_grant[p][v])) 
		    $write ("[OUTP=%1d]", oh2bin(x_output_port_for_sw[p][v]));
		  if (switch_req[p][v]) $write ("(Switch_Req)");
		  //if (spec_switch_req[p][v]) $write ("(Spec_Switch_Req)");
		  if (switch_grant[p][v]) $write ("(Switch_Grant)");
		  if (x_vc_new_valid[p][v]) $write ("(New VC Alloc'd)");
		  
		  $display ("");
	       end
	    end // for (p=0; p<NP; p++)
	    $display ("-------------------------------------------------");
	    $display ("Output Used=%b", output_used);
	    $display ("-------------------------------------------------");
//	    $finish;
	 end // if (db_out_used!=db_in_popped)
      end
   end // always@ (posedge clk)
// synopsys translate_on
`endif

   
endmodule // simple_router
