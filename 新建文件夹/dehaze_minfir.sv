`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/05 14:58:42
// Design Name: 
// Module Name: dehaze_minfir
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


module dehaze_minfir                 #(      
	// declare parameters
	// filter size must be odd and (power of 2) minus 1.
	parameter                          		  FIR_MAX_SIZE = 15        , 
	parameter                          		  RATIO_SIZE   = 3         ,
	parameter                          		  FIFO_WIDTH   = 18        , 
	parameter                          		  DATA_WIDTH   = 8         ,
	parameter                          		  LINE_LENGTH  = 960       ,
	parameter                          		  MF_IN_BOF_JUDGE   = 960*8+7 )
									  (
	// logic clock and active-low reset
	input                              		  clk                      ,
	input                              		  rst_n                    ,
	
	// data in
	input         [DATA_WIDTH-1 : 0]          mf_in_da                 ,
	input                              		  mf_in_vld                ,
	
	// stay high for one cycle aligned to the first frame data
	input                              		  mf_in_bof                ,
	// stay high for one cycle aligned to the last frame data
	input                                     mf_in_eof                ,
	
	// adjustable-size 
	input         [RATIO_SIZE-1 : 0]          mf_fir_size              ,
	
	// data out
	output    reg [DATA_WIDTH-1 : 0]          mf_out_da                ,
	output    reg                             mf_out_vld               ,
	output    reg                             mf_out_bof               ,
	output    reg                             mf_out_eof               	
	                                                                  );
																	  
																	  
	// ************************* define variable types ********************* // 

	reg                                       mf_sqr_rst_n             ;
	wire                                      mf_sqr_rst_n_bufg        ;																	  
																	  
	reg           [DATA_WIDTH-1 : 0]          mf_sqr      	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
	reg           [DATA_WIDTH-1 : 0]          mf_sqr_1d   	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;
	reg                                       mf_sqr_mask 	      [FIR_MAX_SIZE           : 0][FIR_MAX_SIZE           : 0] ;

	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_2d      [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/2-1   : 0] ;
	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_3d      [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/4-1   : 0] ;
	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_4d      [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/8-1   : 0] ;
	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_5d      [FIR_MAX_SIZE           : 0][(FIR_MAX_SIZE+1)/16-1  : 0] ;
	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_6d      [(FIR_MAX_SIZE+1)/2-1   : 0][(FIR_MAX_SIZE+1)/16-1  : 0] ;
	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_7d      [(FIR_MAX_SIZE+1)/4-1   : 0][(FIR_MAX_SIZE+1)/16-1  : 0] ;
	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_8d      [(FIR_MAX_SIZE+1)/8-1   : 0][(FIR_MAX_SIZE+1)/16-1  : 0] ;

	reg           [DATA_WIDTH-1 : 0]          mf_sqr_comp_all          ; 
    reg           [RATIO_SIZE-1 : 0]	      mf_fir_size_r            ;
																	  
	reg           [DATA_WIDTH-1 : 0]          mf_in_da_r               ;
	reg                                       mf_in_eof_en             ;
	reg                                       mf_in_stream_en          ;
	reg                                       mf_in_stream_en_1d       ;
	wire                                      mf_in_stream_en_1d_bufg  ;
																	  
	reg           [19:0]                      mf_in_cnt                ;
	reg           [19:0]                      mf_out_stream_cnt        ;
	reg           [19:0]                      mf_out_cnt               ;
	reg                                       mf_out_vld_r             ;
	reg                                       mf_out_vld_w             ;
																	  
	integer                            		  mf_x_index               ;
	integer                            		  mf_y_index               ;
																	   
	genvar                                    mf_p                     ;

	wire          [FIFO_WIDTH*(FIR_MAX_SIZE)-1 : 0]   mf_buf_in_da     ;
	wire          [FIFO_WIDTH*(FIR_MAX_SIZE)-1 : 0]   mf_buf_out_da    ;
	wire          [(FIR_MAX_SIZE-1) : 0]              mf_buf_prof_full ;
	wire          [(FIR_MAX_SIZE-1) : 0]              mf_buf_wr        ;
	wire          [(FIR_MAX_SIZE-1) : 0]              mf_buf_rd        ;
	reg           [(FIR_MAX_SIZE-1) : 0]              mf_buf_rd_1d     ;
	reg                                               mf_buf_rst       ;
																	  
																  
	// ********************* high fanout signals ********************* //
	
    BUFG BUFG_mf_inst1  ( .O(mf_sqr_rst_n_bufg      ), .I(mf_sqr_rst_n       ));
    BUFG BUFG_mf_inst2  ( .O(mf_in_stream_en_1d_bufg), .I(mf_in_stream_en_1d ));							  
 
 
	// ************************* line buffers ************************ // 
	
	assign mf_buf_in_da[FIFO_WIDTH*(FIR_MAX_SIZE)-1 : FIFO_WIDTH] = mf_buf_out_da[FIFO_WIDTH*(FIR_MAX_SIZE-1)-1 : 0];
	assign mf_buf_in_da[FIFO_WIDTH-1 : 0] = mf_in_da_r;
	assign mf_buf_rd = mf_buf_prof_full[(FIR_MAX_SIZE)-1 : 0] & {(FIR_MAX_SIZE){mf_in_stream_en}};
	assign mf_buf_wr[(FIR_MAX_SIZE)-1 : 1] = mf_buf_prof_full[(FIR_MAX_SIZE-1)-1 : 0] & {(FIR_MAX_SIZE-1){mf_in_stream_en}};
	assign mf_buf_wr[0] = mf_in_stream_en;
	
	// mf_buf_rst
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_buf_rst <= 1'b1;
		end
		else if((mf_out_stream_cnt == (mf_in_cnt - 'd1)) && (mf_out_stream_cnt != 'd0)) begin
			mf_buf_rst <= 1'b1;
		end
		else begin
			mf_buf_rst <= 1'b0;
		end
	end
	
	generate 
		for (mf_p = 0; mf_p < (FIR_MAX_SIZE); mf_p = mf_p + 1) begin:
			mf_line_buffers 
				line_buffer mf_line_buffer_inst    (
				.clk                               (clk                                                           ),             
				.rst                               (mf_buf_rst                                                    ),           
				.din                               (mf_buf_in_da[mf_p*FIFO_WIDTH+FIFO_WIDTH-1 : mf_p*FIFO_WIDTH]  ),             
				.wr_en                             (mf_buf_wr[mf_p]                                               ),         
				.rd_en                             (mf_buf_rd[mf_p]                                               ),         
				.dout                              (mf_buf_out_da[mf_p*FIFO_WIDTH+FIFO_WIDTH-1 : mf_p*FIFO_WIDTH] ),           
				.full                              (                                                              ),           
				.empty                             (                                                              ),         
				.valid                             (                                                              ),         
				.prog_full                         (mf_buf_prof_full[mf_p]                                        ),  
				.wr_rst_busy                       (                                                              ), 
				.rd_rst_busy                       (                                                              )  
				                                                                                                  );
		end
	endgenerate
 
 
	// ************************* stream ctrl ************************* // 
	// mf_in_da_r
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_in_da_r <= {DATA_WIDTH{1'b1}};
		end
		else if(mf_in_vld == 1'b1) begin
			mf_in_da_r <= mf_in_da;
		end
		else begin
			mf_in_da_r <= {DATA_WIDTH{1'b1}};
		end
	end

	// mf_in_eof_en
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_in_eof_en <= 1'b0;
		end
		else if(mf_in_bof == 1'b1) begin
			mf_in_eof_en <= 1'b0;
		end
		else if(mf_in_eof == 1'b1)begin
			mf_in_eof_en <= 1'b1;
		end
	end
	
	// mf_in_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_in_cnt <= 'd0;
		end
		else if(mf_in_bof == 1'b1) begin
			mf_in_cnt <= 'd1;
		end
		else if(mf_in_vld == 1'b1) begin
			mf_in_cnt <= mf_in_cnt + 'd1;
		end
	end	

	// mf_out_stream_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_out_stream_cnt <= 'd0;
		end
		else if(mf_in_bof == 1'b1) begin
			mf_out_stream_cnt <= 'd0;
		end
		else if(mf_out_vld_r == 1'b1) begin
			mf_out_stream_cnt <= mf_out_stream_cnt + 'd1;
		end
	end	
	
	// mf_out_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_out_cnt <= 'd0;
		end
		else if(mf_in_bof == 1'b1) begin
			mf_out_cnt <= 'd0;
		end
		else if(mf_out_vld_w == 1'b1) begin
			mf_out_cnt <= mf_out_cnt + 'd1;
		end
	end	

	// mf_out_vld_r
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_out_vld_r <= 1'b0;
		end
		else if(mf_in_cnt < MF_IN_BOF_JUDGE) begin
			mf_out_vld_r <= 1'b0;
		end
		else begin
			mf_out_vld_r <= mf_in_stream_en;
		end
	end
	
	// mf_in_stream_en
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_in_stream_en <= 1'b0;
		end
		else if(mf_in_vld == 1'b1) begin
			mf_in_stream_en <= 1'b1;
		end
		else if(mf_out_stream_cnt >= (mf_in_cnt - 'd2)) begin
			mf_in_stream_en <= 1'b0;
		end
		else if(mf_in_eof_en == 1'b1) begin
			mf_in_stream_en <= 1'b1;
		end
		else begin
			mf_in_stream_en <= 1'b0;
		end
	end
	
	// mf_in_stream_en_1d 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_in_stream_en_1d <= 1'b0;
		end
		else begin
			mf_in_stream_en_1d <= mf_in_stream_en;
		end
	end	
 
	// ****************** square windows assignment ****************** //	
	// mf_sqr_rst_n
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_sqr_rst_n <= 1'b0;
		end
		else if(mf_out_cnt == mf_in_cnt) begin
			mf_sqr_rst_n <= 1'b0;
		end
		else begin
			mf_sqr_rst_n <= 1'b1;
		end
	end
	
	// mf_buf_rd_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_buf_rd_1d <= 'b0;
		end
		else begin
			mf_buf_rd_1d <= mf_buf_rd;
		end
	end
	
	always @ (posedge clk or negedge mf_sqr_rst_n_bufg) begin
		if(mf_sqr_rst_n_bufg == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1); mf_y_index = mf_y_index + 1) begin
					mf_sqr[mf_x_index][mf_y_index] <= {DATA_WIDTH{1'b1}};
				end			
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				mf_sqr[mf_x_index][FIR_MAX_SIZE] <= {DATA_WIDTH{1'b1}};
			end			
			for (mf_y_index = 0; mf_y_index < FIR_MAX_SIZE; mf_y_index = mf_y_index + 1) begin
				mf_sqr[FIR_MAX_SIZE][mf_y_index] <= {DATA_WIDTH{1'b1}};
			end			

			mf_sqr[0][0]   <=  (mf_buf_rd_1d[0]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*0 +DATA_WIDTH-1  :  FIFO_WIDTH*0 ]  :  mf_sqr[0][0] ;
			mf_sqr[0][1]   <=  (mf_buf_rd_1d[1]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*1 +DATA_WIDTH-1  :  FIFO_WIDTH*1 ]  :  mf_sqr[0][1] ;
			mf_sqr[0][2]   <=  (mf_buf_rd_1d[2]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*2 +DATA_WIDTH-1  :  FIFO_WIDTH*2 ]  :  mf_sqr[0][2] ;
			mf_sqr[0][3]   <=  (mf_buf_rd_1d[3]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*3 +DATA_WIDTH-1  :  FIFO_WIDTH*3 ]  :  mf_sqr[0][3] ;
			mf_sqr[0][4]   <=  (mf_buf_rd_1d[4]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*4 +DATA_WIDTH-1  :  FIFO_WIDTH*4 ]  :  mf_sqr[0][4] ;
			mf_sqr[0][5]   <=  (mf_buf_rd_1d[5]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*5 +DATA_WIDTH-1  :  FIFO_WIDTH*5 ]  :  mf_sqr[0][5] ;
			mf_sqr[0][6]   <=  (mf_buf_rd_1d[6]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*6 +DATA_WIDTH-1  :  FIFO_WIDTH*6 ]  :  mf_sqr[0][6] ;
			mf_sqr[0][7]   <=  (mf_buf_rd_1d[7]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*7 +DATA_WIDTH-1  :  FIFO_WIDTH*7 ]  :  mf_sqr[0][7] ;
			mf_sqr[0][8]   <=  (mf_buf_rd_1d[8]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*8 +DATA_WIDTH-1  :  FIFO_WIDTH*8 ]  :  mf_sqr[0][8] ;
			mf_sqr[0][9]   <=  (mf_buf_rd_1d[9]  == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*9 +DATA_WIDTH-1  :  FIFO_WIDTH*9 ]  :  mf_sqr[0][9] ;
			mf_sqr[0][10]  <=  (mf_buf_rd_1d[10] == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*10+DATA_WIDTH-1  :  FIFO_WIDTH*10]  :  mf_sqr[0][10];
			mf_sqr[0][11]  <=  (mf_buf_rd_1d[11] == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*11+DATA_WIDTH-1  :  FIFO_WIDTH*11]  :  mf_sqr[0][11];
			mf_sqr[0][12]  <=  (mf_buf_rd_1d[12] == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*12+DATA_WIDTH-1  :  FIFO_WIDTH*12]  :  mf_sqr[0][12];
			mf_sqr[0][13]  <=  (mf_buf_rd_1d[13] == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*13+DATA_WIDTH-1  :  FIFO_WIDTH*13]  :  mf_sqr[0][13];
			mf_sqr[0][14]  <=  (mf_buf_rd_1d[14] == 1'b1)?  mf_buf_out_da[FIFO_WIDTH*14+DATA_WIDTH-1  :  FIFO_WIDTH*14]  :  mf_sqr[0][14];
			
			for (mf_x_index = 1; mf_x_index < FIR_MAX_SIZE; mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < FIR_MAX_SIZE; mf_y_index = mf_y_index + 1) begin
					mf_sqr[mf_x_index][mf_y_index] <= (mf_in_stream_en_1d_bufg == 1'b1)? mf_sqr[mf_x_index-1][mf_y_index] : mf_sqr[mf_x_index][mf_y_index];
				end			
			end
		end
	end
	
	// filter size
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_fir_size_r <= 3'd7;
		end
		else begin
			mf_fir_size_r <= (mf_in_stream_en == 1'b1)? mf_fir_size : mf_fir_size_r;
		end
	end
	
	// mf_sqr_mask
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1); mf_y_index = mf_y_index + 1) begin
					mf_sqr_mask[mf_x_index][mf_y_index] <= 1'b0;
				end			
			end
		end
		else begin 
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1); mf_y_index = mf_y_index + 1) begin
					if((mf_x_index >= ((FIR_MAX_SIZE-1)/2 - mf_fir_size_r)) && 
					   (mf_x_index <= ((FIR_MAX_SIZE-1)/2 + mf_fir_size_r)) &&
					   (mf_y_index >= ((FIR_MAX_SIZE-1)/2 - mf_fir_size_r)) &&
					   (mf_y_index <= ((FIR_MAX_SIZE-1)/2 + mf_fir_size_r))   )
						mf_sqr_mask[mf_x_index][mf_y_index] <= 1'b1;
					else
						mf_sqr_mask[mf_x_index][mf_y_index] <= 1'b0;
				end			
			end
		end
	end

	// mf_sqr_1d
	always @ (posedge clk or negedge mf_sqr_rst_n_bufg) begin
		if(mf_sqr_rst_n_bufg == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1); mf_y_index = mf_y_index + 1) begin
					mf_sqr_1d[mf_x_index][mf_y_index] <= {DATA_WIDTH{1'b1}};
				end			
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1); mf_y_index = mf_y_index + 1) begin
					mf_sqr_1d[mf_x_index][mf_y_index] <= (mf_sqr_mask[mf_x_index][mf_y_index] == 1'b0)? {DATA_WIDTH{1'b1}} : mf_sqr[mf_x_index][mf_y_index];
				end			
			end
		end
	end 
																		
	// ******************** pipeline comparators ********************* // 
	// mf_sqr_comp_2d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/2; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_2d[mf_x_index][mf_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/2; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_2d[mf_x_index][mf_y_index] <= (mf_sqr_1d[mf_x_index][mf_y_index*2] < mf_sqr_1d[mf_x_index][mf_y_index*2+1])? 
					                                           mf_sqr_1d[mf_x_index][mf_y_index*2] : mf_sqr_1d[mf_x_index][mf_y_index*2+1];
				end
			end
		end
	end
	
	// mf_sqr_comp_3d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/4; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_3d[mf_x_index][mf_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/4; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_3d[mf_x_index][mf_y_index] <= (mf_sqr_comp_2d[mf_x_index][mf_y_index*2] < mf_sqr_comp_2d[mf_x_index][mf_y_index*2+1])? 
					                                           mf_sqr_comp_2d[mf_x_index][mf_y_index*2] : mf_sqr_comp_2d[mf_x_index][mf_y_index*2+1];
				end
			end
		end
	end

	// mf_sqr_comp_4d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/8; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_4d[mf_x_index][mf_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/8; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_4d[mf_x_index][mf_y_index] <= (mf_sqr_comp_3d[mf_x_index][mf_y_index*2] < mf_sqr_comp_3d[mf_x_index][mf_y_index*2+1])? 
					                                           mf_sqr_comp_3d[mf_x_index][mf_y_index*2] : mf_sqr_comp_3d[mf_x_index][mf_y_index*2+1];
				end
			end
		end
	end

	// mf_sqr_comp_5d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/16; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_5d[mf_x_index][mf_y_index] <= 'b0;
				end
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1); mf_x_index = mf_x_index + 1) begin
				for (mf_y_index = 0; mf_y_index < (FIR_MAX_SIZE+1)/16; mf_y_index = mf_y_index + 1) begin
					mf_sqr_comp_5d[mf_x_index][mf_y_index] <= (mf_sqr_comp_4d[mf_x_index][mf_y_index*2] < mf_sqr_comp_4d[mf_x_index][mf_y_index*2+1])? 
					                                           mf_sqr_comp_4d[mf_x_index][mf_y_index*2] : mf_sqr_comp_4d[mf_x_index][mf_y_index*2+1];
				end
			end
		end
	end
 
	// mf_sqr_comp_6d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1)/2; mf_x_index = mf_x_index + 1) begin
				mf_sqr_comp_6d[mf_x_index][0] <= 'b0;
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1)/2; mf_x_index = mf_x_index + 1) begin
				mf_sqr_comp_6d[mf_x_index][0] <= (mf_sqr_comp_5d[mf_x_index*2][0] < mf_sqr_comp_5d[mf_x_index*2+1][0])? 
					                              mf_sqr_comp_5d[mf_x_index*2][0] : mf_sqr_comp_5d[mf_x_index*2+1][0];
			end
		end
	end

	// mf_sqr_comp_7d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1)/4; mf_x_index = mf_x_index + 1) begin
				mf_sqr_comp_7d[mf_x_index][0] <= 'b0;
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1)/4; mf_x_index = mf_x_index + 1) begin
				mf_sqr_comp_7d[mf_x_index][0] <= (mf_sqr_comp_6d[mf_x_index*2][0] < mf_sqr_comp_6d[mf_x_index*2+1][0])? 
					                              mf_sqr_comp_6d[mf_x_index*2][0] : mf_sqr_comp_6d[mf_x_index*2+1][0];
			end
		end
	end

	// mf_sqr_comp_8d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1)/8; mf_x_index = mf_x_index + 1) begin
				mf_sqr_comp_8d[mf_x_index][0] <= 'b0;
			end
		end
		else begin
			for (mf_x_index = 0; mf_x_index < (FIR_MAX_SIZE+1)/8; mf_x_index = mf_x_index + 1) begin
				mf_sqr_comp_8d[mf_x_index][0] <= (mf_sqr_comp_7d[mf_x_index*2][0] < mf_sqr_comp_7d[mf_x_index*2+1][0])? 
					                              mf_sqr_comp_7d[mf_x_index*2][0] : mf_sqr_comp_7d[mf_x_index*2+1][0];
			end
		end
	end

	// mf_sqr_comp_all
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_sqr_comp_all <= 'b0;
		end
		else begin
			mf_sqr_comp_all <= (mf_sqr_comp_8d[0][0] < mf_sqr_comp_8d[1][0])? 
					            mf_sqr_comp_8d[0][0] : mf_sqr_comp_8d[1][0];
		end
	end
	
	// mf_out_vld_delay
	mf_out_vld_delay mf_out_vld_delay0 (.D(mf_out_vld_r), .CLK(clk), .Q(mf_out_vld_w));
	
	
	// ************************ signals output *********************** //	
	// mf_out_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_out_vld <= 'b0;
		end
		else begin
			mf_out_vld <= mf_out_vld_w;
		end
	end
	
	// mf_out_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_out_da <= 'd0;
		end
		else begin
			mf_out_da <= (mf_out_vld_w == 1'b1)? mf_sqr_comp_all : 'd0;
		end
	end
	
	// mf_out_bof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_out_bof <= 'b0;
		end
		else begin
			mf_out_bof <= (mf_out_cnt == 0) && (mf_out_vld_w == 1'b1);
		end
	end
	
	// mf_out_eof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			mf_out_eof <= 'b0;
		end
		else begin
			mf_out_eof <= (mf_out_cnt == (mf_in_cnt - 'd1)) && (mf_out_vld_w == 1'b1);
		end
	end

endmodule
