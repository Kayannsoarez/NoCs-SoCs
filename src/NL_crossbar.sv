// Multiplexer with one-hot encoded select input
//
// - output is '0 if no select input is asserted
//
module NL_mux_oh_select_crossbar (data_in, select, data_out);

	parameter type dtype_t = byte;
	parameter n = 4;

	input dtype_t data_in [n-1:0];
	input [n-1:0] select;
	output dtype_t data_out;

	int i;

	always_comb
	begin
		data_out='0;
		for (i=0; i<n; i++) begin
			if (select[i]) data_out = data_in[i];
		end
	end

endmodule

//
// Crossbar built from multiplexers, one-hot encoded select input
//
module NL_crossbar (data_in, select, data_out);

	parameter type dtype_t = byte;
	parameter n = 4;

	input dtype_t data_in [n-1:0];
	input [n-1:0][n-1:0] select;   // n one-hot encoded select signals per output
	output dtype_t data_out [n-1:0];

	genvar i;

	generate
		for (i=0; i<n; i++) begin:outmuxes
			NL_mux_oh_select_crossbar #(.dtype_t(dtype_t), .n(n)) xbarmux (data_in, select[i], data_out[i]);
		end
	endgenerate
   
endmodule 