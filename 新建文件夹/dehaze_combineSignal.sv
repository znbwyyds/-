`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/12 17:06:33
// Design Name: 
// Module Name: dehaze_combineSignal
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


module dehaze_combineSignal          #(      
	// declare parameters
	parameter                          		   IN_DATA_WIDTH = 18          ,  
	parameter                          		   OUT_DATA_WIDTH = 36         )
	                                  (
	// logic clock and active-low reset
	input                                      clk                         ,
	input                                      rst_n                       ,
	
	// data in
	input      [IN_DATA_WIDTH-1 : 0]           cb_in_gd_da                 ,
	input                              		   cb_in_gd_vld                ,
	input                              		   cb_in_gd_bof                ,
	input                              		   cb_in_gd_eof                ,
									
	input      [IN_DATA_WIDTH-1 : 0]           cb_in_pd_da                 ,
	input                              		   cb_in_pd_vld                ,
	input                              		   cb_in_pd_bof                ,
	input                              		   cb_in_pd_eof                ,

	// data out
	output reg [OUT_DATA_WIDTH-1: 0]           cb_out_gp_da                ,
	output reg                          	   cb_out_gp_vld               ,
	output reg                          	   cb_out_gp_bof               ,
	output reg                          	   cb_out_gp_eof               
	)                                                                      ;
	
	// ************************ define variable types ******************** // 
	
	reg        [IN_DATA_WIDTH-1 : 0]           cb_in_pd_da_1d              ;
	reg                                        cb_in_pd_vld_1d             ;
	reg                                        cb_in_pd_bof_1d             ;
	reg                                        cb_in_pd_eof_1d             ;
	reg                                        cd_buf_rst                  ;
	wire       [IN_DATA_WIDTH-1 : 0]           cd_buf_out_da               ;
	
	// ************************* input signals delay ********************* //
	// cb_in_pd_vld_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_in_pd_vld_1d <= 1'b0;
		end
		else begin
			cb_in_pd_vld_1d <= cb_in_pd_vld;
		end
	end

	// cb_in_pd_da_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_in_pd_da_1d <= 'd0;
		end
		else begin
			cb_in_pd_da_1d <= cb_in_pd_da;
		end
	end

	// cb_in_pd_bof_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_in_pd_bof_1d <= 1'b0;
		end
		else begin
			cb_in_pd_bof_1d <= cb_in_pd_bof;
		end
	end

	// cb_in_pd_eof_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_in_pd_eof_1d <= 1'b0;
		end
		else begin
			cb_in_pd_eof_1d <= cb_in_pd_eof;
		end
	end


	// ************************** guide image fifo *********************** //
	// cd_buf_rst
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cd_buf_rst <= 1'b1;
		end
		else if(cb_in_pd_eof_1d == 1'b1) begin
			cd_buf_rst <= 1'b1;
		end
		else begin
			cd_buf_rst <= 1'b0;
		end
	end
	
	cb_pd_buf cb_pd_buf0                      (
	 .clk                                     (clk                        ), 
	 .rst                                     (cd_buf_rst                 ),                 
	 .din                                     (cb_in_gd_da                ),                 
	 .wr_en                                   (cb_in_gd_vld               ),             
	 .rd_en                                   (cb_in_pd_vld               ),             
	 .dout                                    (cd_buf_out_da              ),               
	 .full                                    (                           ),               
	 .empty                                   (                           ),             
	 .wr_rst_busy                             (                           ), 
	 .rd_rst_busy                             (                           )  
	);
	
	// ************************* signals output ************************* //
	// cb_out_gp_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_out_gp_vld <= 1'b1;
		end
		else begin
			cb_out_gp_vld <= cb_in_pd_vld_1d;
		end
	end

	// cb_out_gp_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_out_gp_da <= 'd1;
		end
		else begin
			cb_out_gp_da <= (cb_in_pd_vld_1d == 1'b1)? {cd_buf_out_da, cb_in_pd_da_1d} : 'd0;
		end
	end
	
	// cb_out_gp_bof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_out_gp_bof <= 1'b1;
		end
		else begin
			cb_out_gp_bof <= cb_in_pd_bof_1d;
		end
	end

	// cb_out_gp_eof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			cb_out_gp_eof <= 1'b1;
		end
		else begin
			cb_out_gp_eof <= cb_in_pd_eof_1d;
		end
	end

endmodule
