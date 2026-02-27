`ifndef ETHERNET_10G_BASE_TEST_SV
`define ETHERNET_10G_BASE_TEST_SV

class ethernet_10g_base_test extends uvm_test;
  `uvm_component_utils(ethernet_10g_base_test)
  
  function new(string name = "ethernet_10g_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
    
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  task run_phase();
  endtask
  
endclass

`endif
