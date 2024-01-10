`include "config.vh"

module memory_controller(
    input               clk,
    input               rst,
    input               rdy,

    // for MEM
    input      [7:0]    mem_din,
    input               io_buffer_full,
    output reg [7:0]    mem_dout,
    output reg [31:0]   mem_a,
    output reg          mem_wr,

    // for icache
    input               instr_out_enable,
    input [31:0]        instr_out_addr,
    output reg          instr_out_valid,
    output reg [31:0]   instr_out,

    // for LSB
    input               lsb_enable,
    input [5:0]         lsb_ls_opcode,
    input               lsb_ls,
    input [31:0]        lsb_ls_addr,
    input [31:0]        lsb_s_data,
    output reg          lsb_valid,
    output reg [31:0]   lsb_l_data
);

reg [2:0] state;
reg [2:0] size;
reg [2:0] progress;

integer cnt=0;

always @(posedge clk) begin
    cnt = cnt + 1;
    if (rst) begin
        state <= 3'd0;
        instr_out_valid <= 1'b0;
        lsb_valid <= 1'b0;
        progress <= 3'd0;
        instr_out_valid <= 0;
        mem_dout <= 0;
        mem_a <= 0;
        mem_wr <= 0;
        lsb_l_data <= 0;
    end else if (rdy) begin
        case(state)
        0: begin // IDLE
            instr_out_valid <= 1'b0;
            lsb_valid     <= 1'b0;
            if (lsb_enable) begin
                progress   <= 3'd0;
                size <= lsb_ls_opcode == `SW || lsb_ls_opcode == `LW ? 4 :
                        lsb_ls_opcode == `SH || lsb_ls_opcode == `LH || lsb_ls_opcode == `LHU ? 2 : 1;
                if (lsb_ls) begin
                    state <= 3'd3;
                    mem_wr <= 1'b0;
                    mem_dout <= 8'b0;
                    mem_a <= lsb_ls_addr;
                end
                else begin
                    state <= 3'd2;
                    mem_wr <= 1'b1;
                    mem_dout <= lsb_s_data[7:0];
                    mem_a <= lsb_ls_addr;
                end
            end
            else if (instr_out_enable) begin
                state <= 3'd1;
                progress <= 3'b000;
                mem_wr <= 1'b0;
                mem_dout <= 8'b0;
                mem_a <= instr_out_addr;
            end
        end
        1: begin // INST
            case (progress)
                3'b001: instr_out[7:0] <= mem_din;
                3'b010: instr_out[15:8] <= mem_din;
                3'b011: instr_out[23:16] <= mem_din;
                3'b100: instr_out[31:24] <= mem_din;
                default;
            endcase
            if (progress == 4) begin
                progress <= 3'b000;
                state <= 3'd4;
                instr_out_valid <= 1'b1;
                mem_a <= 32'b0;
            end
            else begin
                progress <= progress + 1;
                mem_a <= mem_a + 1;    
            end
        end
        2: begin // STORE
            if (progress == size - 1) begin
                progress <= 3'b000;
                state <= 3'd4;
                lsb_valid <= 1'b1;
                mem_wr <= 1'b0;
                mem_a <= 32'b0;
                if (`DEBUG && cnt > `HEAD) $display("[memory %d] stored %h to %h", cnt, lsb_s_data, mem_a);
            end
            else begin 
                case (progress)
                    3'b000: mem_dout <= lsb_s_data[15:8];
                    3'b001: mem_dout <= lsb_s_data[23:16];
                    3'b010: mem_dout <= lsb_s_data[31:24];
                    default;
                endcase
                progress <= progress + 1;
                mem_a <= mem_a + 1;
            end
        end
        3: begin // LOAD
            mem_wr      <= 1'b0;
            case (progress)
                3'b001: lsb_l_data[7:0] <= mem_din;
                3'b010: lsb_l_data[15:8] <= mem_din;
                3'b011: lsb_l_data[23:16] <= mem_din;
                3'b100: lsb_l_data[31:24] <= mem_din;
                default;
            endcase
            if (progress == size) begin
                progress <= 3'b000;
                state <= 3'd4;
                lsb_valid <= 1'b1;
                mem_wr <= 1'b0;
                mem_a <= 32'b0;
                if (lsb_ls_opcode == `LH) begin
                    lsb_l_data[31:16] <= {16{mem_din[7]}};
                end
                else if (lsb_ls_opcode == `LB) begin
                    lsb_l_data[31:8] <= {24{mem_din[7]}};
                end
                else if (lsb_ls_opcode == `LBU) begin
                    lsb_l_data[31:8] <= 24'b0;
                end
                else if (lsb_ls_opcode == `LHU) begin
                    lsb_l_data[31:16] <= 16'b0;
                end
            end
            else begin
                progress <= progress + 1;
                mem_a <= mem_a + 1;
            end
        end
        4: begin // STALL
            state <= 3'd0;
            lsb_valid     <= 1'b0;
            instr_out_valid <= 1'b0;
        end
        endcase
    end
end

endmodule