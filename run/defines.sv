/* 
 -------------------------------------------------------------
 * defines.sv
 * Created by Alexandre Coelho
 * First Version - 20/02/2017
 *
 -------------------------------------------------------------
 * `defines are only used to create type definitions 
 * module parameters should always be used locally in modules
 *
 -------------------------------------------------------------
 */
 
`include "parameters.sv"

 /* 
 #############################################################
 *
 * Defines some debugs need just for simulation.
 *
 #############################################################
 */
`define DEBUG
`define DEBUG_HOTSPOT 0
//`define DEBUG_CC
//`define DEBUG_PACK_SENT
`define VERBOSE
`define VERBOSE_COUNT
`define MODELSIM
/*------------------------------------------------------------*/
 
 
 /* 
 #############################################################
 *
 * Choose the router algorithm 
 * NEED TO BE USED IN SIMULATION AND SYNTHESIS
 * The default routing is the Baseline, if NO define is selected.
 *
 #############################################################
 */
`define RT_NOCFT
/*------------------------------------------------------------*/

/* ADDED FOR TESTING WITH CONGESTION - IF FAIL REMOVE IT */
`define CONGESTION_METRIC_BUF

/* 
 #############################################################
 *
 * Do not change after this point... 
 *
 #############################################################
 */
`define CHANNEL_DATA_WIDTH channel_data_width
`define MAX_PACKET_SIZE sim_packet_length
`define MAX_FLIT_SIZE $clog2(sim_packet_length)


`define X_ADDR_BITS $clog2(network_x)
`define Y_ADDR_BITS $clog2(network_y)


`define ROUTER_NUM_VCS_X router_num_vcs_x
`define ROUTER_NUM_VCS_Y router_num_vcs_y


`define VC_INDEX_BITS_X $clog2(router_num_vcs_x)
`define VC_INDEX_BITS_Y $clog2(router_num_vcs_y)


`define ROUTER_NUM_VCS router_num_max_vcs
`define VC_INDEX_BITS $clog2(router_num_max_vcs) // If I need more than 1 VCs
//`define VC_INDEX_BITS router_num_max_vcs // Used only when I set 1 VC
`define ROUTER_RADIX  router_radix
`define OUTPUT_PORT_RADIX  output_port_radix


//Network X and Y dimension
`define NETWORK_X network_x
`define NETWORK_Y network_y



// port ids for 7 port router (input or output)
`define port7id_north 5'b00001
`define port7id_east  5'b00010
`define port7id_south 5'b00100
`define port7id_west  5'b01000
`define port7id_tile  5'b10000



// Defines points cardinals
`define NORTH 0
`define EAST  1
`define SOUTH 2
`define WEST  3
`define TILE  4
//`define UP    5
//`define DOWN  6


// Defines First-Last two more bits
`define WEST_V1  0
`define SOUTH_V1 1


// Defines TURNs
`define NE 0
`define SE 1
`define SW 2
`define NW 3
`define EW 4


//Define Ports x Virtual Channels
`define PV  NP*NV
/*------------------------------------------------------------*/