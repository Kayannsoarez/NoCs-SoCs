/*
 * FIFO-based VC Free Pool
 * ============-==========
 * 
 * Serves next free VC id. Tail flits sent on output link replenish free VC pool
 * 
 * One free VC pool per output port
 * 
 */

module NL_vc_free_pool (flit, valid,
						vc_alloc_status,        // VC allocation status
						vc_allocated,           // which VCs were allocated on this cycle?
						vc_empty,               // is downstream FIFO associated with VC empty?
						clk, rst_n);

	parameter num_vcs_global = 4; // in router
	parameter num_vcs_local  = 4; // at this output port

	//-------
	input flit_t flit;
	input valid;
	input [num_vcs_global-1:0] vc_allocated;
	output [num_vcs_global-1:0] vc_alloc_status;
	input [num_vcs_global-1:0]  vc_empty;
	input  clk, rst_n;

	logic [num_vcs_global-1:0] vc_alloc_status_reg;

	genvar vc;

	generate
		for (vc=0; vc < num_vcs_global; vc++) begin:forvcs2
			// =============================================================
			// Unrestricted VC allocation
			// =============================================================
			always@(posedge clk) begin
				if (!rst_n) begin
					vc_alloc_status_reg[vc] <= (vc<num_vcs_local);
				end else begin
					// *************************************
					// VC consumed, mark VC as allocated
					// *************************************				
					if (vc_allocated[vc]) begin
						vc_alloc_status_reg[vc]<=1'b0;
					end
					
					// *************************************
					// If TAIL flit departs, packets VC is ready to be used again
					// what about single flit packets - test
					// *************************************
					if (valid && flit.control.tail && oh2bin(flit.control.vc_id) == vc) begin
					`ifdef DEBUG
						assert (!vc_alloc_status_reg[oh2bin(flit.control.vc_id)]);
						//TIMA_DEB = Check it, I have problem with modelsim student. It is working with modelsim SE
					`endif
						vc_alloc_status_reg[vc]<=1'b1;
					end
				end
			end // always@ (posedge clk)
		
			// *************************************
			// Only allocate VC when Empty
			// *************************************
			assign vc_alloc_status[vc] = vc_alloc_status_reg[vc] & vc_empty[vc];
		end	// for
	endgenerate
   
endmodule // NW_vc_free_pool

