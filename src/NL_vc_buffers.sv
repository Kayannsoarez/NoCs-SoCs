/* -------------------------------------------------------------------------------
 *
 * Virtual-Channel Buffers
 * =======================
 * 
 * Instantiates 'N' FIFOs in parallel, if 'push' is asserted
 * data_in is sent to FIFO[vc_id].
 *
 * The output is determined by an external 'select' input.
 * 
 * if 'pop' is asserted by the end of the clock cycle, the 
 * FIFO that was read (indicated by 'select') recieves a 
 * pop command.
 *
 * - flags[] provides access to all FIFO status flags.
 * - output_port[] provides access to 'output_port' field of flits at head of FIFOs
 * 
 * Assumptions:
 * - 'vc_id' is binary encoded (select is one-hot) //and 'select' are binary encoded.
 * 
 */

 
  
/************************************************************************************
 *
 * NL_vc_buffers 
 *
 ************************************************************************************/
module NL_vc_buffers (push, pop, data_in, vc_id, select, data_out, flags, /*flit_buffer_out,*/ clk, rst_n);

	// length of VC FIFOs
	parameter size = 3;
	// number of virtual channels
	parameter n = 4;
	parameter nvs = 4;
	// what does each FIFO hold?
	parameter type fifo_elements_t = flit_t;
	// export output of each VC buffer
	//parameter output_all_head_flits = 1;

	input     push;
	input     [n-1:0] pop;
	input     fifo_elements_t data_in;
	input     [clog2(n)-1:0] vc_id;
	input 	  [n-1:0] select;

	output    fifo_elements_t data_out;
	output    fifo_flags_t[n-1:0] flags;
	//output    fifo_elements_t [n-1:0] flit_buffer_out;

	input     clk, rst_n;

	// single fifo output;
	fifo_elements_t sel_fifo_out;
	// fifo outputs
	fifo_elements_t fifo_out [n-1:0];
	// fifo push/pop control
	logic [n-1:0] push_fifo;//, pop_fifo;//, elf_stop_pop_fifo;

	genvar i;
	//integer j;

   
	generate
		for (i=0; i</*n*/nvs; i++) begin:vcbufs
			// **********************************
			// SINGLE FIFO holds complete flit
			// **********************************
			NL_vc_fifo #(.fifo_elements_t(fifo_elements_t), .size(size)) 
				vc_fifo
						(.push(push_fifo[i]),
						.pop(pop[i]),
						.data_in(data_in), 
						.data_out(fifo_out[i]),
						.flags(flags[i]),
						.clk, .rst_n);

			assign push_fifo[i] = push & (vc_id==i);

		end
	endgenerate

	//
	// Mux Buffers
	//
	NL_mux_oh_select #(.dtype_t(fifo_elements_t), .n(n)) 
			fifosel (.data_in(fifo_out), .select(select), .data_out(sel_fifo_out));
	
	assign data_out = sel_fifo_out;
	
	//
	// some architectures require access to head of all VC buffers
	//
	/*generate
		if (output_all_head_flits) begin
			for (i=0; i<n; i++) begin:allvcs
				assign flit_buffer_out[i] = fifo_out[i];
			end
		end
	endgenerate*/

endmodule 


 
/************************************************************************************
 *
 * FIFO 
 *
 ************************************************************************************/
module NL_vc_fifo (push, pop, data_in, data_out, flags, clk, rst_n);
   
	// Type of FIFO elements
	parameter type fifo_elements_t = flit_t ;
	// max no. of entries
	parameter size = 8;


	input     push, pop;
	output    fifo_flags_t flags;
	input     fifo_elements_t data_in;
	output    fifo_elements_t data_out;
	input     clk, rst_n;

	//fifo_elements_t second;

	//logic is_push;
	
	/************************************************************************************
	* Generate Flags for FIFO (flags are always generated for a FIFO of length 'size')
	************************************************************************************/
	fifo_flags #(.size(size)) 
		genflags 
				(push, pop, flags, clk, rst_n);

	/************************************************************************************
	* FIFO Buffer of length 'size'
	************************************************************************************/
	fifo_buffer #(.fifo_elements_t(fifo_elements_t), 
				.size(size))
		fifo_buf 
				(push, pop, data_in, data_out, clk, rst_n);

endmodule // fifo_v




/************************************************************************************
 *
 * Maintain FIFO flags (full, nearly_empty and empty)
 * 
 * This design uses a shift register to ensure flags are available quickly.
 * 
 ************************************************************************************/
module fifo_flags (push, pop, flags, clk, rst_n);
	input push, pop;
	output fifo_flags_t flags;
	input clk, rst_n;

	parameter size = 8;

	reg [size:0]   counter;      // counter must hold 1..size + empty state

	logic 	  was_push, was_pop;

	//fifo_flags_t flags_reg;
	
	logic 	  add, sub, same;

	/*
	* maintain flags
	*
	*
	* maintain shift register as counter to determine if FIFO is full or empty
	* full=counter[size-1], empty=counter[0], etc..
	* init: counter=1'b1;
	*   (push & !pop): shift left
	*   (pop & !push): shift right
	*/

	always@(posedge clk) begin
		if (!rst_n) begin
			// initialise flags counter on reset (empty)
			counter<={{size{1'b0}},1'b1};
			
			was_push<=1'b0;
			was_pop<=1'b0;
			
		end else begin
		
			if (add) begin
				assert (counter!={1'b1,{size{1'b0}}}) else $fatal;
				counter <= {counter[size-1:0], 1'b0};
			end else if (sub) begin
				assert (counter!={{size{1'b0}},1'b1}) else $fatal;
				counter <= {1'b0, counter[size:1]};
			end
	 
			assert (counter!=0) else $fatal;

			was_push<=push;
			was_pop<=pop;

			assert (push!==1'bx) else $fatal;
			assert (pop!==1'bx) else $fatal;
				 
		end // else: !if(!rst_n)
      
	end // always (clk)

	assign add = was_push && !was_pop;
	assign sub = was_pop && !was_push;
	assign same = !(add || sub);

	assign flags.full = (counter[size] && !sub) || (counter[size-1] && add);
	assign flags.empty = (counter[0] && !add) || (counter[1] && sub);

	assign flags.nearly_empty = (counter[1] && same) || (counter[0] && add) || (counter[2] && sub);
	
endmodule // fifo_flags



/************************************************************************************
 *
 * Simple core FIFO module
 * 
 ************************************************************************************/
module fifo_buffer (push, pop, data_in, data_out, clk, rst_n);

	// what does FIFO hold?
	parameter type fifo_elements_t = flit_t ;
	// max no. of entries
	parameter int unsigned size = 4;

	
	input     push, pop;
	input     fifo_elements_t data_in;
	output    fifo_elements_t data_out;
	input     clk, rst_n;

	logic unsigned [size-1:0] rd_ptr, wt_ptr;

	fifo_elements_t fifo_mem[0:size-1];

	integer i,j;

	always@(posedge clk) begin

		assert (size>=2) else $fatal();
		
		if (!rst_n) begin
			// Initialise empty FIFO
			rd_ptr<={{size-1{1'b0}},1'b1};
			wt_ptr<={{size-1{1'b0}},1'b1};
		 
		end else begin
		
			if (push) begin
				// Enqueue new data
				for (i=0; i<size; i++) begin
					if (wt_ptr[i]==1'b1) begin
						fifo_mem[i] <= data_in;
					end
				end
			end

			
			// Rotate Write and Read pointer
			if (push) begin
				// Rotate write pointer
				wt_ptr <= {wt_ptr[size-2:0], wt_ptr[size-1]};
			end
			if (pop) begin
				// Rotate read pointer
				rd_ptr <= {rd_ptr[size-2:0], rd_ptr[size-1]};	    
			end
			
		end 
		
	end // always@ (posedge clk)
	
	//FIFO output is item pointed to by read pointer 
	always_comb begin
		//
		// one bit of read pointer is always set, ensure synthesis tool 
		// doesn't add logic to force a default
		//
		data_out = 'x;  
      
		for (j=0; j<size; j++) begin
			if (rd_ptr[j]==1'b1) begin
				// output entry pointed to by read pointer
				data_out = fifo_mem[j];
			end
		end 
	end
endmodule // fifo_buffer