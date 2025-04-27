// ============================================================
// test_mips32.sv (Top-level)
// ============================================================
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "mips_transaction.sv"
`include "mips_sequence.sv"
`include "mips_sequencer.sv"
`include "mips_driver.sv"
`include "mips_monitor.sv"
`include "mips_scoreboard.sv"
`include "mips_agent.sv"
`include "mips_env.sv"
`include "mips_test.sv"

module test_mips32;
  logic clk1, clk2;
  mips_if vif();

  // Clock generation
  initial begin
    clk1 = 0; 
    clk2 = 0;
    forever begin
      #5 clk1 = ~clk1;
      #5 clk2 = ~clk2;
    end
  end

  assign vif.clk1 = clk1;
  assign vif.clk2 = clk2;

 pipe_MIPS32 dut (
   .clk1(vif.clk1),
   .clk2(vif.clk2),
   .pc(vif.pc),
   .instr1(vif.instr1),
   .instr2(vif.instr2),
   .instr3(vif.instr3),
   .instr4(vif.instr4),
   .alu_result(vif.alu_result),
   .mem_write(vif.mem_write)
);
  
  initial begin
      $dumpfile("dump.vcd");
    $dumpvars;
    $dumpvars(0,test_mips32.dut.Mem[0]);
    end
  
    
  initial begin
    uvm_config_db#(virtual mips_if)::set(null, "*", "vif", vif);
    run_test("mips_test");
  end
endmodule
