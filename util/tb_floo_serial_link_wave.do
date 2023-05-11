onerror {resume}
quietly WaveActivateNextPane {} 0

delete wave *

set num_phys_channels [expr [llength [find instances -bydu floo_wormhole_arbiter]] / 2 / 2]
set simple_rob [expr [llength [find instances -bydu floo_simple_rob]] / 2 == 2]

add wave -noupdate -color Yellow -group BridgeValid /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/clk_i
add wave -noupdate -group BridgeValid -divider Bridge_0_to_Bridge_1
add wave -noupdate -group BridgeValid -group req_0_to_1 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.valid
add wave -noupdate -group BridgeValid -group req_0_to_1 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.valid
add wave -noupdate -color Orange -group BridgeValid -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/axis_out_payload.hdr
add wave -noupdate -group BridgeValid -group rsp_0_to_1 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.valid
add wave -noupdate -group BridgeValid -group rsp_0_to_1 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.valid
add wave -noupdate -group BridgeValid -divider Bridge_1_to_Bridge_0
add wave -noupdate -group BridgeValid -group req_1_to_0 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.valid
add wave -noupdate -group BridgeValid -group req_1_to_0 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.valid
add wave -noupdate -color Orange -group BridgeValid -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/axis_out_payload.hdr
add wave -noupdate -group BridgeValid -group rsp_1_to_0 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.valid
add wave -noupdate -group BridgeValid -group rsp_1_to_0 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.valid

add wave -noupdate -color Yellow -group BridgeReady /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/clk_i
add wave -noupdate -group BridgeReady -divider Bridge_0_to_Bridge_1
add wave -noupdate -group BridgeReady -group req_0_to_1 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.ready
add wave -noupdate -group BridgeReady -group req_0_to_1 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.ready
add wave -noupdate -color Orange -group BridgeReady -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/axis_out_payload.hdr
add wave -noupdate -group BridgeReady -group rsp_0_to_1 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.ready
add wave -noupdate -group BridgeReady -group rsp_0_to_1 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.ready
add wave -noupdate -group BridgeReady -divider Bridge_1_to_Bridge_0
add wave -noupdate -group BridgeReady -group req_1_to_0 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.ready
add wave -noupdate -group BridgeReady -group req_1_to_0 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.ready
add wave -noupdate -color Orange -group BridgeReady -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/axis_out_payload.hdr
add wave -noupdate -group BridgeReady -group rsp_1_to_0 -ports tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.ready
add wave -noupdate -group BridgeReady -group rsp_1_to_0 -ports tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.ready

quietly virtual function -install /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.src_id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.last, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.rsvd }} req_i_data_gen
quietly virtual function -install /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.src_id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.last, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.rsvd }} req_o_data_gen
quietly virtual function -install /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.src_id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.last, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.rsvd }} rsp_i_data_gen
quietly virtual function -install /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.src_id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.last, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.rsvd }} rsp_o_data_gen
quietly virtual function -install /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.src_id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.last, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i.data.gen.rsvd }} req_i_data_gen
quietly virtual function -install /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.src_id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.last, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o.data.gen.rsvd }} req_o_data_gen
quietly virtual function -install /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.src_id, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.last, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i.data.gen.rsvd }} rsp_i_data_gen
quietly virtual function -install /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network -env /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network { &{/tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.rob_req, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.rob_idx, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.src_id, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.last, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.axi_ch, /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o.data.gen.rsvd }} rsp_o_data_gen
quietly WaveActivateNextPane {} 0

add wave -noupdate -color Yellow -group BridgeData /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/clk_i
add wave -noupdate -group BridgeData -divider Bridge_0_to_Bridge_1
add wave -noupdate -group BridgeData -group req_0_to_1 /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i_data_gen
add wave -noupdate -group BridgeData -group req_0_to_1 /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o_data_gen
add wave -noupdate -color Orange -group BridgeData /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/axis_out_payload.hdr
add wave -noupdate -group BridgeData -group rsp_0_to_1 /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i_data_gen
add wave -noupdate -group BridgeData -group rsp_0_to_1 /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o_data_gen
add wave -noupdate -group BridgeData -divider Bridge_1_to_Bridge_0
add wave -noupdate -group BridgeData -group req_1_to_0 /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_i_data_gen
add wave -noupdate -group BridgeData -group req_1_to_0 /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/req_o_data_gen
add wave -noupdate -color Orange -group BridgeData /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/axis_out_payload.hdr
add wave -noupdate -group BridgeData -group rsp_1_to_0 /tb_floo_serial_link/i_serial_link_1/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_i_data_gen
add wave -noupdate -group BridgeData -group rsp_1_to_0 /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/rsp_o_data_gen

add wave -noupdate -color Yellow -group BridgeValidHandshake /tb_floo_serial_link/i_serial_link_0/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/clk_i
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_0_req_o
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_0_req_i
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_1_req_o
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_1_req_i
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_0_rsp_o
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_0_rsp_i
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_1_rsp_o
add wave -noupdate -color Cyan -group BridgeValidHandshake /tb_floo_serial_link/Bridge_1_rsp_i

for {set i 0} {$i < 2} {incr i} {
    set group_name "Adapter $i"

    add wave -noupdate -group $group_name -ports tb_floo_serial_link/i_floo_axi_chimney_${i}/*
    
    add wave -noupdate -group BridgeSignals -expand -group NocBridge_${i} -ports tb_floo_serial_link/i_serial_link_${i}/gen_multi_channel_serial_link/i_serial_link/bridge/i_serial_link_network/*

    add wave -noupdate -group $group_name -group Arbiter -group ArbiterReq -ports tb_floo_serial_link/i_floo_axi_chimney_${i}/i_req_wormhole_arbiter/*
    add wave -noupdate -group $group_name -group Arbiter -group ArbiterRsp -ports tb_floo_serial_link/i_floo_axi_chimney_${i}/i_rsp_wormhole_arbiter/*

    add wave -noupdate -group $group_name -group Arbiter tb_floo_serial_link/i_floo_axi_chimney_${i}/aw_w_sel_q
    add wave -noupdate -group $group_name -group Arbiter tb_floo_serial_link/i_floo_axi_chimney_${i}/aw_w_sel_d

    add wave -noupdate -group $group_name -group Packer tb_floo_serial_link/i_floo_axi_chimney_${i}/aw_data
    add wave -noupdate -group $group_name -group Packer tb_floo_serial_link/i_floo_axi_chimney_${i}/w_data
    add wave -noupdate -group $group_name -group Packer tb_floo_serial_link/i_floo_axi_chimney_${i}/b_data
    add wave -noupdate -group $group_name -group Packer tb_floo_serial_link/i_floo_axi_chimney_${i}/ar_data
    add wave -noupdate -group $group_name -group Packer tb_floo_serial_link/i_floo_axi_chimney_${i}/r_data

    add wave -noupdate -group $group_name -group Unpacker tb_floo_serial_link/i_floo_axi_chimney_${i}/unpack_aw_data
    add wave -noupdate -group $group_name -group Unpacker tb_floo_serial_link/i_floo_axi_chimney_${i}/unpack_w_data
    add wave -noupdate -group $group_name -group Unpacker tb_floo_serial_link/i_floo_axi_chimney_${i}/unpack_ar_data
    add wave -noupdate -group $group_name -group Unpacker tb_floo_serial_link/i_floo_axi_chimney_${i}/unpack_b_data
    add wave -noupdate -group $group_name -group Unpacker tb_floo_serial_link/i_floo_axi_chimney_${i}/unpack_r_data

    if {!$simple_rob} {
        add wave -noupdate -group $group_name -group R_RoB -group StatusTable tb_floo_serial_link/i_floo_axi_chimney_${i}/gen_rob/i_r_rob/i_floo_rob_status_table/*
        add wave -noupdate -group $group_name -group R_RoB tb_floo_serial_link/i_floo_axi_chimney_${i}/gen_rob/i_r_rob/*
    } else {
        add wave -noupdate -group $group_name -group R_RoB tb_floo_serial_link/i_floo_axi_chimney_${i}/gen_simple_rob/i_r_rob/*
    }

    add wave -noupdate -group $group_name -group B_RoB tb_floo_serial_link/i_floo_axi_chimney_${i}/i_b_rob/*

}

add wave -noupdate -group axi_channel_compare -group compare_1_to_2 /tb_floo_serial_link/i_axi_channel_compare_1_to_2/axi_a_req
add wave -noupdate -group axi_channel_compare -group compare_1_to_2 /tb_floo_serial_link/i_axi_channel_compare_1_to_2/axi_a_res
add wave -noupdate -group axi_channel_compare -group compare_1_to_2 /tb_floo_serial_link/i_axi_channel_compare_1_to_2/axi_b_req
add wave -noupdate -group axi_channel_compare -group compare_1_to_2 /tb_floo_serial_link/i_axi_channel_compare_1_to_2/axi_b_res
add wave -noupdate -group axi_channel_compare -group compare_2_to_1 /tb_floo_serial_link/i_axi_channel_compare_2_to_1/axi_a_req
add wave -noupdate -group axi_channel_compare -group compare_2_to_1 /tb_floo_serial_link/i_axi_channel_compare_2_to_1/axi_a_res
add wave -noupdate -group axi_channel_compare -group compare_2_to_1 /tb_floo_serial_link/i_axi_channel_compare_2_to_1/axi_b_req
add wave -noupdate -group axi_channel_compare -group compare_2_to_1 /tb_floo_serial_link/i_axi_channel_compare_2_to_1/axi_b_res

TreeUpdate [SetDefaultTree]
quietly wave cursor active 1
configure wave -namecolwidth 220
configure wave -valuecolwidth 110
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
