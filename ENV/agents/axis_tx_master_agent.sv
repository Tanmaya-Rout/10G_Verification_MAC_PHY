`ifndef AXIS_TX_MASTER_AGENT_SV
`define AXIS_TX_MASTER_AGENT_SV

class axis_tx_master_agent extends uvm_agent;
  `uvm_component_utils(axis_tx_master_agent)
  
  function new(string name = "axis_tx_master_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

 function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

 function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
 endfunction

endclass

`endif
