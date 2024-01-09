`include "config.vh"

module reorder_buffer(
    input               clk,
    input               rst,
    input               rdy,

    // for IU
    input               issue_valid,
    input [4:0]         issue_rd,
    input               issue_jump,
    input [5:0]         issue_opcode,

    output [5:0]        next_index,

    input [5:0]         issue_check1,
    input [5:0]         issue_check2,
    output              issue_value_valid1,
    output              issue_value_valid2,
    output [31:0]       issue_value1,
    output [31:0]       issue_value2,

    // for RF
    output reg          rf_valid,
    output reg [5:0]    rf_index,
    output reg [4:0]    rf_rd,
    output reg [31:0]   rf_value,

    // for ALU
    input               alu_valid,
    input [31:0]        alu_res,
    input               alu_jump,
    input [31:0]        alu_jump_pc,
    input [5:0]         alu_rob_index,

    // LSB
    input               lsb_ls_enable,
    input [5:0]         lsb_rob_index_out,
    input [31:0]        lsb_l_data,
    output reg          lsb_enable,
    output reg [5:0]    lsb_rob_index,
    output reg [5:0]    lsb_opcode,
    output reg [31:0]   lsb_ls_addr,
    output reg [31:0]   lsb_s_val,

    // for CDB
    output              rob_full,
    output reg          flush,
    output reg          new_pc_enable,
    output reg [31:0]   new_pc
);

reg [63:0]              ready;
reg [4:0]               rd [63:0];
reg [63:0]              jump;
reg [63:0]              real_jump;
reg [31:0]              jump_pc [63:0]; // also serve as store data
reg [5:0]               opcode [63:0];
reg [31:0]              res [63:0];

reg [5:0]               next;
reg [5:0]               head;
reg [6:0]               size;
wire [5:0] after_next = (next == 63) ? 0 : next + 1;
wire [5:0] after_head = (head == 63) ? 0 : head + 1;
wire full = size == 63 || size == 64;

assign rob_full = full;
assign next_index = next;

integer i;

always @(posedge clk) begin
    if (rst || flush) begin
        // reset
        flush <= 0;
        new_pc_enable <= 0;
        for (i = 0; i < 64; i = i + 1) begin
            ready[i] <= 0;
            rd[i] <= 0;
            jump[i] <= 0;
            real_jump[i] <= 0;
            jump_pc[i] <= 0;
            opcode[i] <= 0;
            res[i] <= 0;
        end
        rf_valid <= 0;
        head <= 0;
        next <= 0;
        size <= 0;
    end else if (rdy) begin
        if (issue_valid) begin
            rd[next] <= issue_rd;
            jump[next] <= issue_jump;
            opcode[next] <= issue_opcode;
            ready[next] <= 1'b0;
            next <= after_next;
            if (!lsb_ls_enable && (!ready[head] || (opcode[head] >= `LB && opcode[head] <= `SW))) size <= size + 1;
        end
        if (alu_valid) begin
            res[alu_rob_index] <= alu_res;
            real_jump[alu_rob_index] <= alu_jump;
            jump_pc[alu_rob_index] <= alu_jump_pc;
        end
        if (lsb_ls_enable) begin
            head <= after_head;
            if (!issue_valid) size <= size - 1;
            if (opcode[lsb_rob_index_out] >= `LB && opcode[lsb_rob_index_out] <= `LHU) begin
                rf_valid <= 1'b1;
                rf_index <= head;
                rf_rd <= rd[head];
                rf_value <= lsb_l_data;
            end
        end
        if (ready[head]) begin
            if (opcode[head] < `LB || opcode[head] > `SW) begin
                rf_valid <= 1'b1;
                rf_index <= head;
                rf_rd <= rd[head];
                rf_value <= res[head];
                if (jump[head] != real_jump[head]) begin
                    flush <= 1'b1;
                    new_pc_enable <= 1'b1;
                    new_pc <= real_jump[head] ? jump_pc[head] : res[head];
                end else begin
                    flush <= 1'b0;
                    new_pc_enable <= 1'b0;
                    if (opcode[head] == `JALR) begin
                        new_pc_enable <= 1'b1;
                        new_pc <= res[head];
                    end
                end
                head <= after_head;
                if (!issue_valid) size <= size - 1;
            end else begin
                ready[head] <= 0;
                lsb_enable <= 1;
                lsb_rob_index <= head;
                lsb_opcode <= opcode[head];
                lsb_ls_addr <= res[head];
                lsb_s_val <= jump_pc[head];
            end
        end else begin
            flush <= 1'b0;
            rf_valid <= 1'b0;
            new_pc_enable <= 1'b0;
            flush <= 1'b0;
        end
    end
end


endmodule