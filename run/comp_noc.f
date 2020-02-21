#
# Mini - Netmaker
#

#
# RTL-level simulation
#
defines.sv
../src/NL_package.sv
#
# Registers etc.
#
../src/NL_pipelined_channel.sv
#
# FIFOs, Arbiters, Input Buffers, etc.
#
../src/NL_arbiter.sv
../src/NL_vc_buffers.sv
#../src/NL_vc_escape_buffers.sv
../src/NL_vc_input_port.sv
../src/NL_vc_free_pool.sv
../src/NL_vc_fc_out.sv
#
# Crossbar
#
../src/NL_crossbar.sv
#
# Switch Allocation
#
../src/NL_vc_switch_allocator.sv  
#
# VC allocation
#
../src/NL_vc_unrestricted_allocator.sv
#
# Misc Modules
#
../src/NL_unary_select_pair.sv
../src/NL_mux_oh_select.sv
#
# Congestion Metric - Added for testing with congestion!
#
../src/NL_route_preselect.sv
#
# Routing Unit
#
../src/routing_unit/NL_nocft_planar.sv
#../src/routing_unit/NL_nocft_updown.sv
#
# Router and Network
#
../src/NL_vc_router.sv
../src/NL_router.sv
../src/NL_mesh_network.sv
# 
# Testbench
#
../verif/NL_traffic_source_fifo.sv
../verif/NL_traffic_source.sv
../verif/NL_traffic_sink.sv
../verif/NL_traffic_test_functions.sv
../verif/NL_test_random.sv