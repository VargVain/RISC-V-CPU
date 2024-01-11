`include "config.vh"

module load_store_buffer (
    input               clk,
    input               rst,
    input               rdy,

    // for MC
    input               mem_l_valid,
    input [31:0]        mem_l_data,
    output reg          mem_valid,
    output reg [5:0]    mem_ls_opcode,
    output reg          mem_ls, // 0-STORE, 1-LOAD
    output reg [31:0]   mem_ls_addr,
    output reg [31:0]   mem_s_data,

    // for ROB
    input               rob_valid,
    input [5:0]         rob_index,
    input [5:0]         rob_opcode,
    input [31:0]        rob_ls_addr,
    input [31:0]        rob_s_val,
    output reg          rob_ls_valid,
    output reg [5:0]    rob_ls_index_out,
    output reg [31:0]   rob_l_data,

    // for RS
    output reg          lsb_valid,
    output reg [5:0]    lsb_rs_rob_index,
    output reg [31:0]   lsb_rs_res,

    // for CDB
    input               flush,
    output              lsb_full
);

    reg [5:0]           index;

    reg [1:0]           state; // 0-IDLE, 1-STORE, 2-LOAD

    assign lsb_full = 0;

    always @(posedge clk) begin
        if (rst) begin
            lsb_valid <= 0;
            state <= 0;
            mem_valid <= 0;
            rob_ls_valid <= 0;
        end else if (rdy) begin
            if (flush) begin
                lsb_valid <= 0;
                state <= 0;
                mem_valid <= 0;
                rob_ls_valid <= 0;
            end else begin
                case (state)
                2'd0: begin // IDLE
                    lsb_valid <= 0;
                    rob_ls_valid <= 0;
                    if (rob_valid) begin
                        index <= rob_index;
                        mem_valid <= 1;
                        mem_ls <= rob_opcode < `SB ? 1 : 0;
                        mem_ls_opcode <= rob_opcode;
                        mem_ls_addr <= rob_ls_addr;
                        mem_s_data <= rob_s_val;
                        state <= rob_opcode < `SB ? 2 : 1;
                    end
                end
                2'd1: begin // STORE
                    if (mem_l_valid) begin
                        mem_valid <= 0;
                        rob_ls_valid <= 1;
                        rob_ls_index_out <= index;
                        state <= 0;
                    end
                end
                2'd2: begin // LOAD
                    if (mem_l_valid) begin
                        mem_valid <= 0;    
                        rob_ls_valid <= 1;
                        rob_ls_index_out <= index;
                        rob_l_data <= mem_l_data;

                        lsb_valid <= 1;
                        lsb_rs_rob_index <= index;
                        lsb_rs_res <= mem_l_data;

                        state <= 0;
                    end
                end
                default;
                endcase
            end
        end
    end

endmodule