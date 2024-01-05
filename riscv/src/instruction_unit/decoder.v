`include "../const.v"

module decoder (
    input [31:0]        instr_in,
    output reg [5:0]    opcode,
    output reg [4:0]    rs1_out,
    output reg [4:0]    rs2_out,
    output reg [4:0]    rd_out,
    output reg [31:0]   imm_out
);

wire [6:0] op1 = instr_in[6:0];
wire [2:0] op2 = instr_in[14:12];
wire [6:0] op3 = instr_in[31:25];
wire [4:0] rd = instr_in[11:7];
wire [4:0] rs1 = instr_in[19:15];
wire [4:0] rs2 = instr_in[24:20];
wire [31:0] upper_imm = {instr_in[31:12], 12'b0};
wire [31:0] sext_imm = {{20{instr_in[31]}}, instr_in[31:20]};
wire [31:0] jal_imm = {{12{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
wire [31:0] store_imm = {{20{instr_in[31]}}, instr_in[31:25], instr_in[11:7]};
wire [31:0] branch_imm = {{20{instr_in[31]}}, instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
wire [31:0] shamt = {27'b0, instr_in[24:20]};

always @(*) begin

    opcode = `NULL;
    rs1_out = rs1;
    rs2_out = rs2;
    rd_out = rd;
    imm_out = 32'b0;

    case (op1)
        7'b0110111: begin
            opcode = `LUI;
            rs1_out = 5'b0;
            rs2_out = 5'b0;
            imm_out = upper_imm;
        end
        7'b0010111: begin
            opcode = `AUIPC;
            rs1_out = 5'b0;
            rs2_out = 5'b0;
            imm_out = upper_imm;
        end
        7'b1101111: begin
            opcode = `JAL;
            rs1_out = 5'b0;
            rs2_out = 5'b0;
            imm_out = jal_imm;
        end
        7'b1100111: begin
            opcode = `JALR;
            rs2_out = 5'b0;
            imm_out = sext_imm;
        end
        7'b1100011: begin
            rd_out = 5'b0;
            imm_out = branch_imm;
            case (op2)
                3'b000: opcode = `BEQ;
                3'b001: opcode = `BNE;
                3'b100: opcode = `BLT;
                3'b101: opcode = `BGE;
                3'b110: opcode = `BLTU;
                3'b111: opcode = `BGEU;
                default;
            endcase
        end
        7'b0000011: begin
            rs2_out = 5'b0;
            imm_out = sext_imm;
            case (op2)
                3'b000: opcode = `LB;
                3'b001: opcode = `LH;
                3'b010: opcode = `LW;
                3'b100: opcode = `LBU;
                3'b101: opcode = `LHU;
                default;
            endcase
        end
        7'b0100011: begin
            rd_out = 5'b0;
            imm_out = store_imm;
            case (op2)
                3'b000: opcode = `SB;
                3'b001: opcode = `SH;
                3'b010: opcode = `SW;
                default;
            endcase
        end
        7'b0010011: begin 
            rs2_out = 5'b0;
            imm_out = sext_imm;
            case (op2)
                3'b000: opcode = `ADDI;
                3'b010: opcode = `SLTI;
                3'b011: opcode = `SLTIU;
                3'b100: opcode = `XORI;
                3'b110: opcode = `ORI;
                3'b111: opcode = `ANDI;
                3'b001: begin
                    imm_out = shamt;
                    opcode = `SLLI;
                end
                3'b101: begin
                    imm_out = shamt;
                    case (op3)
                        7'b0000000: opcode = `SRLI;
                        7'b0100000: opcode = `SRAI;
                        default;
                    endcase
                end
            endcase
        end
        7'b0110011: begin
            case (op2)
                3'b000: begin
                    case (op3)
                        7'b0000000: opcode = `ADD;
                        7'b0100000: opcode = `SUB;
                        default;
                    endcase
                end
                3'b001: opcode = `SLL;
                3'b010: opcode = `SLT;
                3'b011: opcode = `SLTU;
                3'b100: opcode = `XOR;
                3'b101: begin
                    case (op3)
                        7'b0000000: opcode = `SRL;
                        7'b0100000: opcode = `SRA;
                        default;
                    endcase
                end
                3'b110: opcode = `OR;
                3'b111: opcode = `AND;
          endcase
        end
        default;
    endcase

end
    
endmodule