//============================================================================
//  Groovy_MiSTer by psakhis
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = scandoubler_fx;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = 0;
assign BUTTONS = 0;

wire [1:0] ar = status[2:1];
wire [1:0] scandoubler_fx = status[4:3];
wire [1:0] scale = status[6:5];

//
// CONF_STR for OSD and other settings
//

`include "build_id.v"
localparam CONF_STR = {
	"Groovy;;",
	"-;",	
   "P1,Video Settings;",
   "P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
   "P1O[4:3],Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
	"P1O[6:5],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",		
	"P1O[10],Orientation,Horz,Vert;",
	"P1-;",
	"d1P1O[11],240p Crop,Off,On;",
   "d2P1O[16:12],Crop Offset,0,1,2,3,4,5,6,7,8,-8,-7,-6,-5,-4,-3,-2,-1;",
   "P1-;",
   "P1O[20:17],Analog Video H-Pos,0,-1,-2,-3,-4,-5,-6,-7,8,7,6,5,4,3,2,1;",
   "P1O[24:21],Analog Video V-Pos,0,-1,-2,-3,-4,-5,-6,-7,8,7,6,5,4,3,2,1;",   
	"-;",
	"-;",
	"J1,Red;",
	"jn,A;",
	"V,v",`BUILD_DATE

};


//
// HPS is the module that communicates between the linux and fpga
//
wire  [1:0] buttons;
wire        forced_scandoubler;
wire [21:0] gamma_bus;
wire 			direct_video;
wire        video_rotated = 0;
wire        no_rotate = ~status[10];

wire        allow_crop_240p = ~forced_scandoubler && scale == 0;
wire        crop_240p = allow_crop_240p & status[11];
wire [4:0]  crop_offset = status[16:12] < 9 ? {status[16:12]} : ( status[16:12] + 5'd15 );

wire [31:0] status;
wire [31:0] joy;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(EXT_BUS),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),
	.video_rotated(video_rotated),
	
	.buttons(buttons),
	.status(status),
	.status_menumask({crop_240p, allow_crop_240p, direct_video}),
	
   .joystick_0(joy) // debug only purposes
	
);

////////////////////////////  HPS I/O  EXT ///////////////////////////////////

wire [35:0] EXT_BUS;
reg  cmd_init = 0, cmd_switchres = 0, cmd_blit = 0, cmd_get_vcount = 0;

hps_ext hps_ext
(
	.clk_sys(clk_sys),
	.EXT_BUS(EXT_BUS),
	.hps_rise(1'b1),	
	.vga_vcount(vga_vcount), 
	.cmd_init() // no use spi, better with ddr (we are not in main, can be interference with OSD)
);

/////////////////////////////////////////////////////////
//  PLL - clocks are the most important part of a system
/////////////////////////////////////////////////////////

wire clk_sys, pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),  
	.locked(pll_locked),
	.reconfig_to_pll(reconfig_to_pll),
   .reconfig_from_pll(reconfig_from_pll)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
    .mgmt_clk(CLK_50M),
    .mgmt_reset(0),
    .mgmt_waitrequest(cfg_waitrequest),
    .mgmt_read(0),
    .mgmt_readdata(),
    .mgmt_write(cfg_write),
    .mgmt_address(cfg_address),
    .mgmt_writedata(cfg_data),
    .reconfig_to_pll(reconfig_to_pll),
    .reconfig_from_pll(reconfig_from_pll)
);

localparam PLL_PARAM_COUNT = 6;

//SMS
/* 
wire [31:0] PLL_60HZ[PLL_PARAM_COUNT * 2] = '{
    'h0, 'h0, // set waitrequest mode
    'h4, 'h21b1a, // M COUNTER 2'b10 + 8bit (27 M High) + 8bit (26 M Low)
    'h3, 'h202, // N COUNTER 8bit (2 N High) 8bit (2 N Low)
    'h5, 'h404, // C0 COUNTER 8 bit (4 C High) 8bit (4 C Low)   
    'h8, 'h6, // BANDWIDTH SETTING (auto)
    'h2, 'h0 // start reconfigure
};
*/

wire [31:0] PLL_ARM[PLL_PARAM_COUNT * 2] = '{
    'h0, 'h0, // set waitrequest mode
    'h4, {16'b10, PoC_pll_M0, PoC_pll_M1}, // M COUNTER 2'b10 + 8bit (High) + 8bit (Low)
    'h3, {16'b00, PoC_pll_N0, PoC_pll_N1}, // N COUNTER 8bit (High) + 8bit (Low)
    'h5, {16'b00, PoC_pll_C0, PoC_pll_C1}, // C COUNTER 8bit (High) + 8bit (Low)   
    'h8, 'h6, // BANDWIDTH SETTING (auto)
    'h2, 'h0 // start reconfigure
};


//reg reconfig_pause = 0;
reg req_modeline = 0;
reg new_modeline = 0;
reg new_vmode = 0; // notify to OSD

always @(posedge CLK_50M) begin
    reg [3:0] param_idx = 0;
    reg [7:0] reconfig = 0;

    cfg_write <= 0;

    if (pll_locked & ~cfg_waitrequest) begin
        //pll_init_locked <= 1;
        if (&reconfig) begin // do reconfig		 
          cfg_address <= PLL_ARM[param_idx * 2 + 0][5:0];
          cfg_data    <= PLL_ARM[param_idx * 2 + 1];           		  		  
          cfg_write <= 1;
          param_idx <= param_idx + 4'd1;
          if (param_idx == PLL_PARAM_COUNT - 1) reconfig <= 8'd0;
        end else if (req_modeline != new_modeline) begin // new timing requested
            new_modeline <= req_modeline;
            reconfig <= 8'd1;
            //reconfig_pause <= 1;
            param_idx <= 0;
        end else if (|reconfig) begin // pausing before reconfigure
            reconfig <= reconfig + 8'd1;
        end// else begin
        //    reconfig_pause <= 0; // unpause once pll is locked again
       // end
    end
end

//reg pll_init_locked = 0;
//wire reset = RESET | buttons[1] | ~pll_init_locked;

/////////////////////// PIXEL CLOCK/////////////////////////////////////

wire ce_pix;

reg [7:0] ce_pix_arm;
assign ce_pix_arm = PoC_ce_pix - 1'd1;

reg [3:0] cencnt = 4'd0;

always @(posedge clk_sys) begin     
	 cencnt <= cencnt==ce_pix_arm ? 4'd0 : (cencnt+4'd1);	 
end

always @(posedge clk_sys) begin
    ce_pix <= cencnt == 4'd0;  
end



////////////////////////////  MEMORY  ///////////////////////////////////
//
//

////////////////////////////  DDRAM  ///////////////////////////////////
assign DDRAM_CLK = clk_sys;

wire [63:0]  ddr_data;
wire [959:0] ddr_data960; //40 pixels

reg          ddr_data_req=1'b0;
reg          ddr_req_ch=0;
reg          ddr_data_ch=0;
reg  [27:0]  ddr_addr_next;
reg  [27:0]  ddr_addr_subf;
reg  [27:0]  ddr_addr={18'b0,10'b0111111000}; //0x6000000 for read 0x30000000 (chunk 8 bytes, last 3 bits)	
wire         ddr_data_ready;
wire         ddr_busy;
reg          ddr_data_write=1'b0;
reg[7:0]     ddr_word24 = 8'd0;
reg[7:0]     ddr_word24_subf = 8'd0;
reg[7:0]     ddr_burst = 8'd1;

reg  [63:0]  ddr_data_to_write={8'h00,8'h00,8'h00,8'h00,8'h00,8'h73,8'h65,8'h72};

//wire [31:0] address = 32'h30000000;

ddram ddram
(
	.*,   
	.mem_addr(ddr_addr[27:1]),
	.mem_dout(ddr_data),	
	.mem_dout_ch(ddr_data_ch),	
	.mem_din(ddr_data_to_write), 			
	.mem_rd(ddr_data_req),
	.mem_rd_ch(ddr_req_ch),
	.mem_burst(ddr_burst),
	.mem_wr(ddr_data_write),	
	.mem960_dout(ddr_data960),	
	.mem_busy(ddr_busy),
	.mem_dready(ddr_data_ready)
);

///////////////////////////////////////////////////////////////////////////
//
//                        MAIN FLOW
//
///////////////////////////////////////////////////////////////////////////

reg [7:0] r_in = 8'h00, g_in = 8'h00, b_in = 8'h00; 
reg [7:0] r_vram_in = 8'h00, g_vram_in = 8'h00, b_vram_in = 8'h00; 
   
reg [7:0] state     = 8'd0;  
reg [7:0] state_4   = 8'd0;           // testing joy btn A   

// Header from arm
reg [7:0]  PoC_frame_ddr       = 8'd0;
reg [23:0] PoC_subframe_px_ddr = 24'd0;

// Modeline from arm (default 256x240 sms)
reg [63:0] PoC_header     = 64'd0;
reg [15:0] PoC_H          = 16'd256;
reg [7:0]  PoC_HFP        = 8'd10;
reg [7:0]  PoC_HS         = 8'd24;
reg [7:0]  PoC_HBP        = 8'd41;
reg [15:0] PoC_V          = 16'd240;
reg [7:0]  PoC_VFP        = 8'd2;
reg [7:0]  PoC_VS         = 8'd3;
reg [7:0]  PoC_VBP        = 8'd16;

// PLL (default 60hz for sms)
reg [7:0]  PoC_pll_M0     = 8'd31;
reg [7:0]  PoC_pll_M1     = 8'd30;
reg [7:0]  PoC_pll_N0     = 8'd2;
reg [7:0]  PoC_pll_N1     = 8'd2;
reg [7:0]  PoC_pll_C0     = 8'd5;
reg [7:0]  PoC_pll_C1     = 8'd4;
reg [7:0]  PoC_ce_pix     = 8'd16;

// Current frame on vram
reg [7:0]  PoC_frame_vram = 8'd0;

// Pixels writed on current frame for subframe updates 
reg [23:0] PoC_subframe_px_vram = 24'd0;

// Main flow
always @(posedge clk_sys) begin              	  		  		          	  		  		 		             	  		  		          	  		  		 		        		  	
		  
		  
        // Button A for testing 
        if (joy[4]) begin
		     state <= 8'd0;
		     case (state_4)  
		      8'd0:                             // debug code
			 	begin						  					  				 
				end				
	         default:
				begin
				  state_4               <= 8'd0;
				  state                 <= 8'd0;
				end				
		     endcase	
			  
		  // Normal proces
		  end else begin		     			   
            
	        //case -> only evaluates first match (break implicit), if not then default	  
			  case (state)
				8'd0: // start?				
				begin		
				  {r_in, g_in, b_in}   <= {8'hd1,8'h96,8'h28};		// dark yellow, not cmd_init
				  vram_reset           <= 1'b1;	
				  vram_active          <= 1'b0;			  							 
				  vram_sync_ddr        <= 1'b0;					 
				  ddr_to_vram          <= 1'b0;				
				  ddr_data_write       <= 1'b0;				  
				  ddr_data_req         <= ddr_busy ? 1'b0 : 1'b1;					
				  ddr_req_ch           <= 1'b0;					
				  ddr_data_ch          <= 1'b0;	
		        ddr_burst            <= 8'd1;		  
              ddr_addr             <= 28'd0;	
				  PoC_frame_ddr        <= 8'd0;                
				  PoC_subframe_px_ddr  <= 24'd0;		
				  PoC_subframe_px_vram <= 24'd0;	 					 
				  PoC_frame_vram       <= 8'd0;					 				    
				  state                <= 8'd20;		                				 
				end		  
				8'd1: // what to do? dispatcher
				begin		 
              {r_in, g_in, b_in}   <= {8'h00,8'h00,8'h00};		  				
				  vram_reset           <= 1'b0;
				  ddr_to_vram          <= 1'b0;				  
				  ddr_data_write       <= 1'b0;
				  ddr_data_req         <= 1'b0;	
				  ddr_req_ch           <= 1'b0;					
				  ddr_data_ch          <= 1'b0;	
				  ddr_addr             <= 28'd0;			
              if (!cmd_init) begin 		
                {r_in, g_in, b_in} <= {8'hd1,8'h96,8'h28};	   // dark yellow, not cmd_init			  
				    state 				  <= 8'd0;
              end else					
				  if (cmd_get_vcount) begin 							   //4x slower than spi
                cmd_get_vcount	  <= 1'b0;	
					 PoC_header[6 +:1]  <= 1'b0;					 
				    state 				  <= 8'd60;
              end else					
		        if (cmd_switchres & !ddr_busy) begin	// request modeline					  
					 cmd_switchres  	  <= 1'b0;			  
				    ddr_data_req       <= 1'b1;
					 ddr_addr           <= 28'd8; 
					 ddr_burst          <= 8'd3;
		          state 				  <= 8'd30;		  
				  end else	 
              if (cmd_blit & !ddr_busy) begin // request ch0 read framebuffer 					 
				    cmd_blit     	     <= 1'b0;		
			       ddr_addr           <= ddr_addr_next;				          		
					 ddr_burst          <= 8'd15;				 
	             ddr_data_req       <= 1'b1;	                    				 				    
		          state 				  <= 8'd40;					    
			     end else 
				  if (!ddr_busy & ce_pix) begin // pool header for new requests
				    ddr_data_req       <= 1'b1;
					 ddr_burst          <= 8'd1;
                state              <= 8'd20;				  
				  end
				end
				
				8'd20:  // header ready
				begin		               
              if (ddr_data_ready) begin				              	
				    vram_sync_ddr       <= (vram_active & !vram_synced) ? 1'b1 : 1'b0;				
					 PoC_header          <= ddr_data;
				    PoC_frame_ddr       <= ddr_data[15:8];
				    PoC_subframe_px_ddr <= ddr_data[39:16];	
				    ddr_data_req        <= 1'b0;	   			      					 					 
				    state               <= 8'd21; 	
				  end	 				
				end 	
				8'd21:  // actions on header
				begin		
              cmd_init <= PoC_header[0 +:1];								 
				  if (!PoC_header[1 +:1]) begin	
				    if (PoC_header[6 +:1]) cmd_get_vcount <= 1'b1;				  
				    else if (PoC_header[4 +:1] | PoC_header[5 +:1]) cmd_switchres <= 1'b1;				   	   	  // request change modeline/pll 
					 else if (PoC_frame_ddr != PoC_frame_vram && PoC_subframe_px_ddr > PoC_subframe_px_vram) begin // ddr updated frame/subframe
					 	     if (vram_sync_ddr && PoC_subframe_px_vram == 0) begin  // resync?
						       vram_reset  <= 1'b1;
							    vram_active <= 1'b0;
							  end 		
		                 ddr_addr_next     <= PoC_subframe_px_vram == 0 ? 28'hff : ddr_addr_subf;							 
							  cmd_blit          <= 1'b1;					  
						   end 								   
				  end 
          	  state <= 8'd1;			
				end 
				
				8'd30: // switchres requested and data ready
				begin						  
				  if (ddr_data_ready) begin				    
				    ddr_data_req       <= 1'b0;
					 state              <= 8'd31;
				  end
				end
				8'd31: // apply switch on vblank
				begin		
				  if (!vram_active || (vram_active && vblank_core)) begin 				
					 // modeline  
					 if (PoC_header[4 +:1]) begin
					   PoC_H      <= ddr_data960[0  +:16];
					   PoC_HFP    <= ddr_data960[16 +:08];
					   PoC_HS     <= ddr_data960[24 +:08];
					   PoC_HBP    <= ddr_data960[32 +:08];
					   PoC_V      <= ddr_data960[40 +:16];
					   PoC_VFP    <= ddr_data960[56 +:08];
					   PoC_VS     <= ddr_data960[64 +:08];
					   PoC_VBP    <= ddr_data960[72 +:08];
						PoC_header[4 +:1] <= 1'b0;
					 end	
					 // pixel clock	
                if (PoC_header[5 +:1]) begin					 
					   PoC_pll_M0 <= ddr_data960[80  +:08];
					   PoC_pll_M1 <= ddr_data960[88  +:08];
					   PoC_pll_N0 <= ddr_data960[96  +:08];
					   PoC_pll_N1 <= ddr_data960[104 +:08];
					   PoC_pll_C0 <= ddr_data960[112 +:08];
					   PoC_pll_C1 <= ddr_data960[120 +:08];
					   PoC_ce_pix <= ddr_data960[128 +:08];
						PoC_header[5 +:1] <= 1'b0;
						req_modeline  <= ~new_modeline; // update pll
					 end						 
					 new_vmode       <= ~new_vmode; // notify to osd
					 vram_reset      <= 1'b1; 
					 vram_active     <= 1'b0;						 			
					 state           <= 8'd32;
				  end 			
				end								
 		      8'd32:  // update header modeline/change pll done
				begin		
				  ddr_data_req <= 1'b0;				  			 				         
				  if (!ddr_busy) begin 		
                ddr_addr                 <= 28'd0;  						            			
				    ddr_data_to_write        <= PoC_header;							 
                ddr_data_write           <= 1'b1;						 
				    state                    <= 8'd33;		     							  					
				  end	 
				end  		
				8'd33:  // write ok
				begin		
				  if (!ddr_busy) begin 		
                ddr_data_write           <= 1'b0;						 						     							  				
					 state                    <= 8'd1;			     							  					
				  end	 
				end  
				 		   	
            8'd40:  // first channel full, prepare next one
				begin		    
              if (ddr_data_ready) begin	                				   	
                ddr_data_req      <= 1'b0;	
				    ddr_addr_subf	    <= ddr_addr_next;					 					 
					 ddr_addr_next     <= ddr_addr_next + 8'd120; // next one				 				  
				    state             <= 8'd41;				  							  
				  end	 
				end	
            8'd41:  // request ch1 read framebuffer 
				begin		    
              if (!ddr_busy) begin 		
                ddr_addr        <= ddr_addr_next;				                  					
					 ddr_req_ch      <= 1;		
		          ddr_burst       <= 8'd15;			 
	             ddr_data_req    <= 1'b1;	                    				 
				    state           <= 8'd42;				     							  					
				  end	 
				end					
				8'd42:  // both channel requested, start from ch0
				begin		                 
				  if (ddr_busy) begin	// isn't necessary wait ch1 full readed for start
                ddr_data_ch     <= 0;			             
				    ddr_word24      <= PoC_subframe_px_vram == 0 ? 8'd0 : ddr_word24_subf;		
                ddr_data_req    <= 1'b0;          				 
				    state           <= 8'd43; // all prepared to put pixels on vram											       			 
				  end	 
				end	
				8'd43:  // save pixel on vram                
				begin		 
              ddr_to_vram     <= 1'b0;	
				  ddr_word24_subf <= ddr_word24;	 	
			     if (vram_end_frame && PoC_subframe_px_vram > 0)       state <= 8'd50; // end of frame    -> update					    				   					
              else if (PoC_subframe_px_ddr <= PoC_subframe_px_vram) state <= 8'd1;  // end of subframe -> wait new pixels				         										         		
				  else if (vram_req_ready) begin	
							if (!vram_active) new_vmode       <= !new_vmode;				  
							vram_active                       <= 1'b1;			
							{r_vram_in, g_vram_in, b_vram_in} <= ddr_data960[24*(ddr_word24) +:24];                
							ddr_to_vram                       <= 1'b1;	
	                  PoC_subframe_px_vram              <= PoC_subframe_px_vram + 1'd1;						
							state                             <= 8'd44;																		  				 
				       end 
				end  				
				8'd44:  // probably can be more optimal writing vram on same cycle but for now it's inestable         
				begin					 
				  ddr_to_vram <= 1'b0;					  						  
				  if (ddr_word24 < 8'd39) begin 		
                ddr_word24         <= ddr_word24 + 1'd1;
				  	 state              <= 8'd43;				    					      
				  end else begin		
                ddr_addr_subf		  <= ddr_addr_next;	  
				    ddr_addr_next      <= ddr_addr_next + 8'd120;
				 	 state              <= 8'd45;
				  end
				end		  			
            8'd45:  // reuse channel
				begin						
				  if (!ddr_busy) begin 		
                ddr_addr     <= ddr_addr_next;
  					 ddr_req_ch   <= ddr_data_ch;
	             ddr_data_req <= 1'b1;	
                ddr_burst    <= 8'd15;						 
				    state        <= 8'd46;			     							  					
				  end	 
				end  
            8'd46:  // change channel 
				begin		                       
              if (ddr_busy) begin				             
				    ddr_data_ch  <= ~ddr_data_ch;
                ddr_word24   <= 8'd0;					  
                ddr_data_req <= 1'b0;	
				    state        <= 8'd43;               				    				
				  end	
				end		 
				
		      8'd50:                        // save vram end frame, it's safe for arm rewrite ddr
				begin		
				  ddr_data_req               <= 1'b0;				  
				  if (!ddr_busy) begin 		
                ddr_addr                 <= 28'hC0;  						            
				    ddr_data_to_write        <= {48'd0,7'd0,vram_sync_ddr,PoC_frame_ddr[7:0]};		//update frame and synced on vram 				
					 PoC_frame_vram           <= PoC_frame_ddr;
					 PoC_subframe_px_vram     <= 24'd0;
                ddr_data_write           <= 1'b1;						 
				    state                    <= 8'd51;		     							  					
				  end	 
				end  
				8'd51:  // write ok
				begin		
				  if (!ddr_busy) begin 		
                ddr_data_write           <= 1'b0;						 						     							  				
					 state                    <= 8'd1;			     							  					
				  end	 
				end  	
			   
				8'd60:                        // save vcount
				begin		
				  ddr_data_req               <= 1'b0;				  
				  if (!ddr_busy) begin 		
                ddr_addr                 <= 28'h00;  						            
				    ddr_data_to_write        <= {vga_vcount,8'd0,PoC_header[39:0]};									 																		 				
                ddr_data_write           <= 1'b1;						 
				    state                    <= 8'd61;		     							  					
				  end	 
				end  				
				8'd61:  // write ok
				begin		
				  if (!ddr_busy) begin 		
                ddr_data_write           <= 1'b0;						 						     							  				
					 state                    <= 8'd1;			     							  					
				  end	 
				end  					
				
				default:
				begin
				  state <= 8'd0;
				  state_4 <= 8'd0;
				end
			  endcase	  		  
		  
		  end		 
		  	      	
	
end
			  

////////////////////////////////////////////////////////////////////////////////
//
//                               VIDEO MODULES
//
////////////////////////////////////////////////////////////////////////////////

assign CLK_VIDEO = clk_sys;
wire vram_req_ready;
wire vram_end_frame;
wire vram_synced;
wire[23:0] vram_pixels;

reg ddr_to_vram = 1'b0;
reg vram_active = 1'b0;
reg vram_reset = 1'b0;
reg vram_sync_ddr = 1'b0;

wire[7:0] r_core, g_core, b_core;
wire hsync_core, vsync_core,  vblank_core, hblank_core, vga_de_core;
wire[15:0] vga_vcount;


vga vga 
(           
    .clk_sys        (clk_sys),     
	 .ce_pix         (ce_pix),
	  //modeline
	 .H(PoC_H),
	 .HFP(PoC_HFP),
	 .HS(PoC_HS),
	 .HBP(PoC_HBP),
	 .V(PoC_V),
	 .VFP(PoC_VFP),
	 .VS(PoC_VS),
	 .VBP(PoC_VBP),
	  //vram 
	 .vram_req       (ddr_to_vram),	     // write pixel {r_in, g_in, b_in} to vram
	 .vram_active    (vram_active),       // read pixels from vram, if 0 no vram consumed but vram_req is atended
	 .vram_reset     (vram_reset),	     // clean vram 	 		 		 		
	 .r_vram_in      (r_vram_in),         // active vram r in
	 .g_vram_in      (g_vram_in),         // active vram g in 
	 .b_vram_in      (b_vram_in),         // active vram b in
	 .r_in           (r_in),              // non active vram r in (used for testing)
	 .g_in           (g_in),              // non active vram g in (used for testing)
	 .b_in           (b_in),              // non active vram b in (used for testing)  
	 .vram_ready     (vram_req_ready),    // vram it's ready to write a new pixel	 
	 .vram_end_frame (vram_end_frame),    // in vram there ara all pixels of current frame	    
	 .vram_synced    (vram_synced),       // vram it's synced on frame
	 .vram_pixels    (vram_pixels),		  // pixels on vram	 
	 .vcount         (vga_vcount),	     // vertical count raster position
	  //out signals
	 .hsync          (hsync_core),
	 .vsync          (vsync_core),
	 .r              (r_core),
	 .g              (g_core),
	 .b              (b_core),
	 .vga_de         (vga_de_core),	 
	 .hblank         (hblank_core),
	 .vblank         (vblank_core)
	 
);


wire hs_jt, vs_jt;

// H/V offset

wire [3:0]	hoffset = status[20:17];
wire [3:0]	voffset = status[24:21];
jtframe_resync jtframe_resync
(
    .clk(clk_sys),
    .pxl_cen(ce_pix),
    .hs_in(hsync_core),
    .vs_in(vsync_core),
    .LVBL(~vblank_core),
    .LHBL(~hblank_core),
    .hoffset(hoffset),
    .voffset(voffset),
    .hs_out(hs_jt),
    .vs_out(vs_jt)
);


video_mixer #(512, 0, 1) video_mixer(
    .CLK_VIDEO(CLK_VIDEO),
    .CE_PIXEL(CE_PIXEL),
    .ce_pix(ce_pix),

    .scandoubler(forced_scandoubler || scandoubler_fx != 2'b00),
    .hq2x(0),

    .gamma_bus(gamma_bus),

    .R(r_core),
    .G(g_core),
    .B(b_core),

    .HBlank(hblank_core),
    .VBlank(vblank_core),
    .HSync(hs_jt),
    .VSync(vs_jt),

    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .VGA_DE(VGA_DE_MIXER),

    .HDMI_FREEZE(HDMI_FREEZE)
);


wire VGA_DE_MIXER;
	
video_freak video_freak(
    .CLK_VIDEO(CLK_VIDEO),
    .CE_PIXEL(CE_PIXEL),
    .VGA_VS(VGA_VS),
    .HDMI_WIDTH(HDMI_WIDTH),
    .HDMI_HEIGHT(HDMI_HEIGHT),
    .VGA_DE(VGA_DE),
    .VIDEO_ARX(VIDEO_ARX),
    .VIDEO_ARY(VIDEO_ARY),

    .VGA_DE_IN(VGA_DE_MIXER),
    .ARX((!ar) ? ( no_rotate ? 12'd4 : 12'd3 ) : (ar - 1'd1)),
    .ARY((!ar) ? ( no_rotate ? 12'd3 : 12'd4 ) : 12'd0),
    .CROP_SIZE(crop_240p ? 240 : 0),
    .CROP_OFF(crop_offset),
    .SCALE(scale)
);
	
	
endmodule
