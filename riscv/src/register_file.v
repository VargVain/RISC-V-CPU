module register_file(
    input               clk,
    input               rst,
    input               rdy,

    // for ROB
    input               rob_valid,
    input [5:0]         rob_index,
    input [4:0]         rob_rd,
    input [31:0]        rob_value,

    // for IU
    input               issue_valid,
    input [4:0]         issue_regname,
    input [5:0]         issue_regrename,
    input [4:0]         check1,
    input [4:0]         check2,
    output [31:0]       val1,
    output [5:0]        dep1,
    output              has_dep1,
    output [31:0]       val2,
    output [5:0]        dep2,
    output              has_dep2,

    // for CDB
    input               flush
);

reg [31:0]              register [31:0];
reg [5:0]               reg_dep [31:0];
reg                     reg_has_dep [31:0];

wire forward1 = rob_valid && rob_rd == check1 && rob_index == reg_dep[check1];
wire forward2 = rob_valid && rob_rd == check2 && rob_index == reg_dep[check2];

assign has_dep1 = check1 == 0 ? 0 : forward1 ? 0 : reg_has_dep[check1];
assign has_dep2 = check2 == 0 ? 0 : forward2 ? 0 : reg_has_dep[check2];
assign dep1 = has_dep1 ? reg_dep[check1] : 0;
assign dep2 = has_dep2 ? reg_dep[check2] : 0;
assign val1 = forward1 ? rob_value : register[check1];
assign val2 = forward2 ? rob_value : register[check2];

integer i, cnt=0;

always @(posedge clk) begin
    cnt = cnt + 1;
    if (rst) begin
        for (i = 0; i < 32; i = i + 1) begin
            register[i] <= 0;
            reg_dep[i] <= 0;
            reg_has_dep[i] <= 0;
        end
    end else if (rdy) begin
        if (flush) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg_dep[i] <= 0;
                reg_has_dep[i] <= 0;
            end
        end else begin
            if (rob_valid && rob_rd != 0) begin
                register[rob_rd] <= rob_value;
                if (reg_dep[rob_rd] == rob_index) begin
                    if (~issue_valid || issue_regname != rob_rd) reg_has_dep[rob_rd] <= 1'b0;
                end
            end
            if (issue_valid && issue_regname != 0) begin
                reg_dep[issue_regname] <= issue_regrename;
                reg_has_dep[issue_regname] <= 1'b1;
            end
        end
    end
end

endmodule