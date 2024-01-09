`include "config.vh"

module arithmetic_logic_unit(
    // for RS
    input [5:0]          opcode,
    input [31:0]         val1,
    input [31:0]         val2,
    input [31:0]         imm,
    input [31:0]         pc,
    input [5:0]          rob_index,

    // for ROB & LSB & RS
    output reg           valid,
    output reg [31:0]    res,
    output reg           real_jump,
    output reg [31:0]    real_jump_pc,
    output reg [5:0]     rob_index_out
);

always @(*) begin
    rob_index_out = rob_index;
    valid = opcode != 0;
    case (opcode)
        `LUI: begin
            res = imm;
        end
        `AUIPC: begin
            res = pc + imm;
        end
        `JAL: begin
            res = pc + 4;
            real_jump_pc = pc + imm;
        end
        `JALR: begin
            res = pc + 4;
            real_jump_pc = (val1 + imm) & 32'hfffffffe;
        end
        `BEQ: begin
            res = pc + 4;
            real_jump = val1 == val2;
            real_jump_pc = pc + imm;
        end
        `BNE: begin
            res = pc + 4;
            real_jump = val1 != val2;
            real_jump_pc = pc + imm;
        end
        `BLT: begin
            res = pc + 4;
            real_jump = $signed(val1) < $signed(val2);
            real_jump_pc = pc + imm;
        end
        `BGE: begin
            res = pc + 4;
            real_jump = $signed(val1) >= $signed(val2);
            real_jump_pc = pc + imm;
        end
        `BLTU: begin
            res = pc + 4;
            real_jump = val1 < val2;
            real_jump_pc = pc + imm;
        end
        `BGEU: begin
            res = pc + 4;
            real_jump = val1 > val2;
            real_jump_pc = pc + imm;
        end
        `LB: begin
            res = val1 + imm;
        end
        `LH: begin
            res = val1 + imm;
        end
        `LW: begin
            res = val1 + imm;
        end
        `LBU: begin
            res = val1 + imm;
        end
        `LHU: begin
            res = val1 + imm;
        end
        `SB: begin
            res = val1 + imm;
            real_jump_pc = val2;
        end
        `SH: begin
            res = val1 + imm;
            real_jump_pc = val2;
        end
        `SW: begin
            res = val1 + imm;
            real_jump_pc = val2;
        end
        `ADDI: begin
            res = val1 + imm;
        end
        `SLTI: begin
            res = val1 < $signed(imm) ? 1 : 0;
        end
        `SLTIU: begin
            res = val1 < $signed(imm) ? 1 : 0;
        end
        `XORI : begin
            res = val1 ^ imm;
        end
        `ORI: begin
            res = val1 | imm;
        end
        `ANDI: begin
            res = val1 & imm;
        end
        `SLLI: begin
            res = val1 << imm;
        end
        `SRLI: begin
            res = val1 >> imm;
        end
        `SRAI: begin
            res = $signed(val1) >>> imm;
        end
        `ADD: begin
            res = val1 + val2;
        end
        `SUB: begin
            res = val1 - val2;
        end
        `SLL: begin
            res = val1 << (val2 & 32'h1f);
        end
        `SLT: begin
            res = $signed(val1) < $signed(val2) ? 1 : 0;
        end
        `SLTU: begin
            res = val1 < val2 ? 1 : 0;
        end
        `XOR: begin
            res = val1 ^ val2;
        end
        `SRL: begin
            res = val1 >> (val2 & 32'h1f);
        end
        `SRA: begin
            res = $signed(val1) >>> (val2 & 32'h1f);
        end
        `OR: begin
            res = val1 | val2;
        end
        `AND: begin
            res = val1 & val2;
        end
        default: begin
            res = 0;
        end
    endcase
end

endmodule