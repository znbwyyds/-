`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/02/03 15:43:43
// Design Name: 
// Module Name: dehaze_codec_cfg
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


module dehaze_codec_cfg                       (
	input                              		   clk                         ,
		
	output                                     cf_in_scl                   ,
	inout                                      cf_in_sda                   ,
	output                                     cf_in_rst                   ,

	output                                     cf_out_scl                  ,
	inout                                      cf_out_sda                   	
                                                                          );
	
	
	ADV7511_INTERFACE my_ADV7511_INTERFACE    (                           
	 .clk100M                                 (clk                        ),
	 .HDMI_O_SCL                              (cf_out_scl                 ),
	 .HDMI_O_SDA                              (cf_out_sda                 )
                                                                          );  
																		  
	ADV7611_INTERFACE my_ADV7611_INTERFACE    (                           
     .clk100M                                 (clk                        ),
     .HDMI_I_SCL                              (cf_in_scl                  ),
     .HDMI_I_SDA                              (cf_in_sda                  ),
     .HDMI_I_RESET                            (cf_in_rst                  )
                                                                          );

endmodule
