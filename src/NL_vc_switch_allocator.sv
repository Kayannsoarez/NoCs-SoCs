/*
 * VC Switch Allocator
 * ===================
 * 
 * Technically this is an input first seperable allocator (see Dally/Towles p.367)
 * 
 * Arbitration Stage 1:
 *    * Arbitrate between requests from VCs at each input port (NP x NV:1 arbiters)
 *    * Select the output port request of the winning flit
 * 
 * Arbitration Stage 2:
 *    * Arbitrate between requests for each output port (NP x NP:1 arbiters)
 *    * Determine which input port requests were successful.
 * 
 * 
 *    ----> req                                                               --> grant
 *    ----> required_output_port                                                 
 *                .                                                            .
 *                .                    [STAGE 1]            [STAGE 2]          .
 *                .                Arbitrate between    Arbitrate between      .       
 *    ----> req                    requests from same   winners of stage 1    --> grant
 *    ----> required_output_port       input port       that require the    
 *                                                      same output port 
 * 
 * Parameters
 * ==========
 * 
 *     # NP - number of ports (assumes no. input = no. output)
 *     # NV - number of virtual-channels
 *
 */

module NL_vc_switch_allocator (req,
			       output_port, 
			       grant,
			       vc_mux_sel,              // not used by Lochside
			       xbar_select,             // not used by Lochside
			       any_request_for_output,  // not used by Lochside
			       clk, rst_n);

	parameter NP=7;
	parameter NV=2;

	// This option is necessary if you want/permit turn model(180 - EAST then WEST, for example) : Function "NL_route_valid_turn" in the source file NL_package.sv
	parameter turn_opt = 1 ; // 0 useful when testing, default 1

	input [NP-1:0][NV-1:0] req;
	input output_port_t output_port [NP-1:0][NV-1:0];
	output [NP-1:0][NV-1:0] grant;
	output [NP-1:0][NV-1:0] vc_mux_sel;
	output [NP-1:0][NP-1:0] xbar_select;
	output [NP-1:0] any_request_for_output;
	input clk, rst_n;

	logic [NP-1:0] input_port_success;
	logic [NP-1:0][NV-1:0] stage1_grant;
	output_port_t winning_port_req [NP-1:0];

	logic [NP-1:0][NP-1:0] output_port_req, all_grants_for_input, output_port_grant, 
	permitted_output_port_req, permitted_output_port_grant;



	genvar i,j;

	// buffers at each input port arbitrate for access to single port on crossbar
	// (winners of stage1 go on to arbitrate for access to actually output port)
	assign vc_mux_sel = stage1_grant; 
   
	// arbitrate between virtual-channels at each input port	
	generate
		for (i=0; i<NP; i++) begin:inport

			// **********************************
			// NV:1 arbiter at each input port
			// **********************************
			matrix_arb #(.size(NV), .multistage(1)) 
				vc_arb
					(.request(req[i]),
					.grant(stage1_grant[i]),
					.success(input_port_success[i]),
					.clk, 
					.rst_n);

			// select output port request of (first-stage) winner
			NL_mux_oh_select #(.dtype_t(output_port_t), .n(NV)) 
				reqmux
					(output_port[i], 
					stage1_grant[i], 
					winning_port_req[i]);

			// setup requests for output ports
			for (j=0; j<NP; j++) begin:outport
				// if turn is invalid output port request will never be made
				if (turn_opt) begin
					assign output_port_req[j][i]=(NL_route_valid_turn(i,j)) ? winning_port_req[i][j] : 1'b0;
				end else begin
					assign output_port_req[j][i] = winning_port_req[i][j];
				end

				// for cases when both speculative and non-speculative versions of a switch
				// allocator are employed together.
				assign permitted_output_port_req[j][i] = output_port_req[j][i];
			end

			for (j=0; j<NV/*nvs[i]*/; j++) begin:suc   
				// was request successful at both input and output arbitration?
				assign grant[i][j]=stage1_grant[i][j] && input_port_success[i];
			end
		end // for (i=0; i<NP; i++) block: inport

		
		
		for (i=0; i<NP; i++) begin:outport

			// **********************************
			// NP:1 arbiter at each output port
			// **********************************
			matrix_arb #(.size(NP), .multistage(0)) 
				outport_arb
					(.request(output_port_req[i]),
					.grant(output_port_grant[i]),
					.success((1==1)),
					.clk, .rst_n);

			for (j=0; j<NP; j++) begin:g
				// was input port successful?
				assign all_grants_for_input[j][i]=output_port_grant[i][j];

				assign permitted_output_port_grant[j][i] = output_port_grant[j][i];

			end

			assign input_port_success[i]=|all_grants_for_input[i];

			assign any_request_for_output[i]=|permitted_output_port_req[i];

		end
	endgenerate

	assign xbar_select = permitted_output_port_grant;
    
endmodule // NW_vc_switch_allocator