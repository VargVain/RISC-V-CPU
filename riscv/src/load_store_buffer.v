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
    output reg          rob_ls_out,
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

    reg [1:0]           state; // 0-IDLE, 1-STORE, 2-LOAD

    reg [5:0]           index[31:0];
    reg [31:0]          addr[31:0];
    reg [31:0]          val[31:0];
    reg [5:0]           opcode[31:0];

    reg [31:0]          busy;
    reg [4:0]           head;
    reg [4:0]           next;
    reg [5:0]           size;

    wire [4:0] after_head = head == 31 ? 0 : head + 1;
    wire [4:0] after_next = next == 31 ? 0 : next + 1;

    assign lsb_full = size >= 13;

    integer i, cnt=0;
    wire debug = `DEBUG && `LSB && cnt >= `HEAD && cnt <= `TAIL;

    always @(posedge clk) begin
        cnt = cnt + 1;
        if (rst) begin
            lsb_valid <= 0;
            state <= 0;
            mem_valid <= 0;
            rob_ls_valid <= 0;
            for (i = 0; i < 32; i = i + 1) begin
                index[i] <= 0;
                addr[i] <= 0;
                val[i] <= 0;
                opcode[i] <= 0;
            end
            busy <= 0;
            head <= 0;
            next <= 0;
            size <= 0;
        end else if (rdy) begin

            if (debug) begin
                $display("[lsb] [clk=%d] [head=%d] [next=%d] [size=%d] [state=%d]", cnt, head, next, size, state);
                for (i = 0; i < 32; i = i + 1) begin
                    $display("%d--------busy:%d index:%d addr:%d opcode:%d", i, busy[i], index[i], addr[i], opcode[i]);
                end
            end

            if (rob_valid) begin
                index[next] <= rob_index;
                addr[next] <= rob_ls_addr;
                val[next] <= rob_s_val;
                opcode[next] <= rob_opcode;
                busy[next] <= 1'b1;
                next <= after_next;
                if (~mem_l_valid) size <= size + 1; 
            end

            case (state)
            2'd0: begin // IDLE
                lsb_valid <= 0;
                rob_ls_valid <= 0;
                if (busy[head]) begin
                    mem_valid <= 1;
                    mem_ls <= opcode[head] < `SB ? 1 : 0;
                    mem_ls_opcode <= opcode[head];
                    mem_ls_addr <= addr[head];
                    mem_s_data <= val[head];
                    state <= opcode[head] < `SB ? 2 : 1;
                end
            end
            2'd1: begin // STORE
                if (mem_l_valid) begin
                    mem_valid <= 0;

                    busy[head] <= 0;
                    head <= after_head;
                    state <= 0;
                    if (~rob_valid) size <= size - 1;
                end
            end
            2'd2: begin // LOAD
                if (mem_l_valid) begin
                    mem_valid <= 0;    
                    rob_ls_valid <= 1;
                    rob_ls_index_out <= index[head];
                    rob_l_data <= mem_l_data;

                    lsb_valid <= 1;
                    lsb_rs_rob_index <= index[head];
                    lsb_rs_res <= mem_l_data;

                    busy[head] <= 0;
                    head <= after_head;
                    state <= 0;
                    if (~rob_valid) size <= size - 1;
                end
            end
            default;
        endcase
    end
end

endmodule