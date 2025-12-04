// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`define SLINK_ASSIGN_RDL_RD_ACK(field, hw2reg = hw2reg, reg2hw = reg2hw) \
  assign hw2reg.field.rd_ack = reg2hw.field.req & ~reg2hw.field.req_is_wr;

`define SLINK_ASSIGN_RDL_WR_ACK(field, hw2reg = hw2reg, reg2hw = reg2hw) \
  assign hw2reg.field.wr_ack = reg2hw.field.req & reg2hw.field.req_is_wr;

`define SLINK_SET_RDL_RD_ACK(field, hw2reg = hw2reg, reg2hw = reg2hw) \
  hw2reg.field.rd_ack = reg2hw.field.req & ~reg2hw.field.req_is_wr;

`define SLINK_SET_RDL_WR_ACK(field, hw2reg = hw2reg, reg2hw = reg2hw) \
  hw2reg.field.wr_ack = reg2hw.field.req & reg2hw.field.req_is_wr;
