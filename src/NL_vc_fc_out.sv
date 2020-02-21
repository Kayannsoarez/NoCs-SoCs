/*
 * Virtual-Channel (Channel-level) Flow-Control 
 * ============================================
 *
 * Supports
 *   - credit flow-control
 * 
 * Credit Counter Optimization (for credit-based flow-control)
 * ===========================
 * 
 * optimized_credit_counter = 0 | 1
 * 
 * Set to '1' to move credit counter logic to start of next clock cycle.
 * Remove add/sub from critical path.
 * 
 * To move add/sub logic we buffer the last credit rec. and the any
 * flit sent on the output.
 * 
 */

module NL_vc_fc_out (flit, flit_valid, 
					 channel_cntrl_in, 
					 vc_status,          // vc_status[vc]=1 if blocked (fifo is full)
					 // only when using credit-based flow control
					 vc_empty,           // vc_empty[vc]=1 if VC fifo is empty (credits=init_credits)
					 //vc_credits, 
					 clk, rst_n);

   
	parameter num_vcs = 2;
	parameter nvs = 2;
	parameter init_credits = 4;

	// +1 as has to hold 'init_credits' value
	parameter counter_bits = clogb2(init_credits+1);

	input flit_t flit;
	input flit_valid;
	input chan_cntrl_t channel_cntrl_in;
	output vc_t vc_status;
	output [num_vcs-1:0] vc_empty;
	//output [num_vcs-1:0][counter_bits-1:0] vc_credits;

	input  clk, rst_n;

	logic [num_vcs-1:0][counter_bits-1:0] counter;

	logic [num_vcs-1:0] inc, dec;

	// buffer credit and flit vc id.'s so we can move counter in credit counter optimization
	logic last_credit_valid, last_flit_valid;
	logic [num_vcs-1:0] last_flit_vc_id;


	vc_index_t last_credit;

	logic [num_vcs-1:0][counter_bits-1:0] counter_current;

	logic [num_vcs-1:0] 	    vc_empty;

	genvar i;

	// *************************************
	// Credit-based Flow Control
	// *************************************
	generate
		// ***********************************
		// optimized credit-counter (moves counter logic off critical path)
		// ***********************************
		always@(posedge clk) begin
			last_credit_valid <= channel_cntrl_in.credit_valid;
			last_credit <= channel_cntrl_in.credit;
			last_flit_valid <= flit_valid;
			last_flit_vc_id <= flit.control.vc_id;

			//	    $display ("empty=%b", vc_empty);
		end

		//assign vc_credits = counter_current;

		for (i=0; i</*num_vcs*/nvs; i++) begin:pervc1

			always_comb begin:addsub
				if (inc[i] && !dec[i])
					counter_current[i]=counter[i]+1;
				else if (dec[i] && !inc[i]) 
					counter_current[i]=counter[i]-1;
				else
					counter_current[i]=counter[i];
			end

			always@(posedge clk) begin
				if (!rst_n) begin
					counter[i]<=init_credits;
					vc_empty[i]<='1;
				
				end else begin

					counter[i]<=counter_current[i];

					if ((counter_current[i]==0) ||
					((counter_current[i]==1) && flit_valid && (oh2bin(flit.control.vc_id)==i)) && 
					!(channel_cntrl_in.credit_valid && (channel_cntrl_in.credit==i))) begin
						vc_status[i] <= 1'b1;
						vc_empty[i] <= 1'b0;
					end else begin
						vc_status[i] <= 1'b0;
						vc_empty[i] <= (counter_current[i]==init_credits);
					end

				end // else: !if(!rst_n)
			end // always@ (posedge clk)

			assign inc[i]=(last_credit_valid) && (last_credit==i);

			assign dec[i]=(last_flit_valid) && (oh2bin(last_flit_vc_id)==i);

		end 
	endgenerate

endmodule
