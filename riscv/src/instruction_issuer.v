`include "config.vh"

module instruction_issuer(
    input               clk,
    input               rst,
    input               rdy,

    // for IF
    input               instr_in_valid,
    input [31:0]        instr_in,
    input               jumped,
    input [31:0]        pc,

    // for decoder
    input [5:0]         opcode,
    input [4:0]         rs1,
    input [4:0]         rs2,
    input [4:0]         rd,
    input [31:0]        imm,
    output [31:0]       instr_decode,

    // for ROB
    output reg          rob_valid,
    output reg [4:0]    rob_rd,
    output reg          rob_jumped,
    output reg [5:0]    rob_opcode,
    output reg [31:0]   rob_pc,

    input               rob_value_valid1,
    input               rob_value_valid2,
    input [31:0]        rob_value1,
    input [31:0]        rob_value2,
    output [5:0]        rob_check1,
    output [5:0]        rob_check2,

    // for RS
    output reg          rs_valid,
    output reg [5:0]    rs_opcode,
    output reg [31:0]   rs_val1,
    output reg [5:0]    rs_dep1,
    output reg          rs_has_dep1,
    output reg [31:0]   rs_val2,
    output reg [5:0]    rs_dep2,
    output reg          rs_has_dep2,
    output reg [5:0]    rs_rob_index,
    output reg [31:0]   rs_imm,
    output reg [31:0]   rs_pc,

    // for RF
    input [31:0]        rf_val1,
    input [5:0]         rf_dep1,
    input               rf_has_dep1,
    input [31:0]        rf_val2,
    input [5:0]         rf_dep2,
    input               rf_has_dep2,
    output [4:0]        rf_check1,
    output [4:0]        rf_check2,

    output reg          rf_valid,
    output reg [4:0]    rf_regname,
    output reg [5:0]    rf_regrename,

    // for CDB
    input               flush
);

assign instr_decode = instr_in;
assign rf_check1 = rs1;
assign rf_check2 = rs2;
assign rob_check1 = rf_dep1;
assign rob_check2 = rf_dep2;

reg [5:0] rob_next_index;
reg [4:0] last_regname;
reg [5:0] last_regrename;

wire has_dep1 = rs1 == 0 ? 0 : (rf_has_dep1 && ~rob_value_valid1 || last_regname != 0 && rs1 == last_regname);
wire has_dep2 = rs2 == 0 ? 0 : (rf_has_dep2 && ~rob_value_valid2 || last_regname != 0 && rs2 == last_regname);
wire [5:0] dep1 = has_dep1 ? (rf_has_dep1 && ~rob_value_valid1 ? rf_dep1 : last_regrename) : 0;
wire [5:0] dep2 = has_dep2 ? (rf_has_dep2 && ~rob_value_valid2 ? rf_dep2 : last_regrename) : 0;
wire [31:0] val1 = rs1 == 0 ? 0 : rf_has_dep1 ? (rob_value_valid1 ? rob_value1 : 0) : rf_val1;
wire [31:0] val2 = rs2 == 0 ? 0 : rf_has_dep2 ? (rob_value_valid2 ? rob_value2 : 0) : rf_val2;

integer cnt=0;

always @(posedge clk) begin
    cnt = cnt + 1;
if (rst) begin
        // reset
        rs_valid <= 0;
        rf_valid <= 0;
        rob_valid <= 0;
        rob_next_index <= 0;
        last_regname <= 0;
        last_regrename <= 0;
    end else if (rdy) begin
        if (flush) begin
            // flush
            rs_valid <= 0;
            rf_valid <= 0;
            rob_valid <= 0;
            rob_next_index <= 0;
            last_regname <= 0;
            last_regrename <= 0;
        end else begin
            if (instr_in_valid) begin
                if (`DEBUG && cnt > `HEAD) $display("%d", rf_has_dep2);
                if (`DEBUG && cnt > `HEAD) $display("[issue %d]: rob_index=%d pc=%h opcode=%d rd=%d {rs1=%d dep1=%d has_dep1=%d val1=%h} {rs2=%d dep2=%d has_dep2=%d val2=%h} imm=%h", cnt, rob_next_index, pc, opcode, rd, rs1, dep1, has_dep1, val1, rs2, dep2, has_dep2, val2, imm);
                rob_valid <= 1'b1;
                rob_rd <= rd;
                rob_jumped <= jumped;
                rob_opcode <= opcode;
                rob_pc <= pc;

                rs_valid <= 1'b1;
                rs_opcode <= opcode;
                rs_val1 <= val1;
                rs_dep1 <= dep1;
                rs_has_dep1 <= has_dep1;
                rs_val2 <= val2;
                rs_dep2 <= dep2;
                rs_has_dep2 <= has_dep2;
                rs_rob_index <= rob_next_index;
                rs_imm <= imm;
                rs_pc <= pc;

                rf_valid <= 1'b1;
                rf_regname <= rd;
                rf_regrename <= rob_next_index;

                rob_next_index <= rob_next_index == 63 ? 0 : rob_next_index + 1;
                last_regname <= rd;
                last_regrename <= rob_next_index;
            end else begin
                rob_valid <= 1'b0;
                rs_valid <= 1'b0;
                rf_valid <= 1'b0;
                last_regname <= 0;
            end
        end
    end
end

endmodule