`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/12 16:14:30
// Design Name: 
// Module Name: dehaze_streamMachine
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


module dehaze_streamMachine          #(      
	// declare parameters
	parameter                          		   BURST_LEN_WIDTH = 10        ,  
	parameter                          		   AF_DATA_WIDTH   = 18        ,  
	parameter                          		   VD_DATA_WIDTH   = 24        ,  
	parameter                          		   APP_ADDR_WIDTH  = 30        ,  
	parameter                          		   APP_DATA_WIDTH  = 512       ,
	parameter                                  GFIR_LAMTA      = 68        ) 
									  (
	// ddr inst
	input                                      st_ui_clk                   ,
	
	input                                      st_wr_da_req                ,
	input                                      st_wr_fsh                   ,
	output reg                                 st_wr_req                   ,
	output reg  [BURST_LEN_WIDTH-1 : 0]        st_wr_len                   ,
	output reg  [APP_ADDR_WIDTH-1  : 0]        st_wr_addr                  ,
	output      [APP_DATA_WIDTH-1  : 0]        st_wr_data                  ,
																		   
	input       [APP_DATA_WIDTH-1  : 0]        st_rd_data                  ,
	input                                      st_rd_vld                   ,
	input                                      st_rd_fsh                   ,
	output reg                                 st_rd_req                   ,
	output reg  [BURST_LEN_WIDTH-1 : 0]        st_rd_len                   ,
	output reg  [APP_ADDR_WIDTH-1  : 0]        st_rd_addr                  ,
									  
	// logic clock and active-low reset
	input                                      clk                         ,
	input                                      rst_n                       ,
		
	// data in
	input       [2*AF_DATA_WIDTH-1 : 0]        st_in_gp_da                 ,
	input                                      st_in_gp_vld                ,
	input                                      st_in_gp_bof                ,
	input                                      st_in_gp_eof                ,
		        
	input                              		   st_in_vd_hs                 ,
	input                              		   st_in_vd_vs                 ,
	input                              		   st_in_vd_de                 ,
	input       [VD_DATA_WIDTH-1   : 0]        st_in_vd_da                 ,

	// data out   
    output reg                                 st_out_vd_hs                ,
	output reg                                 st_out_vd_vs                ,
	output reg                                 st_out_vd_de                ,
	output reg  [VD_DATA_WIDTH-1   : 0]        st_out_vd_da                ,

	output reg                                 st_out_tf_hs                ,
	output reg                                 st_out_tf_vs                ,
	output reg                                 st_out_tf_de                ,
	output reg  [AF_DATA_WIDTH-1   : 0]        st_out_tf_da                
    )                                                                      ;
	
	
	// ************************ define variable types ******************** // 
    
    localparam                                 FIFO_DDR_WIDTH = 320        ;
    localparam                                 FIFO_OUT_WIDTH = 40         ;
    localparam                                 ST_BURST_LEN_L = 10'd480    ;
    localparam                                 ST_BURST_LEN_S = 10'd480    ;
	
    localparam                                 ST_CAL_SIZE    = 20'd64800  ;	
    localparam                                 ST_VD_HEAD_A   = 20'd0      ;
    localparam                                 ST_VD_HEAD_B   = 20'd259200 ;
    localparam                                 ST_GP_HEAD_A   = 20'd518400 ;
    localparam                                 ST_GP_HEAD_B   = 20'd583200 ;
    localparam                                 ST_TR_HEAD_A   = 20'd648000 ;
    localparam                                 ST_TR_HEAD_B   = 20'd712800 ;
    localparam                                 ST_MM_HEAD     = 20'd777600 ;
    localparam                                 ST_RG_HEAD     = 20'd842400 ;

    localparam                                 ST_VD_OUT_TSH1 = 12'd0      ;
    localparam                                 ST_VD_OUT_TSH2 = 12'd1120   ;

    localparam                                 ST_GL_IDLE     = 3'd0       ;
    localparam                                 ST_GL_VD_OUT   = 3'd1       ;
    localparam                                 ST_GL_TR_OUT   = 3'd2       ;
    localparam                                 ST_GL_VD_IN    = 3'd3       ;
    localparam                                 ST_GL_GP_IN    = 3'd4       ;
    localparam                                 ST_GL_CAL      = 3'd5       ;
															   
	localparam                                 ST_LC_IDLE     = 4'd0       ;
	localparam                                 ST_LC_IDLE1    = 4'd1       ;
	localparam                                 ST_LC_GP1      = 4'd2       ;
	localparam                                 ST_LC_MM1      = 4'd3       ;
	localparam                                 ST_LC_IDLE2    = 4'd4       ;
	localparam                                 ST_LC_GP2      = 4'd5       ;
	localparam                                 ST_LC_MM2      = 4'd6       ;
	localparam                                 ST_LC_RG2      = 4'd7       ;
	localparam                                 ST_LC_IDLE3    = 4'd8       ;
	localparam                                 ST_LC_GP3      = 4'd9       ;
	localparam                                 ST_LC_MM3      = 4'd10      ;
	localparam                                 ST_LC_RG3      = 4'd11      ;
	localparam                                 ST_LC_TR3      = 4'd12      ;
	
	//reg                                        st_fifo_rst                 ;
	
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_fifo_in_ddr_vd_di        ;
	wire        [FIFO_DDR_WIDTH-1  : 0]        st_fifo_in_ddr_vd_do        ;
	wire                                       st_fifo_in_ddr_vd_wr        ;
	wire                                       st_fifo_in_ddr_vd_rd        ;
	wire                                       st_fifo_in_ddr_vd_pemy      ;

	wire        [FIFO_OUT_WIDTH-1  : 0]        st_fifo_in_ddr_gp_di        ;
	wire        [FIFO_DDR_WIDTH-1  : 0]        st_fifo_in_ddr_gp_do        ;
	wire                                       st_fifo_in_ddr_gp_wr        ;
	wire                                       st_fifo_in_ddr_gp_rd        ;
	wire                                       st_fifo_in_ddr_gp_pemy      ;

	wire        [FIFO_OUT_WIDTH-1  : 0]        st_fifo_in_ddr_mm_di        ;
	wire        [FIFO_DDR_WIDTH-1  : 0]        st_fifo_in_ddr_mm_do        ;
	wire                                       st_fifo_in_ddr_mm_wr        ;
	wire                                       st_fifo_in_ddr_mm_rd        ;
	wire                                       st_fifo_in_ddr_mm_pemy      ;

	wire        [FIFO_OUT_WIDTH-1  : 0]        st_fifo_in_ddr_rg_di        ;
	wire        [FIFO_DDR_WIDTH-1  : 0]        st_fifo_in_ddr_rg_do        ;
	wire                                       st_fifo_in_ddr_rg_wr        ;
	wire                                       st_fifo_in_ddr_rg_rd        ;
	wire                                       st_fifo_in_ddr_rg_pemy      ;
	
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_fifo_in_ddr_tr_di        ;
	wire        [FIFO_DDR_WIDTH-1  : 0]        st_fifo_in_ddr_tr_do        ;
	wire                                       st_fifo_in_ddr_tr_wr        ;
	wire                                       st_fifo_in_ddr_tr_rd        ;
	wire                                       st_fifo_in_ddr_tr_pemy      ;
	
	wire        [FIFO_DDR_WIDTH-1  : 0]        st_ddr_out_fifo_vd_di       ;
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_ddr_out_fifo_vd_do       ;
	wire                                       st_ddr_out_fifo_vd_wr       ;
	wire                                       st_ddr_out_fifo_vd_rd       ;
	wire                                       st_ddr_out_fifo_vd_pful     ;
	
	wire        [FIFO_DDR_WIDTH-1  : 0]        st_ddr_out_fifo_tr_di       ;
	wire                                       st_ddr_out_fifo_tr_wr       ;
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_ddr_out_fifo_tr_do0      ;
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_ddr_out_fifo_tr_do1      ;
	wire                                       st_ddr_out_fifo_tr_rd0      ;
	wire                                       st_ddr_out_fifo_tr_rd1      ;
	wire                                       st_ddr_out_fifo_tr_pful0    ;
	wire                                       st_ddr_out_fifo_tr_pful1    ;

	wire        [FIFO_DDR_WIDTH-1  : 0]        st_ddr_out_fifo_gp_di       ;
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_ddr_out_fifo_gp_do       ;
	wire                                       st_ddr_out_fifo_gp_wr       ;
	wire                                       st_ddr_out_fifo_gp_rd       ;
	wire                                       st_ddr_out_fifo_gp_pful     ;
	wire                                       st_ddr_out_fifo_gp_emy      ;
	wire                                       st_ddr_out_fifo_gp_vld      ;

	wire        [FIFO_DDR_WIDTH-1  : 0]        st_ddr_out_fifo_mm_di       ;
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_ddr_out_fifo_mm_do       ;
	wire                                       st_ddr_out_fifo_mm_wr       ;
	wire                                       st_ddr_out_fifo_mm_rd       ;
	wire                                       st_ddr_out_fifo_mm_pful     ;
	wire                                       st_ddr_out_fifo_mm_emy      ;
	wire                                       st_ddr_out_fifo_mm_vld      ;

	wire        [FIFO_DDR_WIDTH-1  : 0]        st_ddr_out_fifo_rg_di       ;
	wire        [FIFO_OUT_WIDTH-1  : 0]        st_ddr_out_fifo_rg_do       ;
	wire                                       st_ddr_out_fifo_rg_wr       ;
	wire                                       st_ddr_out_fifo_rg_rd       ;
	wire                                       st_ddr_out_fifo_rg_pful     ;
	wire                                       st_ddr_out_fifo_rg_emy      ;
	wire                                       st_ddr_out_fifo_rg_vld      ;
	
	reg                                        st_in_vd_hs_1d              ;
	reg                                        st_in_vd_de_1d              ;
	reg         [11 : 0]                       st_in_vd_hs_cnt             ;
	reg                                        st_in_vd_de_flag            ;
	reg                                        st_in_vd_de_gap             ;
	reg                                        st_out_vd_rdy               ;
	wire                                       st_out_vd_rdy_sync          ;
	wire                                       st_in_vd_vs_sync            ;
	reg                                        st_in_vd_vs_sync_1d         ;
	
	reg         [2  : 0]                       st_gl_current_state         ;
	reg         [2  : 0]                       st_gl_next_state            ;
	reg         [3  : 0]                       st_lc_current_state         ;
	reg         [3  : 0]                       st_lc_next_state            ;
	
	reg                                        st_lc_gp1_fsh               ;
	reg                                        st_lc_mm1_fsh               ;
	reg                                        st_lc_gp2_fsh               ;
	reg                                        st_lc_mm2_fsh               ;
	reg                                        st_lc_rg2_fsh               ;
	reg                                        st_lc_gp3_fsh               ;
	reg                                        st_lc_mm3_fsh               ;
	reg                                        st_lc_rg3_fsh               ;
	reg                                        st_lc_tr3_fsh               ;
	
	reg                                        st_lc_state1_fsh            ;
	reg                                        st_lc_state2_fsh            ;
	reg                                        st_lc_state3_fsh            ;
	
	reg                                        st_lc_cal_rdy               ;
	
	reg                                        st_part_flag                ;
	reg         [19 : 0]                       st_in_vd_addr               ;
	reg         [19 : 0]                       st_out_vd_addr              ;
	reg         [19 : 0]                       st_in_gp_addr               ;
	reg         [19 : 0]                       st_out_gp_addr              ;
	reg         [19 : 0]                       st_in_tr_addr               ;
	reg         [19 : 0]                       st_out_tr_addr              ;
	reg         [19 : 0]                       st_mm_addr                  ;
	reg         [19 : 0]                       st_rg_addr                  ;
	
	
	wire                                       st_fifo_in_ddr_gp_ful       ;
	wire                                       st_fifo_in_ddr_mm_ful       ;
	wire                                       st_fifo_in_ddr_rg_ful       ;
	wire                                       st_fifo_in_ddr_tr_ful       ;
	wire                                       st_fifo_in_ddr_vd_ful       ;
	wire                                       st_ddr_out_fifo_gp_ful      ;
	wire                                       st_ddr_out_fifo_mm_ful      ;
	wire                                       st_ddr_out_fifo_rg_ful      ;
	wire                                       st_ddr_out_fifo_tr_ful0     ;
	wire                                       st_ddr_out_fifo_tr_ful1     ;
	wire                                       st_ddr_out_fifo_vd_ful      ;

	wire                                       st_fifo_in_ddr_gp_emy       ;
	wire                                       st_fifo_in_ddr_mm_emy       ;
	wire                                       st_fifo_in_ddr_rg_emy       ;
	wire                                       st_fifo_in_ddr_tr_emy       ;
	wire                                       st_fifo_in_ddr_vd_emy       ;
	wire                                       st_ddr_out_fifo_gp_emy      ;
	wire                                       st_ddr_out_fifo_mm_emy      ;
	wire                                       st_ddr_out_fifo_rg_emy      ;
	wire                                       st_ddr_out_fifo_tr_emy0     ;
	wire                                       st_ddr_out_fifo_tr_emy1     ;
	wire                                       st_ddr_out_fifo_vd_emy      ;
	
	wire full;
	wire empty;
	wire [19:0]ca_in_da_cnt;
    wire ca_in_af0_vld; 	
	wire ca_in_af0_bof;
	wire ca_in_af0_eof;
	
	assign full = st_fifo_in_ddr_gp_ful   |
	              st_fifo_in_ddr_mm_ful   |
	              st_fifo_in_ddr_rg_ful   |
	              st_fifo_in_ddr_tr_ful   |
	              st_fifo_in_ddr_vd_ful   |
	              st_ddr_out_fifo_gp_ful  |
	              st_ddr_out_fifo_mm_ful  |
	              st_ddr_out_fifo_rg_ful  |
	              st_ddr_out_fifo_tr_ful0 |
	              st_ddr_out_fifo_tr_ful1 |
	              st_ddr_out_fifo_vd_ful  ;
	assign empty= st_fifo_in_ddr_gp_emy   |
	              st_fifo_in_ddr_mm_emy   |
	              st_fifo_in_ddr_rg_emy   |
	              st_fifo_in_ddr_tr_emy   |
	              st_fifo_in_ddr_vd_emy   |
	              st_ddr_out_fifo_gp_emy  |
	              st_ddr_out_fifo_mm_emy  |
	              st_ddr_out_fifo_rg_emy  |
	              st_ddr_out_fifo_tr_emy0 |
	              st_ddr_out_fifo_tr_emy1 |
	              st_ddr_out_fifo_vd_emy  ;
	
	
/*	

ddr_ila0 ddr_ila001 (
	.clk(st_ui_clk), // input wire clk


	.probe0 (st_gl_current_state), // input wire [2:0]  probe0  
	.probe1 (st_lc_current_state), // input wire [3:0]  probe1 
	.probe2 (st_lc_gp1_fsh ), // input wire [0:0]  probe2 
	.probe3 (st_lc_mm1_fsh ), // input wire [0:0]  probe3 
	.probe4 (st_lc_gp2_fsh ), // input wire [0:0]  probe4 
	.probe5 (st_lc_mm2_fsh ), // input wire [0:0]  probe5 
	.probe6 (st_lc_rg2_fsh ), // input wire [0:0]  probe6 
	.probe7 (st_lc_gp3_fsh ), // input wire [0:0]  probe7 
	.probe8 (st_lc_mm3_fsh ), // input wire [0:0]  probe8 
	.probe9 (st_lc_rg3_fsh ), // input wire [0:0]  probe9 
	.probe10(st_lc_tr3_fsh ), // input wire [0:0]  probe10 
	.probe11(st_lc_state1_fsh), // input wire [0:0]  probe11 
	.probe12(st_lc_state2_fsh), // input wire [0:0]  probe12 
	.probe13(st_lc_state3_fsh), // input wire [0:0]  probe13 
	.probe14(st_part_flag), // input wire [0:0]  probe14 
	.probe15(st_in_vd_hs_cnt), // input wire [11:0]  probe15 
	.probe16(st_wr_da_req), // input wire [0:0]  probe16 
	.probe17(st_wr_fsh   ), // input wire [0:0]  probe17 
	.probe18(st_wr_req   ), // input wire [0:0]  probe18 
	.probe19(st_wr_addr[19:0]), // input wire [19:0]  probe19 
	.probe20(st_rd_vld), // input wire [0:0]  probe20 
	.probe21(st_rd_fsh), // input wire [0:0]  probe21 
	.probe22(st_rd_req), // input wire [0:0]  probe22 
	.probe23(st_rd_addr[19:0]), // input wire [19:0]  probe23 
	.probe24(empty), // input wire [0:0]  probe24
	.probe25(ca_in_da_cnt), // input wire [19:0]  probe25 
	.probe26(ca_in_af0_vld), // input wire [19:0]  probe26
	.probe27(st_fifo_in_ddr_gp_emy  ), // input wire [0:0]  probe27 
	.probe28(st_fifo_in_ddr_mm_emy  ), // input wire [0:0]  probe28 
	.probe29(st_fifo_in_ddr_rg_emy  ), // input wire [0:0]  probe29 
	.probe30(st_fifo_in_ddr_tr_emy  ), // input wire [0:0]  probe30 
	.probe31(st_fifo_in_ddr_vd_emy  ), // input wire [0:0]  probe31 
	.probe32(st_ddr_out_fifo_gp_emy ), // input wire [0:0]  probe32 
	.probe33(st_ddr_out_fifo_mm_emy ), // input wire [0:0]  probe33 
	.probe34(st_ddr_out_fifo_rg_emy ), // input wire [0:0]  probe34 
	.probe35(st_ddr_out_fifo_tr_emy0), // input wire [0:0]  probe35 
	.probe36(st_ddr_out_fifo_tr_emy1), // input wire [0:0]  probe36 
	.probe37(st_ddr_out_fifo_vd_emy ), // input wire [0:0]  probe37 
	.probe38(ca_in_af0_bof), // input wire [0:0]  probe38 
	.probe39(ca_in_af0_eof) // input wire [0:0]  probe39
);
*/	
	// ***************************** vd stream ************************** //
    // st_in_vd_hs_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_in_vd_hs_1d <= 1'b0;
		end
		else begin
			st_in_vd_hs_1d <= st_in_vd_hs;
		end
	end
	
	// st_in_vd_hs_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_in_vd_hs_cnt <= 'd0;
		end
		else if(st_in_vd_vs == 1'b1) begin
			st_in_vd_hs_cnt <= 'd0;
		end
		else if((st_in_vd_hs == 1'b1) && (st_in_vd_hs_1d == 1'b0)) begin
			st_in_vd_hs_cnt <= st_in_vd_hs_cnt + 'd1;
		end
	end
	
	// st_out_vd_rdy
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_out_vd_rdy <= 1'b0;
		end
		else if((st_in_vd_hs_cnt > ST_VD_OUT_TSH1) && (st_in_vd_hs_cnt < ST_VD_OUT_TSH2)) begin
			st_out_vd_rdy <= 1'b1;
		end
		else begin
			st_out_vd_rdy <= 1'b0;
		end
	end
	
	// st_in_vd_de_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_in_vd_de_1d <= 1'b0;
		end
		else begin
			st_in_vd_de_1d <= st_in_vd_de;
		end
	end

	// st_in_vd_de_flag
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_in_vd_de_flag <= 'd0;
		end
		else if(st_in_vd_vs == 1'b1) begin
			st_in_vd_de_flag <= 'd0;
		end
		else if((st_in_vd_de_1d == 1'b1) && (st_in_vd_de == 1'b0)) begin
			st_in_vd_de_flag <= ~st_in_vd_de_flag;
		end
	end
	
	// st_in_vd_de_gap
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_in_vd_de_gap <= 'd0;
		end
		else if(st_in_vd_de == 1'b1) begin
			st_in_vd_de_gap <= ~st_in_vd_de_gap;
		end
		else begin
			st_in_vd_de_gap <= 1'b0;
		end
	end


	
	// ************** asynchronous signals synchronization ************** // 
	xpm_cdc_single           #( .DEST_SYNC_FF   (4         ), .INIT_SYNC_FF  (0                  ), 
	                            .SIM_ASSERT_CHK (0         ), .SRC_INPUT_REG (0                  ))
	xpm_cdc_single_inst_0     ( .src_clk        (clk       ), .src_in        (st_out_vd_rdy      ), 
	                            .dest_clk       (st_ui_clk ), .dest_out      (st_out_vd_rdy_sync ));
	xpm_cdc_single           #( .DEST_SYNC_FF   (4         ), .INIT_SYNC_FF  (0                  ), 
	                            .SIM_ASSERT_CHK (0         ), .SRC_INPUT_REG (0                  ))
	xpm_cdc_single_inst_1     ( .src_clk        (clk       ), .src_in        (st_in_vd_vs        ), 
	                            .dest_clk       (st_ui_clk ), .dest_out      (st_in_vd_vs_sync   ));
								
	// st_in_vd_vs_sync_1d
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_in_vd_vs_sync_1d <= 1'b0;
		end
		else begin
			st_in_vd_vs_sync_1d <= st_in_vd_vs_sync;
		end
	end
	
	
	// ***************************** cal state ************************** //
	// st_lc_state1_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_state1_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_state1_fsh <= 1'b0;
	    end
		else if((st_mm_addr == (ST_MM_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S)) && (st_lc_current_state == ST_LC_MM1) && (st_wr_fsh == 1'b1)) begin
			st_lc_state1_fsh <= 1'b1;
		end
	end
	
	// st_lc_state2_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_state2_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_state2_fsh <= 1'b0;
	    end
		else if((st_rg_addr == (ST_RG_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S)) && (st_lc_current_state == ST_LC_RG2) && (st_wr_fsh == 1'b1)) begin
			st_lc_state2_fsh <= 1'b1;
		end
	end

	// st_lc_state3_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_state3_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_state3_fsh <= 1'b0;
	    end
		else if(((st_in_tr_addr == (ST_TR_HEAD_B + ST_CAL_SIZE - ST_BURST_LEN_S)) || (st_in_tr_addr == (ST_TR_HEAD_A + ST_CAL_SIZE - ST_BURST_LEN_S)))
        	  && (st_lc_current_state == ST_LC_TR3) && (st_wr_fsh == 1'b1)) begin
			st_lc_state3_fsh <= 1'b1;
		end
	end
	
	// st_lc_gp1_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_gp1_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_gp1_fsh <= 1'b0;
	    end
		else if(((st_out_gp_addr == (ST_GP_HEAD_A + ST_CAL_SIZE - ST_BURST_LEN_S)) || (st_out_gp_addr == (ST_GP_HEAD_B + ST_CAL_SIZE - ST_BURST_LEN_S))) 
		      && (st_lc_current_state == ST_LC_GP1) && (st_rd_fsh == 1'b1)) begin
			st_lc_gp1_fsh <= 1'b1;
		end
	end

	// st_lc_mm1_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_mm1_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_mm1_fsh <= 1'b0;
	    end
		else if((st_mm_addr == (ST_MM_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S)) && (st_lc_current_state == ST_LC_MM1) && (st_wr_fsh == 1'b1)) begin
			st_lc_mm1_fsh <= 1'b1;
		end
	end

	// st_lc_gp2_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_gp2_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_gp2_fsh <= 1'b0;
	    end
		else if(((st_out_gp_addr == (ST_GP_HEAD_A + ST_CAL_SIZE - ST_BURST_LEN_S)) || (st_out_gp_addr == (ST_GP_HEAD_B + ST_CAL_SIZE - ST_BURST_LEN_S))) 
		      && (st_lc_current_state == ST_LC_GP2) && (st_rd_fsh == 1'b1)) begin
			st_lc_gp2_fsh <= 1'b1;
		end
	end

	// st_lc_mm2_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_mm2_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_mm2_fsh <= 1'b0;
	    end
		else if((st_mm_addr == (ST_MM_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S)) && (st_lc_current_state == ST_LC_MM2) && (st_rd_fsh == 1'b1)) begin
			st_lc_mm2_fsh <= 1'b1;
		end
	end

	// st_lc_rg2_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_rg2_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_rg2_fsh <= 1'b0;
	    end
		else if((st_rg_addr == (ST_RG_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S)) && (st_lc_current_state == ST_LC_RG2) && (st_wr_fsh == 1'b1)) begin
			st_lc_rg2_fsh <= 1'b1;
		end
	end

	// st_lc_gp3_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_gp3_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_gp3_fsh <= 1'b0;
	    end
		else if(((st_out_gp_addr == (ST_GP_HEAD_A + ST_CAL_SIZE - ST_BURST_LEN_S)) || (st_out_gp_addr == (ST_GP_HEAD_B + ST_CAL_SIZE - ST_BURST_LEN_S))) 
		      && (st_lc_current_state == ST_LC_GP3) && (st_rd_fsh == 1'b1)) begin
			st_lc_gp3_fsh <= 1'b1;
		end
	end
	
	// st_lc_mm3_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_mm3_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_mm3_fsh <= 1'b0;
	    end
		else if((st_mm_addr == (ST_MM_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S)) && (st_lc_current_state == ST_LC_MM3) && (st_rd_fsh == 1'b1)) begin
			st_lc_mm3_fsh <= 1'b1;
		end
	end

	// st_lc_rg3_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_rg3_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_rg3_fsh <= 1'b0;
	    end
		else if((st_rg_addr == (ST_RG_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S)) && (st_lc_current_state == ST_LC_RG3) && (st_rd_fsh == 1'b1)) begin
			st_lc_rg3_fsh <= 1'b1;
		end
	end

	// st_lc_tr3_fsh
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_tr3_fsh <= 1'b0;
		end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_lc_tr3_fsh <= 1'b0;
	    end
		else if(((st_in_tr_addr == (ST_TR_HEAD_B + ST_CAL_SIZE - ST_BURST_LEN_S)) || (st_in_tr_addr == (ST_TR_HEAD_A + ST_CAL_SIZE - ST_BURST_LEN_S)))
        	  && (st_lc_current_state == ST_LC_TR3) && (st_wr_fsh == 1'b1)) begin
			st_lc_tr3_fsh <= 1'b1;
		end
	end	
	
	// st_lc_cal_rdy
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_cal_rdy <= 1'b0;
		end
		else begin
			case({st_lc_state1_fsh, st_lc_state2_fsh, st_lc_state3_fsh})
				3'b000  : st_lc_cal_rdy <= ((st_fifo_in_ddr_mm_pemy  == 1'b0 ) && (st_lc_mm1_fsh == 1'b0 )) | 
				                           ((st_ddr_out_fifo_gp_pful == 1'b0 ) && (st_lc_gp1_fsh == 1'b0 )) ;
				3'b100  : st_lc_cal_rdy <= ((st_fifo_in_ddr_rg_pemy  == 1'b0 ) && (st_lc_rg2_fsh == 1'b0 )) |
				                           ((st_ddr_out_fifo_mm_pful == 1'b0 ) && (st_lc_mm2_fsh == 1'b0 )) |
										   ((st_ddr_out_fifo_gp_pful == 1'b0 ) && (st_lc_gp2_fsh == 1'b0 )) ;				
				3'b110  : st_lc_cal_rdy <= ((st_fifo_in_ddr_tr_pemy  == 1'b0 ) && (st_lc_tr3_fsh == 1'b0 )) |
				                           ((st_ddr_out_fifo_gp_pful == 1'b0 ) && (st_lc_gp3_fsh == 1'b0 )) |
										   ((st_ddr_out_fifo_rg_pful == 1'b0 ) && (st_lc_rg3_fsh == 1'b0 )) |
										   ((st_ddr_out_fifo_mm_pful == 1'b0 ) && (st_lc_mm3_fsh == 1'b0 )) ;
				default : st_lc_cal_rdy <= 1'b0;
			endcase
		end
	end
	
	
	// ************************** state machine  ************************ // 
	// global state machine
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_gl_current_state <= ST_GL_IDLE;
		end
		else begin
			st_gl_current_state <= st_gl_next_state;
	    end
	end
	
	always @ ( * ) begin
		case(st_gl_current_state)
			ST_GL_IDLE   : begin
				// if((st_ddr_out_fifo_vd_pful == 1'b0) && (st_out_vd_rdy_sync == 1'b1)) 
					// st_gl_next_state = ST_GL_VD_OUT;
				// else if((st_ddr_out_fifo_tr_pful0 == 1'b0) && (st_out_vd_rdy_sync == 1'b1)) 
					// st_gl_next_state = ST_GL_TR_OUT;
				// else if(st_fifo_in_ddr_vd_pemy == 1'b0)
					// st_gl_next_state = ST_GL_VD_IN;
				// else if(st_fifo_in_ddr_gp_pemy == 1'b0)
					// st_gl_next_state = ST_GL_GP_IN;
				// else if((st_out_vd_rdy_sync == 1'b1) && (st_lc_cal_rdy == 1'b1))
					// st_gl_next_state = ST_GL_CAL;
				// else
					// st_gl_next_state = ST_GL_IDLE;
					
				
				// if((st_ddr_out_fifo_vd_pful == 1'b0) && (st_out_vd_rdy_sync == 1'b1)) 
					// st_gl_next_state = ST_GL_VD_OUT;
				
				
				if((st_ddr_out_fifo_tr_pful0 == 1'b0) && (st_out_vd_rdy_sync == 1'b1)) 
					st_gl_next_state = ST_GL_TR_OUT;
				// else if(st_fifo_in_ddr_vd_pemy == 1'b0)
					// st_gl_next_state = ST_GL_VD_IN;
				else if(st_fifo_in_ddr_gp_pemy == 1'b0)
					st_gl_next_state = ST_GL_GP_IN;
				else if((st_out_vd_rdy_sync == 1'b1) && (st_lc_cal_rdy == 1'b1))
					st_gl_next_state = ST_GL_CAL;
				else
					st_gl_next_state = ST_GL_IDLE;
				
			end
			ST_GL_VD_OUT : begin
				if(st_rd_fsh == 1'b1) st_gl_next_state = ST_GL_IDLE; 
				else st_gl_next_state = ST_GL_VD_OUT;
			end
			ST_GL_TR_OUT : begin
				if(st_rd_fsh == 1'b1) st_gl_next_state = ST_GL_IDLE;
				else st_gl_next_state = ST_GL_TR_OUT;
			end
			ST_GL_VD_IN  : begin
				if(st_wr_fsh == 1'b1) st_gl_next_state = ST_GL_IDLE;
				else st_gl_next_state = ST_GL_VD_IN;
			end
			ST_GL_GP_IN  : begin
				if(st_wr_fsh == 1'b1) st_gl_next_state = ST_GL_IDLE;
				else st_gl_next_state = ST_GL_GP_IN;
			end
			ST_GL_CAL    : begin
				if((st_rd_fsh == 1'b1) || (st_wr_fsh == 1'b1)) st_gl_next_state = ST_GL_IDLE;
				else st_gl_next_state = ST_GL_CAL;
			end
			default      : begin
				st_gl_next_state = ST_GL_IDLE;
			end
		endcase
	end
	
	// local state machine
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_lc_current_state <= ST_LC_IDLE;
		end
		else begin
			st_lc_current_state <= st_lc_next_state;
	    end
	end
	
	always @ ( * ) begin
		case(st_lc_current_state)
			ST_LC_IDLE  : begin
				if((st_lc_state1_fsh == 1'b0) && (st_gl_current_state == ST_GL_CAL)) st_lc_next_state = ST_LC_IDLE1;
				else if((st_lc_state2_fsh == 1'b0) && (st_gl_current_state == ST_GL_CAL)) st_lc_next_state = ST_LC_IDLE2;
				else if((st_lc_state3_fsh == 1'b0) && (st_gl_current_state == ST_GL_CAL)) st_lc_next_state = ST_LC_IDLE3;
				else st_lc_next_state = ST_LC_IDLE;
			end
			ST_LC_IDLE1 : begin
				if((st_fifo_in_ddr_mm_pemy == 1'b0) && (st_lc_mm1_fsh == 1'b0)) st_lc_next_state = ST_LC_MM1;
				else if((st_ddr_out_fifo_gp_pful == 1'b0) && (st_lc_gp1_fsh == 1'b0)) st_lc_next_state = ST_LC_GP1;
				else st_lc_next_state = ST_LC_IDLE;
			end
			ST_LC_IDLE2 : begin
				if((st_fifo_in_ddr_rg_pemy == 1'b0) && (st_lc_rg2_fsh == 1'b0)) st_lc_next_state = ST_LC_RG2;
				else if((st_ddr_out_fifo_mm_pful == 1'b0) && (st_lc_mm2_fsh == 1'b0)) st_lc_next_state = ST_LC_MM2;
				else if((st_ddr_out_fifo_gp_pful == 1'b0) && (st_lc_gp2_fsh == 1'b0)) st_lc_next_state = ST_LC_GP2;
				else st_lc_next_state = ST_LC_IDLE;
			end
			ST_LC_IDLE3 : begin
				if((st_fifo_in_ddr_tr_pemy == 1'b0) && (st_lc_tr3_fsh == 1'b0)) st_lc_next_state = ST_LC_TR3;
				else if((st_ddr_out_fifo_gp_pful == 1'b0) && (st_lc_gp3_fsh == 1'b0)) st_lc_next_state = ST_LC_GP3;
				else if((st_ddr_out_fifo_rg_pful == 1'b0) && (st_lc_rg3_fsh == 1'b0)) st_lc_next_state = ST_LC_RG3;
				else if((st_ddr_out_fifo_mm_pful == 1'b0) && (st_lc_mm3_fsh == 1'b0)) st_lc_next_state = ST_LC_MM3;
				else st_lc_next_state = ST_LC_IDLE;
			end
			
		    ST_LC_GP1   : begin
				if(st_rd_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_GP1;
			end
		    ST_LC_MM1   : begin
				if(st_wr_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_MM1;
			end
		    ST_LC_GP2   : begin
				if(st_rd_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_GP2;
			end
		    ST_LC_MM2   : begin
				if(st_rd_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_MM2;
			end
		    ST_LC_RG2   : begin
				if(st_wr_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_RG2;
			end
		    ST_LC_GP3   : begin
				if(st_rd_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_GP3;
			end
		    ST_LC_MM3   : begin
				if(st_rd_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_MM3;
			end
		    ST_LC_RG3   : begin
				if(st_rd_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_RG3;
			end
		    ST_LC_TR3   : begin
				if(st_wr_fsh == 1'b1) st_lc_next_state = ST_LC_IDLE;
				else st_lc_next_state = ST_LC_TR3;
			end
			default     : begin
				st_lc_next_state = ST_LC_IDLE;
			end
		endcase
	end	
	

	// ************************** st_wr_rd_addr ************************* //
	// st_part_flag == 1'b0 : in vd A/ in gp A ---- |cal---gp B/ mm/ rg/ tr B/--end| ---- out vd A/ out tr A
	// st_part_flag == 1'b1 : in vd B/ in gp B ---- |cal---gp A/ mm/ rg/ tr A/--end| ---- out vd B/ out tr B
	
	// st_part_flag  
	// Notice! we flip st_part_flag at the negedge edge of st_in_vd_vs_sync, so that avoiding the ambiguity of st_out_gp_addr's adding judgement 
	// which depends on the level of st_part_flag.
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_part_flag <= 1'b0;
		end
		else if((st_in_vd_vs_sync == 1'b0) && (st_in_vd_vs_sync_1d == 1'b1)) begin
			st_part_flag <= ~st_part_flag;
	    end
	end
	
	// st_in_vd_addr 
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_in_vd_addr <= ST_VD_HEAD_A;
		end
		else if((st_gl_current_state == ST_GL_VD_IN) && (st_wr_fsh == 1'b1)) begin
			st_in_vd_addr <= st_in_vd_addr + ST_BURST_LEN_L;
	    end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_in_vd_addr <= (st_part_flag == 1'b1)? ST_VD_HEAD_A : ST_VD_HEAD_B;
		end
	end
	
	// st_in_gp_addr 
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_in_gp_addr <= ST_GP_HEAD_A;
		end
		else if((st_gl_current_state == ST_GL_GP_IN) && (st_wr_fsh == 1'b1)) begin
			st_in_gp_addr <= st_in_gp_addr + ST_BURST_LEN_L;
	    end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_in_gp_addr <= (st_part_flag == 1'b1)? ST_GP_HEAD_A : ST_GP_HEAD_B;
		end
	end
	
	// st_in_tr_addr 
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_in_tr_addr <= ST_TR_HEAD_B;
		end
		else if((st_lc_current_state == ST_LC_TR3) && (st_wr_fsh == 1'b1)) begin
			st_in_tr_addr <= st_in_tr_addr + ST_BURST_LEN_S;
	    end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_in_tr_addr <= (st_part_flag == 1'b1)? ST_TR_HEAD_B : ST_TR_HEAD_A;
		end
	end
	

	// st_out_vd_addr
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_vd_addr <= ST_VD_HEAD_A;
		end
		else if((st_gl_current_state == ST_GL_VD_OUT) && (st_rd_fsh == 1'b1)) begin
			st_out_vd_addr <= st_out_vd_addr + ST_BURST_LEN_L;
	    end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_out_vd_addr <= (st_part_flag == 1'b1)? ST_VD_HEAD_A : ST_VD_HEAD_B;
		end
	end
	
	// st_out_tr_addr
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_tr_addr <= ST_TR_HEAD_A;
			//st_out_tr_addr <= ST_GP_HEAD_B;
			//st_out_tr_addr <= ST_RG_HEAD;
		end
		else if((st_gl_current_state == ST_GL_TR_OUT) && (st_rd_fsh == 1'b1)) begin
			st_out_tr_addr <= st_out_tr_addr + ST_BURST_LEN_L;
	    end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_out_tr_addr <= (st_part_flag == 1'b1)? ST_TR_HEAD_A : ST_TR_HEAD_B;
			//st_out_tr_addr <= (st_part_flag == 1'b1)? ST_GP_HEAD_B : ST_GP_HEAD_A;
			//st_out_tr_addr <= ST_RG_HEAD;
		end
	end
	
	// st_out_gp_addr
	// Notice the level of st_part_flag, which has flipped at the negedge edge of st_in_vd_vs_sync.
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_gp_addr <= ST_GP_HEAD_B;
		end
		else if(((st_lc_current_state == ST_LC_GP1)  || 
		         (st_lc_current_state == ST_LC_GP2)  || 
				 (st_lc_current_state == ST_LC_GP3)) && 
				 (st_rd_fsh == 1'b1) && (st_part_flag == 1'b1)) begin
			st_out_gp_addr <= (st_out_gp_addr == (ST_GP_HEAD_A + ST_CAL_SIZE - ST_BURST_LEN_S))? ST_GP_HEAD_A : (st_out_gp_addr + ST_BURST_LEN_S);
	    end
		else if(((st_lc_current_state == ST_LC_GP1)  || 
		         (st_lc_current_state == ST_LC_GP2)  || 
				 (st_lc_current_state == ST_LC_GP3)) && 
				 (st_rd_fsh == 1'b1) && (st_part_flag == 1'b0)) begin
			st_out_gp_addr <= (st_out_gp_addr == (ST_GP_HEAD_B + ST_CAL_SIZE - ST_BURST_LEN_S))? ST_GP_HEAD_B : (st_out_gp_addr + ST_BURST_LEN_S);
	    end		
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_out_gp_addr <= (st_part_flag == 1'b1)? ST_GP_HEAD_B : ST_GP_HEAD_A;
		end
	end

	// st_mm_addr
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_mm_addr <= ST_MM_HEAD;
		end
		else if(((st_lc_current_state == ST_LC_MM1) && (st_wr_fsh == 1'b1)) || 
		        ((st_lc_current_state == ST_LC_MM2) && (st_rd_fsh == 1'b1)) || 
				((st_lc_current_state == ST_LC_MM3) && (st_rd_fsh == 1'b1)))  begin
			st_mm_addr <= (st_mm_addr == (ST_MM_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S))? ST_MM_HEAD : (st_mm_addr + ST_BURST_LEN_S);
	    end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_mm_addr <= ST_MM_HEAD;
		end
	end

	// st_rg_addr
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_rg_addr <= ST_RG_HEAD;
		end
		else if(((st_lc_current_state == ST_LC_RG2) && (st_wr_fsh == 1'b1)) || 
				((st_lc_current_state == ST_LC_RG3) && (st_rd_fsh == 1'b1)))  begin
			st_rg_addr <= (st_rg_addr == (ST_RG_HEAD + ST_CAL_SIZE - ST_BURST_LEN_S))? ST_RG_HEAD : (st_rg_addr + ST_BURST_LEN_S);
	    end
		else if(st_in_vd_vs_sync == 1'b1) begin
			st_rg_addr <= ST_RG_HEAD;
		end
	end
	
	// st_wr_addr
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_wr_addr[19:0] <= 'd0;
			st_wr_addr[APP_ADDR_WIDTH-1 : 20] <= 'd0;
		end
		else if(st_gl_current_state == ST_GL_CAL) begin
			st_wr_addr[APP_ADDR_WIDTH-1 : 20] <= 'd0;
			case(st_lc_current_state)
				ST_LC_MM1    : st_wr_addr[19:0] <= st_mm_addr;
				ST_LC_RG2    : st_wr_addr[19:0] <= st_rg_addr;
				ST_LC_TR3    : st_wr_addr[19:0] <= st_in_tr_addr;
				default      : st_wr_addr[19:0] <= st_wr_addr[19:0];
			endcase
		end
		else begin
			st_wr_addr[APP_ADDR_WIDTH-1 : 20] <= 'd0;
			case(st_gl_current_state)
				ST_GL_VD_IN  : st_wr_addr[19:0] <= st_in_vd_addr;
				ST_GL_GP_IN  : st_wr_addr[19:0] <= st_in_gp_addr;
                default      : st_wr_addr[19:0] <= st_wr_addr[19:0];
            endcase		
		end
	end
	
	// st_rd_addr
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_rd_addr[19:0] <= 'd0;
			st_rd_addr[APP_ADDR_WIDTH-1 : 20] <= 'd0;
		end
		else if(st_gl_current_state == ST_GL_CAL) begin
			st_rd_addr[APP_ADDR_WIDTH-1 : 20] <= 'd0;
			case(st_lc_current_state)
		    	ST_LC_GP1    : st_rd_addr[19:0] <= st_out_gp_addr;
		    	ST_LC_GP2    : st_rd_addr[19:0] <= st_out_gp_addr;
		    	ST_LC_MM2    : st_rd_addr[19:0] <= st_mm_addr;
		    	ST_LC_GP3    : st_rd_addr[19:0] <= st_out_gp_addr;
		    	ST_LC_MM3    : st_rd_addr[19:0] <= st_mm_addr;
		    	ST_LC_RG3    : st_rd_addr[19:0] <= st_rg_addr;	
		    	default      : st_rd_addr[19:0] <= st_rd_addr[19:0];
		    endcase
		end
		else begin
			st_rd_addr[APP_ADDR_WIDTH-1 : 20] <= 'd0;
			case(st_gl_current_state)
				ST_GL_VD_OUT : st_rd_addr[19:0] <= st_out_vd_addr;
				ST_GL_TR_OUT : st_rd_addr[19:0] <= st_out_tr_addr;
		        default      : st_rd_addr[19:0] <= st_rd_addr[19:0];
		    endcase				
		end
	end


	// ********************* st_wr_req & st_wr_len ********************** //
	// st_wr_req
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_wr_req <= 1'b0;
		end
		else if(st_gl_current_state == ST_GL_CAL) begin
			case(st_lc_current_state)
            	ST_LC_MM1    : st_wr_req <= (st_wr_fsh == 1'b1)? 1'b0 : 1'b1;
            	ST_LC_RG2    : st_wr_req <= (st_wr_fsh == 1'b1)? 1'b0 : 1'b1;
            	ST_LC_TR3    : st_wr_req <= (st_wr_fsh == 1'b1)? 1'b0 : 1'b1;
            	default      : st_wr_req <= 1'b0;
            endcase
		end
		else begin
			case(st_gl_current_state)
				ST_GL_VD_IN  : st_wr_req <= (st_wr_fsh == 1'b1)? 1'b0 : 1'b1;
				ST_GL_GP_IN  : st_wr_req <= (st_wr_fsh == 1'b1)? 1'b0 : 1'b1;
                default      : st_wr_req <= 1'b0;
            endcase				
		end
	end
	
	// st_wr_len
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_wr_len <= 'd0;
		end
		else if(st_gl_current_state == ST_GL_CAL) begin
			case(st_lc_current_state)
				ST_LC_MM1    : st_wr_len <= (st_wr_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				ST_LC_RG2    : st_wr_len <= (st_wr_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				ST_LC_TR3    : st_wr_len <= (st_wr_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				default      : st_wr_len <= 'd0;
			endcase
		end
		else begin
			case(st_gl_current_state)
				ST_GL_VD_IN  : st_wr_len <= (st_wr_fsh == 1'b1)? 'd0 : ST_BURST_LEN_L;
				ST_GL_GP_IN  : st_wr_len <= (st_wr_fsh == 1'b1)? 'd0 : ST_BURST_LEN_L;
                default      : st_wr_len <= 'd0;
            endcase				
		end
	end


	// ********************* st_rd_req & st_rd_len ********************** //
	// st_rd_req
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_rd_req <= 1'b0;
		end
		else if(st_gl_current_state == ST_GL_CAL) begin
			case(st_lc_current_state)
            	ST_LC_GP1    : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
            	ST_LC_GP2    : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
            	ST_LC_MM2    : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
            	ST_LC_GP3    : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
            	ST_LC_MM3    : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
            	ST_LC_RG3    : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
            	default      : st_rd_req <= 1'b0;	
            endcase
		end
		else begin
			case(st_gl_current_state)
				ST_GL_VD_OUT : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
				ST_GL_TR_OUT : st_rd_req <= (st_rd_fsh == 1'b1)? 1'b0 : 1'b1;
                default      : st_rd_req <= 1'b0;
            endcase				
		end
	end
	
	// st_rd_len
	always @ (posedge st_ui_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_rd_len <= 'd0;
		end
		else if(st_gl_current_state == ST_GL_CAL) begin
			case(st_lc_current_state)
				ST_LC_GP1    : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				ST_LC_GP2    : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				ST_LC_MM2    : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				ST_LC_GP3    : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				ST_LC_MM3    : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				ST_LC_RG3    : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_S;
				default      : st_rd_len <= 'd0;				
			endcase
		end
		else begin
			case(st_gl_current_state)
				ST_GL_VD_OUT : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_L;
				ST_GL_TR_OUT : st_rd_len <= (st_rd_fsh == 1'b1)? 'd0 : ST_BURST_LEN_L;
                default      : st_rd_len <= 'd0;
            endcase				
		end
	end
	
	
	// ************************** fifo signals ************************** // 
	// st_fifo_in_ddr_vd
	assign st_fifo_in_ddr_vd_di = st_in_vd_da;
	assign st_fifo_in_ddr_vd_wr = st_in_vd_de;
	assign st_fifo_in_ddr_vd_rd = st_wr_da_req & (st_gl_current_state == ST_GL_VD_IN);
	
	// st_fifo_in_ddr_gp
	assign st_fifo_in_ddr_gp_di = st_in_gp_da;
	assign st_fifo_in_ddr_gp_wr = st_in_gp_vld;
	assign st_fifo_in_ddr_gp_rd = st_wr_da_req & (st_gl_current_state == ST_GL_GP_IN);
	
	// st_fifo_in_ddr_mm
	assign st_fifo_in_ddr_mm_rd = st_wr_da_req & (st_lc_current_state == ST_LC_MM1);
	
	// st_fifo_in_ddr_rg
	assign st_fifo_in_ddr_rg_rd = st_wr_da_req & (st_lc_current_state == ST_LC_RG2);
	
	// st_fifo_in_ddr_tr
	assign st_fifo_in_ddr_tr_rd = st_wr_da_req & (st_lc_current_state == ST_LC_TR3);
	
	// dout
	assign st_wr_data[FIFO_DDR_WIDTH-1 : 0] = (st_gl_current_state == ST_GL_VD_IN) ? st_fifo_in_ddr_vd_do : 
											  (st_gl_current_state == ST_GL_GP_IN) ? st_fifo_in_ddr_gp_do : 
											  (st_lc_current_state == ST_LC_MM1)   ? st_fifo_in_ddr_mm_do : 
											  (st_lc_current_state == ST_LC_RG2)   ? st_fifo_in_ddr_rg_do : st_fifo_in_ddr_tr_do;
	assign st_wr_data[APP_DATA_WIDTH-1 : FIFO_DDR_WIDTH] = 'd0; 
	
	// st_ddr_out_fifo_vd
	assign st_ddr_out_fifo_vd_di = st_rd_data;
	assign st_ddr_out_fifo_vd_wr = st_rd_vld & (st_gl_current_state == ST_GL_VD_OUT);
	assign st_ddr_out_fifo_vd_rd = st_in_vd_de;

	// st_ddr_out_fifo_tr
	assign st_ddr_out_fifo_tr_di = st_rd_data;
	assign st_ddr_out_fifo_tr_wr = st_rd_vld & (st_gl_current_state == ST_GL_TR_OUT);
	assign st_ddr_out_fifo_tr_rd0 = (st_in_vd_de) & (~st_in_vd_de_gap) & (~st_in_vd_de_flag);
	assign st_ddr_out_fifo_tr_rd1 = (st_in_vd_de) & (~st_in_vd_de_gap) & (st_in_vd_de_flag );

	// st_ddr_out_fifo_gp
	assign st_ddr_out_fifo_gp_di = st_rd_data;
	assign st_ddr_out_fifo_gp_wr = st_rd_vld & ((st_lc_current_state == ST_LC_GP1) || (st_lc_current_state == ST_LC_GP2) || (st_lc_current_state == ST_LC_GP3));

	// st_ddr_out_fifo_mm
	assign st_ddr_out_fifo_mm_di = st_rd_data;
	assign st_ddr_out_fifo_mm_wr = st_rd_vld & ((st_lc_current_state == ST_LC_MM2) || (st_lc_current_state == ST_LC_MM3));

	// st_ddr_out_fifo_rg
	assign st_ddr_out_fifo_rg_di = st_rd_data;
	assign st_ddr_out_fifo_rg_wr = st_rd_vld & (st_lc_current_state == ST_LC_RG3);
	
	
	// *************************** signals out ************************** // 
	// st_out_tf_hs
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_tf_hs <= 1'b0;
		end
		else begin
			st_out_tf_hs <= st_in_vd_hs;
		end
	end		
	
	// st_out_tf_vs
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_tf_vs <= 1'b0;
		end
		else begin
			st_out_tf_vs <= st_in_vd_vs;
		end
	end		

	// st_out_tf_de
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_tf_de <= 1'b0;
		end
		else begin
			st_out_tf_de <= st_in_vd_de;
		end
	end			
	
	// st_out_tf_da 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_tf_da <= 'd0;
		end
		else begin
			st_out_tf_da <= (st_in_vd_de_flag == 1'b0)? st_ddr_out_fifo_tr_do0[AF_DATA_WIDTH-1 : 0] : st_ddr_out_fifo_tr_do1[AF_DATA_WIDTH-1 : 0];
			// st_out_tf_da <= (st_in_vd_de_flag == 1'b0)? st_ddr_out_fifo_tr_do0[2*AF_DATA_WIDTH-1 : AF_DATA_WIDTH] : st_ddr_out_fifo_tr_do1[2*AF_DATA_WIDTH-1 : AF_DATA_WIDTH];
		end
	end				
	
	// st_out_vd_hs 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_vd_hs <= 1'b0;
		end
		else begin
			st_out_vd_hs <= st_in_vd_hs;
		end
	end		

	// st_out_vd_vs 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_vd_vs <= 1'b0;
		end
		else begin
			st_out_vd_vs <= st_in_vd_vs;
		end
	end		

	// st_out_vd_de 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_vd_de <= 1'b0;
		end
		else begin
			st_out_vd_de <= st_in_vd_de;
		end
	end		

	// st_out_vd_da 
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin 
			st_out_vd_da <= 'd0;
		end
		else begin
			st_out_vd_da <= st_ddr_out_fifo_vd_do[VD_DATA_WIDTH-1 : 0];
		end
	end		    
	
	wire gf_ca_clk;
	wire st_lc_state1_fsh_sync;
	wire st_lc_state2_fsh_sync;
	wire st_lc_state3_fsh_sync;
	wire rst_n_sync;

	gf_clk gf_clk1  ( .clk_out1(gf_ca_clk), .clk_in1(st_ui_clk));     
	
	xpm_cdc_single           #( .DEST_SYNC_FF   (4         ), .INIT_SYNC_FF  (0                     ), 
	                            .SIM_ASSERT_CHK (0         ), .SRC_INPUT_REG (0                     ))
	xpm_cdc_single_inst_a     ( .src_clk        (st_ui_clk ), .src_in        (st_lc_state1_fsh      ), 
	                            .dest_clk       (gf_ca_clk ), .dest_out      (st_lc_state1_fsh_sync ));
	xpm_cdc_single           #( .DEST_SYNC_FF   (4         ), .INIT_SYNC_FF  (0                     ), 
	                            .SIM_ASSERT_CHK (0         ), .SRC_INPUT_REG (0                     ))
	xpm_cdc_single_inst_b     ( .src_clk        (st_ui_clk ), .src_in        (st_lc_state2_fsh      ), 
	                            .dest_clk       (gf_ca_clk ), .dest_out      (st_lc_state2_fsh_sync ));
	xpm_cdc_single           #( .DEST_SYNC_FF   (4         ), .INIT_SYNC_FF  (0                     ), 
	                            .SIM_ASSERT_CHK (0         ), .SRC_INPUT_REG (0                     ))
	xpm_cdc_single_inst_c     ( .src_clk        (st_ui_clk ), .src_in        (st_lc_state3_fsh      ), 
	                            .dest_clk       (gf_ca_clk ), .dest_out      (st_lc_state3_fsh_sync ));
	xpm_cdc_single           #( .DEST_SYNC_FF   (4         ), .INIT_SYNC_FF  (0                     ), 
	                            .SIM_ASSERT_CHK (0         ), .SRC_INPUT_REG (0                     ))
	xpm_cdc_single_inst_d     ( .src_clk        (st_ui_clk ), .src_in        (rst_n                 ), 
	                            .dest_clk       (gf_ca_clk ), .dest_out      (rst_n_sync            ));
	

	// *************************** fifo to ddr ************************** // 
	fifo_in_ddr st_fifo_in_ddr_vd             (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (clk                        ),
	 .rd_clk                                  (st_ui_clk                  ),
	 .din                                     (st_fifo_in_ddr_vd_di       ),
	 .wr_en                                   (st_fifo_in_ddr_vd_wr       ),
	 .rd_en                                   (st_fifo_in_ddr_vd_rd       ),
	 .dout                                    (st_fifo_in_ddr_vd_do       ),
	 .full                                    (st_fifo_in_ddr_vd_ful      ),
	 .empty                                   (st_fifo_in_ddr_vd_emy      ),
	 .valid                                   (                           ),
	 .prog_empty                              (st_fifo_in_ddr_vd_pemy     ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	fifo_in_ddr st_fifo_in_ddr_gp             (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (clk                        ),
	 .rd_clk                                  (st_ui_clk                  ),
	 .din                                     (st_fifo_in_ddr_gp_di       ),
	 .wr_en                                   (st_fifo_in_ddr_gp_wr       ),
	 .rd_en                                   (st_fifo_in_ddr_gp_rd       ),
	 .dout                                    (st_fifo_in_ddr_gp_do       ),
	 .full                                    (st_fifo_in_ddr_gp_ful      ),
	 .empty                                   (st_fifo_in_ddr_gp_emy      ),
	 .valid                                   (                           ),
	 .prog_empty                              (st_fifo_in_ddr_gp_pemy     ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	fifo_in_ddr   st_fifo_in_ddr_mm           (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (gf_ca_clk                  ),
	 .rd_clk                                  (st_ui_clk                  ),
	 .din                                     (st_fifo_in_ddr_mm_di       ),
	 .wr_en                                   (st_fifo_in_ddr_mm_wr       ),
	 .rd_en                                   (st_fifo_in_ddr_mm_rd       ),
	 .dout                                    (st_fifo_in_ddr_mm_do       ),
	 .full                                    (st_fifo_in_ddr_mm_ful      ),
	 .empty                                   (st_fifo_in_ddr_mm_emy      ),
	 .valid                                   (                           ),
	 .prog_empty                              (st_fifo_in_ddr_mm_pemy     ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	fifo_in_ddr   st_fifo_in_ddr_rg           (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (gf_ca_clk                  ),
	 .rd_clk                                  (st_ui_clk                  ),
	 .din                                     (st_fifo_in_ddr_rg_di       ),
	 .wr_en                                   (st_fifo_in_ddr_rg_wr       ),
	 .rd_en                                   (st_fifo_in_ddr_rg_rd       ),
	 .dout                                    (st_fifo_in_ddr_rg_do       ),
	 .full                                    (st_fifo_in_ddr_rg_ful      ),
	 .empty                                   (st_fifo_in_ddr_rg_emy      ),
	 .valid                                   (                           ),
	 .prog_empty                              (st_fifo_in_ddr_rg_pemy     ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	fifo_in_ddr   st_fifo_in_ddr_tr           (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (gf_ca_clk                  ),
	 .rd_clk                                  (st_ui_clk                  ),
	 .din                                     (st_fifo_in_ddr_tr_di       ),
	 .wr_en                                   (st_fifo_in_ddr_tr_wr       ),
	 .rd_en                                   (st_fifo_in_ddr_tr_rd       ),
	 .dout                                    (st_fifo_in_ddr_tr_do       ),
	 .full                                    (st_fifo_in_ddr_tr_ful      ),
	 .empty                                   (st_fifo_in_ddr_tr_emy      ),
	 .valid                                   (                           ),
	 .prog_empty                              (st_fifo_in_ddr_tr_pemy     ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;

	// *************************** ddr to fifo ************************** // 
	ddr_out_fifo st_ddr_out_fifo_vd           (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (st_ui_clk                  ),
	 .rd_clk                                  (clk                        ),
	 .din                                     (st_ddr_out_fifo_vd_di      ),
	 .wr_en                                   (st_ddr_out_fifo_vd_wr      ),
	 .rd_en                                   (st_ddr_out_fifo_vd_rd      ),
	 .dout                                    (st_ddr_out_fifo_vd_do      ),
	 .full                                    (st_ddr_out_fifo_vd_ful     ),
	 .empty                                   (st_ddr_out_fifo_vd_emy     ),
	 .valid                                   (                           ),
	 .prog_full                               (st_ddr_out_fifo_vd_pful    ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	ddr_out_fifo st_ddr_out_fifo_tr0          (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (st_ui_clk                  ),
	 .rd_clk                                  (clk                        ),
	 .din                                     (st_ddr_out_fifo_tr_di      ),
	 .wr_en                                   (st_ddr_out_fifo_tr_wr      ),
	 .rd_en                                   (st_ddr_out_fifo_tr_rd0     ),
	 .dout                                    (st_ddr_out_fifo_tr_do0     ),
	 .full                                    (st_ddr_out_fifo_tr_ful0    ),
	 .empty                                   (st_ddr_out_fifo_tr_emy0    ),
	 .valid                                   (                           ),
	 .prog_full                               (st_ddr_out_fifo_tr_pful0   ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	ddr_out_fifo st_ddr_out_fifo_tr1          (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (st_ui_clk                  ),
	 .rd_clk                                  (clk                        ),
	 .din                                     (st_ddr_out_fifo_tr_di      ),
	 .wr_en                                   (st_ddr_out_fifo_tr_wr      ),
	 .rd_en                                   (st_ddr_out_fifo_tr_rd1     ),
	 .dout                                    (st_ddr_out_fifo_tr_do1     ),
	 .full                                    (st_ddr_out_fifo_tr_ful1    ),
	 .empty                                   (st_ddr_out_fifo_tr_emy1    ),
	 .valid                                   (                           ),
	 .prog_full                               (st_ddr_out_fifo_tr_pful1   ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	ddr_out_fifo   st_ddr_out_fifo_gp         (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (st_ui_clk                  ),
	 .rd_clk                                  (gf_ca_clk                  ),
	 .din                                     (st_ddr_out_fifo_gp_di      ),
	 .wr_en                                   (st_ddr_out_fifo_gp_wr      ),
	 .rd_en                                   (st_ddr_out_fifo_gp_rd      ),
	 .dout                                    (st_ddr_out_fifo_gp_do      ),
	 .full                                    (st_ddr_out_fifo_gp_ful     ),
	 .empty                                   (st_ddr_out_fifo_gp_emy     ),
	 .valid                                   (st_ddr_out_fifo_gp_vld     ),
	 .prog_full                               (st_ddr_out_fifo_gp_pful    ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	ddr_out_fifo   st_ddr_out_fifo_mm         (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (st_ui_clk                  ),
	 .rd_clk                                  (gf_ca_clk                  ),
	 .din                                     (st_ddr_out_fifo_mm_di      ),
	 .wr_en                                   (st_ddr_out_fifo_mm_wr      ),
	 .rd_en                                   (st_ddr_out_fifo_mm_rd      ),
	 .dout                                    (st_ddr_out_fifo_mm_do      ),
	 .full                                    (st_ddr_out_fifo_mm_ful     ),
	 .empty                                   (st_ddr_out_fifo_mm_emy     ),
	 .valid                                   (st_ddr_out_fifo_mm_vld     ),
	 .prog_full                               (st_ddr_out_fifo_mm_pful    ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	ddr_out_fifo   st_ddr_out_fifo_rg         (
	 .rst                                     (st_in_vd_vs_sync           ),
	 .wr_clk                                  (st_ui_clk                  ),
	 .rd_clk                                  (gf_ca_clk                  ),
	 .din                                     (st_ddr_out_fifo_rg_di      ),
	 .wr_en                                   (st_ddr_out_fifo_rg_wr      ),
	 .rd_en                                   (st_ddr_out_fifo_rg_rd      ),
	 .dout                                    (st_ddr_out_fifo_rg_do      ),
	 .full                                    (st_ddr_out_fifo_rg_ful     ),
	 .empty                                   (st_ddr_out_fifo_rg_emy     ),
	 .valid                                   (st_ddr_out_fifo_rg_vld     ),
	 .prog_full                               (st_ddr_out_fifo_rg_pful    ),
	 .wr_rst_busy                             (                           ),
	 .rd_rst_busy                             (                           )
	)                                                                      ;
	

	// *************************** guidefir cal************************** // 
	dehaze_guidefirCal                       #(      
	 .GFIR_LAMTA                              (GFIR_LAMTA                 ),
	 .GD_CAL_SIZE                             (ST_CAL_SIZE * 'd8          ),
	 .FIFO_OUT_WIDTH                          (FIFO_OUT_WIDTH             ),
	 .AF_DATA_WIDTH                           (AF_DATA_WIDTH              ))
	my_dehaze_guidefirCal                     (                           
	 .clk                                     (gf_ca_clk                  ),
	 .rst_n                                   (rst_n_sync                 ),
	 
	 .ca_in_da_cnt                            (ca_in_da_cnt               ),
	 .ca_in_af0_vld                           (ca_in_af0_vld              ),
	 .ca_in_af0_bof                           (ca_in_af0_bof              ),
	 .ca_in_af0_eof                           (ca_in_af0_eof              ),
	                                                                      
	 .st_lc_state1_fsh                        (st_lc_state1_fsh_sync      ),
	 .st_lc_state2_fsh                        (st_lc_state2_fsh_sync      ),
	 .st_lc_state3_fsh                        (st_lc_state3_fsh_sync      ),
	                                                                      
	 .ca_in_gp_da                             (st_ddr_out_fifo_gp_do      ),
	 .ca_in_gp_vld                            (st_ddr_out_fifo_gp_vld     ),
	 .ca_in_gp_emy                            (st_ddr_out_fifo_gp_emy     ),
	 .ca_in_gp_rq                             (st_ddr_out_fifo_gp_rd      ),
	                                                                      
	 .ca_in_mm_da                             (st_ddr_out_fifo_mm_do      ),
	 .ca_in_mm_vld                            (st_ddr_out_fifo_mm_vld     ),
	 .ca_in_mm_emy                            (st_ddr_out_fifo_mm_emy     ),
	 .ca_in_mm_rq                             (st_ddr_out_fifo_mm_rd      ),
	                                                                      
	 .ca_in_rg_da                             (st_ddr_out_fifo_rg_do      ),
	 .ca_in_rg_vld                            (st_ddr_out_fifo_rg_vld     ),
	 .ca_in_rg_emy                            (st_ddr_out_fifo_rg_emy     ),
	 .ca_in_rg_rq                             (st_ddr_out_fifo_rg_rd      ),
                                                                          
	 .ca_out_mm_da                            (st_fifo_in_ddr_mm_di       ),
	 .ca_out_mm_vld                           (st_fifo_in_ddr_mm_wr       ),
	                                                                      
	 .ca_out_rg_da                            (st_fifo_in_ddr_rg_di       ),
	 .ca_out_rg_vld                           (st_fifo_in_ddr_rg_wr       ),
                                                                          
	 .ca_out_tr_da                            (st_fifo_in_ddr_tr_di       ),
	 .ca_out_tr_vld                           (st_fifo_in_ddr_tr_wr       )
	)                                                                      ;
	
endmodule
