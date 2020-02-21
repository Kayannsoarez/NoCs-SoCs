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