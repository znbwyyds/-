`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/08 14:40:48
// Design Name: 
// Module Name: dehaze_rgb2gray
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


module dehaze_rgb2gray               #( 

	// declare parameters
	parameter                          		      IN_DATA_WIDTH   = 8      ,
	parameter                          		      OUT_DATA_WIDTH  = 18     )
									  (           
	// logic clock and active-low reset           
	input                              		      clk                      ,
	input                              		      rst_n                    ,
											      
	// data in                                    
	input             [IN_DATA_WIDTH-1 : 0]       gr_in_da_r               ,
	input             [IN_DATA_WIDTH-1 : 0]       gr_in_da_g               ,
	input             [IN_DATA_WIDTH-1 : 0]       gr_in_da_b               ,
	input                              		      gr_in_vld                ,
	
	// stay high for one cycle aligned to the first frame data
	input                              		      gr_in_bof                ,
	// stay high for one cycle aligned to the last frame data
	input                                         gr_in_eof                ,
		
	// data out
	output reg        [OUT_DATA_WIDTH-1 : 0]      gr_out_da                ,
	output reg                                    gr_out_vld               ,
	output reg                                    gr_out_bof               ,
	output reg                                    gr_out_eof               	
	                                                                      );
																	  
	// ********************** define variable types ********************* // 
	
	localparam                                    GRAY_R_PARAM  =       306;
	localparam                                    GRAY_G_PARAM  =       601;
	localparam                                    GRAY_B_PARAM  =       117;
	
	reg               [IN_DATA_WIDTH+10-1 : 0]    gr_r_mul                 ;
	reg               [IN_DATA_WIDTH+10-1 : 0]    gr_g_mul                 ;
	reg               [IN_DATA_WIDTH+10-1 : 0]    gr_b_mul                 ;
		         
	reg               [OUT_DATA_WIDTH-1   : 0]    gr_out_mul               ;
	
	wire                                          gr_out_vld_w             ;
	wire                                          gr_out_bof_w             ;
	wire                                          gr_out_eof_w             ;

	
	
	// *************************** stream ctrl ************************** // 
	gr_out_vld_delay gr_out_vld_delay0 (.D    ({gr_in_vld, gr_in_bof, gr_in_eof}          ),
                                     	.CLK  (clk                                        ), 
										.Q    ({gr_out_vld_w, gr_out_bof_w, gr_out_eof_w} ));


	// ************************* pipeline mults ************************* //
	// gr_r_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			gr_r_mul <= 'd0;
		end
		else begin
			gr_r_mul <= gr_in_da_r * GRAY_R_PARAM;
		end
	end

	// gr_g_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			gr_g_mul <= 'd0;
		end
		else begin
			gr_g_mul <= gr_in_da_g * GRAY_G_PARAM;
		end
	end

	// gr_b_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			gr_b_mul <= 'd0;
		end
		else begin
			gr_b_mul <= gr_in_da_b * GRAY_B_PARAM;
		end
	end
	
	// gr_out_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			gr_out_mul <= 'd0;
		end
		else begin
			gr_out_mul <= gr_r_mul + gr_g_mul + gr_b_mul;
		end
	end
	
	// ************************** signals output ************************ //
	// gr_out_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			gr_out_vld <= 1'b0;
		end
		else begin
			gr_out_vld <= gr_out_vld_w;
		end
	end

	// gr_out_da
	always @ (posedge clk or negedge rst_n) begin 
		if(rst_n == 1'b0) begin
			gr_out_da <= 'd0;
		end
		else begin
			gr_out_da <= (gr_out_vld_w == 1'b1)? {2'b0, gr_out_mul[OUT_DATA_WIDTH-1 : 2]} : 'd0;
		end
	end
	
	// gr_out_bof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			gr_out_bof <= 1'b0;
		end
		else begin
			gr_out_bof <= gr_out_bof_w;
		end
	end

	// gr_out_eof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			gr_out_eof <= 1'b0;
		end
		else begin
			gr_out_eof <= gr_out_eof_w;
		end
	end



endmodule
