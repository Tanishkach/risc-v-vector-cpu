// REGISTER FILE — The CPU's scratchpad
// Think of this as 32 small boxes (registers),
// each holding a 32-bit number.
// The CPU reads from and writes to these constantly.

module register_file (
    input  logic        clk,          // clock signal
    input  logic        rst,          // reset — clears everything
    
    // READ PORT 1
    input  logic [4:0]  rs1_addr,     // which box to read from (0-31)
    output logic [31:0] rs1_data,     // the value inside that box
    
    // READ PORT 2
    input  logic [4:0]  rs2_addr,     // which box to read from (0-31)
    output logic [31:0] rs2_data,     // the value inside that box
    
    // WRITE PORT
    input  logic        we,           // write enable — permission to write
    input  logic [4:0]  rd_addr,      // which box to write to
    input  logic [31:0] rd_data       // the value to write
);

    // The 32 registers — each is 32 bits wide
    logic [31:0] regs [0:31];

    // READ — happens instantly (combinational)
    // Register 0 is hardwired to zero in RISC-V, always.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

    // WRITE — happens on the rising edge of the clock
    integer i;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // on reset, clear all registers to 0
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && rd_addr != 5'd0) begin
            // never allow writing to register 0
            regs[rd_addr] <= rd_data;
        end
    end

endmodule