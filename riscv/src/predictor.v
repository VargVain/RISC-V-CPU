module predictor(
    input               clk,
    input               rst,
    input               rdy,

    // for IF
    input [31:0]        instr_predict_addr,
    output              jump,
    
    // for ROB
    input               rob_pred_valid,
    input [31:0]        rob_pred_pc,
    input               rob_pred_taken
);

reg [1:0]               ppht[127:0];

wire [6:0] pred_hash = instr_predict_addr[8:2];
wire [6:0] rob_hash = rob_pred_pc[8:2];

assign jump = ppht[pred_hash][1];

integer i;

initial begin
    for (i = 0; i < 128; i = i + 1) begin
        ppht[i] = 2'b10;
    end
end

always @(posedge clk) begin
    if (rst) begin
        //
    end else if (rdy) begin
        if (rob_pred_valid) begin
            if (rob_pred_taken && ppht[rob_hash] != 2'b11) ppht[rob_hash] <= ppht[rob_hash] + 1;
            if (!rob_pred_taken && ppht[rob_hash] != 2'b00) ppht[rob_hash] <= ppht[rob_hash] - 1;
        end
    end
end

endmodule