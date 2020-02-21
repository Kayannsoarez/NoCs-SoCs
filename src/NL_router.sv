/* 
 * Wrapper to select different router architectures
 * 
 */

module NL_router (x_cur, y_cur,
				i_flit_in, i_flit_out,
				i_cntrl_in, i_cntrl_out,
				i_input_full_flag,	
				i_input_empty_flag,
				clk, rst_n);

	`include "parameters.sv"

	parameter NP = router_radix;
	parameter NV = router_num_max_vcs;
	parameter [2:0] NVS [0:4] = router_num_vcs;
	
	input x_coord_t x_cur;
	input y_coord_t y_cur;

	// FIFO rec. data from tile/core is full?
	//output  fifo_flags_t [router_num_vcs_on_entry-1:0] i_input_full_flag;
	output  logic [router_num_vcs_on_entry-1:0] i_input_full_flag /* synthesis syn_keep = 1 */;
	output  logic [router_num_vcs_on_entry-1:0] i_input_empty_flag;

	// link data and control
	input   flit_t i_flit_in [NP-1:0];
	output  flit_t i_flit_out [NP-1:0];
	input   chan_cntrl_t i_cntrl_in [NP-1:0];
	output  chan_cntrl_t i_cntrl_out [NP-1:0];

	input   clk, rst_n;
  
   generate
	 NL_vc_router #(.buf_len(router_buf_len),
			.NP(NP), 
			.NV(NV),
			.NVS(NVS),
			.router_num_vcs_on_entry(router_num_vcs_on_entry),
			.router_num_vcs_on_exit(router_num_vcs_on_exit)) 
		router
		   (x_cur, y_cur,
			i_flit_in, i_flit_out,
			i_cntrl_in, i_cntrl_out,
			i_input_full_flag,
			i_input_empty_flag,
			clk, rst_n);
   endgenerate

endmodule
   
