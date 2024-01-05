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
    input [5:0]         rob_next_index,

    output reg          rob_valid,
    output reg [4:0]    rob_rd,
    output reg          rob_jumped,
    output reg [5:0]    rob_opcode,

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

    // for LSB

    // for CDB
    input               flush
);

assign instr_decode = instr_in;
assign rf_check1 = rs1;
assign rf_check2 = rs2;
assign rob_check1 = rf_dep1;
assign rob_check2 = rf_dep2;

wire has_dep1 = rf_has_dep1 && ~rob_value_valid1;
wire has_dep2 = rf_has_dep2 && ~rob_value_valid2;
wire [5:0] dep1 = has_dep1 ? rf_dep1 : 0;
wire [5:0] dep2 = has_dep2 ? rf_dep2 : 0;
wire [31:0] val1 = rf_has_dep1 ? (rob_value_valid1 ? rob_value1 : 0) : rf_val1;
wire [31:0] val2 = rf_has_dep2 ? (rob_value_valid2 ? rob_value2 : 0) : rf_val2;

always @(posedge clk) begin
if (rst) begin
        // reset
        rs_valid <= 0;
        rf_valid <= 0;
        rob_valid <= 0;
    end else if (rdy) begin
        if (flush) begin
            // flush
        end else begin
            if (instr_in_valid) begin
                rob_valid <= 1'b1;
                rob_rd <= rd;
                rob_jumped <= jumped;

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
            end else begin
                rob_valid <= 1'b0;
                rs_valid <= 1'b0;
                rf_valid <= 1'b0;
            end
        end
    end
end

endmodule