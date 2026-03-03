`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/06 21:12:01
// Design Name: 
// Module Name: dehaze_avefir
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

module dehaze_avefir                 #(      
	// declare parameters
	// filter size must be odd and (power of 2) minus 1.
	parameter                          		  FIR_MAX_SIZE = 31        ,  
	parameter                          		  RATIO_SIZE   = 3         ,
	parameter                          		  FIFO_WIDTH   = 18        , 
	parameter                          		  DATA_WIDTH   = 18        ,
	parameter                          		  LINE_LENGTH  = 960       ,
	parameter                          		  AF_IN_BOF_JUDGE   = 960*16+15 )
									  (
	// logic clock and active-low reset
	input                              		  clk                      ,
	input                              		  rst_n                    ,
	
	// signed data in
	input  signed [DATA_WIDTH-1 : 0]          af_in_da                 ,
	input                              		  af_in_vld                ,
	
	// stay high for one cycle aligned to the first frame data
	input                              		  af_in_bof                ,
	// stay high for one cycle aligned to the last frame data
	input                                     af_in_eof                ,
	
	// adjustable-size 
	input         [RATIO_SIZE-1 : 0]          af_fir_size              ,
	
	// signed data out
	output reg signed [DATA_WIDTH-1 : 0]      af_out_da                ,
	output reg                                af_out_vld               ,
	output reg                                af_out_bof               ,
	output reg                                af_out_eof               	
	                                                                  );
																	  

	// ****************** define dividor-multiply parameter **************** // 
	localparam signed [DATA_WIDTH-1 : 0]       af_div_coe          [2**RATIO_SIZE-1 : 0] = 
	{78, 105, 149, 227, 388, 809, 2621, 65536};
	
															   
	// ************************* define variable types ********************* // 
	
	reg                                       af_sqr_rst_n             ;
	wire                                      af_sqr_rst_n_bufg        ;
	
	reg    signed [DATA_WIDTH-1 : 0]          af_sqr      	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
	reg    signed [DATA_WIDTH-1 : 0]          af_sqr_1d   	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
	reg                                       af_sqr_mask 	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
																						  						 
	reg    signed [DATA_WIDTH   : 0]          af_sqr_add_2d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/2-1   : 0] ;
	reg    signed [DATA_WIDTH+1 : 0]          af_sqr_add_3d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/4-1   : 0] ;
	reg    signed [DATA_WIDTH+2 : 0]          af_sqr_add_4d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/8-1   : 0] ;
	reg    signed [DATA_WIDTH+3 : 0]          af_sqr_add_5d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/16-1  : 0] ;
	reg    signed [DATA_WIDTH+4 : 0]          af_sqr_add_6d       [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/32-1  : 0] ;
	reg    signed [DATA_WIDTH+5 : 0]          af_sqr_add_7d       [(FIR_MAX_SIZE+1)/2-1   : 0][(FIR_MAX_SIZE+1)/32-1  : 0] ;
	reg    signed [DATA_WIDTH+6 : 0]          af_sqr_add_8d       [(FIR_MAX_SIZE+1)/4-1   : 0][(FIR_MAX_SIZE+1)/32-1  : 0] ;
	reg    signed [DATA_WIDTH+7 : 0]          af_sqr_add_9d       [(FIR_MAX_SIZE+1)/8-1   : 0][(FIR_MAX_SIZE+1)/32-1  : 0] ;
	reg    signed [DATA_WIDTH+8 : 0]          af_sqr_add_ad       [(FIR_MAX_SIZE+1)/16-1  : 0][(FIR_MAX_SIZE+1)/32-1  : 0] ;
	
	reg    signed [DATA_WIDTH+9 : 0]          af_sqr_add_all           ; 
    reg           [RATIO_SIZE-1 : 0]	      af_fir_size_r            ;
	
	reg    signed [DATA_WIDTH-1   : 0]        af_sqr_mul_coe           ;
	reg    signed [2*DATA_WIDTH+8 : 0]	      af_sqr_mul               ;
	reg    signed [DATA_WIDTH-1   : 0]	      af_sqr_mean_out          ;
		
	reg    signed [DATA_WIDTH-1 : 0]          af_in_da_r               ;
	reg                                       af_in_eof_en             ;
	reg                                       af_in_stream_en          ;
	reg                                       af_in_stream_en_1d       ;
	wire                                      af_in_stream_en_1d_bufg  ;
	
	reg           [19:0]                      af_in_cnt                ;
	reg           [19:0]                      af_out_stream_cnt        ;
	reg           [19:0]                      af_out_cnt               ;
	reg                                       af_out_vld_r             ;
	wire                                      af_out_vld_w             ;

	integer                            		  af_x_index               ;
	integer                            		  af_y_index               ;
	
	genvar                                    af_p                     ;

	wire          [FIFO_WIDTH*(FIR_MAX_SIZE)-1 : 0]   af_buf_in_da     ;
	wire          [FIFO_WIDTH*(FIR_MAX_SIZE)-1 : 0]   af_buf_out_da    ;
	wire          [(FIR_MAX_SIZE-1) : 0]              af_buf_prof_full ;
	wire          [(FIR_MAX_SIZE-1) : 0]              af_buf_wr        ;
	wire          [(FIR_MAX_SIZE-1) : 0]              af_buf_rd        ;
	reg           [(FIR_MAX_SIZE-1) : 0]              af_buf_rd_1d     ;
	reg                                               af_buf_rst       ;

	
	
	// ********************* high fanout signals ********************* //
    BUFG BUFG_af_inst1  ( .O(af_sqr_rst_n_bufg      ), .I(af_sqr_rst_n       ));
    BUFG BUFG_af_inst2  ( .O(af_in_stream_en_1d_bufg), .I(af_in_stream_en_1d ));
	
	

	// ************************* line buffers ************************ // 
	
	assign af_buf_in_da[FIFO_WIDTH*(FIR_MAX_SIZE)-1 : FIFO_WIDTH] = af_buf_out_da[FIFO_WIDTH*(FIR_MAX_SIZE-1)-1 : 0];
	assign af_buf_in_da[FIFO_WIDTH-1 : 0] = af_in_da_r;
	assign af_buf_rd = af_buf_prof_full[(FIR_MAX_SIZE)-1 : 0] & {(FIR_MAX_SIZE){af_in_stream_en}};
	assign af_buf_wr[(FIR_MAX_SIZE)-1 : 1] = af_buf_prof_full[(FIR_MAX_SIZE-1)-1 : 0] & {(FIR_MAX_SIZE-1){af_in_stream_en}};
	assign af_buf_wr[0] = af_in_stream_en;
	
	// af_buf_rst
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_buf_rst <= 1'b1;
		end
		else if((af_out_stream_cnt == (af_in_cnt - 'd1)) && (af_out_stream_cnt != 'd0)) begin
			af_buf_rst <= 1'b1;
		end
		else begin
			af_buf_rst <= 1'b0;
		end
	end
	
	generate 
		for (af_p = 0; af_p < (FIR_MAX_SIZE); af_p = af_p + 1) begin:
			af_line_buffers 
				line_buffer af_line_buffer_inst    (
				.clk                               (clk                                                           ),             
				.rst                               (af_buf_rst                                                    ),           
				.din                               (af_buf_in_da[af_p*FIFO_WIDTH+FIFO_WIDTH-1 : af_p*FIFO_WIDTH]  ),             
				.wr_en                             (af_buf_wr[af_p]                                               ),         
				.rd_en                             (af_buf_rd[af_p]                                               ),         
				.dout                              (af_buf_out_da[af_p*FIFO_WIDTH+FIFO_WIDTH-1 : af_p*FIFO_WIDTH] ),           
				.full                              (                                                              ),           
				.empty                             (                                                              ),         
				.valid                             (                                                              ),         
				.prog_full                         (af_buf_prof_full[af_p]                                        ),  
				.wr_rst_busy                       (                                                              ), 
				.rd_rst_busy                       (                                                              )  
				                                                                                                  );
		end
	endgenerate
	
	// ************************* stream ctrl ************************* // 
	// af_in_da_r
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_in_da_r <= 'b0;
		end
		else if(af_in_vld == 1'b1) begin
			af_in_da_r <= af_in_da;
		end
		else begin
			af_in_da_r <= 'b0;
		end
	end

	// af_in_eof_en
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_in_eof_en <= 1'b0;
		end
		else if(af_in_bof == 1'b1) begin
			af_in_eof_en <= 1'b0;
		end
		else if(af_in_eof == 1'b1)begin
			af_in_eof_en <= 1'b1;
		end
	end
	
	// af_in_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_in_cnt <= 'd0;
		end
		else if(af_in_bof == 1'b1) begin
			af_in_cnt <= 'd1;
		end
		else if(af_in_vld == 1'b1) begin
			af_in_cnt <= af_in_cnt + 'd1;
		end
	end	

	// af_out_stream_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_out_stream_cnt <= 'd0;
		end
		else if(af_in_bof == 1'b1) begin
			af_out_stream_cnt <= 'd0;
		end
		else if(af_out_vld_r == 1'b1) begin
			af_out_stream_cnt <= af_out_stream_cnt + 'd1;
		end
	end	
	
	// af_out_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_out_cnt <= 'd0;
		end
		else if(af_in_bof == 1'b1) begin
			af_out_cnt <= 'd0;
		end
		else if(af_out_vld_w == 1'b1) begin
			af_out_cnt <= af_out_cnt + 'd1;
		end
	end	

	// af_out_vld_r
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_out_vld_r <= 1'b0;
		end
		else if(af_in_cnt < AF_IN_BOF_JUDGE) begin
			af_out_vld_r <= 1'b0;
		end
		else begin
			af_out_vld_r <= af_in_stream_en;
		end
	end
	
	// af_in_stream_en
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_in_stream_en <= 1'b0;
		end
		else if(af_in_vld == 1'b1) begin
			af_in_stream_en <= 1'b1;
		end
		else if(af_out_stream_cnt >= (af_in_cnt - 'd2)) begin
			af_in_stream_en <= 1'b0;
		end
		else if(af_in_eof_en == 1'b1) begin
			af_in_stream_en <= 1'b1;
		end
		else begin
			af_in_stream_en <= 1'b0;
		end
	end
	
	// af_in_stream_en_1d 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_in_stream_en_1d <= 1'b0;
		end
		else begin
			af_in_stream_en_1d <= af_in_stream_en;
		end
	end	
	
	
	// ****************** square windows assignment ****************** //	
	// af_sqr_rst_n
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_sqr_rst_n <= 1'b0;
		end
		else if(af_out_cnt == af_in_cnt) begin
			af_sqr_rst_n <= 1'b0;
		end
		else begin
			af_sqr_rst_n <= 1'b1;
		end
	end
	
	// af_buf_rd_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_buf_rd_1d <= 'b0;
		end
		else begin
			af_buf_rd_1d <= af_buf_rd;
		end
	end
	
	always @ (posedge clk or negedge af_sqr_rst_n_bufg) begin
		if(af_sqr_rst_n_bufg == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1); af_y_index = af_y_index + 1) begin
					af_sqr[af_x_index][af_y_index] <= 'b0;
				end			
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				af_sqr[af_x_index][31] <= 'b0;
			end			
			for (af_y_index = 0; af_y_index < FIR_MAX_SIZE; af_y_index = af_y_index + 1) begin
				af_sqr[31][af_y_index] <= 'b0;
			end			

			af_sqr[0][0]   <=  (af_buf_rd_1d[0]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*0 +DATA_WIDTH-1  :  FIFO_WIDTH*0 ]  :  af_sqr[0][0] ;
			af_sqr[0][1]   <=  (af_buf_rd_1d[1]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*1 +DATA_WIDTH-1  :  FIFO_WIDTH*1 ]  :  af_sqr[0][1] ;
			af_sqr[0][2]   <=  (af_buf_rd_1d[2]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*2 +DATA_WIDTH-1  :  FIFO_WIDTH*2 ]  :  af_sqr[0][2] ;
			af_sqr[0][3]   <=  (af_buf_rd_1d[3]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*3 +DATA_WIDTH-1  :  FIFO_WIDTH*3 ]  :  af_sqr[0][3] ;
			af_sqr[0][4]   <=  (af_buf_rd_1d[4]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*4 +DATA_WIDTH-1  :  FIFO_WIDTH*4 ]  :  af_sqr[0][4] ;
			af_sqr[0][5]   <=  (af_buf_rd_1d[5]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*5 +DATA_WIDTH-1  :  FIFO_WIDTH*5 ]  :  af_sqr[0][5] ;
			af_sqr[0][6]   <=  (af_buf_rd_1d[6]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*6 +DATA_WIDTH-1  :  FIFO_WIDTH*6 ]  :  af_sqr[0][6] ;
			af_sqr[0][7]   <=  (af_buf_rd_1d[7]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*7 +DATA_WIDTH-1  :  FIFO_WIDTH*7 ]  :  af_sqr[0][7] ;
			af_sqr[0][8]   <=  (af_buf_rd_1d[8]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*8 +DATA_WIDTH-1  :  FIFO_WIDTH*8 ]  :  af_sqr[0][8] ;
			af_sqr[0][9]   <=  (af_buf_rd_1d[9]  == 1'b1)?  af_buf_out_da[FIFO_WIDTH*9 +DATA_WIDTH-1  :  FIFO_WIDTH*9 ]  :  af_sqr[0][9] ;
			af_sqr[0][10]  <=  (af_buf_rd_1d[10] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*10+DATA_WIDTH-1  :  FIFO_WIDTH*10]  :  af_sqr[0][10];
			af_sqr[0][11]  <=  (af_buf_rd_1d[11] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*11+DATA_WIDTH-1  :  FIFO_WIDTH*11]  :  af_sqr[0][11];
			af_sqr[0][12]  <=  (af_buf_rd_1d[12] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*12+DATA_WIDTH-1  :  FIFO_WIDTH*12]  :  af_sqr[0][12];
			af_sqr[0][13]  <=  (af_buf_rd_1d[13] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*13+DATA_WIDTH-1  :  FIFO_WIDTH*13]  :  af_sqr[0][13];
			af_sqr[0][14]  <=  (af_buf_rd_1d[14] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*14+DATA_WIDTH-1  :  FIFO_WIDTH*14]  :  af_sqr[0][14];
			af_sqr[0][15]  <=  (af_buf_rd_1d[15] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*15+DATA_WIDTH-1  :  FIFO_WIDTH*15]  :  af_sqr[0][15];
			af_sqr[0][16]  <=  (af_buf_rd_1d[16] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*16+DATA_WIDTH-1  :  FIFO_WIDTH*16]  :  af_sqr[0][16];
			af_sqr[0][17]  <=  (af_buf_rd_1d[17] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*17+DATA_WIDTH-1  :  FIFO_WIDTH*17]  :  af_sqr[0][17];
			af_sqr[0][18]  <=  (af_buf_rd_1d[18] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*18+DATA_WIDTH-1  :  FIFO_WIDTH*18]  :  af_sqr[0][18];
			af_sqr[0][19]  <=  (af_buf_rd_1d[19] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*19+DATA_WIDTH-1  :  FIFO_WIDTH*19]  :  af_sqr[0][19];
			af_sqr[0][20]  <=  (af_buf_rd_1d[20] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*20+DATA_WIDTH-1  :  FIFO_WIDTH*20]  :  af_sqr[0][20];
			af_sqr[0][21]  <=  (af_buf_rd_1d[21] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*21+DATA_WIDTH-1  :  FIFO_WIDTH*21]  :  af_sqr[0][21];
			af_sqr[0][22]  <=  (af_buf_rd_1d[22] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*22+DATA_WIDTH-1  :  FIFO_WIDTH*22]  :  af_sqr[0][22];
			af_sqr[0][23]  <=  (af_buf_rd_1d[23] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*23+DATA_WIDTH-1  :  FIFO_WIDTH*23]  :  af_sqr[0][23];
			af_sqr[0][24]  <=  (af_buf_rd_1d[24] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*24+DATA_WIDTH-1  :  FIFO_WIDTH*24]  :  af_sqr[0][24];
			af_sqr[0][25]  <=  (af_buf_rd_1d[25] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*25+DATA_WIDTH-1  :  FIFO_WIDTH*25]  :  af_sqr[0][25];
			af_sqr[0][26]  <=  (af_buf_rd_1d[26] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*26+DATA_WIDTH-1  :  FIFO_WIDTH*26]  :  af_sqr[0][26];
			af_sqr[0][27]  <=  (af_buf_rd_1d[27] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*27+DATA_WIDTH-1  :  FIFO_WIDTH*27]  :  af_sqr[0][27];
			af_sqr[0][28]  <=  (af_buf_rd_1d[28] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*28+DATA_WIDTH-1  :  FIFO_WIDTH*28]  :  af_sqr[0][28];
			af_sqr[0][29]  <=  (af_buf_rd_1d[29] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*29+DATA_WIDTH-1  :  FIFO_WIDTH*29]  :  af_sqr[0][29];
			af_sqr[0][30]  <=  (af_buf_rd_1d[30] == 1'b1)?  af_buf_out_da[FIFO_WIDTH*30+DATA_WIDTH-1  :  FIFO_WIDTH*30]  :  af_sqr[0][30];
			
			for (af_x_index = 1; af_x_index < FIR_MAX_SIZE; af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < FIR_MAX_SIZE; af_y_index = af_y_index + 1) begin
					af_sqr[af_x_index][af_y_index] <= (af_in_stream_en_1d_bufg == 1'b1)? af_sqr[af_x_index-1][af_y_index] : af_sqr[af_x_index][af_y_index];
				end			
			end
		end
	end
	
	// filter size
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_fir_size_r <= 3'd7;
		end
		else begin
			af_fir_size_r <= (af_in_stream_en == 1'b1)? af_fir_size : af_fir_size_r;
		end
	end
	
	// af_sqr_mask
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1); af_y_index = af_y_index + 1) begin
					af_sqr_mask[af_x_index][af_y_index] <= 1'b0;
				end			
			end
		end
		else begin 
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1); af_y_index = af_y_index + 1) begin
					if((af_x_index >= ((FIR_MAX_SIZE-1)/2 - af_fir_size_r*2)) && 
					   (af_x_index <= ((FIR_MAX_SIZE-1)/2 + af_fir_size_r*2)) &&
					   (af_y_index >= ((FIR_MAX_SIZE-1)/2 - af_fir_size_r*2)) &&
					   (af_y_index <= ((FIR_MAX_SIZE-1)/2 + af_fir_size_r*2))   )
						af_sqr_mask[af_x_index][af_y_index] <= 1'b1;
					else
						af_sqr_mask[af_x_index][af_y_index] <= 1'b0;
				end			
			end
		end
	end

	// af_sqr_1d
	always @ (posedge clk or negedge af_sqr_rst_n_bufg) begin
		if(af_sqr_rst_n_bufg == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1); af_y_index = af_y_index + 1) begin
					af_sqr_1d[af_x_index][af_y_index] <= 'd0;
				end			
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1); af_y_index = af_y_index + 1) begin
					af_sqr_1d[af_x_index][af_y_index] <= (af_sqr_mask[af_x_index][af_y_index] == 1'b0)? 'd0 : af_sqr[af_x_index][af_y_index];
				end			
			end
		end
	end
																		
	// *********************** pipeline adders *********************** // 
	// af_sqr_add_2d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/2; af_y_index = af_y_index + 1) begin
					af_sqr_add_2d[af_x_index][af_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/2; af_y_index = af_y_index + 1) begin
					af_sqr_add_2d[af_x_index][af_y_index] <= af_sqr_1d[af_x_index][af_y_index*2] + af_sqr_1d[af_x_index][af_y_index*2+1];
				end
			end
		end
	end
	
	// af_sqr_add_3d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/4; af_y_index = af_y_index + 1) begin
					af_sqr_add_3d[af_x_index][af_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/4; af_y_index = af_y_index + 1) begin
					af_sqr_add_3d[af_x_index][af_y_index] <= af_sqr_add_2d[af_x_index][af_y_index*2] + af_sqr_add_2d[af_x_index][af_y_index*2+1];
				end
			end
		end
	end

	// af_sqr_add_4d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/8; af_y_index = af_y_index + 1) begin
					af_sqr_add_4d[af_x_index][af_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/8; af_y_index = af_y_index + 1) begin
					af_sqr_add_4d[af_x_index][af_y_index] <= af_sqr_add_3d[af_x_index][af_y_index*2] + af_sqr_add_3d[af_x_index][af_y_index*2+1];
				end
			end
		end
	end

	// af_sqr_add_5d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/16; af_y_index = af_y_index + 1) begin
					af_sqr_add_5d[af_x_index][af_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/16; af_y_index = af_y_index + 1) begin
					af_sqr_add_5d[af_x_index][af_y_index] <= af_sqr_add_4d[af_x_index][af_y_index*2] + af_sqr_add_4d[af_x_index][af_y_index*2+1];
				end
			end
		end
	end

	// af_sqr_add_6d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/32; af_y_index = af_y_index + 1) begin
					af_sqr_add_6d[af_x_index][af_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1); af_x_index = af_x_index + 1) begin
				for (af_y_index = 0; af_y_index < (FIR_MAX_SIZE+1)/32; af_y_index = af_y_index + 1) begin
					af_sqr_add_6d[af_x_index][af_y_index] <= af_sqr_add_5d[af_x_index][af_y_index*2] + af_sqr_add_5d[af_x_index][af_y_index*2+1];
				end
			end
		end
	end

	// af_sqr_add_7d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/2; af_x_index = af_x_index + 1) begin
				af_sqr_add_7d[af_x_index][0] <= 'b0;
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/2; af_x_index = af_x_index + 1) begin
				af_sqr_add_7d[af_x_index][0] <= af_sqr_add_6d[af_x_index*2][0] + af_sqr_add_6d[af_x_index*2+1][0];
			end
		end
	end

	// af_sqr_add_8d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/4; af_x_index = af_x_index + 1) begin
				af_sqr_add_8d[af_x_index][0] <= 'b0;
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/4; af_x_index = af_x_index + 1) begin
				af_sqr_add_8d[af_x_index][0] <= af_sqr_add_7d[af_x_index*2][0] + af_sqr_add_7d[af_x_index*2+1][0];
			end
		end
	end

	// af_sqr_add_9d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/8; af_x_index = af_x_index + 1) begin
				af_sqr_add_9d[af_x_index][0] <= 'b0;
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/8; af_x_index = af_x_index + 1) begin
				af_sqr_add_9d[af_x_index][0] <= af_sqr_add_8d[af_x_index*2][0] + af_sqr_add_8d[af_x_index*2+1][0];
			end
		end
	end

	// af_sqr_add_ad
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/16; af_x_index = af_x_index + 1) begin
				af_sqr_add_ad[af_x_index][0] <= 'b0;
			end
		end
		else begin
			for (af_x_index = 0; af_x_index < (FIR_MAX_SIZE+1)/16; af_x_index = af_x_index + 1) begin
				af_sqr_add_ad[af_x_index][0] <= af_sqr_add_9d[af_x_index*2][0] + af_sqr_add_9d[af_x_index*2+1][0];
			end
		end
	end
	
	// af_sqr_add_all
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_sqr_add_all <= 'b0;
		end
		else begin
			af_sqr_add_all <= af_sqr_add_ad[0][0] + af_sqr_add_ad[1][0];
		end
	end
		
																		
	// ****************** calculation of meanfilter ****************** //
	// LUT af_div_coe
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_sqr_mul_coe <= 'd0;
		end
		else begin
			af_sqr_mul_coe <= af_div_coe[af_fir_size_r];
		end
	end
	
	// mean calculation
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_sqr_mul <= 'd0;
		end
		else begin
			af_sqr_mul <= af_sqr_mul_coe * af_sqr_add_all;
		end
	end

	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_sqr_mean_out <= 'd0;
		end
		else begin
			af_sqr_mean_out <= {af_sqr_mul[2*DATA_WIDTH+8], af_sqr_mul[DATA_WIDTH+16-2 : 16]};
		end
	end
	
	// af_out_vld_delay
	af_out_vld_delay af_out_vld_delay0 (.D(af_out_vld_r), .CLK(clk), .Q(af_out_vld_w));
																		
	// ************************ signals output *********************** //
	// af_out_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_out_vld <= 'b0;
		end
		else begin
			af_out_vld <= af_out_vld_w;
		end
	end
	
	// af_out_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_out_da <= 'd0;
		end
		else begin
			af_out_da <= (af_out_vld_w == 1'b1)? af_sqr_mean_out : 'd0;
		end
	end
	
	// af_out_bof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_out_bof <= 'b0;
		end
		else begin
			af_out_bof <= (af_out_cnt == 0) && (af_out_vld_w == 1'b1);
		end
	end
	
	// af_out_eof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			af_out_eof <= 'b0;
		end
		else begin
			af_out_eof <= (af_out_cnt == (af_in_cnt - 'd1)) && (af_out_vld_w == 1'b1);
		end
	end

endmodule