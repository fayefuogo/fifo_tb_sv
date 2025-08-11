# fifo_tb_sv

This project is a **SystemVerilog-based verification environment** for a synchronous FIFO design.  
It was developed as a learning exercise to explore **class-based verification**, **mailboxes**, and **self-checking testbenches**.

## Overview

The testbench is built using a modular verification architecture:

| Component   | Role |
|-------------|------|
| **transaction** | Encapsulates a single FIFO operation (read or write), including input/output data and FIFO status. Supports constrained randomization of operation type. |
| **generator**   | Creates randomized `transaction` objects and sends them to the driver. Controls the simulation sequence via events. |
| **driver**      | Drives FIFO interface signals to perform reads or writes based on transactions. |
| **monitor**     | Observes FIFO signals and records operations/data for later checking. |
| **scoreboard**  | Validates FIFO behavior by comparing expected data (tracked internally) with actual DUT output. Counts mismatches. |
| **environment** | Connects and coordinates the generator, driver, monitor, and scoreboard. |
| **tb**          | Top-level testbench instantiating the DUT (`FIFO`) and starting the environment. |

## Key Features
- **Constrained random stimulus** (`operation_ctrl` constraint for balanced read/write).
- **Mailboxes** for communication between verification components.
- **Self-checking** scoreboard that logs matches/mismatches.
- **Error counting** for automated pass/fail indication.
- **Separation of concerns** — easy to modify or extend.

## How It Works
1. **Generator** produces random read/write operations.
2. **Driver** applies those operations to the FIFO DUT.
3. **Monitor** observes DUT activity and captures transaction data.
4. **Scoreboard** compares DUT behavior to an internal model (queue-based).
5. **Environment** manages synchronization and test sequencing.

## Running the Simulation
- Requires a SystemVerilog-capable simulator (`iverilog`, `VCS`, `QuestaSim`, etc.).
- Compile all `.sv` files along with your FIFO DUT and `fifo_if` interface.
- Run the simulation; results will be printed to the console and saved in `dump.vcd` for waveform viewing.

## Notes
- Written for learning purposes; structure is educational but adaptable.
- Transaction count is set in the testbench:
  ```systemverilog
  env.gen.total = <N>;

