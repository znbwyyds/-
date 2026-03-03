`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/08 10:20:17
// Design Name: 
// Module Name: dehaze_dsamp
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

module dehaze_dsamp                  #(
	// declare parameters
	parameter                          		  DOWN_SIZE        = 2     , 
	parameter                          		  IN_LINE_LENGTH   = 1920  ,
	parameter                          		  IN_LINE_NUM      = 1080  ,
	parameter                          		  DATA_WIDTH       = 24    )
	                                  (
	// logic clock and active-low reset
	input                              		  clk                      ,
	input                              		  rst_n                    ,
	// data in
	input                                     ds_in_hs                 ,
	input                                     ds_in_vs                 ,
	input                                     ds_in_de                 ,
	input         [DATA_WIDTH-1 : 0]          ds_in_da                 ,
	
	// data out
	output    reg [DATA_WIDTH-1 : 0]          ds_out_da                ,
	output    reg                             ds_out_vld               ,
	output    reg                             ds_out_bof               ,
	output    reg                             ds_out_eof               	
																	  );
																	  
	// ******************** define variable types ******************** // 
	
	reg                                       ds_in_de_1d              ;
	wire                                      ds_in_de_pls             ;
	reg           [10:0]                      ds_in_de_cnt             ;
	reg           [10:0]                      ds_in_hs_cnt             ;
	wire                                      ds_gap_en                ;	
	
	reg           [10:0]                      ds_out_de_cnt            ;
	reg           [10:0]                      ds_out_hs_cnt            ;
		
	wire                                      ds_out_fifo_rd           ;
	wire                                      ds_out_fifo_empty        ;
	wire          [DATA_WIDTH-1 : 0]          ds_out_fifo_da           ;
	wire                                      ds_out_fifo_vld          ;
	reg                                       ds_out_fifo_vld_1d       ;
	wire                                      ds_out_fifo_vld_pls      ;


	// ************************* stream ctrl ************************* // 
	// ds_in_de_pls
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_in_de_1d <= 1'b0;
		end
		else begin
			ds_in_de_1d <= ds_in_de;
		end
	end
	assign ds_in_de_pls = ds_in_de_1d & (~ds_in_de);

    // ds_in_de_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_in_de_cnt <= 'd0;
		end
		else if(ds_in_de_pls == 1'b1) begin
			ds_in_de_cnt <= 'd0;
		end
		else if(ds_in_de == 1'b1) begin
			ds_in_de_cnt <= ds_in_de_cnt + 11'd1;
		end
	end

	// ds_in_hs_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin                                        
			ds_in_hs_cnt <= 'd0;
		end
		else if(ds_in_vs == 1'b1) begin
			ds_in_hs_cnt <= 'd0;
		end
		else if(ds_in_de_pls == 1'b1) begin
			ds_in_hs_cnt <= ds_in_hs_cnt + 11'd1;
		end
	end

	// ds_out_fifo_vld_pls
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_out_fifo_vld_1d <= 1'b0;
		end
		else begin
			ds_out_fifo_vld_1d <= ds_out_fifo_vld;
		end
	end
	assign ds_out_fifo_vld_pls = ds_out_fifo_vld_1d & (~ds_out_fifo_vld);

    // ds_out_de_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_out_de_cnt <= 'd0;
		end
		else if((ds_out_fifo_vld_pls == 1'b1) || (ds_in_vs == 1'b1)) begin
			ds_out_de_cnt <= 'd0;
		end
		else if(ds_out_fifo_vld == 1'b1) begin
			ds_out_de_cnt <= ds_out_de_cnt + 11'd1;
		end
	end

	// ds_out_hs_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin                                        
			ds_out_hs_cnt <= 'd0;
		end
		else if(ds_in_vs == 1'b1) begin
			ds_out_hs_cnt <= 'd0;
		end
		else if(ds_out_fifo_vld_pls == 1'b1) begin
			ds_out_hs_cnt <= ds_out_hs_cnt + 11'd1;
		end
	end
	
	// ds_gap_en
	assign ds_gap_en = (ds_in_de_cnt[0] == 1'b1) && (ds_in_hs_cnt[0] == 1'b1);
	
	
	// ************************* line buffers ************************ // 
	assign ds_out_fifo_rd = ((ds_in_hs_cnt[0] == 1'b0) && (ds_out_fifo_empty == 1'b0));
	ds_out_fifo ds_line_buffer_inst     (
	 .clk                               (clk                          ),
	 .rst                               (ds_in_vs                     ),
	 .din                               (ds_in_da                     ),
	 .wr_en                             (ds_gap_en                    ),
	 .rd_en                             (ds_out_fifo_rd               ),
	 .dout                              (ds_out_fifo_da               ),
	 .full                              (                             ),
	 .empty                             (ds_out_fifo_empty            ),
	 .valid                             (ds_out_fifo_vld              ),
	 .wr_rst_busy                       (                             ),
	 .rd_rst_busy                       (                             ) 
	                                                                  );
																	  
	// ************************ signals output *********************** //
	// ds_out_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_out_vld <= 'b0;
		end
		else begin
			ds_out_vld <= ds_out_fifo_vld;
		end
	end
	
	// ds_out_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_out_da <= 'd0;
		end
		else begin
			ds_out_da <= (ds_out_fifo_vld == 1'b1)? ds_out_fifo_da : 'd0;
		end
	end
	
	// ds_out_bof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_out_bof <= 1'b0;
		end
		else begin
			ds_out_bof <= (ds_out_hs_cnt == 11'd0) && (ds_out_de_cnt == 11'd0) && (ds_out_fifo_vld == 1'b1);
		end
	end

	// ds_out_eof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ds_out_eof <= 1'b0;
		end
		else begin
			ds_out_eof <= (ds_out_hs_cnt == ((IN_LINE_NUM/DOWN_SIZE)-'d1)) && (ds_out_de_cnt == ((IN_LINE_LENGTH/DOWN_SIZE) - 'd1));
		end
	end
															
	
endmodule
