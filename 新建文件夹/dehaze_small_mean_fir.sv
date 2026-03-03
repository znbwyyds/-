`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/25 14:29:46
// Design Name: 
// Module Name: dehaze_small_mean_fir
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dehaze_small_mean_fir         #(
	// declare parameters
	// filter size must be odd and (power of 2) minus 1.
	parameter                          		  FIR_MAX_SIZE  = 7        , 
	parameter                          		  DATA_WIDTH    = 17       ,
	parameter                          		  LINE_LENGTH   = 960     )
									  (
	// logic clock and active-low reset
	input                              		  clk                      ,
	input                              		  rst_n                    ,
	
	// signed data in
	input  signed [DATA_WIDTH-1 : 0]          mf_in_da                 ,
	input                              		  mf_in_vld                ,
	
	// adjust-size 3,7,11,15,19,23,27,31
	input         [1 : 0]                     mf_fir_size              ,
	
	// signed data out
	output signed [DATA_WIDTH-1 : 0]          mf_out_da                ,
	output                                    mf_out_vld               
	                                                                  );
																	  
	//`define									  FIR_MAX_SIZE_32							  
	//`define									  FIR_MAX_SIZE_16							  
	//`define									  FIR_MAX_SIZE_8							  
	//`define									  FIR_MAX_SIZE_4							  
															   
	// ************************* define variable types ********************* // 
	
	reg    signed [DATA_WIDTH-1 : 0]          mf_sqr      	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
	reg    signed [DATA_WIDTH-1 : 0]          mf_sqr_1d   	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
	reg                                       mf_sqr_mask 	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
	reg           [4 : 0]                     mf_fir_size_fan_out [FIR_MAX_SIZE           : 0]                             ;
																						  						 
	reg    signed [DATA_WIDTH   : 0]          mf_sqr_add_2d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/2-1   : 0] ;
	reg    signed [DATA_WIDTH+1 : 0]          mf_sqr_add_3d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/4-1   : 0] ;
	reg    signed [DATA_WIDTH+2 : 0]          mf_sqr_add_4d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/8-1   : 0] ;
	reg    signed [DATA_WIDTH+3 : 0]          mf_sqr_add_5d       [(FIR_MAX_SIZE+1)/2     : 0][(FIR_MAX_SIZE+1)/8-1   : 0] ;
	reg    signed [DATA_WIDTH+4 : 0]          mf_sqr_add_6d       [(FIR_MAX_SIZE+1)/4     : 0][(FIR_MAX_SIZE+1)/8-1   : 0] ;
	
	reg    signed [DATA_WIDTH+5 : 0]          mf_sqr_add_all           ; 
    reg           [1:0]	                      mf_fir_size_r            ;
	
	reg                                       mf_sqr_add_2d_en         ;
	reg                                       mf_sqr_add_3d_en         ;
	reg                                       mf_sqr_add_4d_en         ;
	reg                                       mf_sqr_add_5d_en         ;
	reg                                       mf_sqr_add_6d_en         ;
	reg                                       mf_sqr_add_all_en        ;
	
    wire          [1:0]	                      mf_fir_size_bufg         ;
	
	integer                            		  x_index                  ;
	integer                            		  y_index                  ;
	
	// ********************* high fanout signals ********************* // 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_fir_size_r <= 2'd0;
		end
		else begin
			mf_fir_size_r <= (mf_in_vld)? mf_fir_size : 2'd0;
		end
	end
		
    BUFG BUFG_inst_b1 ( .O(mf_fir_size_bufg[1]), .I(mf_fir_size_r[1]));
    BUFG BUFG_inst_b0 ( .O(mf_fir_size_bufg[0]), .I(mf_fir_size_r[0]));	
	
	// ********************** array assignment *********************** // 
	//// mf_fir_size_fan_out
	// always @ (posedge clk or negedge rst_n) begin
		// if(rst_n == 1'b0) begin
			// for (y_index = 0; y_index < FIR_MAX_SIZE; y_index = y_index + 1) begin
				// mf_fir_size_fan_out[y_index] <= 'd0;
			// end
		// end
		// else begin
			// for (y_index = 0; y_index < FIR_MAX_SIZE; y_index = y_index + 1) begin
				// mf_fir_size_fan_out[y_index] <= mf_fir_size_buf;
			// end
		// end
	// end
	
	// din
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < (FIR_MAX_SIZE+1); y_index = y_index + 1) begin
					mf_sqr[x_index][y_index] <= 'b0;
				end			
			end
		end
		else begin
			for (x_index = 1; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < (FIR_MAX_SIZE+1); y_index = y_index + 1) begin
					mf_sqr[x_index][y_index] <= mf_sqr[x_index-1][y_index];
				end			
			end
			for (y_index = 0; y_index < (FIR_MAX_SIZE+1); y_index = y_index + 1) begin
				mf_sqr[0][y_index] <= (mf_in_vld)? mf_in_da : 'b0;
 			end
		end
	end
	
	// mf_sqr_mask
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < (FIR_MAX_SIZE+1); y_index = y_index + 1) begin
					mf_sqr_mask[x_index][y_index] <= 1'b0;
				end			
			end
		end
		else begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < (FIR_MAX_SIZE+1); y_index = y_index + 1) begin
					if((x_index >= ((FIR_MAX_SIZE-1)/2 - mf_fir_size_bufg)) && 
					   (x_index <= ((FIR_MAX_SIZE-1)/2 + mf_fir_size_bufg)) &&
					   (y_index >= ((FIR_MAX_SIZE-1)/2 - mf_fir_size_bufg)) &&
					   (y_index >= ((FIR_MAX_SIZE-1)/2 - mf_fir_size_bufg))   )
						mf_sqr_mask[x_index][y_index] <= 1'b1;
					else
						mf_sqr_mask[x_index][y_index] <= 1'b0;
				end			
			end
		end
	end
	// always @ (posedge clk or negedge rst_n) begin
		// if(rst_n == 1'b0) begin
			// for (x_index = 0; x_index < FIR_MAX_SIZE; x_index = x_index + 1) begin
				// for (y_index = 0; y_index < FIR_MAX_SIZE; y_index = y_index + 1) begin
					// mf_sqr_mask[x_index][y_index] <= 1'b0;
				// end			
			// end
		// end
		// else begin
			// for (x_index = (3 - mf_fir_size_bufg); x_index <= (3 + mf_fir_size_bufg); x_index = x_index + 1) begin
				// for (y_index = (3 - mf_fir_size_bufg); y_index <= (3 + mf_fir_size_bufg); y_index = y_index + 1) begin
					// mf_sqr_mask[x_index][y_index] <= 1'b1;
				// end			
			// end
			// for (x_index = 0; x_index < (3 - mf_fir_size_bufg); x_index = x_index + 1) begin
				// for (y_index = 0; y_index < FIR_MAX_SIZE; y_index = y_index + 1) begin
					// mf_sqr_mask[x_index][y_index] <= 1'b0;
				// end			
			// end
			// for (x_index = (3 + mf_fir_size_bufg + 1); x_index < FIR_MAX_SIZE; x_index = x_index + 1) begin
				// for (y_index = 0; y_index < FIR_MAX_SIZE; y_index = y_index + 1) begin
					// mf_sqr_mask[x_index][y_index] <= 1'b0;
				// end			
			// end
			// for (x_index = (3 - mf_fir_size_bufg); x_index <= (3 + mf_fir_size_bufg); x_index = x_index + 1) begin
				// for (y_index = 0; y_index < (3 - mf_fir_size_bufg); y_index = y_index + 1) begin
					// mf_sqr_mask[x_index][y_index] <= 1'b0;
				// end			
			// end
			// for (x_index = (3 - mf_fir_size_bufg); x_index <= (3 + mf_fir_size_bufg); x_index = x_index + 1) begin
				// for (y_index = (3 + mf_fir_size_bufg + 1); y_index < FIR_MAX_SIZE; y_index = y_index + 1) begin
					// mf_sqr_mask[x_index][y_index] <= 1'b0;
				// end			
			// end
		// end
	// end

	// mf_sqr_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < (FIR_MAX_SIZE+1); y_index = y_index + 1) begin
					mf_sqr_1d[x_index][y_index] <= 'd0;
				end			
			end
		end
		else begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < (FIR_MAX_SIZE+1); y_index = y_index + 1) begin
					mf_sqr_1d[x_index][y_index] <= (mf_sqr_mask[x_index][y_index] == 1'b0)? 'd0 : mf_sqr[x_index][y_index];
				end			
			end
		end
	end
																		
	// *********************** pipeline adders *********************** // 
	// add_en
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_sqr_add_2d_en  <= 1'b0;
			mf_sqr_add_3d_en  <= 1'b0;
			mf_sqr_add_4d_en  <= 1'b0;
			mf_sqr_add_5d_en  <= 1'b0;
			mf_sqr_add_6d_en  <= 1'b0;
			mf_sqr_add_all_en <= 1'b0;
		end
		else begin
			mf_sqr_add_2d_en  <=  mf_in_vld;
			mf_sqr_add_3d_en  <=  mf_sqr_add_2d_en;
			mf_sqr_add_4d_en  <=  mf_sqr_add_3d_en;
			mf_sqr_add_5d_en  <=  mf_sqr_add_4d_en;
			mf_sqr_add_6d_en  <=  mf_sqr_add_5d_en;
			mf_sqr_add_all_en  <=  mf_sqr_add_6d_en;		
		end
	end
	
	// mf_sqr_add_2d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < ((FIR_MAX_SIZE+1)/2); y_index = y_index + 1) begin
					mf_sqr_add_2d[x_index][y_index] <= 'b0;
				end
			end
		end
		else if(mf_sqr_add_2d_en == 1'b1) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < ((FIR_MAX_SIZE+1)/2); y_index = y_index + 1) begin
					mf_sqr_add_2d[x_index][y_index] <= mf_sqr_1d[x_index][y_index*2] + mf_sqr_1d[x_index][y_index*2+1];
				end
			end
		end
	end
	
	// mf_sqr_add_3d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < ((FIR_MAX_SIZE+1)/4); y_index = y_index + 1) begin
					mf_sqr_add_3d[x_index][y_index] <= 'b0;
				end
			end
		end
		else if(mf_sqr_add_3d_en == 1'b1) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < ((FIR_MAX_SIZE+1)/4); y_index = y_index + 1) begin
					mf_sqr_add_3d[x_index][y_index] <= mf_sqr_add_2d[x_index][y_index*2] + mf_sqr_add_2d[x_index][y_index*2+1];
				end
			end
		end
	end

	// mf_sqr_add_4d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < ((FIR_MAX_SIZE+1)/8); y_index = y_index + 1) begin
					mf_sqr_add_4d[x_index][y_index] <= 'b0;
				end
			end
		end
		else if(mf_sqr_add_4d_en == 1'b1) begin
			for (x_index = 0; x_index < (FIR_MAX_SIZE+1); x_index = x_index + 1) begin
				for (y_index = 0; y_index < ((FIR_MAX_SIZE+1)/8); y_index = y_index + 1) begin
					mf_sqr_add_4d[x_index][y_index] <= mf_sqr_add_3d[x_index][y_index*2] + mf_sqr_add_3d[x_index][y_index*2+1];
				end
			end
		end
	end

	// mf_sqr_add_5d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < ((FIR_MAX_SIZE+1)/2); x_index = x_index + 1) begin
				mf_sqr_add_5d[x_index][0] <= 'b0;
			end
		end
		else if(mf_sqr_add_5d_en == 1'b1) begin
			for (x_index = 0; x_index < ((FIR_MAX_SIZE+1)/2); x_index = x_index + 1) begin
				mf_sqr_add_5d[x_index][y_index] <= mf_sqr_add_4d[x_index*2][0] + mf_sqr_add_4d[x_index*2+1][0];
			end
		end
	end

	// mf_sqr_add_6d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (x_index = 0; x_index < ((FIR_MAX_SIZE+1)/4); x_index = x_index + 1) begin
				mf_sqr_add_6d[x_index][0] <= 'b0;
			end
		end
		else if(mf_sqr_add_6d_en == 1'b1) begin
			for (x_index = 0; x_index < ((FIR_MAX_SIZE+1)/4); x_index = x_index + 1) begin
				mf_sqr_add_6d[x_index][y_index] <= mf_sqr_add_5d[x_index*2][0] + mf_sqr_add_5d[x_index*2+1][0];
			end
		end
	end
	
	// mf_sqr_add_all
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_sqr_add_all <= 'b0;
		end
		else if(mf_sqr_add_all_en == 1'b1) begin
			mf_sqr_add_all <= mf_sqr_add_6d[0][0] + mf_sqr_add_6d[1][0];
		end
	end
	
	assign mf_out_da = mf_sqr_add_all/8;
	assign mf_out_vld = mf_sqr_add_all_en;
	
endmodule
