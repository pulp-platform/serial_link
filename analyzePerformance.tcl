#!/usr/bin/tclsh
# execute this script in serial_link with "tclsh analyzePerformance.tcl"
# result will be printed out to perfAnalysis.csv

# define the desired sweep
set noc_credits_include_zero 1
set noc_credits_start 5
set noc_credits_stop 20
set noc_credits_step 5

set link_credits_start 5
set link_credits_stop 21
set link_credits_step 4

proc print_field_explanation {} {
	exec echo "---------- few explanations on the obtained data ----------" >> perfAnalysis.csv
	exec echo "-> The random master/slave configurations (with all relevant parameters),,,are provided in the above section *random master/slaves configuration*. The requested number of transactions are listed for the individual masters in their respective type section." >> perfAnalysis.csv
	exec echo "-> The latency_of_delay_module,,parameter reports the selected delay which will be introduced in the physical layer. The module delays the incoming signal to the serial_link_physical module in the floo_serial_link_narrow_wide instance." >> perfAnalysis.csv
	exec echo "-> bandwidth_physical_channel,,describes the amount of bits which can be transfered over the physical link in one off-chip clock cycle. The off-chip physical channel uses DDR. For this reason the number is twice the size of the actual width of the physical link." >> perfAnalysis.csv
	exec echo "-> Comparing bandwidth_physical_channel with max_data_transfer_size,,,it is possible to find out how many splits are required in the serial_link_data_link when transfering a wide packet." >> perfAnalysis.csv
	exec echo "->  data_link_stream_fifo_depth,,is an extraordinary field. All the other fields report general information which is independant of the parametric run. But this field is not representing globally true information. It shows the resulting stream_fifo depth for the very first simulation run. The information can be used to conclude on how the credits are being consumed and on how many splits may be expected." >> perfAnalysis.csv
	exec echo "-> The {narrow_ax_len & narrow_ax_size & wide_ax_len & wide_ax_size},,,parameters show the selected numbers for the random masters (values passed via the traffic shaping function)" >> perfAnalysis.csv
	exec echo "->  The column *NumCredits* is,,indicating the number of credits used by the credit counter/syncronization unit of the serial_link_data_link." >> perfAnalysis.csv
	exec echo "-> NumCred_NocBridge lists the,,amount of credits available to the channels of the noc_bridge. All of the three virtual channels are make to have the same amount of credits. A value of zero indicates that the noc_bridge without virtual channels is being used (thus no blue background)." >> perfAnalysis.csv
	exec echo "->  The four BW fields report the,,bandwidth which is found from the perspective of the noc_bridge. This means that the sum of all the bits (from all AXI channels) is calculated and devided by the overall required time for the transfers to complete. This is also why the number cannot be as high as the maximal possible transfer rate of the physical link itself. For one reason the physical links BW is shared between narrow & wide channels. Secondly the amount of bits can be different for the individual AXI channels. Lastly the serial_link_data_link may introduce additional payload by sending credit only packets." >> perfAnalysis.csv
	exec echo "max_BW_physical_from_side_1:,,describes the maximal possible bandwidth supported by the physical channel connecting the two chiplets. The calculation considers the clock frequency of the first on-chip clock and devides by a factor of 8 (clock divider for off-chip clock). The resulting frequency is multiplied by the number reported under bandwidth_physical_channel." >> perfAnalysis.csv
	exec echo "max_BW_physical_from_side_2:,,describes the maximal possible bandwidth supported by the physical channel connecting the two chiplets. The calculation considers the clock frequency of the second on-chip clock and devides by a factor of 8 (clock divider for off-chip clock). The resulting frequency is multiplied by the number reported under bandwidth_physical_channel" >> perfAnalysis.csv
	exec echo "" >> perfAnalysis.csv
}

proc print_csv_header {performedSteps} {
	if {$performedSteps == 0} {
		# Fetch the configuration of the random_axi_devices (masters/slaves)
		exec echo "results generated per analyzePerformance script (version 1.0) on [exec date]" >> perfAnalysis.csv
		exec echo "---------- random masters/slaves configuration ----------" >> perfAnalysis.csv
		exec echo -n "narrow_axi_rand_master_t,,AW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ",wide_axi_rand_master_t,AW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo ",narrow_axi_rand_slave_t,,,wide_axi_rand_slave_t,," >> perfAnalysis.csv
        exec echo -n ",,DW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.DW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,DW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.DW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo ",,,,,," >> perfAnalysis.csv
        exec echo -n ",,IW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.IW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,IW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.IW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo ",,,,,," >> perfAnalysis.csv
        exec echo -n ",,UW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.UW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,UW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.UW" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,TA," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.TA" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,TA," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.TA" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,TT," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.TT" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,TT," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.TT" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.AW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.AW" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,MAX_READ_TXNS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.MAX_READ_TXNS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,MAX_READ_TXNS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.MAX_READ_TXNS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,DW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.DW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,DW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.DW" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,MAX_WRITE_TXNS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.MAX_WRITE_TXNS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,MAX_WRITE_TXNS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.MAX_WRITE_TXNS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,IW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.IW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,IW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.IW" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,AX_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AX_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AX_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AX_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,UW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.UW" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,UW," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.UW" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,AX_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AX_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AX_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AX_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,TA," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.TA" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,TA," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.TA" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,W_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.W_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,W_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.W_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,TT," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.TT" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,TT," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.TT" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,W_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.W_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,W_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.W_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RAND_RESP," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.RAND_RESP" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RAND_RESP," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.RAND_RESP" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,RESP_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.RESP_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RESP_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.RESP_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AX_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.AX_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AX_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.AX_MIN_WAIT_CYCLES" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,RESP_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.RESP_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RESP_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.RESP_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AX_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.AX_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AX_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.AX_MAX_WAIT_CYCLES" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,TRAFFIC_SHAPING," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.TRAFFIC_SHAPING" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,TRAFFIC_SHAPING," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.TRAFFIC_SHAPING" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,R_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.R_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,R_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.R_MIN_WAIT_CYCLES" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,AXI_EXCLS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AXI_EXCLS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AXI_EXCLS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AXI_EXCLS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,R_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.R_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,R_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.R_MAX_WAIT_CYCLES" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,AXI_ATOPS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AXI_ATOPS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AXI_ATOPS," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AXI_ATOPS" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RESP_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.RESP_MIN_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RESP_MIN_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.RESP_MIN_WAIT_CYCLES" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,AXI_BURST_FIXED," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AXI_BURST_FIXED" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AXI_BURST_FIXED," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AXI_BURST_FIXED" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RESP_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_slave_t.RESP_MAX_WAIT_CYCLES" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,RESP_MAX_WAIT_CYCLES," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_slave_t.RESP_MAX_WAIT_CYCLES" | cut -d "$" -f 2 >> perfAnalysis.csv
        exec echo -n ",,AXI_BURST_INCR," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AXI_BURST_INCR" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AXI_BURST_INCR," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AXI_BURST_INCR" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo ",,,,,," >> perfAnalysis.csv
        exec echo -n ",,AXI_BURST_WRAP," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: narrow_axi_rand_master_t.AXI_BURST_WRAP" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,AXI_BURST_WRAP," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "rand_device: wide_axi_rand_master_t.AXI_BURST_WRAP" | cut -d "$" -f 2 | head -c-1 >> perfAnalysis.csv
        exec echo ",,,,,," >> perfAnalysis.csv
        exec echo -n ",,Number_Of_Writes (narrow_1)," >> perfAnalysis.csv
        exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 3 | head -c-1 >> perfAnalysis.csv
        exec echo -n ",,Number_Of_Writes (wide_1)," >> perfAnalysis.csv
        exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 7 >> perfAnalysis.csv
		exec echo -n ",,Number_Of_Reads (narrow_1)," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 4 | head -c-1 >> perfAnalysis.csv
		exec echo -n ",,Number_Of_Reads (wide_1)," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 8 >> perfAnalysis.csv
		exec echo -n ",,Number_Of_Writes (narrow_2)," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 5 | head -c-1 >> perfAnalysis.csv
		exec echo -n ",,Number_Of_Writes (wide_2)," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 9 >> perfAnalysis.csv
		exec echo -n ",,Number_Of_Reads (narrow_2)," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 6 | head -c-1 >> perfAnalysis.csv
		exec echo -n ",,Number_Of_Reads (wide_2)," >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "numberOfTransactions:" | cut -d " " -f 10 >> perfAnalysis.csv

		exec echo "---------- general information about this benchmarking run ----------" >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 3 | cut -d ";" -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", , " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 4 | cut -d ";" -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 5 | cut -d ";" -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 6 | cut -d ";" -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 7 | cut -d ";" -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 8 | cut -d ";" -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo ", narrow_ax_len, narrow_ax_size, wide_ax_len, wide_ax_size, max_BW_physical_from_side_1, max_BW_physical_from_side_2" >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 3 | cut -d ";" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", , " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 4 | cut -d ";" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 5 | cut -d ";" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 6 | cut -d ";" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 7 | cut -d ";" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "settings: " | cut -d " " -f 8 | cut -d ";" -f 2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat test/tb_floo_serial_link_narrow_wide.sv | grep narrow_rand_master_1.add_traffic_shaping_fixed_size | cut -d "(" -f2 | cut -d "," -f1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat test/tb_floo_serial_link_narrow_wide.sv | grep narrow_rand_master_1.add_traffic_shaping_fixed_size | cut -d "," -f2 | cut -d " " -f2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat test/tb_floo_serial_link_narrow_wide.sv | grep wide_rand_master_1.add_traffic_shaping_fixed_size | cut -d "(" -f2 | cut -d "," -f1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat test/tb_floo_serial_link_narrow_wide.sv | grep wide_rand_master_1.add_traffic_shaping_fixed_size | cut -d "," -f2 | cut -d " " -f2 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		# exec echo -n "TODO_max_possible_bridge_bw_narrow" >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "max_possible_bandwidth_physical_link !" | cut -d "!" -f 2 >> perfAnalysis.csv
		# exec echo -n ", " >> perfAnalysis.csv
		# exec echo "TODO_max_possible_bridge_bw_wide" >> perfAnalysis.csv
		print_field_explanation
		exec echo "---------- start of the simulation ----------,,,,,,,,,,,,,,,,,,,,,,,average latency (rand_master runtime per packet),,,,min and max latency numbers for the narrow channel from side 1 to 2,,,,,,,,,,min and max latency numbers for the narrow channel from side 2 to 1,,,,,,,,,,min and max latency numbers for the wide channel from side 1 to 2,,,,,,,,,,min and max latency numbers for the wide channel from side 2 to 1" >> perfAnalysis.csv
		exec echo "NumCredits, NumCred_NocBridge, avg_time_per_read/write (lower is better), narrow1 BW (sent/rcv) Mbit/s, narrow2 BW (sent/rcv) Mbit/s, wide1 BW (sent/rcv) Mbit/s, wide2 BW (sent/rcv) Mbit/s, data_link_0: valid_coverage_to_phys, data_link_0: valid_coverage_from_phys, data_link_0: num_cred_only, data_link_0: valid_in_but_not_valid_out, data_link_1: valid_coverage_to_phys, data_link_1: valid_coverage_from_phys, data_link_1: num_cred_only, data_link_1: valid_in_but_not_valid_out, noc_bridge_0: valid_coverage_to_phys, noc_bridge_0: valid_coverage_from_phys, noc_bridge_0: num_cred_only, noc_bridge_0: valid_in_but_not_valid_out, noc_bridge_1: valid_coverage_to_phys, noc_bridge_1: valid_coverage_from_phys, noc_bridge_1: num_cred_only, noc_bridge_1: valid_in_but_not_valid_out,narrow_1 \[ns\],narrow_2 \[ns\],wide_1 \[ns\],wide_2 \[ns\],aw_max \[ns\],w_max \[ns\],b_max \[ns\],ar_max \[ns\],r_max \[ns\],aw_min \[ns\],w_min \[ns\],b_min \[ns\],ar_min \[ns\],r_min \[ns\],aw_max \[ns\],w_max \[ns\],b_max \[ns\],ar_max \[ns\],r_max \[ns\],aw_min \[ns\],w_min \[ns\],b_min \[ns\],ar_min \[ns\],r_min \[ns\],aw_max \[ns\],w_max \[ns\],b_max \[ns\],ar_max \[ns\],r_max \[ns\],aw_min \[ns\],w_min \[ns\],b_min \[ns\],ar_min \[ns\],r_min \[ns\],aw_max \[ns\],w_max \[ns\],b_max \[ns\],ar_max \[ns\],r_max \[ns\],aw_min \[ns\],w_min \[ns\],b_min \[ns\],ar_min \[ns\],r_min \[ns\]" >> perfAnalysis.csv
	}
}

proc results_collector {} {
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
		exec echo -n ",N/A,N/A,N/A,N/A" >> perfAnalysis.csv
	}
	if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | wc -l] == "2"} {
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.benchmarking_attempts" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
	} else {
		exec echo -n ",N/A,N/A" >> perfAnalysis.csv
	}
	if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only" | wc -l] == "2"} {
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_0.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 2 | head -c-1 >> perfAnalysis.csv
	} else {
		exec echo -n ",N/A,N/A" >> perfAnalysis.csv
	}
	if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | wc -l] == "2"} {
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.benchmarking_attempts" | cut -d " " -f 8 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
	} else {
		exec echo -n ",N/A,N/A" >> perfAnalysis.csv
	}
	if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only" | wc -l] == "2"} {
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 1 | head -c-1 >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "benchmarking: tb_floo_serial_link_narrow_wide.i_serial_link_1.num_cred_only" | cut -d " " -f 6 | cut -d "," -f 2 | head -c-1 >> perfAnalysis.csv
	} else {
		exec echo -n ",N/A,N/A" >> perfAnalysis.csv
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
		exec echo -n ",N/A,N/A,N/A,N/A" >> perfAnalysis.csv
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
		exec echo -n ",N/A,N/A,N/A,N/A" >> perfAnalysis.csv
	}
	if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "INFO: narrow_rand_master_1 finished" | wc -l] == "2"} {
		exec echo -n ", " >> perfAnalysis.csv
		set narrow_1_finish [exec cat perfAnalysis.tmp | grep "INFO: narrow_rand_master_1 finished (time = " | cut -d " " -f 7 | head -c-1]
		exec echo -n [expr $narrow_1_finish / 100] >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		set narrow_2_finish [exec cat perfAnalysis.tmp | grep "INFO: narrow_rand_master_2 finished (time = " | cut -d " " -f 7 | head -c-1]
		exec echo -n [expr $narrow_2_finish / 100] >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		set wide_1_finish [exec cat perfAnalysis.tmp | grep "INFO: wide_rand_master_1 finished (time = " | cut -d " " -f 7 | head -c-1]
		exec echo -n [expr $wide_1_finish / 100] >> perfAnalysis.csv
		exec echo -n ", " >> perfAnalysis.csv
		set wide_2_finish [exec cat perfAnalysis.tmp | grep "INFO: wide_rand_master_2 finished (time = " | cut -d " " -f 7 | head -c-1]
		exec echo -n [expr $wide_2_finish / 100] >> perfAnalysis.csv
	} else {
		exec echo -n ",N/A,N/A,N/A,N/A" >> perfAnalysis.csv
	}
	if {[exec cat perfAnalysis.tmp | grep -e "benchmarking: Performance Rating (lower is better): " -e "latency_array" | wc -l] == "2"} {
		exec echo -n ", " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "latency_array: " | cut -d " " -f 3 | head -c-1 >> perfAnalysis.csv
	} else {
		exec echo -n ",N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A" >> perfAnalysis.csv
	}
	# switch to new line
	exec echo "" >> perfAnalysis.csv
}


set requiredSteps [expr (($noc_credits_stop - $noc_credits_start)/$noc_credits_step + 1 + $noc_credits_include_zero) * \
				   (($link_credits_stop - $link_credits_start)/$link_credits_step + 1)]
set performedSteps 0
puts "progress: $performedSteps/$requiredSteps (0%)"
exec echo -n "" > perfAnalysis.csv

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
		exec make sim_c > perfAnalysis.tmp
		print_csv_header $performedSteps
		exec echo -n "$link_credits, 0, " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "Status: " > perfAnalysis.tmp2
		set hasFailedFile [open perfAnalysis.tmp2]
		set fileContent [read $hasFailedFile]
		set progressStatus "ok"
		if {$fileContent == "\[1;37;41mStatus: There are errors!\[0m\n"} {
			set progressStatus "fail"
			exec echo "sim failed" >> perfAnalysis.csv
		} else {
			results_collector
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
		exec make sim_c > perfAnalysis.tmp
		print_csv_header $performedSteps
		exec echo -n "$link_credits, $noc_credits, " >> perfAnalysis.csv
		exec cat perfAnalysis.tmp | grep "Status: " > perfAnalysis.tmp2
		set hasFailedFile [open perfAnalysis.tmp2]
		set fileContent [read $hasFailedFile]
		set progressStatus "ok"
		if {$fileContent == "\[1;37;41mStatus: There are errors!\[0m\n"} {
			set progressStatus "fail"
			exec echo "sim failed" >> perfAnalysis.csv
		} else {
			results_collector
		}
		incr performedSteps
		puts "progress: $performedSteps/$requiredSteps ([expr ($performedSteps*100)/$requiredSteps]%) - $progressStatus"
	}

}
exec rm perfAnalysis.tmp
exec rm perfAnalysis.tmp2