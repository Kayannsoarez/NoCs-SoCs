module NL_vc_input_port(x_cur, y_cur, push, pop, data_in, vc_id, select, 
					// incoming newly granted/allocated VCs and valid bits
					vc_new, vc_new_valid,
					data_out, flags, flit_buffer_out,
					// currently allocated VCs and valid bits
					allocated_vc, allocated_vc_valid, rt_presel_sel,  // ADICIONADO SE BUGAR TIRE
					clk, rst_n);

	// number of virtual channels
	parameter num_vcs = 4;
	parameter nvs = 4;
	parameter NV = 4;
	
	// length of each virtual channel buffer
	parameter buffer_length = 4;


	input x_coord_t x_cur;
	input y_coord_t y_cur;

	
	input  push, clk, rst_n;
	input  [num_vcs-1:0] pop;
	input  flit_t data_in;
	output flit_t data_out;
	output flit_t [num_vcs-1:0] flit_buffer_out;

	input [clogb2(num_vcs)-1:0] vc_id;
	input [num_vcs-1:0] select;

	input rt_presel_sel[3:0];  // ADICIONADO SE BUGAR TIRE

	   
   output fifo_flags_t [num_vcs-1:0] flags;
   output [num_vcs-1:0] allocated_vc [num_vcs-1:0];
   output [num_vcs-1:0] allocated_vc_valid;
  	 
   input [num_vcs-1:0][num_vcs-1:0] vc_new;
   input [num_vcs-1:0] 	vc_new_valid;

   logic [num_vcs-1:0] vc_reg [num_vcs-1:0];
   logic [num_vcs-1:0] allocated_vc_valid;

   flit_t buffer_data_out, routed;//, escape_buffer_data_out;

   //logic [clogb2(num_vcs)-1:0] select_bin; //Used to more than 1 VC
   logic [num_vcs-1:0] select_bin; // Used if the number of VCs are one = 1
	
   logic [num_vcs-1:0] route_valid;
   output_port_t [num_vcs-1:0] routed_output_port;
   vin_t [num_vcs-1:0] routed_vn;
   logic [num_vcs-1:0] routed_drop;
   
   
   genvar vc;
//*******************************************************************************   
   
   
   
   assign select_bin = vc_index_t'(oh2bin(select));
   

   
// *******************************************************************************
// virtual-channel buffers
// *******************************************************************************
	//Normal Buffers
	NL_vc_buffers #(.size(buffer_length),
					.nvs(nvs),
					.n(NV),
					.fifo_elements_t(flit_t)) 
			vc_bufsi
					(.pop(pop),
					.push(push), 
					.data_in(data_in), 
					.vc_id(vc_id), 
					.select(select), 
					.data_out(buffer_data_out), 
					.flags(flags),
					.clk, .rst_n);

				  
	generate
		for (vc=0; vc<NV; vc++) begin:eachvc
			// current VC is always read from register.
			//
			assign allocated_vc[vc] = vc_reg[vc];

			//TIMA
			always_comb begin
				flit_buffer_out[vc].control.output_port = routed_output_port[vc];
				flit_buffer_out[vc].control.vn = routed_vn[vc];
				flit_buffer_out[vc].control.vcalloc_mask = '1;
		
			`ifdef RT_NOCFT
				/*if (routed_vn[vc] == 0) begin
					flit_buffer_out[vc].control.vcalloc_mask = 2'b01;
				end else if (routed_vn[vc] == 1) begin
					flit_buffer_out[vc].control.vcalloc_mask = 2'b01;
				end else begin
					flit_buffer_out[vc].control.vcalloc_mask = 2'b10; //'1; //2'b10;//'1;
				end*/
			`endif

			end
		end
	endgenerate

	
	generate
		for (vc=0; vc<NV; vc++) begin
			always@(posedge clk) begin
				if (!rst_n) begin
					//$display("%m, PORT_ID = %1d", PORT_ID);
					// No allocated VCs on reset
					allocated_vc_valid[vc]<=1'b0;
				end else begin
					// if we have sent the last flit (tail) we don't hold a VC anymore
					//if (flit_buffer_out[vc].control.tail && pop[vc]) begin
					if (buffer_data_out.control.valid && oh2bin(buffer_data_out.control.vc_id) == vc && buffer_data_out.control.tail && pop[vc]) begin
						// tail has gone, no longer hold a valid VC
						allocated_vc_valid[vc]<=1'b0;
						vc_reg[vc]<='0;
					end else begin
						// [may obtain, use and release VC in one cycle (single flit packets), if so
						// allocated_vc_valid[] is never set
						if (vc_new_valid[vc]) begin
							// receive new VC
							//$display ("%m: new VC (%b) written to reg. at input VC buffer %1d", vc_new[i], i);
							allocated_vc_valid[vc]<=1'b1;
							vc_reg[vc]<=vc_new[vc];
						`ifdef DEBUG
							assert (vc_new[vc]!='0) else begin
								$display ("New VC id. is blank?"); 
								$fatal;
							end
						`endif
						end
					end
				end // else: !if(!rst_n)
			end // always@ (posedge clk)
		end // end for
	endgenerate

	//assign sel_allocated_vc_valid = |(allocated_vc_valid & select);

	//TIMA
	generate
	for (vc = 0; vc < NV; vc++) begin
        always @(posedge clk) begin
            if (!rst_n) begin
                route_valid[vc] <= 1'b0;
            end else begin
				if (data_in.control.valid && oh2bin(data_in.control.vc_id) == vc && !route_valid[vc]) begin
                    route_valid[vc] <= 1'b1;
					routed_output_port[vc] <= routed.control.output_port;
					routed_vn[vc] <= routed.control.vn;
					routed_drop[vc] <= routed.control.drop;
                end
				
				if (buffer_data_out.control.valid && oh2bin(buffer_data_out.control.vc_id) == vc && buffer_data_out.control.tail) begin
                    route_valid[vc] <= 1'b0;
                end
				
            end
        end
	end
	endgenerate
   
   
	generate
	
		NL_nocft_planar #(.NV(NV)/*, .PORT_ID(PORT_ID), .NP(NP)*/)
			rfn_nocft_planar 
				(.x_cur(x_cur), .y_cur(y_cur),
				.flit_in(data_in), 
				.flit_out(routed), 
				.route_valid(route_valid), 
				.congestion(rt_presel_sel),  // ADICIONADO SE BUGAR TIRE
				.clk, .rst_n);


		always_comb
		begin
			data_out = buffer_data_out;
			data_out.control.output_port = routed_output_port[select_bin];
			data_out.control.vn = routed_vn[select_bin];
			data_out.control.drop = routed_drop[select_bin];
			data_out.control.vc_id = vc_reg[select_bin]; //(sel_allocated_vc_valid) ? vc_reg[select_bin] : vc_new[select_bin];
		end
	endgenerate

endmodule // vc_input_port