
// USED ONLY TO SELECT VC BLOCKED STATUS
// OPTIMISE FOR XY ROUTING

/* autovdoc@
 * 
 * Takes two unary (one-hot) encoded select signals and selects one bit of the input.
 * 
 * Implements the following:
 * 
 * {\tt selectedbit=datain[binary(sela)*NV+binary(selb)]}
 * 
 * pin@ output_port_sw, NP, in, select signal A (unary encoded)
 * pin@ vc_blocked_chk, NV, in, select signal B (unary encoded)
 * pin@ vc_status_chk, NP*NV, in, input data 
 * pin@ vc_full_blocked, 1, out, selected data bit (see above)
 * 
 * param@ NP, >1, width of select signal A
 * param@ NV, >1, width of select signal B
 * 
 * autovdoc@
 */

module NL_unary_select_pair (output_port_sw, vc_blocked_chk, vc_status_chk, vc_full_blocked);

	parameter input_port = 0; // from 'input_port' to 'output_port_sw' output port
	parameter NP = 4;
	parameter NV = 4;

	input output_port_t output_port_sw;
	input [NV-1:0] vc_blocked_chk;
	input [NP*NV-1:0] vc_status_chk;
	output vc_full_blocked;

	genvar i,j;

	wire [NP*NV-1:0]  selected;

	generate
		for (i=0; i<NP; i=i+1) begin:ol
			for (j=0; j<NV; j=j+1) begin:il
				assign selected[i*NV+j] = (NL_route_valid_turn(input_port, i)) ?
											vc_status_chk[i*NV+j] & 
											output_port_sw[i] & 
											vc_blocked_chk[j] : 1'b0;
			end
		end
	endgenerate

	assign vc_full_blocked=|selected;
   
endmodule // NL_unary_select_pair
