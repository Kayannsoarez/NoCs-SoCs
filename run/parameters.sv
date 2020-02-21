/* 
 ----------------------------------------------------------
 * parameters.sv
 * Modified by Alexandre Coelho
 * Version - 20/02/2017
 ----------------------------------------------------------
 */


/* 
 ##########################################################
 * Simulation Parameter 
 ##########################################################
 */
parameter sim_warmup_packets=0;
parameter sim_measurement_packets=100; /* From 100 to 20 packets per PU */
parameter sim_packet_injected=1;//1000;
parameter sim_stop_cycle = 100000;
parameter sim_packet_length=5;
parameter sim_packet_fixed_length=1;
parameter sim_injection_rate=0.2;
parameter sim_traffic_type=0;


/* 
 ##########################################################
 * Channel parameters, like latency and data_width 
 ##########################################################
 */
parameter channel_data_width=32;
parameter channel_latency=1;


/* 
 ##########################################################
 * Network X and Y dimension 
 ##########################################################
 */
parameter network_x=4; /* From 8x8 to 4x4 */
parameter network_y=4;


/* 
 ##########################################################
 * Router configuration: Virtual Channel and Buffer
 ##########################################################
 */

//Number of VCS in the ROUTER
parameter [2:0] router_num_vcs [0:4] = '{2, 2, 2, 2, 2}; //{N, E, S, W, T/L}
parameter router_num_max_vcs=2;

//Number of VCS in the TILE PORT IN/OUT
parameter router_num_vcs_on_entry=2; // NUM_VCS_ON_TILE IN
parameter router_num_vcs_on_exit=2; // NUM_VCS_ON_TILE OUT

parameter router_buf_len=4;
parameter router_radix=5;
parameter output_port_radix=5;

parameter vcselect_usepacketmask=1;