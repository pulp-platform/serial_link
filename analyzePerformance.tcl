#!/usr/bin/tclsh
# execute this script in serial_link with "tclsh analyzePerformance.tcl"
# result will be printed out to perfAnalysis.csv

# define the desired sweep
set noc_credits_include_zero 0
set noc_credits_start 5
set noc_credits_stop 50
set noc_credits_step 1

set link_credits_start 8
set link_credits_stop 8
set link_credits_step 1


set requiredSteps [expr (($noc_credits_stop - $noc_credits_start)/$noc_credits_step + 1 + $noc_credits_include_zero) * \
				   (($link_credits_stop - $link_credits_start)/$link_credits_step + 1)]
set performedSteps 0
puts "progress: $performedSteps/$requiredSteps (0%)"
exec echo "NumCredits, NumCred_NocBridge, PerformanceRating, narrow1 BW (sent/rcv) Mbit/s, narrow2 BW (sent/rcv) Mbit/s, wide1 BW (sent/rcv) Mbit/s, wide2 BW (sent/rcv) Mbit/s, data_link_0: valid_coverage_to_phys, data_link_0: valid_coverage_from_phys, data_link_0: num_cred_only, data_link_1: valid_coverage_to_phys, data_link_1: valid_coverage_from_phys, data_link_1: num_cred_only, noc_bridge_0: valid_coverage_to_phys, noc_bridge_0: valid_coverage_from_phys, noc_bridge_0: num_cred_only, noc_bridge_0: valid_in_but_not_valid_out, noc_bridge_1: valid_coverage_to_phys, noc_bridge_1: valid_coverage_from_phys, noc_bridge_1: num_cred_only, noc_bridge_1: valid_in_but_not_valid_out" > perfAnalysis.csv


for { set link_credits $link_credits_start}  {$link_credits <= $link_credits_stop} {incr link_credits $link_credits_step} {
	set fd [open src/serial_link_pkg.sv r]
	set newfd [open src/serial_link_pkg.sv.tmp w]
	while {[gets $fd line] >= 0} {
		if {[string first "localparam int NumCredits = " $line] != -1} {
	    	puts $newfd "  localparam int NumCredits = $link_credits;"
		} else {
	    	puts $newfd $line
		}
	}
	close $fd
	close $newfd
	file rename -force "src/serial_link_pkg.sv.tmp" "src/serial_link_pkg.sv"

	if {$noc_credits_include_zero == 1} {
		set fd [open src/noc_bridge_narrow_wide_pkg.sv r]
		set newfd [open src/noc_bridge_narrow_wide_pkg.sv.tmp w]
		while {[gets $fd line] >= 0} {
			if {[string first "localparam int NumCred_NocBridge = " $line] != -1} {
		    	puts $newfd "  localparam int NumCred_NocBridge = 0;"
			} else {
		    	puts $newfd $line
			}
		}
		close $fd
		close $newfd
		file rename -force "src/noc_bridge_narrow_wide_pkg.sv.tmp" "src/noc_bridge_narrow_wide_pkg.sv"
		exec echo -n "$link_credits, 0, " >> perfAnalysis.csv
		exec make sim_c > perfAnalysis.tmp
		exec cat perfAnalysis.tmp | grep "Status: " > perfAnalysis.tmp2
		set hasFailedFile [open perfAnalysis.tmp2]
		set fileContent [read $hasFailedFile]
		set progressStatus "ok"
		if {$fileContent == "\[1;37;41mStatus: There are errors!\[0m\n"} {
			set progressStatus "fail"
			exec echo "sim failed" >> perfAnalysis.csv
		} else {
			exec cat perfAnalysis.tmp | grep "benchmarking: Performance Rating (lower is better): " | cut -d " " -f 8 | head -c-1 >> perfAnalysis.csv
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: narrow1 BW " | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: narrow1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: narrow2 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: wide1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: wide2 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A, N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 5 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 7 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A, N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 5 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 7 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A, N/A, N/A" >> perfAnalysis.csv
			}
			# switch to new line
			exec echo "" >> perfAnalysis.csv
		}
		incr performedSteps
		puts "progress: $performedSteps/$requiredSteps ([expr ($performedSteps*100)/$requiredSteps]%) - $progressStatus"
	}

	for { set noc_credits $noc_credits_start}  {$noc_credits <= $noc_credits_stop} {incr noc_credits $noc_credits_step} {
		set fd [open src/noc_bridge_narrow_wide_pkg.sv r]
		set newfd [open src/noc_bridge_narrow_wide_pkg.sv.tmp w]
		while {[gets $fd line] >= 0} {
			if {[string first "localparam int NumCred_NocBridge = " $line] != -1} {
		    	puts $newfd "  localparam int NumCred_NocBridge = $noc_credits;"
			} else {
		    	puts $newfd $line
			}
		}
		close $fd
		close $newfd
		file rename -force "src/noc_bridge_narrow_wide_pkg.sv.tmp" "src/noc_bridge_narrow_wide_pkg.sv"
		exec echo -n "$link_credits, $noc_credits, " >> perfAnalysis.csv
		exec make sim_c > perfAnalysis.tmp
		exec cat perfAnalysis.tmp | grep "Status: " > perfAnalysis.tmp2
		set hasFailedFile [open perfAnalysis.tmp2]
		set fileContent [read $hasFailedFile]
		set progressStatus "ok"
		if {$fileContent == "\[1;37;41mStatus: There are errors!\[0m\n"} {
			set progressStatus "fail"
			exec echo "sim failed" >> perfAnalysis.csv
		} else {
			exec cat perfAnalysis.tmp | grep "benchmarking: Performance Rating (lower is better): " | cut -d " " -f 8 | head -c-1 >> perfAnalysis.csv
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: narrow1 BW " | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: narrow1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: narrow2 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: wide1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: wide2 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A, N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 5 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 7 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.noc_bridge_benchmarking" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A, N/A, N/A" >> perfAnalysis.csv
			}
			if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | wc -l] == "2"} {
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 5 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 7 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
				exec echo -n ", " >> perfAnalysis.csv
				exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.noc_bridge_benchmarking" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
			} else {
				exec echo -n ", N/A, N/A, N/A, N/A" >> perfAnalysis.csv
			}
			# switch to new line
			exec echo "" >> perfAnalysis.csv
		}
		incr performedSteps
		puts "progress: $performedSteps/$requiredSteps ([expr ($performedSteps*100)/$requiredSteps]%) - $progressStatus"
	}

}
exec rm perfAnalysis.tmp
exec rm perfAnalysis.tmp2