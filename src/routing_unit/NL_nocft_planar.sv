//`ifdef RT_NOCFT
module NL_nocft_planar (x_cur, y_cur,
							flit_in, 
							flit_out, 
							route_valid,
							congestion,
							clk, rst_n);
	
	parameter NV = 2;
	
	
	input x_coord_t x_cur;
	input y_coord_t y_cur;
	
	input  flit_t flit_in;
	output flit_t flit_out;
	
	input  [NV-1:0] route_valid ;
	input  clk, rst_n;


	logic [3:0] cmp;

	input congestion [3:0]; // Variavel de congestao do roteador 
	
	x_coord_t flit_in_x_dest;
	y_coord_t flit_in_y_dest;

	outport_vout_t routes [NV-1:0];
	outport_vout_t tmp_route;


	genvar vc;


	always_comb begin
		cmp = '0;
		
		flit_in_x_dest = flit_in.control.x_dest;
		flit_in_y_dest = flit_in.control.y_dest;

		cmp[`EAST]  = (flit_in_x_dest > x_cur);
		cmp[`WEST]  = (flit_in_x_dest < x_cur);
		cmp[`NORTH] = (flit_in_y_dest < y_cur);
		cmp[`SOUTH] = (flit_in_y_dest > y_cur);
		
	/*`ifdef DEBUG
		assert(~(cmp[`WEST] & cmp[`EAST]));
		assert(~(cmp[`NORTH] & cmp[`SOUTH]));
	`endif*/
	end
	

	always_comb begin
		tmp_route.v_out = flit_in.control.vn;
		tmp_route.drop = 1'b0;

		// Roteamento XY puro
		/*
		if (cmp[`EAST]) begin
			tmp_route.output_port = `port7id_east;
		end else if (cmp[`WEST]) begin
			tmp_route.output_port = `port7id_west;
		end else if (~(cmp[`EAST] | cmp[`WEST]) & cmp[`NORTH]) begin
			tmp_route.output_port = `port7id_north;
		end else if (~(cmp[`EAST] | cmp[`WEST]) & cmp[`SOUTH]) begin
			tmp_route.output_port = `port7id_south;
		end else begin
			tmp_route.output_port = `port7id_tile;
		end
		*/

		// Roteamento West-First. Primeiro teste.
		
		if (cmp[`WEST]) begin //& ~(congestion[`WEST])) begin
			tmp_route.output_port = `port7id_west;
		end else if (~(cmp[`EAST] | cmp[`WEST]) & cmp[`NORTH]) begin //& ~(congestion[`NORTH])) begin
			tmp_route.output_port = `port7id_north;
		end else if (~(cmp[`EAST] | cmp[`WEST]) & cmp[`SOUTH]) begin //& ~(congestion[`SOUTH])) begin
			tmp_route.output_port = `port7id_south;

		end else if (cmp[`EAST]) begin //& ~(congestion[`EAST]))  begin
			if (~(congestion[`EAST])) begin
				tmp_route.output_port = `port7id_east;
			end else if (cmp[`NORTH]) begin
				tmp_route.output_port = `port7id_north;
			end else if (cmp[`SOUTH]) begin
				tmp_route.output_port = `port7id_south;
			end else begin
				tmp_route.output_port = `port7id_east;
			end
		end else if (cmp[`NORTH]) begin //& ~(congestion[`NORTH])) begin
			tmp_route.output_port = `port7id_north;
		end else if (cmp[`SOUTH]) begin //& ~(congestion[`SOUTH])) begin
			tmp_route.output_port = `port7id_south;

		end else if (~(cmp[`EAST] | cmp[`WEST]) & ~(cmp[`NORTH] | cmp[`SOUTH])) begin
			tmp_route.output_port = `port7id_tile;
		end
		

		// Algoritmo North-Last
		/*
		if (cmp[`SOUTH]) begin //& ~(congestion[`SOUTH])) begin
			if (~(congestion[`SOUTH])) begin
				tmp_route.output_port = `port7id_south;
			end else if (cmp[`EAST]) begin
				tmp_route.output_port = `port7id_east;
			end else if (cmp[`WEST]) begin
				tmp_route.output_port = `port7id_west;
			end else begin
				tmp_route.output_port = `port7id_south;
			end
		end else if (cmp[`EAST]) begin //& ~(congestion[`EAST]))  begin
			tmp_route.output_port = `port7id_east;
		end else if (cmp[`WEST]) begin //& ~(congestion[`WEST]))  begin
			tmp_route.output_port = `port7id_west;

		end else if (~(cmp[`EAST] | cmp[`WEST] | cmp[`SOUTH]) & cmp[`NORTH]) begin //& ~(congestion[`NORTH])) begin
			tmp_route.output_port = `port7id_north;
		end else if (~(cmp[`EAST] | cmp[`WEST] | cmp[`SOUTH] | cmp[`NORTH])) begin
			tmp_route.output_port = `port7id_tile;
		end
		*/

		// Algoritmo Negative-First
		/*
		if (cmp[`SOUTH]) begin //& ~(congestion[`SOUTH])) begin
			if(~(congestion[`SOUTH])) begin
				tmp_route.output_port = `port7id_south;
			end else if (cmp[`WEST]) begin
				tmp_route.output_port = `port7id_west;
			end else begin
				tmp_route.output_port = `port7id_south;
			end
		end else if (cmp[`WEST]) begin //& ~(congestion[`WEST]))  begin
			tmp_route.output_port = `port7id_west;
		end else if (~(cmp[`WEST] | cmp[`SOUTH]) & cmp[`EAST]) begin //& ~(congestion[`EAST]))  begin
			if (~(congestion[`EAST])) begin
				tmp_route.output_port = `port7id_east;
			end else if (cmp[`NORTH]) begin
				tmp_route.output_port = `port7id_north;
			end else begin
				tmp_route.output_port = `port7id_east;
			end
		end else if (~(cmp[`WEST] | cmp[`SOUTH]) & cmp[`NORTH]) begin //& ~(congestion[`NORTH])) begin
			tmp_route.output_port = `port7id_north;
		end else if (~(cmp[`EAST] | cmp[`WEST] | cmp[`SOUTH] | cmp[`NORTH])) begin
			tmp_route.output_port = `port7id_tile;
		end
		*/

	end // always_comb begin


	generate
		for (vc=0; vc < NV; vc++) begin
			always @(posedge clk) begin
				if (!rst_n) begin
					//TO DO...
				end else begin
					
					if (!route_valid[vc] && flit_in.control.valid && oh2bin(flit_in.control.vc_id) == vc) begin 
						routes[vc] <= tmp_route;
				
					end
					
				end
			end // always @(posedge clk) begin
		end //for
	endgenerate


	always_comb begin
		flit_out = flit_in;
		if (route_valid[oh2bin(flit_in.control.vc_id)]) begin
			flit_out.control.output_port = routes[oh2bin(flit_in.control.vc_id)].output_port;
			flit_out.control.vn = routes[oh2bin(flit_in.control.vc_id)].v_out;
			flit_out.control.drop = routes[oh2bin(flit_in.control.vc_id)].drop;
		end else begin
			flit_out.control.output_port = tmp_route.output_port;
			flit_out.control.vn = tmp_route.v_out;
			flit_out.control.drop = tmp_route.drop;
		end
	end

endmodule // route
//`endif