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
    input [31:0]        issue_pc,

    input [5:0]         issue_check1,
    input [5:0]         issue_check2,
    output              issue_value_valid1,
    output              issue_value_valid2,
    output [31:0]       issue_value1,
    output [31:0]       issue_value2,

    // for predictor
    output reg          pred_enable,
    output reg [31:0]   pred_pc,
    output reg          pred_taken,

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

    // for LSB
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
reg [31:0]              pc [63:0];

reg [5:0]               next;
reg [5:0]               head;
reg [6:0]               size;

wire [5:0] after_next = next == 63 ? 0 : next + 1;
wire [5:0] after_head = head == 63 ? 0 : head + 1;
wire head_is_ls = opcode[head] >= `LB && opcode[head] <= `SW;
wire lsb_is_l = opcode[lsb_rob_index_out] >= `LB && opcode[lsb_rob_index_out] <= `LHU;

assign rob_full = size >= 60; // redundance
assign issue_value_valid1 = ((opcode[issue_check1] < `LB || opcode[issue_check1] > `LHU) && (ready[issue_check1] || (alu_valid && alu_rob_index == issue_check1))) || (lsb_ls_enable && lsb_rob_index_out == issue_check1);
assign issue_value_valid2 = ((opcode[issue_check2] < `LB || opcode[issue_check2] > `LHU) && (ready[issue_check2] || (alu_valid && alu_rob_index == issue_check2))) || (lsb_ls_enable && lsb_rob_index_out == issue_check2);
assign issue_value1 = issue_value_valid1 ? ((lsb_ls_enable && lsb_rob_index_out == issue_check1) ? lsb_l_data : (ready[issue_check1] ? res[issue_check1] : alu_res)) : 0;
assign issue_value2 = issue_value_valid2 ? ((lsb_ls_enable && lsb_rob_index_out == issue_check2) ? lsb_l_data : (ready[issue_check2] ? res[issue_check2] : alu_res)) : 0;

integer i, cnt=0, total_br=0, wrong_br=0;
wire debug1 = `DEBUG && `ROB && cnt >= `HEAD && cnt <= `TAIL;
wire debug2 = `DEBUG && `ALU && cnt >= `HEAD && cnt <= `TAIL;

always @(posedge clk) begin
    cnt = cnt + 1;
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
            pc[next] <= issue_pc;
            ready[next] <= 1'b0;
            next <= after_next;
            if (!lsb_ls_enable && (!ready[head] || head_is_ls)) size <= size + 1;
        end
        if (alu_valid) begin
            if (debug2) $display("[alu] [clk=%d] [index=%d] [val=%h] [jump=%h]", cnt, alu_rob_index, alu_res, alu_jump);
            ready[alu_rob_index] <= 1;
            res[alu_rob_index] <= alu_res;
            real_jump[alu_rob_index] <= alu_jump;
            jump_pc[alu_rob_index] <= alu_jump_pc;
        end
        if (lsb_ls_enable) begin
            head <= (head == 63) ? 0 : head + 1;
            if (!issue_valid) size <= size - 1;
            if (debug1) $display("[rob] [clk=%d] [index=%d] [opcode=%d] [pc=%h] [rd=%d] [adr=%h] [res=%h] [size=%d] [val=%h]", cnt, lsb_rob_index_out, opcode[lsb_rob_index_out], pc[lsb_rob_index_out], rd[lsb_rob_index_out], res[lsb_rob_index_out], jump_pc[lsb_rob_index_out], size, lsb_l_data);
            if (lsb_is_l) begin
                rf_valid <= 1'b1;
                rf_index <= lsb_rob_index_out;
                rf_rd <= rd[lsb_rob_index_out];
                rf_value <= lsb_l_data;
            end
            ready[head] <= 0;
        end
        if (ready[head]) begin
            if (opcode[head] >= `BEQ && opcode[head] <= `BGEU) begin
                total_br = total_br + 1;
                pred_enable <= 1;
                pred_pc <= pc[head];
                pred_taken <= real_jump[head];
            end else pred_enable <= 0;
            if (pc[head] == 32'h0010) $display("\nCongratulations! your clk cnt: %d, total_br: %d, wrong_br: %d", cnt, total_br, wrong_br);
            if (~head_is_ls) begin
                if (debug1) $display("[rob] [clk=%d] [index=%d] [opcode=%d] [pc=%h] [rd=%d] [res=%h] [jpc=%h] [size=%d]", cnt, head, opcode[head], pc[head], rd[head], res[head], jump_pc[head], size);                                
                rf_valid <= 1'b1;
                rf_index <= head;
                rf_rd <= rd[head];
                rf_value <= res[head];
                if (jump[head] != real_jump[head]) begin
                    flush <= 1'b1;
                    new_pc_enable <= 1'b1;
                    new_pc <= real_jump[head] ? jump_pc[head] : res[head];
                    wrong_br = wrong_br + 1;
                end else begin
                    flush <= 1'b0;
                    if (opcode[head] == `JALR) begin
                        new_pc_enable <= 1'b1;
                        new_pc <= jump_pc[head];
                    end else new_pc_enable <= 1'b0;
                end
                head <= after_head;
                if (!issue_valid) size <= size - 1;
                ready[head] <= 0;
            end else begin
                ready[head] <= 0;
                pred_enable <= 0;
                lsb_enable <= 1;
                lsb_rob_index <= head;
                lsb_opcode <= opcode[head];
                lsb_ls_addr <= res[head];
                lsb_s_val <= jump_pc[head];
            end
        end else begin
            flush <= 1'b0;
            if (~lsb_ls_enable) rf_valid <= 1'b0;
            new_pc_enable <= 1'b0;
            flush <= 1'b0;
            lsb_enable <= 0;
        end
    end
end


endmodule