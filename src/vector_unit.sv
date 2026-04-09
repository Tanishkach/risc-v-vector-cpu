// VECTOR UNIT — The unique feature of this CPU!
// Normal CPUs process one number at a time.
// This unit can process 1, 2, or 4 numbers simultaneously.
// Software can configure how many lanes are active at runtime
// by writing to the VCFG register.

module vector_unit (
    input  logic        clk,
    input  logic        rst,

    // Configuration — how many lanes are active? (1, 2, or 4)
    input  logic [2:0]  vcfg,          // 001=1 lane, 010=2 lanes, 100=4 lanes

    // Vector registers — 8 vector registers, each holds 4 x 32-bit elements
    input  logic [4:0]  vs1_addr,      // source vector reg 1
    input  logic [4:0]  vs2_addr,      // source vector reg 2
    input  logic [4:0]  vd_addr,       // destination vector reg
    input  logic        we,            // write enable
    input  logic [2:0]  vop,           // operation: add, sub, mul, and, or

    output logic [31:0] vresult [0:3], // results for up to 4 lanes
    output logic        vdone          // pulses when operation is complete
);

    // 8 vector registers, each with 4 x 32-bit lanes
    logic [31:0] vreg [0:7][0:3];

    // Internal wires for operands
    logic [31:0] va [0:3];
    logic [31:0] vb [0:3];
    logic [31:0] vout [0:3];

    // How many lanes are actually active
    logic [2:0] active_lanes;
    always_comb begin
        case (vcfg)
            3'b001:  active_lanes = 3'd1;
            3'b010:  active_lanes = 3'd2;
            3'b100:  active_lanes = 3'd4;
            default: active_lanes = 3'd1;
        endcase
    end

    // Read source registers
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : read_lanes
            assign va[i] = vreg[vs1_addr[2:0]][i];
            assign vb[i] = vreg[vs2_addr[2:0]][i];
        end
    endgenerate

    // Execute operation on each lane
    generate
        for (i = 0; i < 4; i++) begin : exec_lanes
            always_comb begin
                if (i < active_lanes) begin
                    case (vop)
                        3'b000: vout[i] = va[i] + vb[i];   // VADD
                        3'b001: vout[i] = va[i] - vb[i];   // VSUB
                        3'b010: vout[i] = va[i] & vb[i];   // VAND
                        3'b011: vout[i] = va[i] | vb[i];   // VOR
                        3'b100: vout[i] = va[i] ^ vb[i];   // VXOR
                        default: vout[i] = 32'd0;
                    endcase
                end else begin
                    vout[i] = 32'd0; // inactive lanes output zero
                end
            end
        end
    endgenerate

    // Write results back to destination register
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            integer j, k;
            for (j = 0; j < 8; j++)
                for (k = 0; k < 4; k++)
                    vreg[j][k] <= 32'd0;
            vdone <= 1'b0;
        end else if (we) begin
            integer l;
            for (l = 0; l < 4; l++) begin
                if (l < active_lanes)
                    vreg[vd_addr[2:0]][l] <= vout[l];
            end
            vdone <= 1'b1;
        end else begin
            vdone <= 1'b0;
        end
    end

    // Output results
    genvar m;
    generate
        for (m = 0; m < 4; m++) begin : output_lanes
            assign vresult[m] = vout[m];
        end
    endgenerate

endmodule