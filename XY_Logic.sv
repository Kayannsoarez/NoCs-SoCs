// Roteamento XY puro
		
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
		