/*
* Content Addressable Memory for storing the TAG numbers of the MM blocks
* CAM will be used for the 2-way Set Associative Cache Design
*
*/

module av_CAM_v (we_n, rd_n, din, argin, addrs, dout, mbits);

parameter arg_max=9,
         // addrs_max=2, 
			 bl_max=4;

input we_n;
input rd_n; // this is used for debugging, to check what value in a particular location of CAM

input [1:0] addrs; // 2-bits to address 4 groups

input [arg_max-3:0] argin; // incoming TAG value (9-bit wide), but only using 7-bits for now
input [arg_max-3:0] din;  // TAG values stored in CAM are 9-bit wide

output reg [arg_max-3:0] dout; // used for debugging with rd_n

output reg [3:0] mbits; // we have 4-groups so 4 1-bit match bit for each group

// declare CAM memory as an array of 4, 9-bit registers
reg [arg_max-3:0] cam_mem [3:0];

integer i, int_addrs,j;

//-- The INITIALIZE procedural block
initial 
begin 
  for (i=0; i<10; i=i+1) 
    for (j = 0; j<4; j= j+1) cam_mem[j] = {(arg_max-2){1'b1}}; 
    mbits = {bl_max{1'b0}};
	j = j+1; 
 end

/* Write procedural block
*
* This enables a new tag value to be written at a specific location, 
*    using a Write_enable, data input and address input busses as with any
*    other memory.
*
* In the context of a cache, this happens when a new block is uploaded in the cache.
*/
always@(we_n, din,addrs)
begin
	int_addrs = addrs;
	if(we_n == 1) // write is active low
	begin
		cam_mem[int_addrs] = din;
	end
end

/* The READ procedural block.
* This allows a value at a specific location to be read out, 
*    using a RD, data output and address input busses as with any
*    other memory.
*
* In the context of a cache, this is not necessary. This functionality 
*    is provided here for reference and debugging purposes.
*/
always@(rd_n, addrs,cam_mem)
begin
	int_addrs = addrs;
	if(rd_n == 1) // read is also active low
	begin
		dout = cam_mem[int_addrs];
	end
	else dout = {(arg_max-2){1'bz}}; // high impedance
end

/*
* Match logic -- actual CAM functionality
*
* an mbit is 1 if argument value is equal to content of CAM
*
*/
always@(argin,cam_mem)
begin
	mbits = 4'b0000; // initialized to all zeros
	for(i = 0; i<4; i = i+1)
	begin
		if(argin == cam_mem[i])
		begin
			mbits[i] = 1;
		end
	end
end

endmodule