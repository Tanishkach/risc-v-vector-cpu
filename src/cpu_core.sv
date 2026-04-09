// CPU CORE — The brain that connects everything together.
// This is a 5-stage pipeline: Fetch → Decode → Execute → Memory → Writeback
// It instantiates the ALU, Register File, and Vector Unit.

module cpu_core (
    input  logic        clk,
    input  logic        rst,

    // Instruction memory interface
    output logic [31:0] imem_addr,     // address to fetch instruction from
    input  logic [31:0] imem_data,     // the instruction that comes back

    // Data memory interface
    output logic [31:0] dmem_addr,     // address to read/write data
    output logic [31:0] dmem_wdata,    // data to write
    output logic        dmem_we,       // write enable
    input  logic [31:0] dmem_rdata,    // data read back

    // Debug outputs so we can watch what's happening
    output logic [31:0] debug_pc,
    output logic [31:0] debug_alu_result
);

    // ─── Program Counter ───────────────────────────────────────────────
    logic [31:0] pc, pc_next;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) pc <= 32'd0;
        else     pc <= pc_next;
    end

    assign imem_addr = pc;
    assign debug_pc  = pc;

    // ─── FETCH ─────────────────────────────────────────────────────────
    logic [31:0] if_instruction;
    logic [31:0] if_pc;

    assign if_instruction = imem_data;
    assign if_pc          = pc;

    // ─── DECODE ────────────────────────────────────────────────────────
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    assign opcode = if_instruction[6:0];
    assign rd     = if_instruction[11:7];
    assign funct3 = if_instruction[14:12];
    assign rs1    = if_instruction[19:15];
    assign rs2    = if_instruction[24:20];
    assign funct7 = if_instruction[31:25];

    // Immediate value decoding (RISC-V standard formats)
    assign imm_i = {{20{if_instruction[31]}}, if_instruction[31:20]};
    assign imm_s = {{20{if_instruction[31]}}, if_instruction[31:25], if_instruction[11:7]};
    assign imm_b = {{19{if_instruction[31]}}, if_instruction[31], if_instruction[7],
                    if_instruction[30:25], if_instruction[11:8], 1'b0};
    assign imm_u = {if_instruction[31:12], 12'd0};
    assign imm_j = {{11{if_instruction[31]}}, if_instruction[31], if_instruction[19:12],
                    if_instruction[20], if_instruction[30:21], 1'b0};

    // ─── REGISTER FILE ─────────────────────────────────────────────────
    logic [31:0] reg_rs1, reg_rs2;
    logic        reg_we;
    logic [4:0]  reg_rd;
    logic [31:0] reg_wdata;

    register_file u_rf (
        .clk     (clk),
        .rst     (rst),
        .rs1_addr(rs1),
        .rs1_data(reg_rs1),
        .rs2_addr(rs2),
        .rs2_data(reg_rs2),
        .we      (reg_we),
        .rd_addr (reg_rd),
        .rd_data (reg_wdata)
    );

    // ─── CONTROL SIGNALS ───────────────────────────────────────────────
    logic        is_rtype, is_itype, is_load, is_store, is_branch, is_jal, is_lui;
    logic        is_vector;  // our custom vector instruction (opcode 7'b1010111)

    assign is_rtype  = (opcode == 7'b0110011);
    assign is_itype  = (opcode == 7'b0010011);
    assign is_load   = (opcode == 7'b0000011);
    assign is_store  = (opcode == 7'b0100011);
    assign is_branch = (opcode == 7'b1100011);
    assign is_jal    = (opcode == 7'b1101111);
    assign is_lui    = (opcode == 7'b0110111);
    assign is_vector = (opcode == 7'b1010111); // custom vector opcode

    // ─── ALU ───────────────────────────────────────────────────────────
    logic [3:0]  alu_op;
    logic [31:0] alu_a, alu_b, alu_result;
    logic        alu_zero;

    // ALU operation selector
    always_comb begin
        case ({funct7[5], funct3})
            4'b0000: alu_op = 4'b0000; // ADD
            4'b1000: alu_op = 4'b0001; // SUB
            4'b0111: alu_op = 4'b0010; // AND
            4'b0110: alu_op = 4'b0011; // OR
            4'b0100: alu_op = 4'b0100; // XOR
            4'b0001: alu_op = 4'b0101; // SLL
            4'b0101: alu_op = 4'b0110; // SRL
            4'b1101: alu_op = 4'b0111; // SRA
            4'b0010: alu_op = 4'b1000; // SLT
            default: alu_op = 4'b0000;
        endcase
    end

    assign alu_a = reg_rs1;
    assign alu_b = (is_rtype || is_branch) ? reg_rs2 : imm_i;

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .alu_op (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    assign debug_alu_result = alu_result;

    // ─── VECTOR UNIT ───────────────────────────────────────────────────
    logic [2:0]  vcfg;          // configurable lane count CSR
    logic [31:0] vresult [0:3];
    logic        vdone;

    // vcfg is written when opcode is vector and funct3==3'b111 (VCFG write)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) vcfg <= 3'b001; // default: 1 lane
        else if (is_vector && funct3 == 3'b111)
            vcfg <= reg_rs1[2:0]; // software writes lane config via register
    end

    vector_unit u_vec (
        .clk      (clk),
        .rst      (rst),
        .vcfg     (vcfg),
        .vs1_addr (rs1),
        .vs2_addr (rs2),
        .vd_addr  (rd),
        .we       (is_vector && funct3 != 3'b111),
        .vop      (funct3),
        .vresult  (vresult),
        .vdone    (vdone)
    );

    // ─── MEMORY ACCESS ─────────────────────────────────────────────────
    assign dmem_addr  = alu_result;
    assign dmem_wdata = reg_rs2;
    assign dmem_we    = is_store;

    // ─── WRITEBACK ─────────────────────────────────────────────────────
    always_comb begin
        reg_we    = 1'b0;
        reg_rd    = rd;
        reg_wdata = 32'd0;

        if (is_rtype || is_itype) begin
            reg_we    = 1'b1;
            reg_wdata = alu_result;
        end else if (is_load) begin
            reg_we    = 1'b1;
            reg_wdata = dmem_rdata;
        end else if (is_lui) begin
            reg_we    = 1'b1;
            reg_wdata = imm_u;
        end else if (is_jal) begin
            reg_we    = 1'b1;
            reg_wdata = pc + 32'd4;
        end
    end

    // ─── NEXT PC ───────────────────────────────────────────────────────
    always_comb begin
        if (is_branch && alu_zero)
            pc_next = pc + imm_b;        // taken branch
        else if (is_jal)
            pc_next = pc + imm_j;        // jump
        else
            pc_next = pc + 32'd4;        // normal: next instruction
    end

endmodule