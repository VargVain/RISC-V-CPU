// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
  input  wire				  rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		    // data input bus
  output wire [ 7:0]          mem_dout,		    // data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
  input  wire                 io_buffer_full,   // 1 if uart buffer is full
	
  output wire [31:0]		  dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// CDB
wire                flush;
wire                new_pc_enable;
wire [31:0]         new_pc;
wire                rob_full;
wire                rs_full;
wire                full = rob_full || rs_full;

// MEM & ICache
wire                icache_instr_out_enable;
wire [31:0]         icache_instr_out_addr;
wire                icache_instr_out_valid;
wire [31:0]         icache_instr_out;

// ICache & IF
wire [31:0]         if_pc;
wire                if_instr_out_valid;
wire [31:0]         if_instr_out;

// IF & IU
wire                iu_instr_out_valid;
wire                iu_jumped;
wire [31:0]         iu_instr_out;
wire [31:0]         iu_instr_out_pc;

// IF & predictor
wire                pred_jump;
wire [31:0]         pred_instr_predict_addr;

// IU & decoder
wire [5:0]          dec_opcode;
wire [4:0]          dec_rs1;
wire [4:0]          dec_rs2;
wire [4:0]          dec_rd;
wire [31:0]         dec_imm;
wire [31:0]         dec_instr_decode;

// IU & ROB
wire [5:0]          rob_next_index;
wire                rob_valid;
wire [4:0]          rob_rd;
wire                rob_jumped;
wire [5:0]          rob_opcode;
wire                rob_value_valid1;
wire                rob_value_valid2;
wire [31:0]         rob_value1;
wire [31:0]         rob_value2;
wire [5:0]          rob_check1;
wire [5:0]          rob_check2;

// IU & RS
wire                rs_valid;
wire [5:0]          rs_opcode;
wire [31:0]         rs_val1;
wire [5:0]          rs_dep1;
wire                rs_has_dep1;
wire [31:0]         rs_val2;
wire [5:0]          rs_dep2;
wire                rs_has_dep2;
wire [5:0]          rs_rob_index;
wire [31:0]         rs_imm;
wire [31:0]         rs_pc;

// IU & RF
wire [31:0]         rf_val1;
wire [5:0]          rf_dep1;
wire                rf_has_dep1;
wire [31:0]         rf_val2;
wire [5:0]          rf_dep2;
wire                rf_has_dep2;
wire [4:0]          rf_check1;
wire [4:0]          rf_check2;

wire                rf_valid;
wire [4:0]          rf_regname;
wire [5:0]          rf_regrename;

// RF & ROB
wire                rf_rob_valid;
wire [5:0]          rf_rob_index;
wire [4:0]          rf_rob_rd;
wire [31:0]         rf_rob_value;

// ALU & RS
wire [5:0]          to_alu_opcode;
wire [31:0]         to_alu_val1;
wire [31:0]         to_alu_val2;
wire [31:0]         to_alu_imm;
wire [31:0]         to_alu_pc;
wire [5:0]          to_alu_rob_index;

// ALU & ROB/RS
wire                from_alu_valid;
wire [31:0]         from_alu_res;
wire                from_alu_real_jump;
wire [31:0]         from_alu_real_jump_pc;
wire [5:0]          from_alu_rob_index_out;

memory_controller  memory_controller_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .mem_din(mem_din),
    .io_buffer_full(io_buffer_full),
    .mem_dout(mem_dout),
    .mem_a(mem_a),
    .mem_wr(mem_wr),
    .instr_out_enable(icache_instr_out_enable),
    .instr_out_addr(icache_instr_out_addr),
    .instr_out_valid(icache_instr_out_valid),
    .instr_out(icache_instr_out)
);

icache  icache_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .instr_in_valid(icache_instr_out_valid),
    .instr_in(icache_instr_out),
    .instr_in_enable(icache_instr_out_enable),
    .instr_in_addr(icache_instr_out_addr),
    .pc(if_pc),
    .instr_out_valid(if_instr_out_valid),
    .instr_out(if_instr_out)
);

instruction_fetcher  instruction_fetcher_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .instr_in_valid(if_instr_out_valid),
    .instr_in(if_instr_out),
    .instr_in_addr(if_pc),
    .instr_out_valid(iu_instr_out_valid),
    .jumped(iu_jumped),
    .instr_out(iu_instr_out),
    .instr_out_pc(iu_instr_out_pc),
    .jump(pred_jump),
    .instr_predict_addr(pred_instr_predict_addr),
    .full(full),
    .flush(flush),
    .new_pc_enable(new_pc_enable),
    .new_pc(new_pc)
);

instruction_issuer  instruction_issuer_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .instr_in_valid(iu_instr_out_valid),
    .instr_in(iu_instr_out),
    .jumped(iu_jumped),
    .pc(iu_instr_out_pc),
    .opcode(dec_opcode),
    .rs1(dec_rs1),
    .rs2(dec_rs2),
    .rd(dec_rd),
    .imm(dec_imm),
    .instr_decode(dec_instr_decode),
    .rob_next_index(rob_next_index),
    .rob_valid(rob_valid),
    .rob_rd(rob_rd),
    .rob_jumped(rob_jumped),
    .rob_opcode(rob_opcode),
    .rob_value_valid1(rob_value_valid1),
    .rob_value_valid2(rob_value_valid2),
    .rob_value1(rob_value1),
    .rob_value2(rob_value2),
    .rob_check1(rob_check1),
    .rob_check2(rob_check2),
    .rs_valid(rs_valid),
    .rs_opcode(rs_opcode),
    .rs_val1(rs_val1),
    .rs_dep1(rs_dep1),
    .rs_has_dep1(rs_has_dep1),
    .rs_val2(rs_val2),
    .rs_dep2(rs_dep2),
    .rs_has_dep2(rs_has_dep2),
    .rs_rob_index(rs_rob_index),
    .rs_imm(rs_imm),
    .rs_pc(rs_pc),
    .rf_val1(rf_val1),
    .rf_dep1(rf_dep1),
    .rf_has_dep1(rf_has_dep1),
    .rf_val2(rf_val2),
    .rf_dep2(rf_dep2),
    .rf_has_dep2(rf_has_dep2),
    .rf_check1(rf_check1),
    .rf_check2(rf_check2),
    .rf_valid(rf_valid),
    .rf_regname(rf_regname),
    .rf_regrename(rf_regrename),
    .flush(flush)
);

predictor  predictor_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .instr_predict_addr(pred_instr_predict_addr),
    .jump(pred_jump)
);

arithmetic_logic_unit  arithmetic_logic_unit_inst (
    .opcode(to_alu_opcode),
    .val1(to_alu_val1),
    .val2(to_alu_val2),
    .imm(to_alu_imm),
    .pc(to_alu_pc),
    .rob_index(to_alu_rob_index),
    .valid(from_alu_valid),
    .res(from_alu_res),
    .real_jump(from_alu_real_jump),
    .real_jump_pc(from_alu_real_jump_pc),
    .rob_index_out(from_alu_rob_index_out)
);

reorder_buffer  reorder_buffer_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .issue_valid(rob_valid),
    .issue_rd(rob_rd),
    .issue_jump(rob_jumped),
    .issue_opcode(rob_opcode),
    .next_index(rob_next_index),
    .issue_check1(rob_check1),
    .issue_check2(rob_check2),
    .issue_value_valid1(rob_value_valid1),
    .issue_value_valid2(rob_value_valid2),
    .issue_value1(rob_value1),
    .issue_value2(rob_value2),
    .rf_valid(rf_rob_valid),
    .rf_index(rf_rob_index),
    .rf_rd(rf_rob_rd),
    .rf_value(rf_rob_value),
    .alu_valid(from_alu_valid),
    .alu_res(from_alu_res),
    .alu_jump(from_alu_real_jump),
    .alu_jump_pc(from_alu_real_jump_pc),
    .alu_rob_index(from_alu_rob_index_out),
    .rob_full(rob_full),
    .flush(flush),
    .new_pc_enable(new_pc_enable),
    .new_pc(new_pc)
);

reservation_station  reservation_station_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .issue_valid(rs_valid),
    .issue_opcode(rs_opcode),
    .issue_val1(rs_val1),
    .issue_dep1(rs_dep1),
    .issue_has_dep1(rs_has_dep1),
    .issue_val2(rs_val2),
    .issue_dep2(rs_dep2),
    .issue_has_dep2(rs_has_dep2),
    .issue_rob_index(rs_rob_index),
    .issue_imm(rs_imm),
    .issue_pc(rs_pc),
    .alu_valid(from_alu_valid),
    .alu_res(from_alu_res),
    .alu_rob_index_out(from_alu_rob_index_out),
    .alu_opcode(to_alu_opcode),
    .alu_val1(to_alu_val1),
    .alu_val2(to_alu_val2),
    .alu_imm(to_alu_imm),
    .alu_pc(to_alu_pc),
    .alu_rob_index(to_alu_rob_index),
    .flush(flush),
    .rs_full(rs_full)
);

register_file  register_file_inst (
    .clk(clk_in),
    .rst(rst_in),
    .rdy(rdy_in),
    .rob_valid(rf_rob_valid),
    .rob_index(rf_rob_index),
    .rob_rd(rf_rob_rd),
    .rob_value(rf_rob_value),
    .issue_valid(rf_valid),
    .issue_regname(rf_regname),
    .issue_regrename(rf_regrename),
    .check1(rf_check1),
    .check2(rf_check2),
    .val1(rf_val1),
    .dep1(rf_dep1),
    .has_dep1(rf_has_dep1),
    .val2(rf_val2),
    .dep2(rf_dep2),
    .has_dep2(rf_has_dep2),
    .flush(flush)
  );


endmodule