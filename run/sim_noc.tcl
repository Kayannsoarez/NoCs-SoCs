#Windows
#cd C:/Users/alexh/NaluNoC/nalu_nocft_rout3d_cobra/branches/dft_elf_nocft_rout3d_cobra/nalu/run
#
#Linux
#vsim -c -do sim_modelsim.tcl | tee results &
#

# ---- Parameters for test ---- #
set filename_read "nalu_log.txt"
set filename_write "results.txt"
set qtd_sim "9"
set list_inj_rate  {0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.12}


# ------------------------------------------------------------------------------ #
# -------------------------DO NOT CHANGE AFTER THIS POINT----------------------- #
# ------------------------------------------------------------------------------ #

# open the filename for writing the testbench result and set the HEAD FILE
set file_writeId [open $filename_write "a"]

# Results HEAD
puts $file_writeId "#-------------------------------------------------------------------------------------------------------------------------------------------#"
puts $file_writeId "#Simulation Results: [clock format [clock seconds]]"
puts $file_writeId "#-------------------------------------------------------------------------------------------------------------------------------------------#"
puts $file_writeId "#InjectionRate \t\tAverageLatency \t\tTotalLatency \t\tPacketReceived \t\tPacketDropped \t\tPacketSended \t\tTrafficPartner"


for {set n 0} {$n <= $qtd_sim } {incr n} {
	# Save lines transcript
	set PrefMain(saveLines) 100000
	set inj_rate [lindex $list_inj_rate $n]

	# START HERE --> Carlos
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
	vsim -gsim_injection_rate=$inj_rate work.NL_test_random
	


	#DEBUG WAVE Input port and router
	#do wave_router.do


	# RUN SIMULATION
	run -all
	#FINISH HERE --> Carlos
	
	#Save transcript in a file
	#write transcript nalu_log_$n
	write transcript nalu_log.txt
	
	
	# open the filename for reading results
	set file_readId [open $filename_read "r"]
	set lines [split [read $file_readId] "\n"]
	close $file_readId
		
	foreach line $lines {
		#puts "\n"
		#puts $line
		
		if {[regexp {(Traffic partner) +(\S+) +(.*)} $line -> name iqual value_traffic_partner]} {
			puts "The name \"$name\" maps to the value \"$value_traffic_partner\""
		}
		
		if {[regexp {(Injection Rate) +(\S+) +(\S+) +(.*)} $line -> name iqual value_inj]} {
			puts "The name \"$name\" maps to the value \"$value_inj\""
		}

		if {[regexp {(AverageLatency) +(\S+) +(\S+) +(.*)} $line -> name iqual value_avg_lat]} {
			puts "The name \"$name\" maps to the value \"$value_avg_lat\""
		}
		
		if {[regexp {(TotalLatency) +(\S+) +(.*)} $line -> name iqual value_tot_lat]} {
			puts "The name \"$name\" maps to the value \"$value_tot_lat\""
		}
		
		if {[regexp {(PacketReceived) +(\S+) +(.*)} $line -> name iqual value_pack_rec]} {
			puts "The name \"$name\" maps to the value \"$value_pack_rec\""
		}

		if {[regexp {(PacketsDropped) +(\S+) +(.*)} $line -> name iqual value_dropped_packet]} {
			puts "The name \"$name\" maps to the value \"$value_dropped_packet\""
		}		
		
		if {[regexp {(PacketsSended) +(\S+) +(.*)} $line -> name iqual value_sended_packet]} {
			puts "The name \"$name\" maps to the value \"$value_sended_packet\""
		}
		
	}
	
	# send the data to the file -
	puts $file_writeId "\t$value_inj \t\t\t$value_avg_lat \t\t\t\t$value_tot_lat \t\t\t$value_pack_rec \t\t\t\t$value_dropped_packet  \t\t\t\t\t$value_sended_packet  \t\t\t\t$value_traffic_partner"
			
	# Flushes any output that has been buffered for fileID.
	flush $file_writeId
	
	# New line for the next input file simulation
	#puts $file_writeId ""
	
	if {$value_avg_lat > 251} {
		set n "100"
	}
	
}

	# Close reult file write
	close $file_writeId
