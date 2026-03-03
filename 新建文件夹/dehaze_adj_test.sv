`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/12 14:38:31
// Design Name: 
// Module Name: dehaze_adjGuidefir
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


module dehaze_adj_test               #(      
	// declare parameters
	parameter                          		   AF_DATA_WIDTH  = 18         ,  
	parameter                          		   VD_DATA_WIDTH  = 24         ,  
	parameter                          		   DDR_DATA_WIDTH = 64         ,  
	parameter                          		   DDR_ADDR_WIDTH = 16         ,  
	parameter                          		   DDR_BANK_WIDTH = 3          ,  
	parameter                          		   DDR_DQ_WIDTH   = 8          ,  
	parameter                                  BURST_LEN_WIDTH= 10         ,
	parameter                          		   APP_ADDR_WIDTH = 30         ,  
	parameter                          		   APP_CMD_WIDTH  = 3          ,  
	parameter                          		   APP_MASK_WIDTH = 64         ,  
	parameter                          		   APP_DATA_WIDTH = 512        ,
	parameter                                  GFIR_LAMTA     = 68         )  
									  (
	// logic clock and active-low reset
	input                                      clk                         ,
	input                                      rst_n                       ,
	
	// data in
	input  [2*AF_DATA_WIDTH-1 : 0]             gd_in_gp_da                 ,
	input                              		   gd_in_gp_vld                ,
	input                              		   gd_in_gp_bof                ,
	input                              		   gd_in_gp_eof                ,

	input                              		   gd_in_vd_hs                 ,
	input                              		   gd_in_vd_vs                 ,
	input                              		   gd_in_vd_de                 ,
	input  [VD_DATA_WIDTH-1 : 0]               gd_in_vd_da                 ,

	// data out
	output                             		   gd_out_vd_hs                ,
	output                             		   gd_out_vd_vs                ,
	output                             		   gd_out_vd_de                ,
	output [VD_DATA_WIDTH-1 : 0]               gd_out_vd_da                ,
	
	output                                     gd_out_tf_hs                ,
	output                             		   gd_out_tf_vs                ,
	output                             		   gd_out_tf_de                ,
	output [AF_DATA_WIDTH-1 : 0]       		   gd_out_tf_da                

    );
	
	
	// ************************ define variable types ******************** // 
		
	wire   [APP_ADDR_WIDTH-1  : 0]             app_addr                    ;
	wire   [APP_CMD_WIDTH-1   : 0]             app_cmd                     ;
	wire                                       app_en                      ;
	wire                                       app_rdy                     ;
	wire   [APP_DATA_WIDTH-1  : 0]             app_rd_data                 ;
	wire                                       app_rd_data_end             ;
	wire                                       app_rd_data_valid           ;
	wire   [APP_DATA_WIDTH-1  : 0]             app_wdf_data                ;
	wire                                       app_wdf_end                 ;
	wire   [APP_MASK_WIDTH-1  : 0]             app_wdf_mask                ;
	wire                                       app_wdf_rdy                 ;
	wire                                       app_wdf_wren 	           ;
	
    wire                                       ddr3_wr_req                 ;
    wire   [BURST_LEN_WIDTH-1 : 0]             ddr3_wr_len                 ;
    wire   [APP_ADDR_WIDTH-1  : 0]             ddr3_wr_addr                ;
    wire   [APP_DATA_WIDTH-1  : 0]             ddr3_wr_data                ;
    wire                                       ddr3_wr_da_req              ;
    wire                                       ddr3_wr_fsh                 ;
															               
    wire                                       ddr3_rd_req                 ;
    wire   [BURST_LEN_WIDTH-1 : 0]             ddr3_rd_len                 ;
    wire   [APP_ADDR_WIDTH-1  : 0]             ddr3_rd_addr                ;
    wire                                       ddr3_rd_vld                 ;
    wire   [APP_DATA_WIDTH-1  : 0]             ddr3_rd_data                ;
    wire                                       ddr3_rd_fsh                 ;

	dehaze_streamMachine                     #(    
	 .BURST_LEN_WIDTH                         (BURST_LEN_WIDTH            ),
	 .AF_DATA_WIDTH                           (AF_DATA_WIDTH              ),
	 .VD_DATA_WIDTH                           (VD_DATA_WIDTH              ),
	 .APP_ADDR_WIDTH                          (APP_ADDR_WIDTH             ),
	 .APP_DATA_WIDTH                          (APP_DATA_WIDTH             ),
	 .GFIR_LAMTA                              (GFIR_LAMTA                 ))
	my_dehaze_streamMachine                   (                           
	.st_ui_clk                                (clk      	              ),
	.st_wr_da_req                             (ddr3_wr_da_req             ),
    .st_wr_fsh                                (ddr3_wr_fsh                ),
    .st_wr_req                                (ddr3_wr_req                ),
    .st_wr_len                                (ddr3_wr_len                ),
    .st_wr_addr                               (ddr3_wr_addr               ),
    .st_wr_data                               (ddr3_wr_data               ),
																		  
	.st_rd_data                               (ddr3_rd_data               ),
	.st_rd_vld                                (ddr3_rd_vld                ),
	.st_rd_fsh                                (ddr3_rd_fsh                ),
	.st_rd_req                                (ddr3_rd_req                ),
	.st_rd_len                                (ddr3_rd_len                ),
	.st_rd_addr                               (ddr3_rd_addr               ),
																		  
	.clk                                      (clk                        ),
    .rst_n                                    (rst_n                      ),
	.st_in_gp_da                              (gd_in_gp_da                ),
	.st_in_gp_vld                             (gd_in_gp_vld               ),
	.st_in_gp_bof                             (gd_in_gp_bof               ),
	.st_in_gp_eof                             (gd_in_gp_eof               ),

	.st_in_vd_hs                              (gd_in_vd_hs                ),
	.st_in_vd_vs                              (gd_in_vd_vs                ),
	.st_in_vd_de                              (gd_in_vd_de                ),
	.st_in_vd_da                              (gd_in_vd_da                ),

	.st_out_vd_hs                             (gd_out_vd_hs               ),
	.st_out_vd_vs                             (gd_out_vd_vs               ),
	.st_out_vd_de                             (gd_out_vd_de               ),
	.st_out_vd_da                             (gd_out_vd_da               ),

	.st_out_tf_hs                             (gd_out_tf_hs               ),
	.st_out_tf_vs                             (gd_out_tf_vs               ),
	.st_out_tf_de                             (gd_out_tf_de               ),
	.st_out_tf_da                             (gd_out_tf_da               )
	)                                                                      ;
	
	dehaze_ddrCtrl                           #(
     .BURST_LEN_WIDTH                         (BURST_LEN_WIDTH            ),	
	 .MEM_DATA_BITS                           (APP_DATA_WIDTH             ),
	 .ADDR_BITS                   	          (APP_ADDR_WIDTH             ))
	my_dehaze_ddrCtrl                         (                                            
	 .rst_n                                   (rst_n                      ),         
	 .mem_clk                                 (clk                        ),
	 .wr_burst_req                            (ddr3_wr_req                ),
	 .wr_burst_len                            (ddr3_wr_len                ),
	 .wr_burst_addr                           (ddr3_wr_addr               ),
	 .wr_burst_data                           (ddr3_wr_data               ),
	 .wr_burst_data_req                       (ddr3_wr_da_req             ),
	 .wr_burst_finish                         (ddr3_wr_fsh                ),
	 .rd_burst_req                            (ddr3_rd_req                ),
	 .rd_burst_len                            (ddr3_rd_len                ),
	 .rd_burst_addr                           (ddr3_rd_addr               ),
	 .rd_burst_data                           (ddr3_rd_data               ),
	 .rd_burst_data_valid                     (ddr3_rd_vld                ),
	 .rd_burst_finish                         (ddr3_rd_fsh                ),
	 .burst_finish                            (                           ),
											 						      
     .app_addr                                (app_addr                   ),
     .app_cmd                                 (app_cmd                    ),
     .app_en                                  (app_en                     ),
     .app_wdf_data                            (app_wdf_data               ),
     .app_wdf_end                             (app_wdf_end                ),
     .app_wdf_mask                            (app_wdf_mask               ),
     .app_wdf_wren                            (app_wdf_wren               ),
     .app_rd_data                             (app_rd_data                ),
     .app_rd_data_end                         (app_rd_data_end            ),
     .app_rd_data_valid                       (app_rd_data_valid          ),
     .app_rdy                                 (app_rdy                    ),
     .app_wdf_rdy                             (app_wdf_rdy                ),
     .ui_clk_sync_rst                         (                           ),
     .init_calib_complete                     (ddr3_init_calib_complete   )
	)                                                                      ;
	
	reg [8:0] out_cnt;
	reg app_rd_data_valid_r;
	
	
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0)
			app_rd_data_valid_r <= 0;
		else if(app_cmd == 1 && app_en == 1 && out_cnt < 480)
			app_rd_data_valid_r <= 1;
		else 
			app_rd_data_valid_r <= 0;
	end

	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0)
			out_cnt <= 0;
		else if(app_cmd == 1 && app_en == 1)
			out_cnt <= out_cnt + 1;
		else 
			out_cnt <= 0;
	end
	
	assign app_rdy = 1;
	assign app_wdf_rdy = 1;
	assign app_rd_data = 4'b1111;
	assign app_rd_data_valid = app_rd_data_valid_r;
	assign ddr3_init_calib_complete = 1;
	assign app_rd_data_end = 0;
	
/*											 
	dehaze_ddr_ip     u_dehaze_ddr_ip0        (
     // Memory interface ports                
     .ddr3_addr                               (ddr3_addr                  ),
     .ddr3_ba                                 (ddr3_ba                    ),
     .ddr3_cas_n                              (ddr3_cas_n                 ),
     .ddr3_ck_n                               (ddr3_ck_n                  ),
     .ddr3_ck_p                               (ddr3_ck_p                  ),
     .ddr3_cke                                (ddr3_cke                   ),
     .ddr3_ras_n                              (ddr3_ras_n                 ),
     .ddr3_reset_n                            (ddr3_reset_n               ),
     .ddr3_we_n                               (ddr3_we_n                  ),
     .ddr3_dq                                 (ddr3_dq                    ),
     .ddr3_dqs_n                              (ddr3_dqs_n                 ),
     .ddr3_dqs_p                              (ddr3_dqs_p                 ),
     .init_calib_complete                     (ddr3_init_calib_complete   ),
										        				 
	 .ddr3_cs_n                               (ddr3_cs_n                  ),
     .ddr3_dm                                 (ddr3_dm                    ),
     .ddr3_odt                                (ddr3_odt                   ),
     // Application interface ports                                       
     .app_addr                                (app_addr                   ),
     .app_cmd                                 (app_cmd                    ),
     .app_en                                  (app_en                     ),
     .app_wdf_data                            (app_wdf_data               ),
     .app_wdf_end                             (app_wdf_end                ),
     .app_wdf_wren                            (app_wdf_wren               ),
     .app_rd_data                             (app_rd_data                ),
     .app_rd_data_end                         (app_rd_data_end            ),
     .app_rd_data_valid                       (app_rd_data_valid          ),
     .app_rdy                                 (app_rdy                    ),
     .app_wdf_rdy                             (app_wdf_rdy                ),
     .app_sr_req                              (1'b0                       ),
     .app_ref_req                             (1'b0                       ),
     .app_zq_req                              (1'b0                       ),
     .app_sr_active                           (                           ),
     .app_ref_ack                             (                           ),
     .app_zq_ack                              (                           ),
     .ui_clk                                  (ddr3_ui_clk                ),
     .ui_clk_sync_rst                         (                           ),
     .app_wdf_mask                            (0                          ),
     // System Clock Ports                                                
     .sys_clk_p                               (sys_clk_p                  ),
     .sys_clk_n                               (sys_clk_n                  ),
     .sys_rst                                 (ddr3_rst                   )
    )                                                                      ;
*/

endmodule
