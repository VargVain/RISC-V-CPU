`include "config.v"

module icache(
    input               clk,
    input               rst,
    input               rdy,

    // for MEM
    input               instr_in_valid,
    input [31:0]        instr_in,
    output reg          instr_in_enable,
    output reg [31:0]   instr_in_addr,

    // for IF
    input [31:0]        pc,
    output              instr_out_valid,
    output [31:0]       instr_out
);

reg [31:0]              data [`INDEX_SIZE-1:0];
reg [`INDEX_SIZE-1:0]   valid;
reg [`TAG_WIDTH-1:0]    tag [`INDEX_SIZE-1:0];
reg                     loading;

wire [`INDEX_WIDTH-1:0] pc_index = pc[`INDEX_RANGE];
wire hit = valid[pc_index] && (tag[pc_index] == pc[`TAG_RANGE]);

assign instr_out_valid = hit;
assign instr_out = data[pc_index];

always @(posedge clk) begin
    if (rst) begin
        // reset
    end else if (rdy) begin
        if (instr_in_valid && loading == 1'b1) begin
            data[pc_index] <= instr_in;
            valid[pc_index] <= 1'b1;
            tag[pc_index] <= instr_in_addr[`TAG_RANGE];
            instr_in_enable <= 1'b0;
            loading <= 1'b0;
        end
        if (loading == 1'b0 && ~hit) begin
            instr_in_addr <= pc;
            instr_in_enable <= 1'b1;
            loading <= 1'b1;
        end
    end
end

endmodule