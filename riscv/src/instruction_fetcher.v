module instruction_fetcher(
    input               clk,
    input               rst,
    input               rdy,

    // for icache
    input               instr_in_valid,
    input [31:0]        instr_in,
    output reg [31:0]   instr_in_addr,

    // for IU
    output reg          instr_out_valid,
    output reg          jumped,
    output reg [31:0]   instr_out,
    output reg [31:0]   instr_out_pc,

    // for predictor
    input               jump,
    output [31:0]       instr_predict_addr,

    // for CDB
    input               full,
    input               flush,
    input               new_pc_enable,
    input [31:0]        new_pc
);

reg [31:0]              pc;
reg                     stall;

wire [6:0] op1 = instr_in[6:0];
wire [4:0] rs1 = instr_in[19:15];
wire [31:0] jal_imm = {{12{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
wire [31:0] branch_imm = {{20{instr_in[31]}}, instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};

assign instr_predict_addr = pc;

always @(posedge clk) begin
    if (rst) begin
        // reset
        stall <= 0;
        instr_out_valid <= 0;
        instr_in_addr <= 0;
        pc <= 0;
    end else if (rdy) begin
        if (flush) begin
            // flush
            stall <= 0;
            instr_out_valid <= 0;
            instr_in_addr <= 0;
            if (new_pc_enable) begin
                pc <= new_pc;
            end
        end else begin
            if (instr_in_valid && ~full && ~stall) begin
                instr_out_valid <= 1'b1;
                instr_out <= instr_in;
                instr_out_pc <= pc;
                case(op1)
                    7'b1101111: begin // JAL
                        pc <= pc + jal_imm;
                        instr_in_addr <= pc + jal_imm;
                        jumped <= 1'b0;
                    end
                    7'b1100111: begin // JALR
                        stall <= 1'b1;
                        jumped <= 1'b0;
                    end
                    7'b1100011: begin // Branch
                        pc <= jump ? pc + branch_imm : pc + 4;
                        instr_in_addr <= jump ? pc + branch_imm : pc + 4;
                        jumped <= jump;
                    end
                    default begin
                        pc <= pc + 4;
                        instr_in_addr <= pc + 4;
                        jumped <= 1'b0;
                    end
                endcase
            end else instr_out_valid <= 1'b0;

            if (stall && new_pc_enable) begin // stupid
                stall <= 1'b0;
                pc <= new_pc;
            end
        end
    end
end

endmodule