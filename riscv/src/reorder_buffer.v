module reorder_buffer(
    input               clk,
    input               rst,
    input               rdy,

    // for IU
    input               issue_valid,
    input [4:0]         issue_rd,
    input               issue_jump,

    output [5:0]        next_index,

    input [4:0]

    // for RF

    // for ALU

    // LSB

    // for CDB
    output              rob_full,
    output              flush
);




endmodule