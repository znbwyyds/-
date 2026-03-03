`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/15 12:25:54
// Design Name: 
// Module Name: dehaze_guidefirCal
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


module dehaze_guidefirCal            #(      
	// declare parameters
	parameter                        		   GFIR_LAMTA     = 68         ,  
	parameter                                  GD_CAL_SIZE    = 20'd518400 ,
	parameter                          		   FIFO_OUT_WIDTH = 40         ,  
	parameter                          		   AF_DATA_WIDTH  = 18         )  
	                                  (
	// logic clock and active-low reset
	input                                      clk                         ,
	input                                      rst_n                       ,
	
	output     [19               : 0]          ca_in_da_cnt                , 
	output 	                                   ca_in_af0_vld               ,
    output                                     ca_in_af0_bof               ,	
    output                                     ca_in_af0_eof               ,	
	
	// cal state
	input                                      st_lc_state1_fsh            ,
	input                                      st_lc_state2_fsh            ,
	input                                      st_lc_state3_fsh            ,
	
	// in gp fifo inst
	input       [FIFO_OUT_WIDTH-1: 0]          ca_in_gp_da                 ,
	input                                      ca_in_gp_vld                ,
	input                                      ca_in_gp_emy                ,
	output reg                                 ca_in_gp_rq                 ,
	
	// in mm fifo inst
	input       [FIFO_OUT_WIDTH-1: 0]          ca_in_mm_da                 ,
	input                                      ca_in_mm_vld                ,
	input                                      ca_in_mm_emy                ,
	output reg                                 ca_in_mm_rq                 ,
	
	// in rg fifo inst
	input       [FIFO_OUT_WIDTH-1: 0]          ca_in_rg_da                 ,
	input                                      ca_in_rg_vld                ,
	input                                      ca_in_rg_emy                ,
	output reg                                 ca_in_rg_rq                 ,

	// out mm fifo inst
	output      [FIFO_OUT_WIDTH-1: 0]          ca_out_mm_da                ,
	output                                     ca_out_mm_vld               ,
	
	// out rg fifo inst
	output      [FIFO_OUT_WIDTH-1: 0]          ca_out_rg_da                ,
	output                                     ca_out_rg_vld               ,

	// out tr fifo inst
	output      [FIFO_OUT_WIDTH-1: 0]          ca_out_tr_da                ,
	output                                     ca_out_tr_vld               

	)                                                                      ;
	
	// ************************ define variable types ******************** // 
	reg                                        st_lc_state1_fsh_1d         ;
	reg                                        st_lc_state2_fsh_1d         ;
	reg                                        st_lc_state3_fsh_1d         ;
	wire        [2                 : 0]        st_lc_state_fsh             ;
	reg         [2                 : 0]        st_lc_state_fsh_1d          ;
	
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_af0_da                ;
	reg                                        ca_in_af0_vld               ;
	reg                                        ca_in_af0_bof               ;
	reg                                        ca_in_af0_eof               ;
	reg         [2                 : 0]        ca_in_af0_size              ;
								    
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_out_af0_da               ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af0_da_1d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af0_da_2d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af0_da_3d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af0_da_4d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af0_da_5d            ;
	wire                                       ca_out_af0_vld              ;
	wire                                       ca_out_af0_bof              ;
	wire                                       ca_out_af0_eof              ;
	reg                                        ca_out_af0_vld_1d           ;
	reg                                        ca_out_af0_vld_2d           ;
	reg                                        ca_out_af0_vld_3d           ;
	reg                                        ca_out_af0_vld_4d           ;
	reg                                        ca_out_af0_vld_5d           ;
	reg                                        ca_out_af0_vld_6d           ;
									    
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_af1_da                ;
	wire                                       ca_in_af1_vld               ;
	wire                                       ca_in_af1_bof               ;
	wire                                       ca_in_af1_eof               ;
	reg         [2                 : 0]        ca_in_af1_size              ;
								    
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_out_af1_da               ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af1_da_1d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af1_da_2d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af1_da_3d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af1_da_4d            ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_out_af1_da_5d            ;
	wire                                       ca_out_af1_vld              ;
	wire                                       ca_out_af1_bof              ;
	wire                                       ca_out_af1_eof              ;
	
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_in_gi_da                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_gi_da_1d              ;
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_in_pi_da                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_pi_da_1d              ;
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_in_mg_da                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_mg_da_1d              ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_mg_da_2d              ;
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_in_mp_da                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_mp_da_1d              ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_mp_da_2d              ;
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_in_vr_da                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_vr_da_1d              ;
	wire signed [AF_DATA_WIDTH-1   : 0]        ca_in_re_da                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_re_da_1d              ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_re_da_2d              ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_re_da_3d              ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_in_re_da_4d              ;
	
	reg  signed [2*AF_DATA_WIDTH-1 : 0]        ca_gigi_mul                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_gigi_mul_sft             ;
	reg  signed [2*AF_DATA_WIDTH-1 : 0]        ca_gipi_mul                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_gipi_mul_sft             ;
	reg  signed [2*AF_DATA_WIDTH-1 : 0]        ca_mgmg_mul                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_mgmg_mul_sft             ;
	reg  signed [2*AF_DATA_WIDTH-1 : 0]        ca_mgmp_mul                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_mgmp_mul_sft             ;
		
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_vr_sub                   ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_rg_sub                   ;
	
	reg         [15                : 0]        ca_guideCal_addr            ;
	wire signed [32                : 0]        ca_guideCal_par             ;
	reg  signed [50                : 0]        ca_multi_in1                ;
	
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_ak                       ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_ak_1d                    ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_ak_2d                    ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_ak_3d                    ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_ak_4d                    ;
	
	reg  signed [AF_DATA_WIDTH+7   : 0]        ca_in_mp_bk1                ;
	reg  signed [AF_DATA_WIDTH+7   : 0]        ca_in_mp_bk2                ;
	reg  signed [AF_DATA_WIDTH+7   : 0]        ca_bk                       ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_bk_sft                   ;
	
	reg  signed [AF_DATA_WIDTH+7   : 0]        ca_akgi_mul                 ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_akgi_mul_sft             ;
	reg  signed [AF_DATA_WIDTH-1   : 0]        ca_akgi_add                 ;

	reg                                        ca_in_gp_vld_1d             ;
	reg                                        ca_in_gp_vld_2d             ;
	reg                                        ca_in_gp_vld_3d             ;

	reg                                        ca_in_rg_vld_1d             ;
	reg                                        ca_in_rg_vld_2d             ;
	reg                                        ca_in_rg_vld_3d             ;
	reg                                        ca_in_rg_vld_4d             ;
	reg                                        ca_in_rg_vld_5d             ;
	reg                                        ca_in_rg_vld_6d             ;
	reg                                        ca_in_rg_vld_7d             ;
	reg                                        ca_in_rg_vld_8d             ;
	reg                                        ca_in_rg_vld_9d             ;
	reg                                        ca_in_rg_vld_ad             ;
	
	reg         [19                : 0]        ca_in_da_cnt                ;
	
	
	// ************************** fifo ctrl signals ********************** // 
	// ca_in_af0_size
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_af0_size <= 'd0;
		end
		else begin
			ca_in_af0_size <= 3'd7;
		end
	end

	// ca_in_af1_size
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_af1_size <= 'd0;
		end
		else begin
			ca_in_af1_size <= 3'd7;
		end
	end
	
	// st_lc_state_fsh
	assign st_lc_state_fsh = {st_lc_state1_fsh, st_lc_state2_fsh, st_lc_state3_fsh};
	
	// st_lc_state_fsh_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			st_lc_state_fsh_1d <= 'd0;
		end
		else begin
			st_lc_state_fsh_1d <= st_lc_state_fsh;
		end
	end

	// ca_in_gp_rq
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_gp_rq <= 1'b0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_gp_rq <= (ca_in_gp_emy == 1'b0)? 1'b1 : 1'b0;
				3'b100:  ca_in_gp_rq <= ((ca_in_gp_emy == 1'b0) && (ca_in_mm_emy == 1'b0))? 1'b1 : 1'b0;
				3'b110:  ca_in_gp_rq <= (ca_out_af0_vld == 1'b1)? 1'b1 : 1'b0;
			    default: ca_in_gp_rq <= 1'b0;
			endcase
		end
	end
	
	// ca_in_mm_rq
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_mm_rq <= 1'b0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_mm_rq <= 1'b0;
				3'b100:  ca_in_mm_rq <= (ca_out_af0_vld == 1'b1)? 1'b1 : 1'b0;
				3'b110:  ca_in_mm_rq <= (ca_in_rg_vld_3d == 1'b1)? 1'b1 : 1'b0;
			    default: ca_in_mm_rq <= 1'b0;
			endcase
		end
	end
	
	// ca_in_rg_rq
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_rg_rq <= 1'b0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_rg_rq <= 1'b0;
				3'b100:  ca_in_rg_rq <= 1'b0;
				3'b110:  ca_in_rg_rq <= ((ca_in_mm_emy == 1'b0) && (ca_in_rg_emy == 1'b0) && (ca_in_gp_emy == 1'b0))? 1'b1 : 1'b0;
			    default: ca_in_rg_rq <= 1'b0;
			endcase
		end
	end

	// ****************************** data in **************************** // 
	// ca_in_gi_da
	assign ca_in_gi_da = (ca_in_gp_vld == 1'b1)? ca_in_gp_da[2*AF_DATA_WIDTH-1 : AF_DATA_WIDTH] : 'd0;
	// ca_in_pi_da
	assign ca_in_pi_da = (ca_in_gp_vld == 1'b1)? ca_in_gp_da[AF_DATA_WIDTH-1 : 0] : 'd0;
	// ca_in_mg_da
	assign ca_in_mg_da = (ca_in_mm_vld == 1'b1)? ca_in_mm_da[2*AF_DATA_WIDTH-1 : AF_DATA_WIDTH] : 'd0;
	// ca_in_mp_da
	assign ca_in_mp_da = (ca_in_mm_vld == 1'b1)? ca_in_mm_da[AF_DATA_WIDTH-1 : 0] : 'd0;
	// ca_in_vr_da
	assign ca_in_vr_da = (ca_in_rg_vld == 1'b1)? ca_in_rg_da[2*AF_DATA_WIDTH-1 : AF_DATA_WIDTH] : 'd0;
	// ca_in_re_da
	assign ca_in_re_da = (ca_in_rg_vld == 1'b1)? ca_in_rg_da[AF_DATA_WIDTH-1 : 0] : 'd0;
	
	// ca_in_gi_da_1d & ca_in_pi_da_1d & ca_in_mg_da_1d & ca_in_mp_da_1d & ca_in_vr_da_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_in_gi_da_1d, ca_in_pi_da_1d, ca_in_mg_da_1d, ca_in_mp_da_1d, ca_in_vr_da_1d} <= 'd0;
		end
		else begin
			{ca_in_gi_da_1d, ca_in_pi_da_1d, ca_in_mg_da_1d, ca_in_mp_da_1d, ca_in_vr_da_1d} <= 
			{ca_in_gi_da   , ca_in_pi_da   , ca_in_mg_da   , ca_in_mp_da   , ca_in_vr_da   } ;
		end
	end
	
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_in_mg_da_2d, ca_in_mp_da_2d} <= 'd0;
		end
		else begin
			{ca_in_mg_da_2d, ca_in_mp_da_2d} <= {ca_in_mg_da_1d, ca_in_mp_da_1d};
		end
	end
	
	

	// ca_in_gp_vld delay
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_in_gp_vld_3d, ca_in_gp_vld_2d, ca_in_gp_vld_1d} <= 'd0;
		end
		else begin
			{ca_in_gp_vld_3d, ca_in_gp_vld_2d, ca_in_gp_vld_1d} <= 
			{ca_in_gp_vld_2d, ca_in_gp_vld_1d, ca_in_gp_vld   } ;
		end
	end
		
	// ca_in_rg_vld delay
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_in_rg_vld_ad, ca_in_rg_vld_9d, ca_in_rg_vld_8d, ca_in_rg_vld_7d, ca_in_rg_vld_6d, ca_in_rg_vld_5d, ca_in_rg_vld_4d, ca_in_rg_vld_3d, ca_in_rg_vld_2d, ca_in_rg_vld_1d} <= 'd0;
		end
		else begin
			{ca_in_rg_vld_ad, ca_in_rg_vld_9d, ca_in_rg_vld_8d, ca_in_rg_vld_7d, ca_in_rg_vld_6d, ca_in_rg_vld_5d, ca_in_rg_vld_4d, ca_in_rg_vld_3d, ca_in_rg_vld_2d, ca_in_rg_vld_1d} <= 
			{ca_in_rg_vld_9d, ca_in_rg_vld_8d, ca_in_rg_vld_7d, ca_in_rg_vld_6d, ca_in_rg_vld_5d, ca_in_rg_vld_4d, ca_in_rg_vld_3d, ca_in_rg_vld_2d, ca_in_rg_vld_1d, ca_in_rg_vld   } ;
		end
	end
	
	// ca_in_da_cnt
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_da_cnt <= 'd0;
		end
		else if(st_lc_state_fsh != st_lc_state_fsh_1d) begin
			ca_in_da_cnt <= 'd0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_da_cnt <= (ca_in_gp_vld    == 1'b1)? (ca_in_da_cnt + 'd1) : ca_in_da_cnt;
				3'b100:  ca_in_da_cnt <= (ca_in_gp_vld_3d == 1'b1)? (ca_in_da_cnt + 'd1) : ca_in_da_cnt;
				3'b110:  ca_in_da_cnt <= (ca_in_rg_vld_ad == 1'b1)? (ca_in_da_cnt + 'd1) : ca_in_da_cnt;
			    default: ca_in_da_cnt <= 'd0;
			endcase
		end
	end
	
	// ca_in_af0_vld
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_af0_vld <= 1'b0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_af0_vld <= ca_in_gp_vld;
				3'b100:  ca_in_af0_vld <= ca_in_gp_vld_3d;
				3'b110:  ca_in_af0_vld <= ca_in_rg_vld_ad;
			    default: ca_in_af0_vld <= 1'b0;
			endcase
		end
	end
	
	// ca_in_af0_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_af0_da <= 'd0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_af0_da <= ca_in_gi_da;
				3'b100:  ca_in_af0_da <= ca_gigi_mul_sft;
				3'b110:  ca_in_af0_da <= ca_ak_4d;
			    default: ca_in_af0_da <= 1'b0;
			endcase
		end
	end
	
	// ca_in_af0_bof	
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_af0_bof <= 1'b0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_af0_bof <= (ca_in_da_cnt == 'd0) && (ca_in_gp_vld    == 1'b1);
				3'b100:  ca_in_af0_bof <= (ca_in_da_cnt == 'd0) && (ca_in_gp_vld_3d == 1'b1);
				3'b110:  ca_in_af0_bof <= (ca_in_da_cnt == 'd0) && (ca_in_rg_vld_ad == 1'b1);
			    default: ca_in_af0_bof <= 1'b0;
			endcase
		end
	end

	// ca_in_af0_eof	
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_af0_eof <= 1'b0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_af0_eof <= (ca_in_da_cnt == (GD_CAL_SIZE - 'd1)) && (ca_in_gp_vld    == 1'b1);
				3'b100:  ca_in_af0_eof <= (ca_in_da_cnt == (GD_CAL_SIZE - 'd1)) && (ca_in_gp_vld_3d == 1'b1);
				3'b110:  ca_in_af0_eof <= (ca_in_da_cnt == (GD_CAL_SIZE - 'd1)) && (ca_in_rg_vld_ad == 1'b1);
			    default: ca_in_af0_eof <= 1'b0;
			endcase
		end
	end

	// ca_in_af1_vld
    assign ca_in_af1_vld = ca_in_af0_vld;
	
	// ca_in_af1_da
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_af1_da <= 'd0;
		end
		else begin
			case(st_lc_state_fsh)
				3'b000:  ca_in_af1_da <= ca_in_pi_da;
				3'b100:  ca_in_af1_da <= ca_gipi_mul_sft;
				3'b110:  ca_in_af1_da <= ca_bk_sft;
			    default: ca_in_af1_da <= 1'b0;
			endcase
		end
	end
	
	// ca_in_af1_bof	
    assign ca_in_af1_bof = ca_in_af0_bof;

	// ca_in_af1_eof	
    assign ca_in_af1_eof = ca_in_af0_eof;
	
	
	
	// **************************** guide fir cal ************************ //
	// ca_gigi_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_gigi_mul <= 'd0;
		end
		else begin
			ca_gigi_mul <= ca_in_gi_da_1d * ca_in_gi_da_1d;
		end
	end
	
	// ca_gigi_mul_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_gigi_mul_sft <= 'd0;
		end
		else begin
			ca_gigi_mul_sft <= ca_gigi_mul / ($signed(65536));
		end
	end
	
	// ca_gipi_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_gipi_mul <= 'd0;
		end
		else begin
			ca_gipi_mul <= ca_in_gi_da_1d * ca_in_pi_da_1d;
		end
	end

	// ca_gipi_mul_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_gipi_mul_sft <= 'd0;
		end
		else begin
			ca_gipi_mul_sft <= ca_gipi_mul / ($signed(65536));
		end
	end
	
	// ca_mgmg_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_mgmg_mul <= 'd0;
		end
		else begin
			ca_mgmg_mul <= ca_in_mg_da_1d * ca_in_mg_da_1d;
		end
	end
	
	// ca_mgmg_mul_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_mgmg_mul_sft <= 'd0;
		end
		else begin
			ca_mgmg_mul_sft <= ca_mgmg_mul / ($signed(65536));
		end
	end

	// ca_mgmp_mul
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_mgmp_mul <= 'd0;
		end
		else begin
			ca_mgmp_mul <= ca_in_mg_da_1d * ca_in_mp_da_1d;
		end
	end
	
	// ca_mgmp_mul_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_mgmp_mul_sft <= 'd0;
		end
		else begin
			ca_mgmp_mul_sft <= ca_mgmp_mul / ($signed(65536));
		end
	end
	
	// ca_guideCal_par
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_guideCal_addr <= 'd0;
		end
		else begin
			ca_guideCal_addr <= ca_in_vr_da[15 : 0] + GFIR_LAMTA;
		end
	end

	guideCal_par guideCal_par0 ( .clka(clk), .addra(ca_guideCal_addr), .douta(ca_guideCal_par));
	
	// ca_in_re_da delay
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_in_re_da_4d, ca_in_re_da_3d, ca_in_re_da_2d, ca_in_re_da_1d} <= 'd0;
		end
		else begin
			{ca_in_re_da_4d, ca_in_re_da_3d, ca_in_re_da_2d, ca_in_re_da_1d} <= 
			{ca_in_re_da_3d, ca_in_re_da_2d, ca_in_re_da_1d, ca_in_re_da   } ;
		end
	end

	// ca_multi_in1
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_multi_in1 <= 'd0;
		end
		else begin
			ca_multi_in1 <= ca_guideCal_par * ca_in_re_da_4d;
		end
	end
	
	// ca_ak
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_ak <= 'd0;
		end
		else begin
			ca_ak <= ca_multi_in1 / ($signed(16777216));
		end
	end
	
	// ca_ak_1d
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_ak_1d <= 'd0;
		end
		else begin
			ca_ak_1d <= (ca_ak > $signed(255) )? $signed(255)  : 
			            (ca_ak < $signed(-256))? $signed(-256) : ca_ak;
		end
	end	
	
	// ca_ak delay
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_ak_4d, ca_ak_3d, ca_ak_2d} <= 'd0;
		end
		else begin
			{ca_ak_4d, ca_ak_3d, ca_ak_2d} <= {ca_ak_3d, ca_ak_2d, ca_ak_1d};
		end
	end
	
	// ca_in_mp_bk1
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_mp_bk1 <= 'd0;
		end
		else begin
			ca_in_mp_bk1 <= ca_in_mp_da_2d * ($signed(256));
		end
	end
	
	// ca_in_mp_bk2
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_in_mp_bk2 <= 'd0;
		end
		else begin
			ca_in_mp_bk2 <= ca_in_mg_da_2d * ca_ak_1d;
		end
	end
	
	// ca_bk
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_bk <= 'd0;
		end
		else begin
			ca_bk <= ca_in_mp_bk1 - ca_in_mp_bk2;
		end
	end
	
	// ca_bk_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_bk_sft <= 'd0;
		end
		else begin
			ca_bk_sft <= ca_bk / ($signed(256));
		end
	end
	
	// ca_out_af0_vld delay
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_out_af0_vld_6d, ca_out_af0_vld_5d, ca_out_af0_vld_4d, ca_out_af0_vld_3d, ca_out_af0_vld_2d, ca_out_af0_vld_1d} <= 'd0;
		end
		else begin
			{ca_out_af0_vld_6d, ca_out_af0_vld_5d, ca_out_af0_vld_4d, ca_out_af0_vld_3d, ca_out_af0_vld_2d, ca_out_af0_vld_1d} <= 
			{ca_out_af0_vld_5d, ca_out_af0_vld_4d, ca_out_af0_vld_3d, ca_out_af0_vld_2d, ca_out_af0_vld_1d, ca_out_af0_vld   };
		end
	end
	
	// ca_out_af0_da delay
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_out_af0_da_5d, ca_out_af0_da_4d, ca_out_af0_da_3d, ca_out_af0_da_2d, ca_out_af0_da_1d} <= 'd0;
		end
		else begin
			{ca_out_af0_da_5d, ca_out_af0_da_4d, ca_out_af0_da_3d, ca_out_af0_da_2d, ca_out_af0_da_1d} <= 
			{ca_out_af0_da_4d, ca_out_af0_da_3d, ca_out_af0_da_2d, ca_out_af0_da_1d, ca_out_af0_da   };
		end
	end
	
	// ca_out_af1_da delay
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			{ca_out_af1_da_5d, ca_out_af1_da_4d, ca_out_af1_da_3d, ca_out_af1_da_2d, ca_out_af1_da_1d} <= 'd0;
		end
		else begin
			{ca_out_af1_da_5d, ca_out_af1_da_4d, ca_out_af1_da_3d, ca_out_af1_da_2d, ca_out_af1_da_1d} <= 
			{ca_out_af1_da_4d, ca_out_af1_da_3d, ca_out_af1_da_2d, ca_out_af1_da_1d, ca_out_af1_da   };
		end
	end
	
	// ca_vr_sub
	// according to matlab simulation results, we set var's limitation to 8192 so that avoiding to unpredictable case.
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_vr_sub <= 'd0;
		end
		else begin
			ca_vr_sub <= ((ca_out_af0_da_5d - ca_mgmg_mul_sft) < $signed(0)   )? $signed(0)    : 
			             ((ca_out_af0_da_5d - ca_mgmg_mul_sft) > $signed(8192))? $signed(8192) : (ca_out_af0_da_5d - ca_mgmg_mul_sft);
		end
	end
	
	// ca_rg_sub
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_rg_sub <= 'd0;
		end
		else begin
			ca_rg_sub <= ca_out_af1_da_5d - ca_mgmp_mul_sft;
		end
	end
	
	// ca_akgi_mul  
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_akgi_mul <= 'd0;
		end
		else begin
			ca_akgi_mul <= ca_in_gi_da_1d * ca_out_af0_da_3d;
		end
	end

	// ca_akgi_mul_sft
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_akgi_mul_sft <= 'd0;
		end
		else begin
			ca_akgi_mul_sft <= ca_akgi_mul / ($signed(256));
		end
	end

	// ca_akgi_add    
	always @ (posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			ca_akgi_add <= 'd0;
		end
		else begin
			ca_akgi_add <= ((ca_akgi_mul_sft + ca_out_af1_da_5d) < $signed(0))?     $signed(0) : 
			               ((ca_akgi_mul_sft + ca_out_af1_da_5d) > $signed(65535))? $signed(65535) : (ca_akgi_mul_sft + ca_out_af1_da_5d);
		end
	end
	
	
	
	// ***************************** signals out ************************* //	
	
	// ca_out_mm_da & ca_out_mm_vld
	assign ca_out_mm_da[2*AF_DATA_WIDTH-1 : AF_DATA_WIDTH] = ca_out_af0_da;
	assign ca_out_mm_da[AF_DATA_WIDTH-1   : 0            ] = ca_out_af1_da;	
	assign ca_out_mm_vld = ca_out_af0_vld & (st_lc_state_fsh == 3'b000);
	
	// ca_out_rg_da & ca_out_rg_vld
	assign ca_out_rg_da[2*AF_DATA_WIDTH-1 : AF_DATA_WIDTH] = ca_vr_sub;
	assign ca_out_rg_da[AF_DATA_WIDTH-1   : 0            ] = ca_rg_sub;	
	assign ca_out_rg_vld = ca_out_af0_vld_6d & (st_lc_state_fsh == 3'b100);
	
	// ca_out_tr_da & ca_out_tr_vld
	assign ca_out_tr_da[AF_DATA_WIDTH-1   : 0            ] = ca_akgi_add;	
	assign ca_out_tr_vld = ca_out_af0_vld_6d & (st_lc_state_fsh == 3'b110);
	
	
	
	//af_replace_shift af_replace_shift0 ( .D({ca_in_af0_da, ca_in_af0_vld, ca_in_af0_bof, ca_in_af0_eof}), .CLK(clk), .Q({ca_out_af0_da, ca_out_af0_vld, ca_out_af0_bof, ca_out_af0_eof}));
    //af_replace_shift af_replace_shift1 ( .D({ca_in_af1_da, ca_in_af1_vld, ca_in_af1_bof, ca_in_af1_eof}), .CLK(clk), .Q({ca_out_af1_da, ca_out_af1_vld, ca_out_af1_bof, ca_out_af1_eof}));

    
	
	dehaze_avefir                            #(
	.FIR_MAX_SIZE                             (31                          ), 
	.RATIO_SIZE                               (3                           ),
	.FIFO_WIDTH                               (18                          ), 
	.DATA_WIDTH                               (18                          ),
	.LINE_LENGTH                              (960                         ),
	.AF_IN_BOF_JUDGE                          (960*16+15                   ))
	my_dehaze_avefir0                         (                            
	// logic clock and active-low reset                                    
	.clk                                      (clk                         ),
	.rst_n                                    (rst_n                       ),
															               
	// signed data in                                                      
	.af_in_da                                 (ca_in_af0_da                ),
	.af_in_vld                                (ca_in_af0_vld               ),
	.af_in_bof                                (ca_in_af0_bof               ),
	.af_in_eof                                (ca_in_af0_eof               ),
															               
	.af_fir_size                              (ca_in_af0_size              ),
															               
	.af_out_da                                (ca_out_af0_da               ),
	.af_out_vld                               (ca_out_af0_vld              ),
	.af_out_bof                               (ca_out_af0_bof              ),
	.af_out_eof                               (ca_out_af0_eof              )
	                                                                       );

	dehaze_avefir                            #(
	.FIR_MAX_SIZE                             (31                          ), 
	.RATIO_SIZE                               (3                           ),
	.FIFO_WIDTH                               (18                          ), 
	.DATA_WIDTH                               (18                          ),
	.LINE_LENGTH                              (960                         ),
	.AF_IN_BOF_JUDGE                          (960*16+15                   ))
	my_dehaze_avefir1                         (                            
	// logic clock and active-low reset                                    
	.clk                                      (clk                         ),
	.rst_n                                    (rst_n                       ),
															               
	// signed data in                                                      
	.af_in_da                                 (ca_in_af1_da                ),
	.af_in_vld                                (ca_in_af1_vld               ),
	.af_in_bof                                (ca_in_af1_bof               ),
	.af_in_eof                                (ca_in_af1_eof               ),
															               
	.af_fir_size                              (ca_in_af1_size              ),
															               
	.af_out_da                                (ca_out_af1_da               ),
	.af_out_vld                               (ca_out_af1_vld              ),
	.af_out_bof                               (ca_out_af1_bof              ),
	.af_out_eof                               (ca_out_af1_eof              )
	                                                                       );
																		   
    
endmodule
