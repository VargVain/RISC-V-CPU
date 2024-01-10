`include "config.vh"

module reservation_station(
    input               clk,
    input               rst,
    input               rdy,

    // for IU
    input               issue_valid,
    input [5:0]         issue_opcode,
    input [31:0]        issue_val1,
    input [5:0]         issue_dep1,
    input               issue_has_dep1,
    input [31:0]        issue_val2,
    input [5:0]         issue_dep2,
    input               issue_has_dep2,
    input [5:0]         issue_rob_index,
    input [31:0]        issue_imm,
    input [31:0]        issue_pc,

    // for ALU
    input               alu_valid,
    input [31:0]        alu_res,
    input [5:0]         alu_rob_index_out,
    input               alu_is_load,
    output reg [5:0]    alu_opcode,
    output reg [31:0]   alu_val1,
    output reg [31:0]   alu_val2,
    output reg [31:0]   alu_imm,
    output reg [31:0]   alu_pc,
    output reg [5:0]    alu_rob_index,

    // for LSB
    input               lsb_valid,
    input [5:0]         lsb_rs_rob_index_out,
    input [31:0]        lsb_rs_res,

    // for CDB
    input               flush,
    output              rs_full

  );

  reg [16:0]              busy;
  reg [5:0]               rob_index [16:0];
  reg [31:0]              val1 [16:0];
  reg [5:0]               dep1 [16:0];
  reg [16:0]              has_dep1;
  reg [31:0]              val2 [16:0];
  reg [5:0]               dep2 [16:0];
  reg [16:0]              has_dep2;
  reg [31:0]              imm [16:0];
  reg [31:0]              pc [16:0];
  reg [5:0]               opcode [16:0];

  wire [16:0] ready = ~has_dep1 & ~has_dep2;
  wire [4:0] first_empty = ~busy[0]  ? 0  :
       ~busy[1]  ? 1  :
       ~busy[2]  ? 2  :
       ~busy[3]  ? 3  :
       ~busy[4]  ? 4  :
       ~busy[5]  ? 5  :
       ~busy[6]  ? 6  :
       ~busy[7]  ? 7  :
       ~busy[8]  ? 8  :
       ~busy[9]  ? 9  :
       ~busy[10] ? 10 :
       ~busy[11] ? 11 :
       ~busy[12] ? 12 :
       ~busy[13] ? 13 :
       ~busy[14] ? 14 :
       ~busy[15] ? 15 :
       16 ;
  wire has_empty = first_empty != 16;
  assign rs_full = first_empty == 15 || first_empty == 16;

  wire [4:0] first_ready = ready[0] && busy[0]  ? 0  :
       ready[1] && busy[1]  ? 1  :
       ready[2] && busy[2]  ? 2  :
       ready[3] && busy[3]  ? 3  :
       ready[4] && busy[4]  ? 4  :
       ready[5] && busy[5]  ? 5  :
       ready[6] && busy[6]  ? 6  :
       ready[7] && busy[7]  ? 7  :
       ready[8] && busy[8]  ? 8  :
       ready[9] && busy[9]  ? 9  :
       ready[10] && busy[10] ? 10 :
       ready[11] && busy[11] ? 11 :
       ready[12] && busy[12] ? 12 :
       ready[13] && busy[13] ? 13 :
       ready[14] && busy[14] ? 14 :
       ready[15] && busy[15] ? 15 :
       16 ;
  wire has_ready = first_ready != 16;

  integer i, cnt=0;

  always @(posedge clk) begin
    cnt = cnt + 1;
    if (rst) begin
      // reset
      for (i = 0; i <= 16; i = i + 1) begin
        busy[i] <= 0;
        rob_index[i] <= 0;
        val1[i] <= 0;
        dep1[i] <= 0;
        has_dep1[i] <= 0;
        val2[i] <= 0;
        dep2[i] <= 0;
        has_dep2[i] <= 0;
        imm[i] <= 0;
        pc[i] <= 0;
        opcode[i] <= 0;
      end
      alu_opcode <= 0;
      alu_val1 <= 0;
      alu_val2 <= 0;
      alu_imm <= 0;
      alu_pc <= 0;
      alu_rob_index <= 0;
    end
    else if (rdy) begin
      if (flush) begin
        // flush
        for (i = 0; i <= 16; i = i + 1) begin
          busy[i] <= 0;
          rob_index[i] <= 0;
          val1[i] <= 0;
          dep1[i] <= 0;
          has_dep1[i] <= 0;
          val2[i] <= 0;
          dep2[i] <= 0;
          has_dep2[i] <= 0;
          imm[i] <= 0;
          pc[i] <= 0;
          opcode[i] <= 0;
        end
        alu_opcode <= 0;
        alu_val1 <= 0;
        alu_val2 <= 0;
        alu_imm <= 0;
        alu_pc <= 0;
        alu_rob_index <= 0;
      end else begin
        if (has_empty && issue_valid) begin
          opcode[first_empty] <= issue_opcode;
          rob_index[first_empty] <= issue_rob_index;

          if (issue_has_dep1 && alu_valid && issue_dep1 == alu_rob_index_out && ~alu_is_load) begin
            val1[first_empty] <= alu_res;
            dep1[first_empty] <= 0;
            has_dep1[first_empty] <= 0;
          end else if (issue_has_dep1 && lsb_valid && issue_dep1 == lsb_rs_rob_index_out) begin
            val1[first_empty] <= lsb_rs_res;
            dep1[first_empty] <= 0;
            has_dep1[first_empty] <= 0;
          end else begin
            val1[first_empty] <= issue_val1;
            dep1[first_empty] <= issue_dep1;
            has_dep1[first_empty] <= issue_has_dep1;
          end
          
          if (issue_has_dep2 && alu_valid && issue_dep2 == alu_rob_index_out && ~alu_is_load) begin
            val2[first_empty] <= alu_res;
            dep2[first_empty] <= 0;
            has_dep2[first_empty] <= 0;
          end else if (issue_has_dep2 && lsb_valid && issue_dep2 == lsb_rs_rob_index_out) begin
            val2[first_empty] <= lsb_rs_res;
            dep2[first_empty] <= 0;
            has_dep2[first_empty] <= 0;
          end else begin
            val2[first_empty] <= issue_val2;
            dep2[first_empty] <= issue_dep2;
            has_dep2[first_empty] <= issue_has_dep2;
          end

          imm[first_empty] <= issue_imm;
          pc[first_empty] <= issue_pc;
          busy[first_empty] <= 1'b1;
        end
        if (has_ready) begin
          //$display("[rs ready]: opcode=%d, val1=%d, val2=%d, rob_index=%d", opcode[first_ready], val1[first_ready], val2[first_ready], rob_index[first_ready]);
          //$display("ready sheet: %b, busy sheet: %b", ready, busy);
          alu_opcode <= opcode[first_ready];
          alu_val1 <= val1[first_ready];
          alu_val2 <= val2[first_ready];
          alu_imm <= imm[first_ready];
          alu_pc <= pc[first_ready];
          alu_rob_index <= rob_index[first_ready];
          busy[first_ready] <= 1'b0;
        end else alu_opcode <= 0;
        if (alu_valid) begin
          if (`DEBUG && cnt > `HEAD) $display("[alu %d] index: %d, val: %h", cnt, alu_rob_index_out, alu_res);
          for (i = 0; i < 16; i = i + 1) begin
            //$display("------%d, %d, %d", i, has_dep2[i], dep2[i]);
            if (has_dep1[i] && dep1[i] == alu_rob_index_out && ~alu_is_load) begin
              val1[i] <= alu_res;
              has_dep1[i] <= 0;
            end
            if (has_dep2[i] && dep2[i] == alu_rob_index_out && ~alu_is_load) begin
              val2[i] <= alu_res;
              has_dep2[i] <= 0;
            end
          end
        end
        if (lsb_valid) begin
          for (i = 0; i < 16; i = i + 1) begin
            if (has_dep1[i] && dep1[i] == lsb_rs_rob_index_out) begin
              val1[i] <= lsb_rs_res;
              has_dep1[i] <= 0;
            end
            if (has_dep2[i] && dep2[i] == lsb_rs_rob_index_out) begin
              //$display("[rs lsb change] %d, %d", dep2[i], lsb_rs_res);
              val2[i] <= lsb_rs_res;
              has_dep2[i] <= 0;
            end
          end
        end
      end
    end
  end

endmodule
