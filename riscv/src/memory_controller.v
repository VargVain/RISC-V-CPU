`include "const.v"

module memory_controller(
    input               clk,
    input               rst,
    input               rdy,

    // for memory access
    input      [7:0]    mem_din,
    input               io_buffer_full,
    output reg [7:0]    mem_dout,
    output reg [31:0]   mem_a,
    output reg          mem_wr,

    // for icache
    input               instr_out_enable,
    input [31:0]        instr_out_addr,
    output              instr_out_valid,
    output [31:0]       instr_out

);

reg [4:0]           state;
reg [2:0]           progress;

always @(posedge clk) begin
    if (rst) begin
        // reset
    end else if (rdy) begin
        case (state)
            `IDLE: begin
                if (instr_out_enable) begin
                    state <= `FETCH;
                    progress <= 0;
                    mem_a <= instr_out_addr;
                    mem_wr <= 1'b0;
                end
            end
            `FETCH: begin
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
                        progress <= 3'd5;
                    end
                    3'd5: begin
                        state <= `IDLE;
                        instr_out_valid <= 1'b0;
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