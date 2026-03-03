`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/09 19:56:15
// Design Name: 
// Module Name: dehaze_rgbmin
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


module dehaze_rgbmin                 #( 
	// declare parameters
	parameter                          		  IN_DATA_WIDTH   = 24     ,
	parameter                          		  OUT_DATA_WIDTH  = 8      )
									  (           
	// logic clock and active-low reset                                
	input                              		  clk                      ,
	input                              		  rst_n                    ,
											  
	// data in                                    
	input         [IN_DATA_WIDTH-1  : 0]      pm_in_da                 ,
	input                              		  pm_in_vld                ,
	// stay high for one cycle aligned to the first frame data         
	input                              		  pm_in_bof                ,
	// stay high for one cycle aligned to the last frame data            
	input                                     pm_in_eof                ,
																       
	// data out                                    	
	output    reg [OUT_DATA_WIDTH-1 : 0]      pm_out_da                ,
	output    reg                      		  pm_out_vld               ,
	output    reg                      		  pm_out_bof               ,
	output    reg                      		  pm_out_eof              );
	
	
	// ******************** define variable types ******************** // 
	reg                                       pm_comp2                 ;
	reg                                       pm_comp1                 ;
	
	reg           [IN_DATA_WIDTH-1  : 0]      pm_in_da_1d              ;
	reg                                       pm_in_vld_1d             ;
	reg                                       pm_in_bof_1d             ;
	reg                                       pm_in_eof_1d             ;


	// ************************* compare rgb ************************* // 
	// pm_comp2
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_comp2 <= 1'b0;
		end
		else begin
			pm_comp2 <= ((pm_in_da[3*OUT_DATA_WIDTH-1 : 2*OUT_DATA_WIDTH] <= pm_in_da[2*OUT_DATA_WIDTH-1 : 1*OUT_DATA_WIDTH]) &&
			             (pm_in_da[3*OUT_DATA_WIDTH-1 : 2*OUT_DATA_WIDTH] <= pm_in_da[1*OUT_DATA_WIDTH-1 : 0*OUT_DATA_WIDTH])) ;			
		end
	end

	// pm_comp1
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_comp1 <= 1'b0;
		end
		else begin
			pm_comp1 <= ((pm_in_da[2*OUT_DATA_WIDTH-1 : 1*OUT_DATA_WIDTH] <= pm_in_da[3*OUT_DATA_WIDTH-1 : 2*OUT_DATA_WIDTH]) &&
			             (pm_in_da[2*OUT_DATA_WIDTH-1 : 1*OUT_DATA_WIDTH] <= pm_in_da[1*OUT_DATA_WIDTH-1 : 0*OUT_DATA_WIDTH])) ;			
		end
	end
	
	// ********************* input signals delay ********************* // 
	// pm_in_da_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_in_da_1d <= 'd0;
		end
		else begin
			pm_in_da_1d <= pm_in_da;
		end
	end

	// pm_in_vld_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_in_vld_1d <= 1'b0;
		end
		else begin
			pm_in_vld_1d <= pm_in_vld;
		end
	end

	// pm_in_bof_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_in_bof_1d <= 1'b0;
		end
		else begin
			pm_in_bof_1d <= pm_in_bof;
		end
	end

	// pm_in_eof_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_in_eof_1d <= 1'b0;
		end
		else begin
			pm_in_eof_1d <= pm_in_eof;
		end
	end


	// ************************ signals output *********************** //
	// pm_out_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_out_da <= 'd0;
		end
		else if(pm_in_vld_1d == 1'b1) begin
			case({pm_comp2, pm_comp1})
				2'b11:   pm_out_da <= pm_in_da_1d[3*OUT_DATA_WIDTH-1 : 2*OUT_DATA_WIDTH];
				2'b10:   pm_out_da <= pm_in_da_1d[3*OUT_DATA_WIDTH-1 : 2*OUT_DATA_WIDTH];
				2'b01:   pm_out_da <= pm_in_da_1d[2*OUT_DATA_WIDTH-1 : 1*OUT_DATA_WIDTH];
				2'b00:   pm_out_da <= pm_in_da_1d[1*OUT_DATA_WIDTH-1 : 0*OUT_DATA_WIDTH];
			endcase
		end
		else begin
			pm_out_da <= 'd0;
		end
	end
	
	// pm_out_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_out_vld <= 1'b0;
		end
		else begin
			pm_out_vld <= pm_in_vld_1d;
		end
	end

	// pm_out_bof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_out_bof <= 1'b0;
		end
		else begin
			pm_out_bof <= pm_in_bof_1d;
		end
	end

	// pm_out_eof
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			pm_out_eof <= 1'b0;
		end
		else begin
			pm_out_eof <= pm_in_eof_1d;
		end
	end
	
endmodule
