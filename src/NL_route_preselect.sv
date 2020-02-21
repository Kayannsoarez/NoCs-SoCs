/* This module collects various signals from the router and outputs:
 * - a 4-bit vector, 1 bit per quadrant (NE, NW, SE, SW), indicating which direction to prefer in each quadrant.
 *  => example: if NE=1 prefer North to East, otherwise prefer East
 * - 4 bitmasks indicating the valid VCs to request at each output port
 *  => example: assuming 4 VCs, possible values for the masks might be (N=1111, W=1110, S=1111, E=1011)
 */
 
 

module NL_route_preselect(credit_valid, flit_valid, flit, select, clk, rst_n);
    
     
	parameter NV = 4;
	parameter NP = 5;
       
        
`ifdef CONGESTION_METRIC_MUX
        `define MAX_CONGESTION_WIDTH (NV*`MAX_PACKET_SIZE)
`endif 
`ifdef CONGESTION_METRIC_HYBRID
        `define MAX_CONGESTION_WIDTH (NV*`MAX_PACKET_SIZE*2)
`endif 
`ifdef CONGESTION_METRIC_BUF
        `define MAX_CONGESTION_WIDTH (NV*4)
`endif
`ifdef NO_CONGESTION_METRIC
		`define MAX_CONGESTION_WIDTH (NV*4)
`endif
 
    parameter congestion_width = clogb2(`MAX_CONGESTION_WIDTH+1);

    input clk;
    input rst_n;
    
    input chan_cntrl_t credit_valid[NP-1:0];
    input [NP-1:0]flit_valid;
    input flit_t flit[NP-1:0];
    
    output select;
    //output mask;
    
 
    logic select[NP-2:0];
	//logic select[3:0];// 4 quadrants
    //logic [NV-1:0] mask [1:0];
    
    // internal congestion values (registers)
    logic [congestion_width-1:0] cvalue [NP-1:0];
    
    // temporary congestion update logic
    logic [congestion_width-1:0] cvalue_new[NP-1:0];

    genvar port,vc;
    
    // Updating local congestion metrics
    generate
    for (port = 0; port < NP; port++) begin
            always_comb begin
                    cvalue_new[port] = cvalue[port];
                    `ifdef CONGESTION_METRIC_BUF
                            if (flit_valid[port]) begin
                                cvalue_new[port] = cvalue_new[port] + 1'b1;
                            end
                            if (credit_valid[port].credit_valid) begin
                                cvalue_new[port] = cvalue_new[port] - 1'b1;
                            end
                    `endif
                    `ifdef CONGESTION_METRIC_MUX
                            if (flit_valid[port] && flit[port].control.head) begin
                                cvalue_new[port] = cvalue_new[port] + `MAX_PACKET_SIZE;
                            end
                            if (credit_valid[port].credit_valid) begin
                                cvalue_new[port] = cvalue_new[port] - 1'b1;
                            end
                    `endif 
                    `ifdef CONGESTION_METRIC_HYBRID
                            if (flit_valid[port]) begin
                                if (flit[port].control.head) begin
                                        cvalue_new[port] = cvalue_new[port] + `MAX_PACKET_SIZE * 2  - 1;
                                end else begin
                                       cvalue_new[port] = cvalue_new[port]  - 1'b1;
                                        
                               end
                            end
                            if (credit_valid[port].credit_valid) begin
                                cvalue_new[port] = cvalue_new[port] - 1'b1;
                            end
                    `endif 
            end
            
            always @(posedge clk) begin
                if (!rst_n) begin  
                    cvalue[port] <= '0;
                end else begin
                    if (credit_valid[port].credit_valid) begin
					`ifndef MODELSIM
                        assert(cvalue[port] > 0);
					`endif
                    end
                    cvalue[port] <= cvalue_new[port];
                end
            end
    end
    endgenerate
    
     // Updating congestion preselect 
    always @(posedge clk) begin
            if (!rst_n) begin
                    select[`NE] <= 1'b0;
                    select[`NW] <= 1'b0;
                    select[`SE] <= 1'b0;
                    select[`SW] <= 1'b0;

            end else begin
				if (cvalue_new[`NORTH] < cvalue_new[`EAST]) begin
					select[`NE] <= 1'b1;
				end else begin
					select[`NE] <= 1'b0;
				end
				if (cvalue_new[`NORTH] < cvalue_new[`WEST]) begin
					select[`NW] <= 1'b1;
				end else begin
					select[`NW] <= 1'b0;
				end
				if (cvalue_new[`SOUTH] < cvalue_new[`EAST]) begin
					select[`SE] <= 1'b1;
				end else begin
					select[`SE] <= 1'b0;
				end
				if (cvalue_new[`SOUTH] < cvalue_new[`WEST]) begin
					select[`SW] <= 1'b1;
				end else begin
					select[`SW] <= 1'b0;
				end
				`ifdef VERBOSE
					//$display("%1d: select[`NE] = %1d, select[`NW] = %1d, select[`SE] = %1d, select[`SW] = %1d", $time, select[`NE], select[`NW], select[`SE], select[`SW]);
				`endif
				//$display("select[`NW] = %1d", select[`NW]);
				//$display("select[`SE] = %1d", select[`SE]);
				//$display("select[`SW] = %1d", select[`SW]);
					
            end// rst_n else begin 
    end

endmodule