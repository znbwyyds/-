`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/02/07 20:39:52
// Design Name: 
// Module Name: dehaze_removal
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


module dehaze_removal                       #(
	// declare parameters
	parameter                                 ATMOS_SAVE       = 230   ,
	parameter                                 IM_DATA_WIDTH    = 8     ,
	parameter                          		  DATA_WIDTH       = 24    )
	                                         (
	// logic clock and active-low reset
	input                              		  clk                      ,
	input                              		  rst_n                    ,
		
	// data in
	input                                     rm_in_hs                 ,
	input                                     rm_in_vs                 ,
	input                                     rm_in_de                 ,
	input         [DATA_WIDTH-1    : 0]       rm_in_da                 ,
	
	input         [IM_DATA_WIDTH-1 : 0]       rm_in_atmo_da            ,
	input         [IM_DATA_WIDTH-1 : 0]       rm_in_tran_da            ,
	
	// data out
	output                                    rm_out_hs                ,
	output                                    rm_out_vs                ,
	output                                    rm_out_de                ,
	output        [DATA_WIDTH-1    : 0]       rm_out_da               	
																	  );
	
	// ********************* define variable types ****************** // 
	
	reg           [15              : 0]       rm_in_atmo_mul           ;
	reg  signed   [8               : 0]       rm_in_atmo_da_s          ;
	
	reg  signed   [8               : 0]       rm_in_da_R               ;
	reg  signed   [8               : 0]       rm_in_da_G               ;
	reg  signed   [8               : 0]       rm_in_da_B               ;
	
	reg  signed   [8               : 0]       rm_sub_R                 ;
	reg  signed   [8               : 0]       rm_sub_G                 ;
	reg  signed   [8               : 0]       rm_sub_B                 ;
	
	wire signed   [24              : 0]       rm_multi_par             ;
	
	reg  signed   [32              : 0]       rm_multi_out_R           ;
	reg  signed   [32              : 0]       rm_multi_out_G           ;
	reg  signed   [32              : 0]       rm_multi_out_B           ;

	reg  signed   [16              : 0]       rm_multi_out_R_sft       ;
	reg  signed   [16              : 0]       rm_multi_out_G_sft       ;
	reg  signed   [16              : 0]       rm_multi_out_B_sft       ;
	
	reg  signed   [16              : 0]       rm_sum_R                 ;
	reg  signed   [16              : 0]       rm_sum_G                 ;
	reg  signed   [16              : 0]       rm_sum_B                 ;	
	
	
	// ********************* haze removal calculate ****************** //
	// rm_multi_par
	dehaze_removalPar dehaze_removalPar_B    (
     .clka                                   (clk                      ),   
     .addra                                  (rm_in_tran_da            ), 
     .douta                                  (rm_multi_par             )  
                                                                       );
																	  	
	// rm_in_atmo_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_in_atmo_mul <= 'd0;
		end
		else begin
			rm_in_atmo_mul <= rm_in_atmo_da * ATMOS_SAVE;
		end
	end
	
	// rm_in_atmo_da_s
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_in_atmo_da_s <= 'd0;
		end
		else begin
			rm_in_atmo_da_s <= {1'b0, rm_in_atmo_mul[15:8]};
		end
	end
	
	// rm_sub_R
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_in_da_R <= 'd0;
		end
		else begin
			rm_in_da_R <= {1'b0, rm_in_da[23:16]};
		end
	end
	
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_sub_R <= 'd0;
		end
		else begin
			rm_sub_R <= rm_in_da_R - rm_in_atmo_da_s;
		end
	end

	// rm_sub_G
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_in_da_G <= 'd0;
		end
		else begin
			rm_in_da_G <= {1'b0, rm_in_da[15:8]};
		end
	end
	
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_sub_G <= 'd0;
		end
		else begin
			rm_sub_G <= rm_in_da_G - rm_in_atmo_da_s;
		end
	end

	// rm_sub_B
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_in_da_B <= 'd0;
		end
		else begin
			rm_in_da_B <= {1'b0, rm_in_da[7:0]};
		end
	end
	
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_sub_B <= 'd0;
		end
		else begin
			rm_sub_B <= rm_in_da_B - rm_in_atmo_da_s;
		end
	end
	
	// rm_multi_out_R
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_multi_out_R <= 'd0;
		end
		else begin
			rm_multi_out_R <= rm_sub_R * rm_multi_par;
		end
	end

	// rm_multi_out_G
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_multi_out_G <= 'd0;
		end
		else begin
			rm_multi_out_G <= rm_sub_G * rm_multi_par;
		end
	end

	// rm_multi_out_B
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_multi_out_B <= 'd0;
		end
		else begin
			rm_multi_out_B <= rm_sub_B * rm_multi_par;
		end
	end
	
	// rm_multi_out_R_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_multi_out_R_sft <= 'd0;
		end
		else begin
			rm_multi_out_R_sft <= rm_multi_out_R / $signed(65536);
		end
	end

	// rm_multi_out_G_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_multi_out_G_sft <= 'd0;
		end
		else begin
			rm_multi_out_G_sft <= rm_multi_out_G / $signed(65536);
		end
	end

	// rm_multi_out_B_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_multi_out_B_sft <= 'd0;
		end
		else begin
			rm_multi_out_B_sft <= rm_multi_out_B / $signed(65536);
		end
	end
	
	// rm_sum_R
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_sum_R <= 'd0;
		end
		else begin
			rm_sum_R <= ((rm_multi_out_R_sft + rm_in_atmo_da_s) >  $signed(255))? $signed(255) : 
			            ((rm_multi_out_R_sft + rm_in_atmo_da_s) <  $signed(0)  )? $signed(0)   : (rm_multi_out_R_sft + rm_in_atmo_da_s);
		end
	end
	
    // rm_sum_G
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_sum_G <= 'd0;
		end
		else begin
			rm_sum_G <= ((rm_multi_out_G_sft + rm_in_atmo_da_s) >  $signed(255))? $signed(255) : 
			            ((rm_multi_out_G_sft + rm_in_atmo_da_s) <  $signed(0)  )? $signed(0)   : (rm_multi_out_G_sft + rm_in_atmo_da_s);
		end
	end

	// rm_sum_B
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			rm_sum_B <= 'd0;
		end
		else begin
			rm_sum_B <= ((rm_multi_out_B_sft + rm_in_atmo_da_s) >  $signed(255))? $signed(255) : 
			            ((rm_multi_out_B_sft + rm_in_atmo_da_s) <  $signed(0)  )? $signed(0)   : (rm_multi_out_B_sft + rm_in_atmo_da_s);
		end
	end

	// ************************** signals out ************************ //

	dehaze_sft_ram dehaze_sft_ram0 ( .D({rm_in_hs, rm_in_vs, rm_in_de}), .CLK(clk), .Q({rm_out_hs, rm_out_vs, rm_out_de}));
	assign rm_out_da = {rm_sum_R[7:0], rm_sum_G[7:0], rm_sum_B[7:0]};

endmodule
