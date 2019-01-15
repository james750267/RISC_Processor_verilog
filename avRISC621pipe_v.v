module avRISC621pipe_v (Resetn_pin, Clock_pin, SW_pin, PB_pin, Ack_in, Slave2Master_data_req, Slave2Master_DataIn, Req_out, Display_pin, LED_data_out,Slave_id);

input	Resetn_pin, Clock_pin;
	input [3:0] SW_pin;
	input PB_pin;
	output reg[7:0] Display_pin;  // used to send data to slave cores
	
	output reg [1:0] Slave_id;
	
	// for lab 11 handshake protocol betwen mastewr and slave
	input Ack_in; // I receive it from slave core
	output reg Req_out;  // input to slave for. I uses logic 0 as request 
	
	// for lab-12
	input Slave2Master_data_req; // slave send this befor sending its data
	input [7:0] Slave2Master_DataIn; // data in from slave to master
	
	output reg[7:0] LED_data_out; // to display result on LED
	
	// performance counter
	reg [13:0] counter;
	reg cnt_flag;
	reg [13:0] cnt_result;
	
//----------------------------------------------------------------------------
//-- Declare machine cycle and instruction cycle parameters
//----------------------------------------------------------------------------
parameter [5:0] SUB_IC = 6'b000000, ADD_IC = 6'b000001, ADDC_IC = 6'h2, SUBC_IC=6'b000011,
	CPY_IC = 6'h4, SWAP_IC = 6'h5, MUL_IC = 6'b000110, DIV_IC = 6'b000111,
	NOT_IC = 6'b001000, AND_IC = 6'b001001, OR_IC = 6'b001010, XOR_IC = 6'b001011, SHRL_IC = 6'b001111,
	SHRA_IC = 6'b001100, ROTL_IC = 6'b001101, ROTR_IC = 6'b001110, RLN_IC = 6'b010000,
	RLZ_IC = 6'b010010, RRC_IC = 6'b010001, RRV_IC = 6'b010011,JMP_IC = 6'h22 , LD_IC = 6'h14, 
	ST_IC = 6'h15, CALL_IC = 6'h20, RET_IC = 6'h21, ADDV_IC = 6'h23, SUBV_IC = 6'h24;
	
	parameter START_CNTR = 6'h25, STOP_CNTR = 6'h26;
	
	parameter [3:0] J_Un = 4'h0, JC = 4'b1000, JN = 4'b0100, JV = 4'b0010, JZ = 4'b0001, 
	JC0 = 4'b0111, JN0 = 4'b1011, JV0 = 4'b1101, JZ0 = 4'b1110;

//----------------------------------------------------------------------------
//-- Declare internal signals
//----------------------------------------------------------------------------
	reg [13:0] R [15:0];  // 14-bit wide, 16 registers
	reg	WR_DM, stall_mc0, stall_mc1, stall_mc2, stall_mc3;
	reg [13:0] PC, IR3, IR2, IR1, DM_in;
	reg [13:0] TA, TB, TALUH, TALUL;
	reg [11:0] TSR, SR;
	reg [14:0]	TALUout;
	wire [13:0]	DM_out;
	wire 			C, Clock_not;
	integer Ri1, Rj1, Ri2, Rj2, Ri3, Rj3;
	reg [13:0] MM_A; // declared it for von neumann ram memory
	   wire [27:0]result_mul ;
	wire [13:0] result_quotient, result_remainder;
	
	reg [13:0] MAB, MAX, MAeff, SP;
	reg [13:0] OPDR, IPDR;
	integer i;
	
	reg[6:0] TA1, TA2, TB1,TB2;
	reg [6:0] TALUout1,TALUout2;
	
	wire cout_1, cout_2, ovfl_1, ovfl_2;
	wire [6:0] result_add1,result_add2;
	wire cout_1_sub, cout_2_sub, ovfl_1_sub, ovfl_2_sub;
	wire [6:0] result_sub1,result_sub2;

	//assign	Clock_not = ~Clock_pin;	

	wire Done;
wire c0,c1,c2;

// PLL at top level, removed it from cache
av_pll_3_v	my_pll 	(Clock_pin, c0, c1, c2);

// RAM instance
//avRISC621_ram1	av_ram	(MM_A[9:0], Clock_not, DM_in, WR_DM, DM_out);	

av_cache_2w_v mem_sys (.Resetn(Resetn_pin), .MEM_address(MM_A[11:0]), .MEM_in(DM_in), .WR(WR_DM), .c0(c0), .c1(c1), .c2(c2), .MEM_out(DM_out), .Done(Done));

// instantiate my multiplier using IP Block
av_MULT av_mult (TA, TB, result_mul);
av_DIV av_div (TB, TA, result_quotient, result_remainder);

// ADD, SUB for SIMD
av_ADDV addv1 (TA1, TB1, cout_1, ovfl_1, result_add1);
av_ADDV addv2 (TA2, TB2, cout_2, ovfl_2, result_add2);

av_SUBV subv1 (TA1, TB1, cout_1_sub, ovfl_1_sub, result_sub1);
av_SUBV subv2 (TA2, TB2, cout_2_sub, ovfl_2_sub, result_sub2);

assign Clock_not = c0;
//------------------------------Code Starts From Here -------------------------------------------------//

always@(posedge Clock_not)
begin
	if(Resetn_pin == 1'b0)
	begin
			PC = 14'h0;
			MM_A = PC;
		// initialize all my registers in RF //
			for(i = 0; i <16; i=i+1)
			begin
				R[i] = 14'h0;
			end
			WR_DM = 1'b0;
			SP = 14'h3FEF;
			DM_in = 14'h0;
			MM_A = 14'h0;
			TA = 14'h0;
			TB = 14'h0;
			TALUL = 14'h0;
			TALUH = 14'h0;
			TSR = 12'h0;
			SR = 12'h0;
			TALUout = 15'h0;
			MAB = 14'h0;
			MAX = 14'h0;
			MAeff = 14'h0;
			i = 0;
//			R[5] = 14'h100;
//			R[6] = 14'h100;
//			R[7] = 14'h100;
//			R[8] = 14'h100;
//			R[9] = 14'h1830;
//			R[12] = 14'h1020;
			Display_pin = 8'h00; // decimal 256
// 	startup of the pipeline. only mc0 is not stalled at startup
			stall_mc0 = 0; stall_mc1 = 1; stall_mc2 = 1; stall_mc3 = 1;
// All IRs are initialized to the "don't care OpCode value 0x3fff
			IR1 = 14'h3fff; IR2 = 14'h3fff; IR3 = 14'h3fff;
			LED_data_out = 8'b00000000;
			// lab-11
			Req_out = 1'b1;
			counter = 14'b00000000000000;
			cnt_result = 14'b00000000000000;
			cnt_flag = 1'b0;
			
			Slave_id = 2'b11;
	end

	else
	begin
	
	if (cnt_flag == 1'b1)
	  counter = counter + 1;
	
	
	if(Done == 0)
	begin
	    PC = PC;
		 MM_A = MM_A;
	end
	
	else begin
//----------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------MC3----------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//

// mc3 is executed first,as its assignments might be needed by MC2 or MC1, this resolves Data or Control D/H
		if(stall_mc3 == 1'b0)
		begin
			case(IR3[13:8])
			
			START_CNTR:  begin
									
									cnt_flag = 1'b1;
		
						  end
		
		
		STOP_CNTR:  begin
									
									cnt_flag = 1'b0;
									cnt_result = counter;
		
						  end
			
			
			
			ADDV_IC, SUBV_IC:
			begin
			    R[Ri3] = TALUH;
				 SR = TSR;
			end
			
LD_IC:
	begin 
			if(MAeff == 14'h3FFD) begin
				IPDR = {9'h000, SW_pin};
				R[Rj3] = IPDR;
				end
			else if(MAeff == 14'h3FFC) begin
				IPDR = {13'h000, PB_pin};
				R[Rj3] = IPDR;
			end
			// for lab-11
			else if (MAeff == 14'h3FFB) begin  // Ack_in
			   IPDR = {13'b0000000000000, Ack_in};
				R[Rj3] = IPDR;
			end
			// for lab-12
			else if (MAeff == 14'h3FF6)
				 R[Rj3] = Slave2Master_DataIn;
			else if (MAeff == 14'h3FF7)
				R[Rj3] = {13'b0000000000000, Slave2Master_data_req};
				
				else if (MAeff == 14'h3FF2) // counter result for performance
				R[Rj3] = {cnt_result};
			
			else if(MAeff == 14'h3FFF)
				R[Rj3] = SP;
			else
				R[Rj3] = DM_out;
		MM_A = PC;
		end
		
	ST_IC:
		begin
			WR_DM = 0;
			MM_A = PC;
		end 
		
	JMP_IC:
		begin
			case(IR3[3:0])
				J_Un:
					begin
						PC = MAeff;
						MM_A = PC;
					end
				JC:
					begin
						if(SR[11] == 1) begin
							PC = MAeff;
							MM_A = PC;
						end
							
						else begin
							//PC =PC+1;
							MM_A = PC;
							end
						
					end
				JN:
					begin
						if(SR[10] == 1) begin
							PC = MAeff;
							MM_A = PC;
						end
						else begin
							//PC =PC+1;
							MM_A = PC;
							end
						
					end
				JV:
					begin
						if(SR[9] == 1) begin
							PC = MAeff;
							MM_A = PC;
						end
						else begin
							//PC =PC+1;
							MM_A = PC;
							end
						
					end
				JZ:
					begin
						if(SR[8] == 1) begin
							PC = MAeff;
							MM_A = PC;
						end
						else begin
							//PC =PC+1;
							MM_A = PC;
							end
						
					end
				JC0:
					begin
						if(SR[11] == 0) begin
							PC = MAeff;
							MM_A = PC;
						end
						else begin
						//	PC =PC+1;
							MM_A = PC;
							end
							
					end
				JN0:
					begin
						if(SR[10] == 0) begin
							PC = MAeff;
							MM_A = PC;
						end
						else begin
							//PC =PC+1;
							MM_A = PC;
							end
							
					end
				JV0:
					begin
						if(SR[9] == 0) begin
							PC = MAeff;
							MM_A = PC;
						end
						else begin
							//PC =PC+1;
							MM_A = PC;
							end	
						
					end
				JZ0:
					begin
						if(SR[8] == 0) begin
							PC = MAeff;
							MM_A = PC;
						end
						else begin
							//PC =PC+1;
							MM_A = PC;
							end
							
					end
				default: PC = PC;
			endcase
		end
		
	CALL_IC:
		begin
		  // MM_A = SP; // we need to next MM location pointed by SP to save PC in MC3
			//DM_in = SR;
			WR_DM = 1'b0;
			PC = MAeff;
			MM_A = MAeff;
		end
	
	RET_IC:
		begin
			PC = DM_out;
			SP = SP + 1'b1;
			MM_A = PC;
		end
			
			
	ADD_IC, SUB_IC, ADDC_IC, SUBC_IC, SHRL_IC, SHRA_IC, ROTL_IC, ROTR_IC,RLN_IC,RLZ_IC, RRC_IC, RRV_IC, NOT_IC, AND_IC, OR_IC, XOR_IC:
			begin
				R[Ri3] = TALUH;
				SR = TSR;
			end 
	MUL_IC, DIV_IC:
			begin
				R[Ri3] = TALUH;
				R[Rj3] = TALUL;
				SR = TSR;
			end
	
	CPY_IC:
		begin
			R[Ri3] = TALUL; 
		end 
	SWAP_IC:
		begin
			R[Rj3] = TALUH;
			R[Ri3] = TALUL;
		end 
	
			default: ;
			endcase
		end

//----------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------MC2----------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//

// mc2 is executed second
		if(stall_mc2 == 1'b0)
		begin
			case(IR2[13:8])
			
			
			START_CNTR:  begin
									
									cnt_flag = 1'b1;
		
						  end
		
		
		STOP_CNTR:  begin
									
									cnt_flag = 1'b0;
									//cnt_result = counter;
		
						  end
			
			SUBV_IC:
			begin
			  	TALUout1 = result_sub1;
				TALUout2 = result_sub2;
				
				TSR[7] = cout_1_sub; // Carry
				TSR[6] = TALUout[6]; // Negative
				TSR[5] = ovfl_1_sub; // V Overflow
					if (TALUout1[6:0] == 6'h0)
						TSR[4] = 1;	// Zero
					else
						TSR[4] = 0;
				
				TSR[3] = cout_2_sub; // Carry
				TSR[2] = TALUout2[6]; // Negative
				TSR[1] = ovfl_2_sub; // V Overflow
					if (TALUout2[6:0] == 6'h0)
						TSR[0] = 1;	// Zero
					else
						TSR[0] = 0;
						
						
				TALUH = {TALUout1[6:0],TALUout2[6:0]};  
			
			end
			
			
			
			ADDV_IC:
			begin
			  	TALUout1 = result_add1;
				TALUout2 = result_add2;
				
				TSR[7] = cout_1; // Carry
				TSR[6] = TALUout[6]; // Negative
				TSR[5] = ovfl_1; // V Overflow
					if (TALUout1[6:0] == 6'h0)
						TSR[4] = 1;	// Zero
					else
						TSR[4] = 0;
				
				TSR[3] = cout_2; // Carry
				TSR[2] = TALUout2[6]; // Negative
				TSR[1] = ovfl_2; // V Overflow
					if (TALUout2[6:0] == 6'h0)
						TSR[0] = 1;	// Zero
					else
						TSR[0] = 0;
						
						
				TALUH = {TALUout1[6:0],TALUout2[6:0]};  
			
			end
			
	LD_IC:
		begin
				WR_DM = 1'b0; // for Load write should be disabled, as we load from the memory
				MAeff = MAB + MAX;
				MM_A = MAeff;
			//MM_A = PC;
		
		end

	ST_IC:
		begin
			MAeff = MAB + MAX;
			
			if(MAeff[13:4] != 12'h3FF)
			begin
						MM_A = MAeff;
						WR_DM = 1'b1; //we write (store) in memory
						
							if(IR3[13:8] == SWAP_IC) begin  // swapy df
								if (Rj2 == Rj3)
									DM_in = R[Rj3];
								else if (Rj2 == Ri3)
									DM_in = R[Ri3];
								else DM_in = R[Rj2];
							end
						
							else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin // mul div df
								if (Rj2 == Rj3)
									DM_in = R[Rj3];
								else if (Rj2 == Ri3)
									DM_in = R[Ri3];
								else DM_in = R[Rj2];
							end
							
							else if(IR3[13:8] == CPY_IC) begin
								if(Rj2 == Ri3)
									DM_in = R[Ri3];
								else DM_in = R[Rj2];
							end
						
							else if(Rj2 == Ri3 && IR3[13:8] != (LD_IC || ST_IC || JMP_IC || CALL_IC || RET_IC || SWAP_IC || CPY_IC || MUL_IC || DIV_IC))
							begin
								DM_in = R[Ri3];
							end
							
					else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				         DM_in = R[Rj2];
				         //TB = R[Rj1];	  
	              end
							
							else DM_in = R[Rj2];
			end
			
			else begin
					WR_DM = 1'b0; // we store(write) in output peripheral not in memory
					//MM_A = PC;
							if(MAeff == 14'h3FFE) begin
							
										if(IR3[13:8] == SWAP_IC) begin  // swapy df
											if (Rj2 == Rj3)
												OPDR = R[Rj3];
											else if (Rj2 == Ri3)
												OPDR = R[Ri3];
											else OPDR = R[Rj2];
										end
									
										else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin // mul div df
											if (Rj2 == Rj3)
												OPDR = R[Rj3];
											else if (Rj2 == Ri3)
												OPDR = R[Ri3];
											else OPDR = R[Rj2];
										end
									
										else if(IR3[13:8] == CPY_IC) begin
											if(Rj2 == Ri3)
												OPDR = R[Ri3];
											else OPDR = R[Rj2];
										end
									
										else if(Rj2 == Ri3 && IR3[13:8] != (LD_IC || ST_IC || JMP_IC || CALL_IC || RET_IC || SWAP_IC || CPY_IC || MUL_IC || DIV_IC))
										begin
											OPDR = R[Ri3];
										end
										
										
					else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				         OPDR = R[Rj2];
				         //TB = R[Rj1];	  
	              end
								
										else OPDR = R[Rj2];
									Display_pin = OPDR[7:0];	
						            
                     end
//						
//						Display_pin = OPDR[7:0];
//			
						else if(MAeff == 14'h3FFF)
						begin
										if(IR3[13:8] == SWAP_IC) begin  // swap df
											if (Rj2 == Rj3)
											SP = R[Rj3];
										else if (Rj2 == Ri3)
											SP = R[Ri3];
										else SP = R[Rj2];
										end
								
									else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin // mul div df
										if (Rj2 == Rj3)
											SP = R[Rj3];
										else if (Rj2 == Ri3)
											SP = R[Ri3];
										else SP = R[Rj2];
								  end
									
										else if(IR3[13:8] == CPY_IC) begin
											if(Rj2 == Ri3)
										SP = R[Ri3];
										else SP = R[Rj2];
									end
							
									else if(Rj2 == Ri3 && IR3[13:8] != (LD_IC || ST_IC || JMP_IC || CALL_IC || RET_IC || SWAP_IC || CPY_IC || MUL_IC || DIV_IC))
										begin
										SP = R[Ri3];
										end
									else SP = R[Rj2];
						end
									
						else if(MAeff == 14'h3FFA) // for Req_out to slave core
						begin
										if(IR3[13:8] == SWAP_IC) begin  // swap df
											if (Rj2 == Rj3)
											Req_out = R[Rj3][0];
										else if (Rj2 == Ri3)
											Req_out = R[Ri3][0];
										else Req_out = R[Rj2][0];
										end
								
									else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin // mul div df
										if (Rj2 == Rj3)
											Req_out = R[Rj3][0];
										else if (Rj2 == Ri3)
											Req_out = R[Ri3][0];
										else Req_out = R[Rj2][0];
								  end
									
										else if(IR3[13:8] == CPY_IC) begin
											if(Rj2 == Ri3)
										Req_out = R[Ri3][0];
										else Req_out = R[Rj2][0];
									end
							
									else if(Rj2 == Ri3 && IR3[13:8] != (LD_IC || ST_IC || JMP_IC || CALL_IC || RET_IC || SWAP_IC || CPY_IC || MUL_IC || DIV_IC))
										begin
										Req_out = R[Ri3][0];
										end
										
								  else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				                   Req_out = R[Rj2][0];
				         //TB = R[Rj1];	  
	                           end
									else Req_out = R[Rj2][0];
									
									
					    end
						 
						 else if(MAeff == 14'h3FF1) // for Slave_id to slave core
						begin
										if(IR3[13:8] == SWAP_IC) begin  // swap df
											if (Rj2 == Rj3)
											Slave_id = R[Rj3][1:0];
										else if (Rj2 == Ri3)
											Slave_id = R[Ri3][1:0];
										else Slave_id = R[Rj2][1:0];
										end
								
									else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin // mul div df
										if (Rj2 == Rj3)
											Slave_id = R[Rj3][1:0];
										else if (Rj2 == Ri3)
											Slave_id = R[Ri3][1:0];
										else Slave_id = R[Rj2][1:0];
								  end
									
										else if(IR3[13:8] == CPY_IC) begin
											if(Rj2 == Ri3)
										Slave_id = R[Ri3][1:0];
										else Slave_id = R[Rj2][1:0];
									end
							
									else if(Rj2 == Ri3 && IR3[13:8] != (LD_IC || ST_IC || JMP_IC || CALL_IC || RET_IC || SWAP_IC || CPY_IC || MUL_IC || DIV_IC))
										begin
										Slave_id = R[Ri3][1:0];
										end
										
								  else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				                   Slave_id = R[Rj2][1:0];
				         //TB = R[Rj1];	  
	                           end
									else Slave_id = R[Rj2][1:0];
									
									
					    end
						 
						 
						 else if(MAeff == 14'h3FF9) // for Req_out to slave core
						begin
										if(IR3[13:8] == SWAP_IC) begin  // swap df
											if (Rj2 == Rj3)
											LED_data_out = R[Rj3][7:0];
										else if (Rj2 == Ri3)
											LED_data_out = R[Ri3][7:0];
										else LED_data_out = R[Rj2][7:0];
										end
								
									else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin // mul div df
										if (Rj2 == Rj3)
											LED_data_out = R[Rj3][7:0];
										else if (Rj2 == Ri3)
											LED_data_out = R[Ri3][7:0];
										else LED_data_out = R[Rj2][7:0];
								  end
									
										else if(IR3[13:8] == CPY_IC) begin
											if(Rj2 == Ri3)
										LED_data_out = R[Ri3][7:0];
										else LED_data_out = R[Rj2][7:0];
									end
							
									else if(Rj2 == Ri3 && IR3[13:8] != (LD_IC || ST_IC || JMP_IC || CALL_IC || RET_IC || SWAP_IC || CPY_IC || MUL_IC || DIV_IC))
										begin
										LED_data_out = R[Ri3][7:0];
										end
										
								  else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				                   LED_data_out = R[Rj2][7:0];
				         //TB = R[Rj1];	  
	                           end
									else LED_data_out = R[Rj2][7:0];
									
									
					    end
						 
						 
					
				end//end else
			
		end
		
	JMP_IC:
		begin
			MAeff = MAB + MAX;
		end
		
	CALL_IC:
		begin
			//WR_DM = 1'b1;
			//DM_in = PC;
			MAeff = MAB + MAX;
			SP = SP -1'b1;
			MM_A = SP; // we need to next MM location pointed by SP to save PC in MC3
			DM_in = SR;
		end
		
	RET_IC:
		begin
			SP = SP + 1'b1;
			MM_A = SP;
			//PC = DM_out;
		//	SP = SP + 1'b1;
		end
			
			
	CPY_IC:
		begin
			TALUL = TB;
		end 
	SWAP_IC:
		begin
			TALUH = TA;
			TALUL = TB;
		end 
			
			
		MUL_IC:
			begin
				TALUH = result_mul[27:14];
				TALUL = result_mul[13:0];
				
				TSR[10] = result_mul[27]; // NEGATIVE
				
					if (result_mul == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0;
			end
		DIV_IC:
			begin
				TALUH = result_quotient;
				TALUL = result_remainder;
				
				//TSR[10] = result_div[27]; // NEGATIVE
				
					if (result_quotient == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0;
			end
		ADD_IC, ADDC_IC:
			begin
				TALUout = TA + TB;
				TSR[11] = TALUout[14]; // Carry
				TSR[10] = TALUout[13]; // Negative
				TSR[9] = ((TA[13] ~^ TB[13]) & TA[13]) ^ (TALUout[13] & (TA[13] ~^ TB[13])); // V Overflow
					if (TALUout[13:0] == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0;
					TALUH = TALUout[13:0];
			end
		SUB_IC, SUBC_IC:
			begin
				TALUout = TA - TB;
				TSR[11] = TALUout[14]; // Carry
				TSR[10] = TALUout[13]; // Negative
				TSR[9] = ((TA[13] ~^ TB[13]) & TA[13]) ^ (TALUout[13] & (TA[13] ~^ TB[13])); // V Overflow
					if (TALUout[13:0] == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0;
				TALUH = TALUout[13:0];
			end
		NOT_IC:
			begin
				TALUH = ~TA;
				TSR[10] = TALUH[13]; // Negative
					if (TALUH[13:0] == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0;
			end
		AND_IC:
			begin
				TALUH = TA & TB;
				TSR[10] = TALUH[13]; // Negative
					if (TALUH[13:0] == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0;
			end
		
		OR_IC:
			begin
				TALUH = TA | TB;
				TSR[10] = TALUH[13]; // Negative
					if (TALUH[13:0] == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0; 
			end
		
		XOR_IC:
			begin
				TALUH = TA ^ TB;
				TSR[10] = TALUH[13]; // Negative
					if (TALUH[13:0] == 14'h0)
						TSR[8] = 1;	// Zero
					else
						TSR[8] = 0;
			end
		SHRL_IC:
			begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end 
					4'b0001:
						begin
							TALUH = {1'b0,TA[13:1]};
						end 
					4'b0010:
						begin
							TALUH = {2'b00,TA[13:2]};
						end 
					4'b0011:
						begin
							TALUH = {3'b000,TA[13:3]};
						end
					default: TALUH = TA;
				endcase 	
			end 
		SHRA_IC:
			begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end
					4'b0001:
						begin
							TALUH = {TA[13],TA[13:1]};
						end
					4'b0010:
						begin
							TALUH = {TA[13],TA[13],TA[13:2]};
						end
						4'b0011:
						begin
							TALUH = {TA[13],TA[13],TA[13],TA[13:3]};
						end
						default: TALUH = TA;
				endcase 	
			end
			
		ROTR_IC:
			begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end
					4'b0001:
						begin
							TALUH = {TA[0],TA[13:1]};
						end
					4'b0010:
						begin
							TALUH = {TA[1],TA[0],TA[13:2]};
						end
						4'b0011:
						begin
							TALUH = {TA[2],TA[1],TA[0],TA[13:3]};
						end
						default: TALUH = TA;
				endcase 	
			end
		
		ROTL_IC:
			begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end
					4'b0001:
						begin
							TALUH = {TA[12:0], TA[13]};
						end
					4'b0010:
						begin
							TALUH = {TA[11:0], TA[13], TA[12]};
						end
						4'b0011:
						begin
							TALUH = {TA[10:0], TA[13], TA[12], TA[11]};
						end
						default: TALUH = TA;
				endcase 	
			end
		
		RLN_IC:
			begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end
					4'b0001:
						begin
							TALUH = {TA[12:0], TSR[10]};
							TSR[10] = TA[13];
						end
					4'b0010:
						begin
							TALUH = {TA[11:0], TSR[10], TA[13]};
							TSR[10] = TA[12];
						end
						4'b0011:
						begin
							TALUH = {TA[10:0], TSR[10], TA[13], TA[12]};
							TSR[10] = TA[11];
						end
						default: TALUH = TA;
				endcase 	
			end
		
		RLZ_IC:
			begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end
					4'b0001:
						begin
							TALUH = {TA[12:0], TSR[8]};
							TSR[8] = TA[13];
						end
					4'b0010:
						begin
							TALUH = {TA[11:0], TSR[8], TA[13]};
							TSR[8] = TA[12];
						end
						4'b0011:
						begin
							TALUH = {TA[10:0], TSR[8], TA[13], TA[12]};
							TSR[8] = TA[11];
						end
						default: TALUH = TA;
				endcase 	
			end
		
		RRC_IC:
			begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end
					4'b0001:
						begin
							TALUH = {TSR[11], TA[13:1]};
							TSR[11] = TA[0];
						end
					4'b0010:
						begin
							TALUH = {TA[0], TSR[11], TA[13:2]};
							TSR[11] = TA[1];
						end
						4'b0011:
						begin
							TALUH = {TA[1], TA[0], TSR[11], TA[13:3]};
							TSR[11] = TA[2];
						end
						default: TALUH = TA;
				endcase 	
			end
			
			RRV_IC:
				begin
				case(IR2[3:0])
					4'b0000:
						begin
							TALUH = TA;
						end
					4'b0001:
						begin
							TALUH = {TSR[9], TA[13:1]};
							TSR[9] = TA[0];
						end
					4'b0010:
						begin
							TALUH = {TA[0], TSR[9], TA[13:2]};
							TSR[9] = TA[1];
						end
						4'b0011:
						begin
							TALUH = {TA[1], TA[0], TSR[9], TA[13:3]};
							TSR[9] = TA[2];
						end
						default: TALUH = TA;
				endcase 	
			end
			
			default: ;
			endcase
		end


//#########################################################################################################################//
//---------------------------------------------------MC1-------------------------------------------------------------------//
//#########################################################################################################################//

// mc1 is executed third
		if(stall_mc1 == 1'b0)
		begin	
			case(IR1[13:8])
			
			
			START_CNTR:  begin
									
									cnt_flag = 1'b1;
		
						  end
		
		
		STOP_CNTR:  begin
									
									cnt_flag = 1'b0;
									//cnt_result = counter;
		
						  end
			
			ADDV_IC, SUBV_IC:
			begin
				if(IR2[13:8] == CPY_IC) begin
					if(Ri1 == Ri2) begin
						TA1 = TALUL[13:7];
						TA2 = TALUL[6:0];
					end
					else begin
					  TA = R[Ri1];
					  TA1 = TA[13:7];
					  TA2 = TA[6:0];
					end
					
				if(Rj1 == Ri2) begin
					TB1 = TALUL[13:7];
					TB1 = TALUL[6:0];
				end 
				else begin 
				  TB = R[Rj1];
				  TB1 = TB[13:7];
				  TB1 = TB[6:0];
				end  
			end
		
		
			else if(IR2[13:8] == SWAP_IC) begin
				if(Ri1 == Ri2) begin
					TA1 = TALUL[13:7];
					TA2 = TALUL[6:0];
				end
				else if(Ri1 == Rj2) begin
				TA1 = TALUH[13:7];
				TA2 = TALUH[6:0];
				end
				else begin
				TA = R[Ri1];
				TA1 = TA[13:7];
				TA2 = TA[6:0];
				end
				
				if(Rj1 == Ri2) begin
				TB1 = TALUL[13:7];
				TB2 = TALUL[6:0];
				end
				else if(Rj1 == Rj2) begin
				TB1 = TALUH[13:7];
				TB2 = TALUH[6:0];
				end
				else begin
				TB = R[Rj1];
				TB1 = TB[13:7];
				TB2 = TB[6:0];
	         end			
	      end 
		
		
			else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin
				if(Ri1 == Ri2) begin
				TA1 = TALUH[13:7];
				TA2 = TALUH[6:0];
				end
				else if(Ri1 == Rj2) begin
				TA1 = TALUL[13:7];
				TA2 = TALUL[6:0];
				end
				else begin
				TA = R[Ri1];
				TA1 = TA[13:7];
				TA2 = TA[6:0];
				end
				
				if(Rj1 == Ri2) begin
				TB1 = TALUH[13:7];
				TB2 = TALUH[6:0];
				end
				else if(Rj1 == Rj2) begin
				TB1 = TALUL[13:7];
				TB2 = TALUL[6:0];
				end
				else begin
				TB = R[Rj1];
				TB1 = TB[13:7];
				TB2 = TB[6:0];
	         end			
	      end
			
		else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				TA = R[Ri1];
				TA1 = TA[13:7];
				TA2 = TA[6:0];
				TB = R[Rj1];
				TB1 = TB[13:7];
				TB2 = TB[6:0];			
	    end
		
		   else begin
		  	  if(Ri1 == Ri2)begin
				  TA1 = TALUH[13:7];
				  TA2 = TALUH[6:0];
			  end
			  else begin
				  TA = R[Ri1];
				  TA1 = TA[13:7];
				  TA2 = TA[6:0];
			  end
			  if(Rj1 == Ri2)begin
             TB1 = TALUH[13:7];
				 TB2 = TALUH[6:0];
			  end
			  else begin
				  TB = R[Rj1];
				  TB1 = TB[13:7];
				  TB2 = TB[6:0];
			  end
		  end	
			
    end // end ADDV
			
	LD_IC, ST_IC, JMP_IC:
		begin
			MAB = DM_out; // this is IW1
			//MAB = IR1;
			if (Ri1 == 0)  // for MAB we take Ri from MC0 from IW0
				MAX = 0;
			else if (Ri1 == 1)
				MAX = PC;
			else if (Ri1 == 2)
				MAX = SP;
			else begin // Data forwarding for Ri1 if needed
					if(IR2[13:8] == CPY_IC) begin
						if(Ri1 == Ri2)
							MAX = TALUL;
						else MAX = R[Ri1];	  
				   end
			
			
					else if(IR2[13:8] == SWAP_IC) begin
						if(Ri1 == Ri2)
						MAX = TALUL;
						else if(Ri1 == Rj2)
						MAX = TALUH;
						else MAX = R[Ri1];	  
					end	

			      else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin
						if(Ri1 == Ri2)
						MAX = TALUH;
						else if(Ri1 == Rj2)
						MAX = TALUL;
						else MAX = R[Ri1];	  
				   end
					
			else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				MAX = R[Ri1];
				//TB = R[Rj1];	  
	       end
			
			
					else begin // this is due to 2 oprand manipulation instructions
							 if(Ri1 == Ri2)begin
								 MAX = TALUH;
							  end
							  else begin
								  MAX = R[Ri1];
							  end
					 end
					
			end
			
			PC = PC + 1'b1;
			//MM_A = PC;
		  
	end 
	
	CALL_IC:
		begin
			MAB = DM_out; // this is IW1 for call
			
			if (Ri1 == 0)  // for MAB we take Ri from MC0 from IW0
				MAX = 0;
			else if (Ri1 == 1)
				MAX = PC;
			else if (Ri1 == 2)
				MAX = SP;
			else begin
					if(IR2[13:8] == CPY_IC) begin
						if(Ri1 == Ri2)
							MAX = TALUL;
						else MAX = R[Ri1];	  
				   end
			
			
					else if(IR2[13:8] == SWAP_IC) begin
						if(Ri1 == Ri2)
						MAX = TALUL;
						else if(Ri1 == Rj2)
						MAX = TALUH;
						else MAX = R[Ri1];	  
					end	

			      else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin
						if(Ri1 == Ri2)
						MAX = TALUH;
						else if(Ri1 == Rj2)
						MAX = TALUL;
						else MAX = R[Ri1];	  
				   end
					
			else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				MAX = R[Ri1];
				//TB = R[Rj1];	  
	       end
			
			
					else begin // this is due to 2 oprand manipulation instructions
							 if(Ri1 == Ri2)begin
								 MAX = TALUH;
							  end
							  else begin
								  MAX = R[Ri1];
							  end
					 end
					
			end
			
			PC = PC + 1'b1;
			SP = SP - 1'b1;
			WR_DM = 1'b1;
			MM_A = SP; // cause in MC2 we store PC in Memory pointed by SP
			DM_in = PC;
		end
		
	RET_IC:
		begin
			MM_A = SP;
			SR = DM_out[11:0];
			//SP = SP + 1'b1;
			
		end
			
			
	CPY_IC:
		begin
		
			if(IR2[13:8] == CPY_IC) begin
				if(Rj1 == Ri2)
				TB = TALUL;
				else TB = R[Rj1];	  
	      end
		
		
			else if(IR2[13:8] == SWAP_IC) begin
				if(Rj1 == Ri2)
				TB = TALUL;
				else if(Rj1 == Rj2)
				TB = TALUH;
				else TB = R[Rj1];	  
	      end
			
	      else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin
					if(Rj1 == Ri2)
					TB = TALUH;
					else if(Rj1 == Rj2)
					TB = TALUL;
					else TB = R[Rj1];	  
		    end
			 
			 else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
			//	TA = R[Ri1];
				TB = R[Rj1];	  
	    end
		
			else TB = R[Rj1];
		end
			
	ADDC_IC, SUBC_IC:
		begin
		
			if(IR2[13:8] == CPY_IC) begin
				if(Ri1 == Ri2)
					TA = TALUL;
				else TA = R[Ri1];	  
	      end
		
			else if(IR2[13:8] == SWAP_IC) begin
				if(Ri1 == Ri2)
				TA = TALUL;
				else if(Ri1 == Rj2)
				TA = TALUH;
				else TA = R[Ri1];	  
	      end		
		
		   else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC)
			begin
		       if(Ri1 == Ri2)
			      TA = TALUH;
			    else if (Ri1 == Rj2) begin
			       TA = TALUL;
					 end
			    else TA = R[Ri1];
		 
		   end
			
		else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				TA = R[Ri1];
				//TB = R[Rj1];	  
	    end
			
		
		   else begin
			  if(Ri1 == Ri2)begin
				  TA = TALUH;
			  end
			  else begin
				  TA = R[Ri1]; // content of register R at address pointed by Ri
			  end	
			end
					
			TB = {10'b0000000000, IR1[3:0]};
		end
		
 NOT_IC, SHRL_IC, SHRA_IC, ROTL_IC, ROTR_IC, RLN_IC,RLZ_IC, RRC_IC,RRV_IC:
		begin
		
			if(IR2[13:8] == CPY_IC) begin
				if(Ri1 == Ri2)
					TA = TALUL;
				else TA = R[Ri1];	  
	      end
		

			else if(IR2[13:8] == SWAP_IC) begin
					if(Ri1 == Ri2)
					TA = TALUL;
					else if(Ri1 == Rj2)
					TA = TALUH;
				else TA = R[Ri1];	  
	       end
				
			else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin
					 if(Ri1 == Ri2)
						TA = TALUH;
				    else if (Ri1 == Rj2)
						TA = TALUL;
			else TA = R[Ri1];
			end
			
		else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				TA = R[Ri1];
				//TB = R[Rj1];	  
	    end
		
		  else begin
			  if(Ri1 == Ri2)begin
			  	  TA = TALUH;
			  end
			  else begin
				  TA = R[Ri1];
			  end
		  end
		 		
		end
		
	MUL_IC, DIV_IC:
	begin
	
			if(IR2[13:8] == CPY_IC) begin
				if(Ri1 == Ri2)
					TA = TALUL;
				else TA = R[Ri1];
				
			if(Rj1 == Ri2)
				TB = TALUL;
			else TB = R[Rj1];	  
		  end
	
	
			else if(IR2[13:8] == SWAP_IC) begin
				if(Ri1 == Ri2)
				TA = TALUL;
				else if(Ri1 == Rj2)
				TA = TALUH;
				else TA = R[Ri1];
				
				if(Rj1 == Ri2)
				TB = TALUL;
				else if(Rj1 == Rj2)
				TB = TALUH;
				else TB = R[Rj1];	  
	      end	

	else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin
		      if(Ri1 == Ri2)
				TA = TALUH;
				else if(Ri1 == Rj2)
				TA = TALUL;
				else TA = R[Ri1];
				
				if(Rj1 == Ri2)
				TB = TALUH;
				else if(Rj1 == Rj2)
		      TB = TALUL;
				else TB = R[Rj1];	  
		  end
		  
		 else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				TA = R[Ri1];
				TB = R[Rj1];	  
	    end
	
	  else begin
	    if(Ri1 == Ri2)begin
		    TA = TALUH;
		  end
		  else begin
			  TA = R[Ri1];
		  end
			  if(Rj1 == Ri2)begin
              TB = TALUH;
			  end
		  else begin
			  TB = R[Rj1];
		  end
		end
		 
	end
			
	default: // ADD_IC, SUB_IC, SWAP_IC, 
		begin
		
			if(IR2[13:8] == CPY_IC) begin
				if(Ri1 == Ri2)
					TA = TALUL;
				else TA = R[Ri1];
				
			if(Rj1 == Ri2)
				TB = TALUL;
			else TB = R[Rj1];	  
		  end
		
		
			if(IR2[13:8] == SWAP_IC) begin
				if(Ri1 == Ri2)
				TA = TALUL;
				else if(Ri1 == Rj2)
				TA = TALUH;
				else TA = R[Ri1];
				
				if(Rj1 == Ri2)
				TB = TALUL;
				else if(Rj1 == Rj2)
				TB = TALUH;
				else TB = R[Rj1];	  
	    end 
		
		
			else if(IR2[13:8] == MUL_IC || IR2[13:8] == DIV_IC) begin
				if(Ri1 == Ri2)
				TA = TALUH;
				else if(Ri1 == Rj2)
				TA = TALUL;
				else TA = R[Ri1];
				
				if(Rj1 == Ri2)
				TB = TALUH;
				else if(Rj1 == Rj2)
				TB = TALUL;
				else TB = R[Rj1];	  
	    end
		 
		 
		 else if(IR2 == 14'h3fff && IR3 == 14'h3fff) begin
				TA = R[Ri1];
				TB = R[Rj1];	  
	    end
		 
		
		  else begin
		  	  if(Ri1 == Ri2)begin
				  TA = TALUH;
			  end
			  else begin
				  TA = R[Ri1];
			  end
			  if(Rj1 == Ri2)begin
             TB = TALUH;
			  end
			  else begin
				  TB = R[Rj1];
			  end
		  end	  
		  
		end

			endcase
		end

//----------------------------------------------------------------------------
// The only data D/H that can occur are RAW.  These are automatically 
//		resolved. 
//	In the case of the JUMPS we stall until the address of the
//		next instruction to be executed is known.
//
// The IR value 0x3fff I call a "don't care" OpCode value.  It allows us to
//		control the refill of the pipe after the stalls of a jump emptied it.
//----------------------------------------------------------------------------

	if (stall_mc2 == 0 && (IR3[13:8] != JMP_IC && IR3[13:8] != ST_IC && IR3[13:8] != LD_IC && IR3[13:8] != CALL_IC && IR3[13:8] != RET_IC)) // Instruction in MC2 can move to MC3
	begin 
		IR3 = IR2; 
		Ri3 = Ri2; 
		Rj3 = Rj2;  // WHY? Ri3;
		stall_mc3 = 0; 
	end
	else if(IR3[13:8] == ST_IC || IR3[13:8] == LD_IC)
	begin
		stall_mc0 = 1;
		IR3 = 14'h3fff;
	end
	else 
	begin 
		stall_mc2 =1; 
		IR3 = 14'h3fff; 
	end // Instruction in MC2 is stalled. IR3 is loaded with the "don't care IW"
	
	
//######################################################################################################//

//--------------------------------------MC1---------------------------------------------------------------//

	if (stall_mc1 == 0 && (IR2[13:8] != JMP_IC && IR2[13:8] != ST_IC && IR2[13:8] != LD_IC && IR2[13:8] != CALL_IC && IR2[13:8] != RET_IC)) // Instruction in MC1 can move to MC2; Rj2 may need to be = Ri1 for certain instruction sequences
	begin 
		IR2 = IR1; 
		Ri2 = Ri1; 
		Rj2 = Rj1; 
		stall_mc2 = 0; 
	end
	else if(IR2[13:8] == ST_IC ||IR2[13:8] == ST_IC )
	begin
		stall_mc1 = 1;
		IR2 = 14'h3fff;
	end
	else 
	begin 
		stall_mc1 = 1; 
		IR2 = 14'h3fff; 
	end // Instruction in MC1 is stalled and IR2 is loaded with the "don't care IW"
	
//#########################################################################################################################//

//------------------------------ MC0---------------------------------------------------------------------------------------//
	
	if (stall_mc0 == 0 && (IR1[13:8] != JMP_IC && IR1[13:8] != ST_IC && IR1[13:8] != LD_IC && IR1[13:8] != CALL_IC && IR1[13:8] != RET_IC)) // Instruction in MC0 can move
		// to MC1; Below: IW0 is fetched directly into IR1, Ri1, and Rj1
	begin 
//	if(Done == 0)
//	begin
//	    PC = PC;
//		 MM_A = PC;
//	end
//else begin
			IR1 = DM_out; 
			Ri1 = DM_out[7:4];
			Rj1 = DM_out[3:0]; 
			PC = PC + 1'b1;
			MM_A = PC;
			WR_DM = 1'b0;
			stall_mc1 = 0; 
	//end
end
	
	else if(IR1[13:8] == ST_IC || IR1[13:8] == LD_IC )
	begin
		stall_mc0 = 1;
		IR1 = 14'h3fff;
	end
	else 
	begin 
		stall_mc0 = 1; 
		IR1 = 14'h3fff;
	end // Instruction in MC0 is stalled and IR1 is loaded with the "don't care IW"
	
	if (IR3 == 14'h3fff && IR2 == 14'h3fff) stall_mc0 = 0; 
//	else if (IR2 == 14'h3fff) stall_mc1 = 0;
//	else if (IR1 == 14'h3fff) stall_mc2 = 0;
	
	// After the instruction in MC3 has
		// been stalled, start refilling the pipe by removing the stalls in
		// this order: stall_mc0 --> stall_mc1 --> stall_mc2
//----------------------------------------------------------------------------

end

end// end done

end

endmodule