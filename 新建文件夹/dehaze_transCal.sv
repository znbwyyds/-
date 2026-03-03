`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/09 21:20:23
// Design Name: 
// Module Name: dehaze_transCal
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


module dehaze_transCal               #( 
	// declare parameters
	parameter                          		  IN_DATA_WIDTH   = 8          ,
	parameter                          		  OUT_DATA_WIDTH  = 18         ,
	parameter                          		  TRANS_MIN       = 16'd6553   ,
	parameter                        		  HAZE_REMAIN     = 16'd58982  )
									  (           
	// logic clock and active-low reset                                
	input                              		  clk                          ,
	input                              		  rst_n                        ,
																	       
	// data in                                                             
	input         [IN_DATA_WIDTH-1   :  0]    tr_in_da                     ,
	input                              		  tr_in_vld                    ,
	input         [IN_DATA_WIDTH-1   :  0]    tr_in_atmos                  ,
	// stay high for one cycle aligned to the first frame data             
	input                              		  tr_in_bof                    ,
	// stay high for one cycle aligned to the last frame data                
	input                                     tr_in_eof                    ,
																           
	// data out                                    	                       
	output reg    [OUT_DATA_WIDTH-1  :  0]    tr_out_da                    ,
	output reg                      		  tr_out_vld                   ,
	output reg                      		  tr_out_bof                   ,
	output reg                      		  tr_out_eof                  );
	
	
	// ************************ define variable types ******************* // 
	reg           [7                  : 0]    tr_in_atmos_pre              ;
	wire          [15                 : 0]    tr_transCal_par              ;
	reg           [24                 : 0]    tr_multi_in1                 ;
	reg           [32                 : 0]    tr_multi_out                 ;
	reg           [15                 : 0]    tr_multi_out_sft             ;
																	       
	reg                                       tr_in_vld_1d                 ;
	reg                                       tr_in_bof_1d                 ;
	reg                                       tr_in_eof_1d                 ;
	reg                                       tr_in_vld_2d                 ;
	reg                                       tr_in_bof_2d                 ;
	reg                                       tr_in_eof_2d                 ;
	
	// ************************* pipeline multis ************************ // 
	// transCal_par
	// tr_in_atmos_pre
	// !!!! assume that atmosphere is more than 128
	// so that just use one DSP48(25bit * 18bit) to multiple two numbers.
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_in_atmos_pre <= 8'd128;
		end
		else begin
			tr_in_atmos_pre <= (tr_in_atmos < 8'd128)? 8'd128 : tr_in_atmos;
		end
	end	
    transCal_par transCal_par0 ( .clka(clk), .addra(tr_in_atmos_pre), .douta(tr_transCal_par));
	
	// tr_multi_in1
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_multi_in1 <= 'd0;
		end
		else begin
			tr_multi_in1 <= tr_transCal_par[8 : 0] * HAZE_REMAIN;
		end
	end	
	
	// tr_multi_out
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_multi_out <= 'd0;
		end
		else begin
			tr_multi_out <= tr_multi_in1 * tr_in_da;
		end
	end	
	
	// tr_multi_out_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_multi_out_sft <= 'd0;
		end
		else begin
			tr_multi_out_sft <= (tr_multi_out[32:16] < (17'd65535 - TRANS_MIN))? tr_multi_out[31 : 16] : (16'd65535 - TRANS_MIN);
		end
	end	
	
	// tr_in_vld_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_in_vld_1d <= 'd0;
		end
		else begin
			tr_in_vld_1d <= tr_in_vld;
		end
	end	

	// tr_in_bof_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_in_bof_1d <= 'd0;
		end
		else begin
			tr_in_bof_1d <= tr_in_bof;
		end
	end	

	// tr_in_eof_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_in_eof_1d <= 'd0;
		end
		else begin
			tr_in_eof_1d <= tr_in_eof;
		end
	end	

	// tr_in_vld_2d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_in_vld_2d <= 'd0;
		end
		else begin
			tr_in_vld_2d <= tr_in_vld_1d;
		end
	end	

	// tr_in_bof_2d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_in_bof_2d <= 'd0;
		end
		else begin
			tr_in_bof_2d <= tr_in_bof_1d;
		end
	end	

	// tr_in_eof_2d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_in_eof_2d <= 'd0;
		end
		else begin
			tr_in_eof_2d <= tr_in_eof_1d;
		end
	end	

	// ************************* signals output ************************* //
	// tr_out_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_out_da <= 'd0;
		end
		else begin
			tr_out_da <= (tr_in_vld_2d == 1'b1)? {2'b0, (16'd65535 - tr_multi_out_sft)} : 'd0;
		end
	end	

	// tr_out_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_out_vld <= 'd0;
		end
		else begin
			tr_out_vld <= tr_in_vld_2d;
		end
	end	

	// tr_out_bof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_out_bof <= 'd0;
		end
		else begin
			tr_out_bof <= tr_in_bof_2d;
		end
	end	

	// tr_out_eof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			tr_out_eof <= 'd0;
		end
		else begin
			tr_out_eof <= tr_in_eof_2d;
		end
	end	

endmodule
