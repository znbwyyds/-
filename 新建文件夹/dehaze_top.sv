`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/02/02 18:34:55
// Design Name: 
// Module Name: dehaze_top
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

module dehaze_top                            #(
	// declare parameters
	parameter                          		   VD_DATA_WIDTH  = 24         ,  
	parameter                          		   AF_DATA_WIDTH  = 18         ,  
	parameter                          		   IM_DATA_WIDTH  = 8          ,  
	parameter                          		   DDR_DATA_WIDTH = 64         ,  
	parameter                          		   DDR_ADDR_WIDTH = 16         ,  
	parameter                          		   DDR_BANK_WIDTH = 3          ,  
	parameter                          		   DDR_DQ_WIDTH   = 8          )  
                                              (
	// ddr ck in
	input                              		   sys_clk_p                   ,
	input                              		   sys_clk_n                   ,
	
	// ddr inouts                                                          
	inout  [DDR_DATA_WIDTH-1  : 0]             ddr3_dq                     ,
	inout  [DDR_DQ_WIDTH-1    : 0]             ddr3_dqs_n                  ,
	inout  [DDR_DQ_WIDTH-1    : 0]             ddr3_dqs_p                  ,
	
	// ddr outputs                                                         
	output [DDR_ADDR_WIDTH-1  : 0]             ddr3_addr                   ,
	output [DDR_BANK_WIDTH-1  : 0]             ddr3_ba                     ,
	output                                     ddr3_ras_n                  ,
	output                                     ddr3_cas_n                  ,
	output                                     ddr3_we_n                   ,
	output                                     ddr3_reset_n                ,
	output [0                 : 0]             ddr3_ck_p                   ,
	output [0                 : 0]             ddr3_ck_n                   ,
	output [0                 : 0]             ddr3_cke                    ,
	output [0                 : 0]             ddr3_cs_n                   ,
	output [DDR_DQ_WIDTH-1    : 0]             ddr3_dm                     ,
	output [0                 : 0]             ddr3_odt                    ,
	output                                     ddr3_init_calib_complete    ,
	
	output                                     dh_led                      ,
	
	// c0 in
	input                                      dh_c1_in_ck                 ,
	input                                      dh_c1_in_hs                 ,
	input                                      dh_c1_in_vs                 ,
	input                                      dh_c1_in_de                 ,
	input  [VD_DATA_WIDTH-1   : 0]             dh_c1_in_da                 ,	
	
	output                                     dh_c1_in_scl                ,
	inout                                      dh_c1_in_sda                ,
	output                                     dh_c1_in_rst                ,
	
	// c0 out
	output                                     dh_c0_out_ck                ,
	output                                     dh_c0_out_hs                ,
	output                                     dh_c0_out_vs                ,
	output                                     dh_c0_out_de                ,
	output [VD_DATA_WIDTH-1   : 0]             dh_c0_out_da                ,
	
	output                                     dh_c0_out_scl               ,
	inout                                      dh_c0_out_sda               ,

	// c0 out
	output                                     dh_c1_out_ck                ,
	output                                     dh_c1_out_hs                ,
	output                                     dh_c1_out_vs                ,
	output                                     dh_c1_out_de                ,
	output [VD_DATA_WIDTH-1   : 0]             dh_c1_out_da                ,
	
	output                                     dh_c1_out_scl               ,
	inout                                      dh_c1_out_sda               

                                                                          );
	
	// ********************** define variable types ********************* // 
	
	reg                                        rst_n                       ;
	reg    [7                 : 0]             rst_cnt                     ;
	wire                                       rst_n_bufg                  ;
	wire                                       dh_c1_in_ck_bufg            ;
	reg    [27                : 0]             dh_led_cnt                  ;

	wire                                       cf_in_scl                   ;
	wire                                       cf_in_sda                   ;
	wire                                       cf_in_rst                   ;
											    	
	wire                                       cf_out_scl                  ;
	wire                                       cf_out_sda                  ;
	
	reg                                        dh_c1_in_hs_r               ;
	reg                                        dh_c1_in_vs_r               ;
	reg                                        dh_c1_in_de_r               ;
	reg    [VD_DATA_WIDTH-1   : 0]             dh_c1_in_da_r               ;	
	
	wire   [VD_DATA_WIDTH-1   : 0]             dh_dsmp_da                  ;
	wire                                       dh_dsmp_vld                 ;
	wire                                       dh_dsmp_bof                 ;
	wire                                       dh_dsmp_eof                 ;

	wire   [IM_DATA_WIDTH-1   : 0]             dh_mrgb_da                  ;
	wire                                       dh_mrgb_vld                 ;
	wire                                       dh_mrgb_bof                 ;
	wire                                       dh_mrgb_eof                 ;

	wire   [AF_DATA_WIDTH-1   : 0]             dh_gray_da                  ;
	wire                                       dh_gray_vld                 ;
	wire                                       dh_gray_bof                 ;
	wire                                       dh_gray_eof                 ;
	
	wire   [IM_DATA_WIDTH-1   : 0]             dh_atmo_da                  ;
	
	wire   [IM_DATA_WIDTH-1   : 0]             dh_minf_da                  ;
	wire                                       dh_minf_vld                 ;
	wire                                       dh_minf_bof                 ;
	wire                                       dh_minf_eof                 ;

	wire   [AF_DATA_WIDTH-1   : 0]             dh_tran_da                  ;
	wire                                       dh_tran_vld                 ;
	wire                                       dh_tran_bof                 ;
	wire                                       dh_tran_eof                 ;

	wire   [2*AF_DATA_WIDTH-1 : 0]             dh_comb_da                  ;
	wire                                       dh_comb_vld                 ;
	wire                                       dh_comb_bof                 ;
	wire                                       dh_comb_eof                 ;

	wire                                       dh_vout_hs                  ;
	wire                                       dh_vout_vs                  ;
	wire                                       dh_vout_de                  ;
	wire   [VD_DATA_WIDTH-1   : 0]             dh_vout_da                  ;

	wire                                       dh_tout_hs                  ;
	wire                                       dh_tout_vs                  ;
	wire                                       dh_tout_de                  ;
	wire   [AF_DATA_WIDTH-1   : 0]             dh_tout_da                  ;
	
	wire                                       dh_rm_hs                    ;
	wire                                       dh_rm_vs                    ;
	wire                                       dh_rm_de                    ;
	wire   [VD_DATA_WIDTH-1   : 0]             dh_rm_da                    ;
	
	wire                                       ddr3_ui_clk                 ;
	
	reg    [11                : 0]             dh_out_da_cnt               ;
	wire                                       dh_out_rm_wr                ;
	wire                                       dh_out_rm_rd                ;
	wire                                       dh_out_rm_vld               ;
	wire   [VD_DATA_WIDTH-1   : 0]             dh_out_rm_da                ;
	
	reg    [VD_DATA_WIDTH-1   : 0]             dh_out_vd_da_1d             ;
	reg    [VD_DATA_WIDTH-1   : 0]             dh_out_vd_da_2d             ;
	reg    [VD_DATA_WIDTH-1   : 0]             dh_out_vd_da_3d             ;
	reg    [VD_DATA_WIDTH-1   : 0]             dh_out_vd_da_4d             ;
	reg    [VD_DATA_WIDTH-1   : 0]             dh_out_vd_da_5d             ;
	
	// ******************* clock & rst_n preprocessing ****************** // 
	dehaze_vd_in_ck dehaze_c0_vd_in_ck  ( .clk_out1(dh_c1_in_ck_bufg), .clk_in1(dh_c1_in_ck  ));
    BUFG            BUFG_dh_inst1       ( .O       (rst_n_bufg      ), .I      (rst_n        ));
		
    assign dh_c0_out_ck = dh_c1_in_ck_bufg;
    assign dh_c1_out_ck = dh_c1_in_ck_bufg;
	
	always @ (posedge ddr3_ui_clk) begin
		if(rst_cnt < 8'hf0) begin
			rst_cnt <= rst_cnt + 'd1;
		end
		else begin
			rst_cnt <= 8'hf0;
		end
	end

	always @ (posedge ddr3_ui_clk) begin
		if(rst_cnt < 8'h80) begin
			rst_n <= 1'b1;
		end
		else if(rst_cnt < 8'hf0) begin
			rst_n <= 1'b0;
		end
		else begin
			rst_n <= 1'b1;
		end
	end
		
	always @ (posedge ddr3_ui_clk) begin
		if(dh_led_cnt == 28'hfffffff) begin
			dh_led_cnt <= 'd0;
		end
		else begin
			dh_led_cnt <= dh_led_cnt + 'd1;
		end
	end
	
	assign dh_led = dh_led_cnt[27];
		
	// ************************ codec chip config *********************** // 
	dehaze_codec_cfg my_dehaze_codec_cfg      (                           
	 .clk                                     (ddr3_ui_clk                ),
																		 
	 .cf_out_scl                              (cf_out_scl                 ),
	 .cf_out_sda                              (cf_out_sda                 ),
																		  
	 .cf_in_scl                               (cf_in_scl                  ),
	 .cf_in_sda                               (cf_in_sda                  ),
	 .cf_in_rst                               (cf_in_rst                  )
                                                                          );
	
	assign dh_c1_in_scl = cf_in_scl;
	assign dh_c1_in_sda = cf_in_sda;
	assign dh_c1_in_rst = cf_in_rst;
	
	assign dh_c0_out_scl = cf_out_scl;
	assign dh_c0_out_sda = cf_out_sda;
	assign dh_c1_out_scl = cf_out_scl;
	assign dh_c1_out_sda = cf_out_sda;			

	// *********************** video signals in buf ********************* // 
	always @ (posedge dh_c1_in_ck_bufg or negedge rst_n_bufg) begin
		if(rst_n_bufg == 1'b0) begin
			{dh_c1_in_hs_r, dh_c1_in_vs_r, dh_c1_in_de_r, dh_c1_in_da_r} <= 'd0;
		end
		else begin
			{dh_c1_in_hs_r, dh_c1_in_vs_r, dh_c1_in_de_r, dh_c1_in_da_r} <=
			{dh_c1_in_hs  , dh_c1_in_vs  , dh_c1_in_de  , dh_c1_in_da  } ;
		end
	end
	
 	// reg [19:0] dh_in_cnt;
	// always @ (posedge dh_c1_in_ck_bufg or negedge rst_n_bufg) begin
		// if(rst_n_bufg == 1'b0) begin
			// dh_in_cnt <= 1'b0;
		// end
		// else if(dh_tran_eof == 1'b1) begin
			// dh_in_cnt <= 0;
		// end
		// else if(dh_tran_vld == 1'b1) begin
			// dh_in_cnt <= dh_in_cnt + 1;
		// end
	// end
	
/* 	reg dh_c1_in_hs_r_1d;
    // dh_c1_in_hs_r_1d
	always @ (posedge dh_c1_in_ck_bufg or negedge rst_n_bufg) begin
		if(rst_n_bufg == 1'b0) begin
			dh_c1_in_hs_r_1d <= 1'b0;
		end
		else begin
			dh_c1_in_hs_r_1d <= dh_c1_in_hs_r;
		end
	end
	
	reg [11:0] dh_c1_in_hs_cnt;
	// dh_c1_in_hs_cnt
	always @ (posedge dh_c1_in_ck_bufg or negedge rst_n_bufg) begin
		if(rst_n_bufg == 1'b0) begin
			dh_c1_in_hs_cnt <= 'd0;
		end
		else if(dh_c1_in_vs_r == 1'b1) begin
			dh_c1_in_hs_cnt <= 'd0;
		end
		else if((dh_c1_in_hs_r == 1'b1) && (dh_c1_in_hs_r_1d == 1'b0)) begin
			dh_c1_in_hs_cnt <= dh_c1_in_hs_cnt + 'd1;
		end
	end */
		
	// ila_0 ila_03 (
		// .clk(ila_pclk), // input wire clk
        
        
        // .probe0(dh_c1_in_hs_r), // input wire [0:0]  probe0  
        // .probe1(dh_c1_in_vs_r), // input wire [0:0]  probe1 
        // .probe2(dh_c1_in_de_r), // input wire [0:0]  probe2 
        // .probe3(dh_c1_in_da_r), // input wire [23:0]  probe3 
        // .probe4(dh_c1_in_hs_cnt), // input wire [11:0]  probe4 
        // .probe5(dh_minf_vld), // input wire [0:0]  probe5 
        // .probe6(dh_minf_bof), // input wire [0:0]  probe6 
        // .probe7(dh_minf_eof), // input wire [0:0]  probe7 
        // .probe8({16'h0, dh_minf_da}), // input wire [23:0]  probe8 
        // .probe9({dh_in_cnt[19:6], dh_atmo_da}) // input wire [21:0]  probe9
    // ); 

	// assign  dh_c0_out_hs = dh_c1_in_hs_r;
	// assign  dh_c0_out_vs = dh_c1_in_vs_r;
	// assign  dh_c0_out_de = dh_c1_in_de_r;
	// assign  dh_c0_out_da = dh_c1_in_da_r;

	// assign  dh_c1_out_hs = dh_c1_in_hs_r;
	// assign  dh_c1_out_vs = dh_c1_in_vs_r;
	// assign  dh_c1_out_de = dh_c1_in_de_r;
	// assign  dh_c1_out_da = {3{dh_tran_da[15:8]}};
	
	
  
	// ************************ downsampling video ********************** // 
    dehaze_dsamp                             #(
	 .DOWN_SIZE                               (2                          ),
	 .IN_LINE_LENGTH                          (1920                       ),
	 .IN_LINE_NUM                             (1080                       ),
	 .DATA_WIDTH                              (24                         ))
	my_dehaze_dsamp                           (
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),
                                                                          
	 .ds_in_hs                                (dh_c1_in_hs_r              ),
	 .ds_in_vs                                (dh_c1_in_vs_r              ),
	 .ds_in_de                                (dh_c1_in_de_r              ),
	 .ds_in_da                                (dh_c1_in_da_r              ),
                                                                          
	 .ds_out_da                               (dh_dsmp_da                 ),
	 .ds_out_vld                              (dh_dsmp_vld                ),
	 .ds_out_bof                              (dh_dsmp_bof                ),
	 .ds_out_eof                              (dh_dsmp_eof                )
                                                                          );
																																		  																		  
	// ********************** get min channel in rgb ******************** // 
	dehaze_rgbmin                            #( 
	 .IN_DATA_WIDTH                           (24                         ),
	 .OUT_DATA_WIDTH                          (8                          ))
	my_dehaze_rgbmin    					  (                           
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),

	 .pm_in_da                                (dh_dsmp_da                 ),
	 .pm_in_vld                               (dh_dsmp_vld                ),  
	 .pm_in_bof                               (dh_dsmp_bof                ),
	 .pm_in_eof                               (dh_dsmp_eof			      ), 

	 .pm_out_da                               (dh_mrgb_da                 ),
	 .pm_out_vld                              (dh_mrgb_vld                ),
	 .pm_out_bof                              (dh_mrgb_bof                ),
	 .pm_out_eof                              (dh_mrgb_eof                )
	                                                                      );
																		  
	// ************************ change rgb to gray ********************** // 
	dehaze_rgb2gray                          #( 
	 .IN_DATA_WIDTH                           (9                          ),
	 .OUT_DATA_WIDTH                          (18                         ))
	my_dehaze_rgb2gray          			  (                           
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),

	 .gr_in_da_r                              (dh_dsmp_da[23 : 16]        ),
	 .gr_in_da_g                              (dh_dsmp_da[15 : 8 ]        ),
	 .gr_in_da_b                              (dh_dsmp_da[7  : 0 ]        ),
	 .gr_in_vld                               (dh_dsmp_vld                ),

	 .gr_in_bof                               (dh_dsmp_bof                ),
	 .gr_in_eof                               (dh_dsmp_eof                ),

	 .gr_out_da                               (dh_gray_da                 ),
	 .gr_out_vld                              (dh_gray_vld                ),
	 .gr_out_bof                              (dh_gray_bof                ),
	 .gr_out_eof                              (dh_gray_eof                )
	                                                                      );
																		  
	// ************************** minimum filter ************************ // 
	dehaze_minfir       					 #(
	 .FIR_MAX_SIZE                            (15                         ),
	 .RATIO_SIZE                              (3                          ),
	 .FIFO_WIDTH                              (18                         ),
	 .DATA_WIDTH                              (8                          ),
	 .LINE_LENGTH                             (960                        ),
	 .MF_IN_BOF_JUDGE                         (960*8+7                    ))
	my_dehaze_minfir                          (
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),

	 .mf_in_da                                (dh_mrgb_da                 ),
	 .mf_in_vld                               (dh_mrgb_vld                ),
	 .mf_in_bof                               (dh_mrgb_bof                ),
	 .mf_in_eof                               (dh_mrgb_eof                ),

	 .mf_fir_size                             (7                          ),

	 .mf_out_da                               (dh_minf_da                 ),
	 .mf_out_vld                              (dh_minf_vld                ),
	 .mf_out_bof                              (dh_minf_bof                ),
	 .mf_out_eof                              (dh_minf_eof                )
	                                                                      );
																		  
	// *********************** atmosphere value cal ********************* // 
	dehaze_atmosCal                          #(                           
	 .DATA_WIDTH                              (8                          ),
	 .SAMPLE_SIZE                             (11                         ),
	 .RATIO                                   (6                          ))
	my_dehaze_atmosCal                        (                           
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),
																		  
	 .at_in_da                                (dh_minf_da                 ),
	 .at_in_vld                               (dh_minf_vld                ),
	 .at_in_bof                               (dh_minf_bof                ),
	 .at_in_eof                               (dh_minf_eof                ),
																		  
	 .at_out_da                               (dh_atmo_da                 )
                                                                          );
																		  
	// ************************ trans function cal ********************** //
	dehaze_transCal                          #(                           
	 .IN_DATA_WIDTH                           (8                          ),
	 .OUT_DATA_WIDTH                          (18                         ),
	 .TRANS_MIN                               (16'd6553                   ),
	 .HAZE_REMAIN                             (16'd58982                  ))
	my_dehaze_transCal  					  (                           
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),
																		  
	 .tr_in_atmos                             (dh_atmo_da                 ),
																		  
	 .tr_in_da                                (dh_minf_da                 ),
	 .tr_in_vld                               (dh_minf_vld                ),
	 .tr_in_bof                               (dh_minf_bof                ),
	 .tr_in_eof                               (dh_minf_eof                ),
																		  
	 .tr_out_da                               (dh_tran_da                 ),
	 .tr_out_vld                              (dh_tran_vld                ),
	 .tr_out_bof                              (dh_tran_bof                ),
	 .tr_out_eof                              (dh_tran_eof                )
																		  );
																		  
	// ******************* combine guide & pending image **************** //
	dehaze_combineSignal                     #(                           
	 .IN_DATA_WIDTH                           (18                         ),
	 .OUT_DATA_WIDTH                          (36                         ))
	my_dehaze_combineSignal                   (                           
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),
																		  
	 .cb_in_gd_da                             (dh_gray_da                 ),
	 .cb_in_gd_vld                            (dh_gray_vld                ),
	 .cb_in_gd_bof                            (dh_gray_bof                ),
	 .cb_in_gd_eof                            (dh_gray_eof                ),
																		  
	 .cb_in_pd_da                             (dh_tran_da                 ),
	 .cb_in_pd_vld                            (dh_tran_vld                ),
	 .cb_in_pd_bof                            (dh_tran_bof                ),
	 .cb_in_pd_eof                            (dh_tran_eof                ),
																		  
	 .cb_out_gp_da                            (dh_comb_da                 ),
	 .cb_out_gp_vld                           (dh_comb_vld                ),
	 .cb_out_gp_bof                           (dh_comb_bof                ),
	 .cb_out_gp_eof                           (dh_comb_eof                )
	                                                                      );
																		  
	// ********************** adjustable guide filter ******************* //
	dehaze_adjGuidefir                       #(      
	 .AF_DATA_WIDTH                           (18                         ),  
	 .VD_DATA_WIDTH                           (24                         ),  
	 .DDR_DATA_WIDTH                          (64                         ),  
	 .DDR_ADDR_WIDTH                          (16                         ),  
	 .DDR_BANK_WIDTH                          (3                          ),  
	 .DDR_DQ_WIDTH                            (8                          ),  
	 .BURST_LEN_WIDTH                         (10                         ),
	 .APP_ADDR_WIDTH                          (30                         ),  
	 .APP_CMD_WIDTH                           (3                          ),  
	 .APP_MASK_WIDTH                          (8                          ),  
	 .APP_DATA_WIDTH                          (512                        ),
	 .GFIR_LAMTA                              (68                         ))  
	my_dehaze_adjGuidefir					  (
	 .clk                                     (dh_c1_in_ck_bufg           ),
	 .rst_n                                   (rst_n_bufg                 ),
	 																		  
	 .gd_in_gp_da                             (dh_comb_da                 ),
	 .gd_in_gp_vld                            (dh_comb_vld                ),
	 .gd_in_gp_bof                            (dh_comb_bof                ),
	 .gd_in_gp_eof                            (dh_comb_eof                ),
																		  
	 .gd_in_vd_hs                             (dh_c1_in_hs_r              ),
	 .gd_in_vd_vs                             (dh_c1_in_vs_r              ),
	 .gd_in_vd_de                             (dh_c1_in_de_r              ),
	 .gd_in_vd_da                             (dh_c1_in_da_r              ),
																		  
	 .gd_out_vd_hs                            (dh_vout_hs                 ),
	 .gd_out_vd_vs                            (dh_vout_vs                 ),
	 .gd_out_vd_de                            (dh_vout_de                 ),
	 .gd_out_vd_da                            (dh_vout_da                 ),

	 .gd_out_tf_hs                            (dh_tout_hs                 ),
	 .gd_out_tf_vs                            (dh_tout_vs                 ),
	 .gd_out_tf_de                            (dh_tout_de                 ),
	 .gd_out_tf_da                            (dh_tout_da                 ),
																		  	
	// **************************** ddr3 signals ************************ // 
	 .ddr3_rst                                (1                          ),
	 .sys_clk_p                               (sys_clk_p                  ),
	 .sys_clk_n                               (sys_clk_n                  ),
																		  
	 .ddr3_dq                                 (ddr3_dq                    ),
	 .ddr3_dqs_n                              (ddr3_dqs_n                 ),
	 .ddr3_dqs_p                              (ddr3_dqs_p                 ),
																		  
	 .ddr3_addr                               (ddr3_addr                  ),
	 .ddr3_ba                                 (ddr3_ba                    ),
	 .ddr3_ras_n                              (ddr3_ras_n                 ),
	 .ddr3_cas_n                              (ddr3_cas_n                 ),
	 .ddr3_we_n                               (ddr3_we_n                  ),
	 .ddr3_reset_n                            (ddr3_reset_n               ),
	 .ddr3_ck_p                               (ddr3_ck_p                  ),
	 .ddr3_ck_n                               (ddr3_ck_n                  ),
	 .ddr3_cke                                (ddr3_cke                   ),
	 .ddr3_cs_n                               (ddr3_cs_n                  ),
	 .ddr3_dm                                 (ddr3_dm                    ),
	 .ddr3_odt                                (ddr3_odt                   ),
	 .ddr3_init_calib_complete                (ddr3_init_calib_complete   ),
	 .ddr3_ui_clk                             (ddr3_ui_clk                )
                                                                          );

	// ***************************** haze removal *********************** // 
	dehaze_removal                          #(
	 .ATMOS_SAVE                             (230                         ),
	 .IM_DATA_WIDTH                          (8                           ),
	 .DATA_WIDTH                             (24                          ))
	my_dehaze_removal                        (                            
	 .clk                                    (dh_c1_in_ck_bufg            ),
	 .rst_n                                  (rst_n_bufg                  ),
																	      
	 .rm_in_hs                               (dh_c1_in_hs_r               ),
	 .rm_in_vs                               (dh_c1_in_vs_r               ),
	 .rm_in_de                               (dh_c1_in_de_r               ),
	 .rm_in_da                               (dh_c1_in_da_r               ),
																	      
	 .rm_in_atmo_da                          (dh_atmo_da                  ),
	 .rm_in_tran_da                          (dh_tout_da[15:8]            ),
																	      
	 .rm_out_hs                              (dh_rm_hs                    ),
	 .rm_out_vs                              (dh_rm_vs                    ),
	 .rm_out_de                              (dh_rm_de                    ),
	 .rm_out_da                              (dh_rm_da                    )
															     		  );
 																		  
	// ************************** video data output ********************* //
    // dh_out_vd_da_5d
	always @ (posedge dh_c1_in_ck_bufg or negedge rst_n_bufg) begin
		if(rst_n_bufg == 1'b0) begin
			{dh_out_vd_da_5d, dh_out_vd_da_4d, dh_out_vd_da_3d, dh_out_vd_da_2d, dh_out_vd_da_1d} <= 'd0;
		end
		else begin
			{dh_out_vd_da_5d, dh_out_vd_da_4d, dh_out_vd_da_3d, dh_out_vd_da_2d, dh_out_vd_da_1d} <= 
			{dh_out_vd_da_4d, dh_out_vd_da_3d, dh_out_vd_da_2d, dh_out_vd_da_1d, dh_c1_in_da_r  } ;
		end
	end

	// dh_out_da_cnt
	always @ (posedge dh_c1_in_ck_bufg or negedge rst_n_bufg) begin
		if(rst_n_bufg == 1'b0) begin
			dh_out_da_cnt <= 'd0;
		end
		else if(dh_c1_in_de_r == 1'b1) begin
			dh_out_da_cnt <= dh_out_da_cnt + 1;
		end
		else begin
			dh_out_da_cnt <= 'd0;
		end
	end
	
	assign dh_out_rm_wr = (dh_out_da_cnt <  12'd960) & (dh_c1_in_de_r == 1'b1);
	assign dh_out_rm_rd = (dh_out_da_cnt >= 12'd959) & (dh_c1_in_de_r == 1'b1);
	
	
	dh_show_fifo dh_show_fifo0               (
	 .clk                                    (dh_c1_in_ck_bufg            ),                
	 .rst                                    (dh_c1_in_hs_r               ),                
	 .din                                    (dh_rm_da                    ),                
	 .wr_en                                  (dh_out_rm_wr                ),            
	 .rd_en                                  (dh_out_rm_rd                ),            
	 .dout                                   (dh_out_rm_da                ),              
	 .full                                   (                            ),              
	 .empty                                  (                            ),            
	 .valid                                  (dh_out_rm_vld               ),            
	 .wr_rst_busy                            (                            ),
	 .rd_rst_busy                            (                            ) 
	);
	
 																		 
	assign  dh_c0_out_hs = dh_tout_hs;
	assign  dh_c0_out_vs = dh_tout_vs;
	assign  dh_c0_out_de = dh_tout_de;
	assign  dh_c0_out_da = {3{dh_tout_da[15:8]}};

	assign  dh_c1_out_hs = dh_rm_hs;
	assign  dh_c1_out_vs = dh_rm_vs;
	assign  dh_c1_out_de = dh_rm_de;
	assign  dh_c1_out_da = (dh_out_rm_vld == 1'b1)? dh_out_rm_da : dh_out_vd_da_5d;
																		 
endmodule
