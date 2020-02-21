/* -------------------------------------------------------------------------------
 * @file nalu_package.vhd
 * @brief Package with Defines definitions, Typedef definitions and Misc. functions packages for NaluNoC
 * @authors Alexandre Coelho, alexandre.coelho@imag.fr
 * @date 01/02/2017
 * @copyright TIMA.
*/

/* -------------------------------------------------------------------------------
 * Typedef definitions
 * 
 * - 'flit_t' gets defined here
 * - 'sim_stats_t' gets defined here
 * - 'chan_cntrl_t' gets defined here
 * - 'fifo_flags_t' gets defined here
 * - 'debug_flit_t' gets defined here
 */

typedef logic [`VC_INDEX_BITS-1:0] vc_index_t;
typedef logic [`OUTPUT_PORT_RADIX-1:0] output_port_t;
typedef logic [`ROUTER_NUM_VCS-1:0] vc_t;
typedef logic [1:0] vin_t;
typedef logic [3:0] elv_coord_t;
typedef logic [`CHANNEL_DATA_WIDTH-1:0] data_t;
typedef logic [`MAX_FLIT_SIZE:0] flit_size_t;
typedef logic [15:0] packet_size_t;
typedef logic [`X_ADDR_BITS-1:0] x_coord_t ;
typedef logic [`Y_ADDR_BITS-1:0] y_coord_t ;
//typedef logic [`Z_ADDR_BITS-1:0] z_coord_t ;



//FIFO Package
typedef struct packed
{
	logic full, empty, nearly_full, nearly_empty;
} fifo_flags_t;



//CHANNEL Package
typedef struct packed 
{
	vc_index_t credit;
	logic credit_valid;	 
} chan_cntrl_t;


typedef struct packed 
{	
	output_port_t output_port;
	vin_t v_out;
	logic drop;
} outport_vout_t;



//DEBUG Package
typedef struct packed
	{
	 integer flit_id;      // sequential flit id.
	 integer packet_id;    // sequential (for a particular source node) packet id.
	 integer inject_time;  // time flit entered source FIFO
	 
	 integer hops;         // no. of routers flit traverses on journey
	 
	 integer xdest, ydest; // final destination
	 integer xsrc, ysrc;   // where was packet sent from

	 } debug_flit_t;

	
//CONTROL Package
typedef struct packed
{
	logic valid;	  
	logic head; 
	logic tail;

	// output port required at next router
	output_port_t output_port;

	// destination as displacement from source
	x_coord_t x_dest;
	y_coord_t y_dest;

	//Virtual Network and drop package
	vin_t vn;
	logic drop;

	// Mask for VC Allocator
	vc_t vcalloc_mask;
	
	// Virtual Channel
	vc_t vc_id;
} control_flit_t;



//FLIT Package
typedef struct packed
{
	data_t data;
	control_flit_t control;
`ifdef DEBUG
	debug_flit_t debug;
`endif

`ifndef DEBUG
	`ifdef DEBUG_ROUTER
		debug_flit_t debug;
	`endif
`endif

} flit_t;



//SIM_STATISTIC Package
typedef struct 
{
	integer total_dropped_flits;
	integer total_latency;
	integer total_hops;
	integer min_latency, max_latency;
	integer min_hops, max_hops;

	// start and end of measurement period
	integer measure_start, measure_end, flit_count; 

	// record statistics for packets with common journey lengths (hop count)
	integer total_lat_for_hop_count [(`NETWORK_X+`NETWORK_Y):0];
	integer total_packets_with_hop_count [(`NETWORK_X+`NETWORK_Y):0];

	// record frequency of different packet latencies
	integer lat_freq[1000:0];
   
} sim_stats_t;



/* -------------------------------------------------------------------------------
 * Misc. functions package
 * 
 *   - clogb2(x) - ceiling(log2(x))
 *   - oh2bin(x) - one-hot to binary encoder
 *   - max (x,y) - returns larger of x and y
 *   - min (x,y) - returns smaller of x and y
 *   - abs (x)   - absolute function
 */

// A constant function to return ceil(logb2(x))
// Is this already present in the Systemverilog Standard = $clog2
function automatic integer clog2 (input integer depth);
   integer i,x;
   begin
      x=1;
      for (i = 0; 2**i < depth; i = i + 1)
	x = i + 1;

      clog2=x;
   end
endfunction

function automatic integer clogb2 (input integer depth);
   integer i,x;
   begin
      x=1;
      for (i = 0; 2**i < depth; i = i + 1)
	x = i + 1;

      clogb2=x;
   end
endfunction

// one hot to binary encoder (careful not to produce priority encoder!)
function automatic integer oh2bin (input integer oh);
   
   integer unsigned i,j;
   begin
      oh2bin='0;
      for (i=0; i<5; i++) begin
	 for (j=0; j<32; j++) begin
	    if ((1'b1 << i)&j) begin
	       oh2bin[i] = oh2bin[i] | oh[j] ;
	    end
	 end
      end
   end
endfunction // oh2bin

function automatic bit NL_route_valid_input_vc (integer port, integer vc);

	//`include "parameters.sv"

	bit valid;
	begin
		valid=1'b1;

		if (port==`TILE) begin
			if (vc>=router_num_vcs_on_entry) valid=1'b0;
		end

		if(port==`NORTH) begin
			if (vc>=router_num_vcs[`NORTH]) valid=1'b0;
		end
		
		if(port==`EAST) begin
			if (vc>=router_num_vcs[`EAST]) valid=1'b0;
		end
		
		if(port==`SOUTH) begin
			if (vc>=router_num_vcs[`SOUTH]) valid=1'b0;
		end
		
		if(port==`WEST) begin
			if (vc>=router_num_vcs[`WEST]) valid=1'b0;
		end

		NL_route_valid_input_vc=valid;
	end
endfunction // automatic

function automatic bit NL_route_valid_turn(output_port_t from, output_port_t to);
	bit valid;
	begin
		valid=1'b1;

		// flits don't leave on the same port as they entered
		if (from==to) valid=1'b0;

		//TILE can send to TILE
		//if(from==`TILE && to ==`TILE) valid=1'b1;
/*		
`ifdef RT_NOCFT
		if(from==`WEST && to ==`WEST) valid=1'b1;
		if(from==`SOUTH && to ==`SOUTH) valid=1'b1;
`endif
*/
		NL_route_valid_turn=valid;
	end
endfunction // bit
