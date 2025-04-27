// ===============================
// MIPS32 UVM Testbench - Full Setup
// ===============================

// --------------------------------------------------
// Modified pipe_MIPS32 Design with Interface Support
// --------------------------------------------------

module pipe_MIPS32 (clk1, clk2, alu_result, instr1, instr2, instr3, instr4, mem_write, pc);
    input clk1, clk2;                                                                      // Two Phase Clock
    output [31:0] alu_result;
  	output reg [31:0] instr1, instr2, instr3, instr4;
    output mem_write;
  	output [31:0] pc;

    reg [31:0] PC = 0; 
    reg [31:0] IF_ID_IR, IF_ID_NPC;
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
    reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type;
    reg [31:0] EX_MEM_IR, EX_MEM_ALUout, EX_MEM_B;
    reg EX_MEM_cond = 0;
    reg [31:0] MEM_WB_IR, MEM_WB_ALUout, MEM_WB_LMD;
    
    reg [31:0] Reg [0:31];                                                                              // 32 x 32 Register Bank
    reg [31:0] Mem [0:1023];                                                                            // 1024 x 32 Memory
    always @(posedge clk1)
        begin
    Mem[0] = 32'h2801000a;                 //ADDI R1,R0,10
    Mem[1] = 32'h28020014;                 //ADDI R2,R0,20
    Mem[2] = 32'h28030019;                 //ADDI R3,R0,25
    Mem[3] = 32'h0ce77800;                 //OR R7,R7,R7 -- Dummy Instruction
    Mem[4] = 32'h0ce77800;                 //OR R7,R7,R7 -- Dummy Instruction
    Mem[5] = 32'h00222000;                 //ADD R4,R1,R2
    Mem[6] = 32'h0ce77800;                 //OR R7,R7,R7 -- Dummy Instruction
    Mem[7] = 32'h00832800;                 //ADD R5,R4,R3
    Mem[8] = 32'hfc000000;                 //HLT
        end
    parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000010,                                              // \
    OR=6'b000011, SLT=6'b000100, MUL=6'b000101,                                                         // |
    HLT=6'b111111, LW=6'b001000, SW=6'b001001,                                                          // | Op-Codes 
    ADDI=6'b001010, SUBI=6'b001011, SLTI=6'b001100,                                                     // |
    BNEQZ=6'b001101, BEQZ=6'b001110;                                                                    // /

    parameter RR_ALU=3'b000, RM_ALU=3'b001,                                                             // \
    LOAD=3'b010, STORE=3'b011,                                                                          // | Types
    BRANCH=3'b100, HALT=3'b101;                                                                         // /

    reg HALTED = 0;                                                                                         // Set HLT after instruction is completed in write-back (WB) stage
    reg TAKEN_BRANCH = 0;                                                                                   // To disable instructions after a branch

    always @(posedge clk1)                                                                              // Instruction Fetch (IF) Stage
        if (HALTED == 0)
        begin
            if (((EX_MEM_IR[31:26]== BEQZ) && (EX_MEM_cond == 1))||                                     // Checking for Branching
            ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
                begin
                    IF_ID_IR        <= #2 Mem[EX_MEM_ALUout];                                           // \
                    TAKEN_BRANCH    <= #2 1'b1;                                                         // | Branch is Taken
                    IF_ID_NPC       <= #2 EX_MEM_ALUout + 1;                                            // | Program Counter updated with the branch instruction 
                    PC              <= #2 EX_MEM_ALUout + 1;                                            // /
                end
            else
                begin
                    IF_ID_IR        <= #2 Mem[PC];                                                      // \
                    IF_ID_NPC       <= #2 PC +1;                                                        // | Branch not Taken, normal updation of Program Counter
                    PC              <= #2 PC +1;                                                        // /
                end
          instr1 = IF_ID_IR;
        end

    always @(posedge clk2)                                                                              // Instruction Decode (ID) Stage
        if (HALTED == 0)
        begin
            if (IF_ID_IR[25:21] == 5'b00000)
                ID_EX_A             <= 0;
            else
                ID_EX_A             <= #2 Reg[IF_ID_IR[25:21]];                                         // "rs"

            if (IF_ID_IR[20:16] == 5'b00000)
                ID_EX_B             <= 0;
            else
                ID_EX_B             <= #2 Reg[IF_ID_IR[20:16]];                                         // "rt"

            ID_EX_NPC               <= #2 IF_ID_NPC;                                                    // Transferring to next stage
            ID_EX_IR                <= #2 IF_ID_IR;                                                     // Transferring to next stage
            ID_EX_Imm               <= #2 {{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}};                       // Sign Extension to 32 bits

            case (IF_ID_IR[31:26])
                ADD, SUB, AND, OR, SLT, MUL: ID_EX_type <= #2 RR_ALU;                                   // \
                ADDI, SUBI, SLTI:            ID_EX_type <= #2 RM_ALU;                                   // |
                LW:                          ID_EX_type <= #2 LOAD;                                     // |
                SW:                          ID_EX_type <= #2 STORE;                                    // | Checking the Op-Code type for invalids
                BNEQZ, BEQZ:                 ID_EX_type <= #2 BRANCH;                                   // |
                HLT:                         ID_EX_type <= #2 HALT;                                     // |
                default:                     ID_EX_type <= #2 HALT;                                     // /
            endcase 
          instr2 = ID_EX_IR;
        end

    always @(posedge clk1)                                                                              // Execution (EX) Stage
        if (HALTED == 0)
        begin
            EX_MEM_type             <= #2 ID_EX_type;
            EX_MEM_IR               <= #2 ID_EX_IR;
            TAKEN_BRANCH            <= #2 0;

            case (ID_EX_type)
                RR_ALU:         begin
                                    case (ID_EX_IR[31:26])                                               // Op-Code
                                        ADD:        EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B; 
                                        SUB:        EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_B;
                                        AND:        EX_MEM_ALUout <= #2 ID_EX_A & ID_EX_B;
                                        OR:         EX_MEM_ALUout <= #2 ID_EX_A | ID_EX_B;
                                        SLT:        EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_B;
                                        MUL:        EX_MEM_ALUout <= #2 ID_EX_A * ID_EX_B;
                                        default:    EX_MEM_ALUout <= #2 32'hxxxxxxxx;
                                    endcase
                                end

                RM_ALU:         begin
                                    case (ID_EX_IR[31:26])                                               // Op-Code
                                        ADDI:       EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
                                        SUBI:       EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_Imm;
                                        SLTI:       EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_Imm;
                                        default:    EX_MEM_ALUout <= #2 32'hxxxxxxxx;
                                    endcase                    
                                end

                LOAD, STORE:    begin
                                    EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
                                    EX_MEM_B      <= #2 ID_EX_B;
                                end

                BRANCH:
                                begin
                                    EX_MEM_ALUout <= #2 ID_EX_NPC + ID_EX_Imm;
                                    EX_MEM_cond   <= #2 (ID_EX_A == 0);
                                end 
            endcase
          instr3 = EX_MEM_IR;
        end

    always @(posedge clk2)                                                                              // Memory (MEM) Stage
        if (HALTED == 0)
        begin
            MEM_WB_type             <= #2 EX_MEM_type;
            MEM_WB_IR               <= #2 EX_MEM_IR;

            case (EX_MEM_type)
                RR_ALU, RM_ALU:
                    MEM_WB_ALUout   <= #2 EX_MEM_ALUout;

                LOAD:
                    MEM_WB_LMD      <= #2 Mem[EX_MEM_ALUout];
                 
                STORE:                                                                                 // Disables Write
                    if (TAKEN_BRANCH == 0)                                                                     
                        Mem[EX_MEM_ALUout]  <= #2 EX_MEM_B;
            endcase
          instr4 = MEM_WB_IR;
        end

    always @(posedge clk1)                                                                             // Write Back (WB) Stage
        begin
            if (TAKEN_BRANCH == 0)                                                                     // Disables Write if branch is taken
                case (MEM_WB_type)
                    RR_ALU:     Reg[MEM_WB_IR[15:11]]   <= #2 MEM_WB_ALUout;                           // "rd"

                    RM_ALU:     Reg[MEM_WB_IR[20:16]]   <= #2 MEM_WB_ALUout;                           // "rt"

                    LOAD:       Reg[MEM_WB_IR[20:16]]   <= #2 MEM_WB_LMD;                              // "rt"

                    HALT:       HALTED                  <= #2 1'b1;     
                endcase
        end
 
    assign alu_result = MEM_WB_ALUout;
    assign mem_write = EX_MEM_cond;
  	assign pc = PC;
endmodule

// --------------------------------------------------
// Interface Definition
// --------------------------------------------------
interface mips_if();
  logic clk1;
  logic clk2;
  logic [31:0] instr1;
  logic [31:0] instr2;
  logic [31:0] instr3;
  logic [31:0] instr4;
  logic [31:0] pc;
  logic [31:0] alu_result;
  logic mem_write;
  logic run_monitor;
endinterface
