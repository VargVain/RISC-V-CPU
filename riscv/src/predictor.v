module predictor(
    input               clk,
    input               rst,
    input               rdy,

    // for IF
    input [31:0]        instr_predict_addr,
    output              jump
    
    // for ROB
);

assign jump = 1'b1;

always @(posedge clk) begin
    if (rst) begin
        // reset
    end else if (rdy) begin
        // predict
    end
end

endmodule