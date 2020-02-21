// Algoritmo Negative-First
		
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
		