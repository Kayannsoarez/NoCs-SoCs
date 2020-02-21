# CLEAN WORK LIBRARY
if {[file exists work]} {
	quit -sim
	vdel -lib work -all
}

# SET WORK LIBRARY
vlib work
vmap work work 

# SOURCE FILES
vlog -sv -mfcu -work work +nowarnSVCHK +nowarnTFMPC +incdir+lib -f comp_noc.f

# BUILD SIMULATION
#vsim -novopt work.NL_test_random
vsim -gsim_injection_rate=0.01 work.NL_test_random


# RUN SIMULATION
run -all