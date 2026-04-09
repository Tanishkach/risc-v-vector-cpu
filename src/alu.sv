// ALU — Arithmetic Logic Unit
// This is the "calculator" of the CPU.
// It takes two numbers and an operation code,
// and gives back a result.

module alu (
    input  logic [31:0] a,        // first number
    input  logic [31:0] b,        // second number
    input  logic [3:0]  alu_op,   // what operation to do
    output logic [31:0] result,   // the answer
    output logic        zero      // is the result zero? (used for branches)
);

    always_comb begin
        case (alu_op)
            4'b0000: result = a + b;          // ADD
            4'b0001: result = a - b;          // SUB
            4'b0010: result = a & b;          // AND
            4'b0011: result = a | b;          // OR
            4'b0100: result = a ^ b;          // XOR
            4'b0101: result = a << b[4:0];    // Shift Left
            4'b0110: result = a >> b[4:0];    // Shift Right
            4'b0111: result = $signed(a) >>> b[4:0]; // Arithmetic Shift Right
            4'b1000: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // Less than
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0); // flag for branch instructions

endmodule