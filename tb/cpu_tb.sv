module cpu_tb;

    // Clock and reset
    logic clk, rst;

    // Memory interfaces
    logic [31:0] imem_addr, dmem_addr, dmem_wdata;
    logic        dmem_we;
    logic [31:0] imem_data, dmem_rdata;

    // Debug
    logic [31:0] debug_pc, debug_alu_result;

    // Instantiate the CPU 
    cpu_core dut (
        .clk             (clk),
        .rst             (rst),
        .imem_addr       (imem_addr),
        .imem_data       (imem_data),
        .dmem_addr       (dmem_addr),
        .dmem_wdata      (dmem_wdata),
        .dmem_we         (dmem_we),
        .dmem_rdata      (dmem_rdata),
        .debug_pc        (debug_pc),
        .debug_alu_result(debug_alu_result)
    );

    // Fake Instruction Memory 
    // This is a small program loaded into the fake memory.
    // Each line is one 32-bit RISC-V instruction in binary.
    logic [31:0] imem [0:15];

    initial begin
        // addi x1, x0, 5       → x1 = 5
        imem[0]  = 32'b000000000101_00000_000_00001_0010011;
        // addi x2, x0, 3       → x2 = 3
        imem[1]  = 32'b000000000011_00000_000_00010_0010011;
        // add  x3, x1, x2      → x3 = 8
        imem[2]  = 32'b0000000_00010_00001_000_00011_0110011;
        // sub  x4, x3, x1      → x4 = 3
        imem[3]  = 32'b0100000_00001_00011_000_00100_0110011;
        // and  x5, x1, x2      → x5 = 1
        imem[4]  = 32'b0000000_00010_00001_111_00101_0110011;
        // or   x6, x1, x2      → x6 = 7
        imem[5]  = 32'b0000000_00010_00001_110_00110_0110011;

        // Vector config: set vcfg = 4 lanes (x1 holds value, custom vector opcode)
        // This is our unique instruction! Tells the vector unit to use 4 lanes.
        imem[6]  = 32'b0000000_00000_00100_111_00000_1010111;

        // Vector ADD on 4 lanes (vs1=x1, vs2=x2, vd=x7)
        imem[7]  = 32'b0000000_00010_00001_000_00111_1010111;

        // nop (addi x0, x0, 0) — do nothing
        imem[8]  = 32'b000000000000_00000_000_00000_0010011;
        imem[9]  = 32'b000000000000_00000_000_00000_0010011;
        imem[10] = 32'b000000000000_00000_000_00000_0010011;
        imem[11] = 32'b000000000000_00000_000_00000_0010011;
        imem[12] = 32'b000000000000_00000_000_00000_0010011;
        imem[13] = 32'b000000000000_00000_000_00000_0010011;
        imem[14] = 32'b000000000000_00000_000_00000_0010011;
        imem[15] = 32'b000000000000_00000_000_00000_0010011;
    end

    // Instruction fetch — address divided by 4 gives array index
    assign imem_data  = imem[imem_addr[5:2]];
    assign dmem_rdata = 32'd0; // no real data memory needed for this test

    // Clock Generator 
    // Toggles every 5ns → 10ns period → 100MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Test Sequence 
    initial begin
        // Create waveform file for Vivado viewer
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);

        // Hold reset for 2 clock cycles
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;

        // Let the CPU run for 20 clock cycles
        repeat (20) @(posedge clk);

        $display("Simulation complete!");
        $finish;
    end

    //Monitor — prints to console every clock cycle 
    always @(posedge clk) begin
        if (!rst) begin
            $display("PC=%0d | ALU=%0d | VecDone=%b | vcfg=%b",
                      debug_pc, debug_alu_result, dut.vdone, dut.vcfg);
        end
    end

endmodule