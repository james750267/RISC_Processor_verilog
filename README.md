# Multicore RISC Processor with 2-Way Set Associative Cache Memory
- Implemented a 4-core RISC Processor using Verilog HDL
- Designed a communication protocol between master and slave cores
- Evaluated the performance of the processor by performing matrix multiplication
- Emulated the working of processor on FPGA board for matrix multiplication
- Compared the performance of multicore and single-core processor for matrix multiplication benchmark

# 4-Core processor and communication protocol:
The processor is instantiated three times as Slave cores and the main processor is called the Master core. Master core has the access to the input and output peripherals of the FPGA board.

Master distributes the given task to the other three slave cores and when they are done they send the result back to the Master core.

## Master to Slave:

![m2s_protocol](https://user-images.githubusercontent.com/13079690/51195413-01396380-18bb-11e9-84ea-18cb68fd2a75.png)

- The Master first sends a request signal to the slave core before it can send any data and then waits for an acknowledgement form the slave core
- Once an acknowledgement is received by the Master it sends the data along with a valid signal
- The Slave core first checks for the valid signal from the Master to ensure that the data is valid and then it can store the data send by the Master.
- After Slave core has received the data it sends an acknowledgement to the Master core indicating successful reception of the data.

The above protocol is repeated till the Master has data to send to the Slave cores.

In my design the data from the Master can be send to all the Slave cores at one time i.e. the Master to Slave communication is broadcast in nature.

## Slave to Master:

![s2m_protocol](https://user-images.githubusercontent.com/13079690/51195436-0eeee900-18bb-11e9-9a4d-f1ea2a409c38.png)

- The Master core first sends the slave ID from which it wants to receive the data from. 
- The Slave core that matches the ID sends a request to Master to indicate that it is ready to send the data
- Master after receiving the request from the slave core sends an acknowledgement to the slave core that it is ready to receive the data
- The Slave after receiving the acknowledgement from the Master sends the data along with the valid signal
- The Master first checks if the data is valid and then it stores the data that was sent by the slave core
- The Master send an acknowledgement to Slave to indicate that it has successfully received the data
- The above protocol is repeated till the Master has received all the data from the slave core
- After Master has received the data it can then set the slave ID for the next slave it wants the data from. The above protocol is repeated again.
