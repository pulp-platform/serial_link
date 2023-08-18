# Copyright (c) 2019 ETH Zurich
# Matheus Cavalcante <matheusd@iis.ee.ethz.ch>

# A library of useful functions for Synopsys Design Compiler.

set ROOT    [file normalize [file join [file dirname [info script]] ../../..]]
set SYNDIR  [file normalize [file join $ROOT gf22/synopsys]]
set BEDIR   [file normalize [file join $ROOT gf22/fusion]]
set TECHDIR [file normalize [file join $ROOT gf22/technology]]
set PDK     /usr/pack/gf-22-kgf/gf/pdk-22FDX-V1.3_2.2/PlaceRoute/ICC2

set disable_multicore_resource_checks true

set_host_options -max_cores 4

suppress_message LINT-1
suppress_message LINT-2
suppress_message LINT-3
suppress_message LINT-28
suppress_message LINT-29
suppress_message LINT-31
suppress_message LINT-32
suppress_message LINT-33
suppress_message LINT-52
suppress_message LINT-54
suppress_message UCN-1
suppress_message VER-61
suppress_message TIM-179

set suppress_errors [list PSYN-115]

proc pause {{message "Hit Enter to continue ==> "}} {
  puts -nonewline $message
  flush stdout
  gets stdin
}

# Analyze all benderized source files.
proc analyze_bender {} {
  global SYNDIR
  global ROOT
  global search_path
  set SAVE_ROOT $ROOT
  exec mkdir -p tmp
  exec bender script synopsys \
    -t rtl \
    -t gf22 > tmp/analyze.tcl 2> /dev/stdin
  source tmp/analyze.tcl > analyze.log
  # ROOT will be overwritten by bender
  set ROOT $SAVE_ROOT
  puts [exec $SYNDIR/scripts/safe_grep.sh -iE "(error|warning):" analyze.log]
  if {[exec $SYNDIR/scripts/safe_grep.sh -ic "error:" analyze.log] > 0} {
    error "Compilation failed"
  }
}