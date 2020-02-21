/*
 * FIFO
 * ====
 *
 * Implementation notes:
 *  
 * - Read and write pointers are simple ring counters
 * 
 * - Number of items held in FIFO is recorded in shift register
 *      (Full/empty flags are most and least-significant bits of register)
 * 
 * - Supports input and/or output registers on FIFO
 * 
 * Examples:
 * 
 *   fifo_v #(.fifo_elements_t(int), .size(8)) myfifo (.*);
 * 
 * Instantiates a FIFO that can hold up to 8 integers.
 * 
 *   fifo_v #(.fifo_elements_t(int), .size(8), .output_reg(1)) myfifo (.*);
 * 
 * Instantiates a FIFO that can hold up to 8 integers with output register
 * 
 * Output Register
 * ===============
 * 
 * Instantiate a FIFO of length (size-1) + an output register and bypass logic
 *  
 *   output_reg = 0 (default) - no output register
 *   output_reg = 1 - instantiate a single output register
 * 
 *                      _
 *      ______    |\   | |
 *  _|-[_FIFO_]-->| |__| |__ Out
 *   |----------->| |  |_|
 *      bypass    |/   Reg.
 *
 * 
  * ===============================================================================      
 */ 


 
/************************************************************************************
 *
 * FIFO NL_traffic_source_fifo
 *
 ************************************************************************************/
module NL_traffic_source_fifo (push, pop, data_in, data_out, flags, clk, rst_n);
   
	// Type of FIFO elements
	parameter type fifo_elements_t = flit_t ;
	// max no. of entries
	parameter size = 8;

	input     push, pop;
	input     fifo_elements_t data_in;
	
	output    fifo_elements_t data_out;
	output    fifo_flags_t flags;

	input     clk, rst_n;	

	//logic is_push;
	
	/************************************************************************************
	* Generate Flags for FIFO (flags are always generated for a FIFO of length 'size')
	************************************************************************************/
	fifo_flags_source #(.size(size)) 
		genflags 
				(push, pop, flags, clk, rst_n);

	/************************************************************************************
	* FIFO Buffer of length 'size'
	************************************************************************************/
	fifo_buffer_source #(.fifo_elements_t(fifo_elements_t), .size(size))
		fifo_buf 
				(push, pop, data_in, data_out, clk, rst_n);

endmodule // fifo_v




/************************************************************************************
 *
 * Maintain FIFO flags (full, empty, nearly_empty and nearly_full)
 * 
 * This design uses a shift register to ensure flags are available quickly.
 * 
 ************************************************************************************/
module fifo_flags_source (push, pop, flags, clk, rst_n);
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

	assign flags.nearly_full = (counter[size-1:0] && same) || (counter[size] && sub) || (counter[size-2] && add);
	assign flags.nearly_empty = (counter[1] && same) || (counter[0] && add) || (counter[2] && sub);
	

endmodule // fifo_flags




/************************************************************************************
 *
 * Simple core FIFO module
 * 
 ************************************************************************************/
module fifo_buffer_source (push, pop, data_in, data_out, clk, rst_n);

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