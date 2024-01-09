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

reg [1:0]           state; // 0-IDLE, 1-INST, 2-STORE, 3-LOAD
reg [2:0]           progress;

always @(posedge clk) begin
    if (rst) begin
        state <= 0;
        progress <= 0;
        instr_out_valid <= 0;
        mem_dout <= 0;
        mem_a <= 0;
        mem_wr <= 0;
    end else if (rdy) begin
        case (state)
            2'd0: begin // IDLE
                instr_out_valid <= 1'b0;
                lsb_valid <= 1'b0;
                if (lsb_valid) begin
                    if (lsb_ls) begin // LOAD
                        state <= 2'd1;
                        progress <= 0;
                        mem_a <= lsb_ls_addr;
                        mem_wr <= 0;
                    end
                    else begin // STORE
                        state <= 2'd2;
                        progress <= 0;
                        mem_a <= lsb_ls_addr;
                        mem_wr <= 1;
                        mem_dout <= lsb_s_data[7:0];
                    end
                end
                else if (instr_out_enable) begin
                    state <= 2'd1;
                    progress <= 0;
                    mem_a <= instr_out_addr;
                    mem_wr <= 1'b0;
                end
            end
            2'd1: begin // INST
                case (progress)
                    3'd0: begin
                        progress <= 3'd1;
                    end
                    3'd1: begin
                        instr_out[7:0] <= mem_din;
                        progress <= 3'd2;
                    end
                    3'd2: begin
                        instr_out[15:8] <= mem_din;
                        progress <= 3'd3;
                    end
                    3'd3: begin
                        instr_out[23:16] <= mem_din;
                        progress <= 3'd4;
                    end
                    3'd4: begin
                        instr_out[31:24] <= mem_din;
                        instr_out_valid <= 1'b1;
                        progress <= 3'd0;
                        state <= 2'b0;
                    end
                    default;
                endcase
                mem_a <= mem_a + 1;
            end
            2'd2: begin // STORE
                case (progress)
                    3'd0: begin
                        if (lsb_ls_opcode == `SB) begin
                            lsb_valid <= 1;
                            mem_wr <= 0;
                            state <= 0;
                        end else begin
                            progress <= 3'd1;
                            mem_dout <= lsb_s_data[15:8];
                        end
                    end
                    3'd1: begin
                        if (lsb_ls_opcode == `SH) begin
                            lsb_valid <= 1;
                            mem_wr <= 0;
                            state <= 0;
                        end else begin
                            progress <= 3'd2;
                            mem_dout <= lsb_s_data[23:16];
                        end
                    end
                    3'd2: begin
                        progress <= 3'd3;
                        mem_dout <= lsb_s_data[31:24];
                    end
                    3'd3: begin
                        lsb_valid <= 1;
                        mem_wr <= 0;
                        state <= 0;
                    end
                    default;
                endcase
                mem_a <= mem_a + 1;
            end
            2'd3: begin // LOAD
                case (progress)
                    3'd0: begin
                        progress <= 3'd1;
                    end
                    3'd1: begin
                        lsb_l_data[7:0] <= mem_din;
                        if (lsb_ls_opcode == `LB) begin
                            lsb_l_data[31:8] <= {24{mem_din[7]}};
                            lsb_valid <= 1;
                            state <= 0;
                        end else if (lsb_ls_opcode == `LBU) begin
                            lsb_valid <= 1;
                            state <= 0;
                        end else begin
                            progress <= 3'd2;
                        end
                    end
                    3'd2: begin
                        lsb_l_data[15:8] <= mem_din;
                        if (lsb_ls_opcode == `LH) begin
                            lsb_l_data[31:16] <= {16{mem_din[7]}};
                            lsb_valid <= 1;
                            state <= 0;
                        end else if (lsb_ls_opcode == `LHU) begin
                            lsb_valid <= 1;
                            state <= 0;
                        end else begin
                            progress <= 3'd3;
                        end
                    end
                    3'd3: begin
                        lsb_l_data[23:16] <= mem_din;
                        progress <= 3'd4;
                    end
                    3'd4: begin
                        lsb_l_data[31:24] <= mem_din;
                        progress <= 3'd0;
                        lsb_valid <= 1;
                        state <= 0;
                    end
                    default;
                endcase
                mem_a <= mem_a + 1;
            end
            default;
        endcase
    end
end

endmodule