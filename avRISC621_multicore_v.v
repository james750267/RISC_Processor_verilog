module avRISC621_multicore_v (Resetn_pin, Clock_pin, SW_pin, PB_pin, Display_pin);

	input	Resetn_pin, Clock_pin;
	// input I/OP
	input	[3:0] SW_pin;
	input PB_pin;
	// output I/OP
	output [7:0] Display_pin;
	
	wire [7:0] Master_out;
	wire M_ack; // input to master, output from slave core
	wire Request; // output from master, PB of slave core is used for request input
	
	wire S_M_data_Req; // slave send request to master before sending data to the master
	reg [9:0] S_M_Data;  // data send from slave to master after computation
	
	wire S_M_req0, S_M_req1, S_M_req2; // slave send request to master before sending data to the master
	wire S_ack0, S_ack1, S_ack2;
	wire Master_ack;
	
	wire [9:0] Slave0_out, Slave1_out, Slave2_out; // data output from slave cores
	//wire [1:0] Slave0_id, Slave1_id, Slave2_id;
	wire [1:0] Slave_id;
	
	// Master will send the data to all the salve cores at one time i.e. Broadcast communication to send the datat to slave cores
	// Master Broadcasts the data only when it receives Ack from all the slave cores
	assign Master_ack = (S_ack0 & S_ack1 & S_ack2);
	//assign Master_ack = (S_ack1); // debug comment it for multicore
	
	assign S_M_data_Req = (S_M_req0 | S_M_req1 | S_M_req2); // now master can send the data to slave

   //assign Slave_id = (Slave0_id | Slave0_id | Slave0_id); 
	
	avRISC621pipe_v master (Resetn_pin, Clock_pin, SW_pin, PB_pin, Master_ack, S_M_data_Req, S_M_Data, Request,  Master_out, Display_pin, Slave_id);
	
	avRISC621pipe_slave0_v slave0 (Resetn_pin, Clock_pin, Master_out[3:0], Request, S_M_req0, S_ack0, Slave0_out); 
	avRISC621pipe_slave1_v slave1 (Resetn_pin, Clock_pin, Master_out[3:0], Request, S_M_req1, S_ack1, Slave1_out);
	avRISC621pipe_slave2_v slave2 (Resetn_pin, Clock_pin, Master_out[3:0], Request, S_M_req2, S_ack2, Slave2_out);
	
	
	// Behavioral part of the code
	// Master core selects the data output from the slave core based on the slave core ID
//	always@(posedge Clock_pin)
//	begin
//	    if(Slave0_out[9:8] == 2'b00)
//		   S_M_Data = Slave0_out[7:0];
//			
//		else if(Slave1_out[9:8] == 2'b01)
//		    S_M_Data = Slave1_out[7:0];
//			 
//			 else if(Slave2_out[9:8] == 2'b10)
//		    S_M_Data = Slave2_out[7:0];
//		
//		else S_M_Data = 8'b00000000;
//		
//	end


	always@(posedge Clock_pin)
	begin
	    if(Slave_id == 2'b00)
		   S_M_Data = Slave0_out[7:0];
			
		else if(Slave_id == 2'b01)
		    S_M_Data = Slave1_out[7:0];
			 
			 else if(Slave_id == 2'b10)
		    S_M_Data = Slave2_out[7:0];
		
		else S_M_Data = 8'b00000000;
		
	end
	
endmodule