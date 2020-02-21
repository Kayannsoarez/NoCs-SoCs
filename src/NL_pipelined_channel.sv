/* 
 * Pipelined channel (link) between routers
 * 
 * 'stages' may range from 0 (routers are clocked but link is simply a wire)
 * to N
 * 
 */
 
//
// Register
//
module NL_reg (data_in, data_out, clk, rst_n);

	parameter type reg_t = flit_t;

	input     reg_t data_in;
	output    reg_t data_out;
	input     clk, rst_n;

	always@(posedge clk) begin
	if (!rst_n) begin
		data_out<='0;
	end else begin
		data_out<=data_in;
	end
      
end
   
endmodule 


module NL_pipelined_channel (data_in, data_out, clk, rst_n);

   parameter type reg_t = flit_t;

   parameter stages = 1;

   input     reg_t data_in;
   output    reg_t data_out;
   input     clk, rst_n;

   genvar    st;

   reg_t ch_reg[stages-1:0];
   
   generate
      if (stages==0) begin
	 // no registers in channel
	 assign data_out = data_in;
      end else begin
	 for (st=0; st<stages; st++) begin:eachstage
	    if (st==0) begin
	       // first register in channel
	       NL_reg #(.reg_t(flit_t)) rg (.data_in(data_in), .data_out(ch_reg[0]), .clk, .rst_n);
	    end else begin
	       // other registers
	       NL_reg #(.reg_t(flit_t)) rg (.data_in(ch_reg[st-1]), .data_out(ch_reg[st]), .clk, .rst_n);
	    end
	 end

	 assign data_out = ch_reg[stages-1];
	 
      end
   endgenerate
   
   
endmodule 
