#!/usr/bin/tclsh
# execute this script in serial_link with "tclsh analyzePerformance.tcl"
# result will be printed out to perfAnalysis.csv

# define the desired sweep
set noc_credits_include_zero 0
set noc_credits_start 8
set noc_credits_stop 8
set noc_credits_step 1

set link_credits_start 8
set link_credits_stop 8
set link_credits_step 1


set requiredSteps [expr (($noc_credits_stop - $noc_credits_start)/$noc_credits_step + 1 + $noc_credits_include_zero) * \
				   (($link_credits_stop - $link_credits_start)/$link_credits_step + 1)]
set performedSteps 0
puts "progress: $performedSteps/$requiredSteps (0%)"
exec echo "NumCredits, NumCred_NocBridge, PerformanceRating, narrow1 BW (sent/rcv) Mbit/s, narrow2 BW (sent/rcv) Mbit/s, wide1 BW (sent/rcv) Mbit/s, wide2 BW (sent/rcv) Mbit/s" > perfAnalysis.csv


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
			exec echo " sim failed" >> perfAnalysis.csv
		} else {
			exec cat perfAnalysis.tmp | grep "INFO: Performance Rating (lower is better): " | cut -d " " -f 8 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: narrow1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: narrow2 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: wide1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: wide2 BW " | cut -d " " -f 5 >> perfAnalysis.csv
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
			exec echo " sim failed" >> perfAnalysis.csv
		} else {
			exec cat perfAnalysis.tmp | grep "INFO: Performance Rating (lower is better): " | cut -d " " -f 8 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: narrow1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: narrow2 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: wide1 BW " | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
			exec echo -n ", " >> perfAnalysis.csv
			exec cat perfAnalysis.tmp | grep "INFO: wide2 BW " | cut -d " " -f 5 >> perfAnalysis.csv
		}
		incr performedSteps
		puts "progress: $performedSteps/$requiredSteps ([expr ($performedSteps*100)/$requiredSteps]%) - $progressStatus"
	}

}
exec rm perfAnalysis.tmp
exec rm perfAnalysis.tmp2