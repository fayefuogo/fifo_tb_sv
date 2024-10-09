class transaction;
  
  rand bit operation;
  bit read, write;
  bit [7:0] input_data;
  bit is_full, is_empty;
  bit [7:0] output_data;
  
  constraint operation_ctrl {  
    operation dist {1 :/ 50 , 0 :/ 50};
  }
  
endclass
///////////////////////////////////////////////////

class generator;
  
  transaction txn;           
  mailbox #(transaction) comm_box;  
  int total = 0;            
  int idx = 0;                
  
  event next_event;               
  event completion;               
   
  function new(mailbox #(transaction) comm_box);
    this.comm_box = comm_box;
    txn = new();
  endfunction; 
 
  task execute(); 
    repeat (total) begin
      assert (txn.randomize) else $error("Randomization failed");
      idx++;
      comm_box.put(txn);
      $display("[GEN] : Operation : %0d iteration : %0d", txn.operation, idx);
      @(next_event);
    end -> completion;
  endtask
  
endclass
////////////////////////////////////////////

class driver;
  
  virtual fifo_if fifo;     
  mailbox #(transaction) comm_box;  
  transaction trans_data;       

  function new(mailbox #(transaction) comm_box);
    this.comm_box = comm_box;
  endfunction; 
 
  task reset_dut();
    fifo.rst <= 1'b1;
    fifo.read <= 1'b0;
    fifo.write <= 1'b0;
    fifo.input_data <= 0;
    repeat (5) @(posedge fifo.clock);
    fifo.rst <= 1'b0;
    $display("[DRV] : DUT Reset Done");
    $display("------------------------------------------");
  endtask
   
  task send_data();
    @(posedge fifo.clock);
    fifo.rst <= 1'b0;
    fifo.read <= 1'b0;
    fifo.write <= 1'b1;
    fifo.input_data <= $urandom_range(1, 10);
    @(posedge fifo.clock);
    fifo.write <= 1'b0;
    $display("[DRV] : DATA WRITE  data : %0d", fifo.input_data);  
    @(posedge fifo.clock);
  endtask
  
  task receive_data();  
    @(posedge fifo.clock);
    fifo.rst <= 1'b0;
    fifo.read <= 1'b1;
    fifo.write <= 1'b0;
    @(posedge fifo.clock);
    fifo.read <= 1'b0;      
    $display("[DRV] : DATA READ");  
    @(posedge fifo.clock);
  endtask
  
  task execute();
    forever begin
      comm_box.get(trans_data);  
      if (trans_data.operation == 1'b1)
        send_data();
      else
        receive_data();
    end
  endtask
  
endclass
///////////////////////////////////////////////////////

class monitor;
 
  virtual fifo_if fifo;     
  mailbox #(transaction) comm_box;  
  transaction txn;          
  
  function new(mailbox #(transaction) comm_box);
    this.comm_box = comm_box;     
  endfunction;
 
  task execute();
    txn = new();
    
    forever begin
      repeat (2) @(posedge fifo.clock);
      txn.write = fifo.write;
      txn.read = fifo.read;
      txn.input_data = fifo.input_data;
      txn.is_full = fifo.is_full;
      txn.is_empty = fifo.is_empty; 
      @(posedge fifo.clock);
      txn.output_data = fifo.output_data;
    
      comm_box.put(txn);
      $display("[MON] : Write:%0d Read:%0d In:%0d Out:%0d Full:%0d Empty:%0d", txn.write, txn.read, txn.input_data, txn.output_data, txn.is_full, txn.is_empty);
    end
    
  endtask
  
endclass
/////////////////////////////////////////////////////

class scoreboard;
  
  mailbox #(transaction) comm_box;  
  transaction txn;          
  event next_event;
  bit [7:0] data_queue[$];       
  bit [7:0] temp_data;         
  int error_count = 0;           
  
  function new(mailbox #(transaction) comm_box);
    this.comm_box = comm_box;     
  endfunction;
 
  task execute();
    forever begin
      comm_box.get(txn);
      $display("[SCO] : Write:%0d Read:%0d In:%0d Out:%0d Full:%0d Empty:%0d", txn.write, txn.read, txn.input_data, txn.output_data, txn.is_full, txn.is_empty);
      
      if (txn.write == 1'b1) begin
        if (txn.is_full == 1'b0) begin
          data_queue.push_front(txn.input_data);
          $display("[SCO] : DATA QUEUED :%0d", txn.input_data);
        end
        else begin
          $display("[SCO] : FIFO is full");
        end
        $display("--------------------------------------"); 
      end
    
      if (txn.read == 1'b1) begin
        if (txn.is_empty == 1'b0) begin  
          temp_data = data_queue.pop_back();
          
          if (txn.output_data == temp_data)
            $display("[SCO] : DATA MATCH");
          else begin
            $error("[SCO] : DATA MISMATCH");
            error_count++;
          end
        end
        else begin
          $display("[SCO] : FIFO IS EMPTY");
        end
        
        $display("--------------------------------------"); 
      end
      
      -> next_event;
    end
  endtask
  
endclass
///////////////////////////////////////////////////////

class environment;
 
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) driver_mailbox;  
  mailbox #(transaction) monitor_mailbox;  
  event next_gen_sco;
  virtual fifo_if fifo;
  
  function new(virtual fifo_if fifo);
    driver_mailbox = new();
    gen = new(driver_mailbox);
    drv = new(driver_mailbox);
    monitor_mailbox = new();
    mon = new(monitor_mailbox);
    sco = new(monitor_mailbox);
    this.fifo = fifo;
    drv.fifo = this.fifo;
    mon.fifo = this.fifo;
    gen.next_event = next_gen_sco;
    sco.next_event = next_gen_sco;
  endfunction
  
  task setup();
    drv.reset_dut();
  endtask
  
  task execute();
    fork
      gen.execute();
      drv.execute();
      mon.execute();
      sco.execute();
    join_any
  endtask
  
  task finalize();
    wait(gen.completion.triggered);  
    $display("---------------------------------------------");
    $display("Error Count :%0d", sco.error_count);
    $display("---------------------------------------------");
    $finish();
  endtask
  
  task run();
    setup();
    execute();
    finalize();
  endtask
  
endclass
///////////////////////////////////////////////////////

module tb;
    
  fifo_if fifo();
  FIFO dut (fifo.clock, fifo.rst, fifo.write, fifo.read, fifo.input_data, fifo.output_data, fifo.is_empty, fifo.is_full);
    
  initial begin
    fifo.clock <= 0;
  end
    
  always #10 fifo.clock <= ~fifo.clock;
    
  environment env;
    
  initial begin
    env = new(fifo);
    env.gen.total = 10;
    env.run();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
   
endmodule
