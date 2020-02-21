/* -------------------------------------------------------------------------------
 * @file nalu_package.vhd
 * @brief Package with Defines definitions, Typedef definitions and Misc. functions packages for NaluNoC
 * @authors Alexandre Coelho, alexandre.coelho@imag.fr
 * @date 01/02/2017
 * @copyright TIMA.
 *
 * -------------------------------------------------------------------------------
 * Misc. Modules
 * 
 * NL_mux_oh_select (data_in, select, data_out):
 *
 * Multiplexer with one-hot encoded select input
 * Output is '0 if no select input is asserted
 * -------------------------------------------------------------------------------
*/

module NL_mux_oh_select (data_in, select, data_out);

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
