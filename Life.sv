/*============================================================================
 *  Conway's Game Of Life
 *  Copyright (C) 2020 Hrvoje Cavrak
 *
 *  Please read LICENSE file.
 *============================================================================*/

module emu
(
   //Master input clock
   input         CLK_50M,
   input         RESET,
   inout  [45:0] HPS_BUS,
   output        CLK_VIDEO,
   output        CE_PIXEL,
   output  [7:0] VIDEO_ARX,
   output  [7:0] VIDEO_ARY,

   output  [7:0] VGA_R,
   output  [7:0] VGA_G,
   output  [7:0] VGA_B,
   output  reg   VGA_HS,
   output  reg   VGA_VS,
   output        VGA_DE,    // = ~(VBlank | HBlank)
   output        VGA_F1,
   output  [1:0] VGA_SL,

   output        LED_USER,  // 1 - ON, 0 - OFF.
   output  [1:0] LED_POWER,
   output  [1:0] LED_DISK,

   input         OSD_STATUS,
   input         HDMI_CLK

);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VGA_F1    = 0;

assign VIDEO_ARX = status[1] ? 8'd4 : 8'd16;
assign VIDEO_ARY = status[1] ? 8'd3 : 8'd9; 

`include "build_id.v" 
localparam CONF_STR = 
{
   "GameOfLife;;",
   "-;",
   "F1,MEM,Load board;",
   "-;",
   "O3,Running,Yes,No;",
   "O2,Seed,Off,On;",
   "O1,Aspect Ratio,16:9,4:3;",  
   "V,v0.1.",`BUILD_DATE
};


///////////////////////////////////////////////////
// HPS Connection
///////////////////////////////////////////////////

wire [31:0] status;

wire        ioctl_download;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [7:0]  ioctl_dout;


hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
   .clk_sys(CLK_50M),
   .HPS_BUS(HPS_BUS),
   .conf_str(CONF_STR),
   .status(status),

   .ioctl_download(ioctl_download),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_dout)
);


///////////////////////////////////////////////////
// Game of life / video
///////////////////////////////////////////////////

reg output_pixel, 
    r1p1, 
    r1p2, 
    r2p1, 
    r2p2, 
    r3p1, 
    r3p2, 
    sync_wait;

wire pixel_out_row1, 
     pixel_out_row2, 
     pixel_out_fifo;
        
   
always @(posedge CLK_50M) begin
   sync_wait <= ioctl_download | (sync_wait & |{hc, vc});
end

/* If uploading new seed state, switch the shift register to 50 MHz HPS clock instead of the video clock.
   Input feed is switched to data received. 
*/
fb fb_shift_reg (
        .clock(ioctl_download ? ioctl_wr : conway_clk),
        .shiftin(ioctl_download ? ioctl_dout[0] : output_pixel),
        .shiftout(pixel_out_fifo)
);

row row1 (
   .clock(ioctl_download ? CLK_50M : conway_clk),
   .shiftin(r2p1),
   .shiftout(pixel_out_row1)                                               
);

row row2 (
   .clock(ioctl_download ? CLK_50M : conway_clk),
   .shiftin(status[2] ? random_data[0] : r3p1),				// status[2] => if set it feeds random pixels to next generation
   .shiftout(pixel_out_row2)                                               
);


/* Stop pixel shifting if we are downloading the new initial state or waiting for new frame to start */
wire conway_clk = HDMI_CLK & (~ioctl_download) & (~sync_wait);

wire [3:0] neighbor_count = r1p1 + r1p2 + pixel_out_row1 + r2p1 + pixel_out_row2 + r3p1 + r3p2 + pixel_out_fifo;

/* One large shift register and two row-sized ones to enable counting all pixel's neighbors in one clock */
always @(posedge conway_clk) begin
            
   /* Row shift registers are a little shorter and padded with two registers each so individual pixels can be
      accessed and cell neighbor count determined. 
   */
   r1p1 <= r1p2; r1p2 <= pixel_out_row1;
   r2p1 <= r2p2; r2p2 <= pixel_out_row2;
   r3p1 <= r3p2; r3p2 <= pixel_out_fifo;
   
   /* status[3] = running flag. If false, the existing pixel is simply copied to the next generation. */
   output_pixel <= status[3] ? r2p2 : (neighbor_count | r2p2) == 4'd3;
   
   /* Monochrome output, if pixel is set we set the brightness to max, if not set it to min */
   fb_pixel <= {8{output_pixel}};
           
end


////////////////////////////////////////////////////////////////////
// Video                                                          //
////////////////////////////////////////////////////////////////////

assign CLK_VIDEO = HDMI_CLK;
assign CE_PIXEL  = 1'b1;

reg  [11:0] hc, vc;                                      // Horizontal and vertical counters

reg [7:0] fb_pixel;

assign VGA_G = fb_pixel;
assign VGA_R = fb_pixel;
assign VGA_B = fb_pixel;

assign VGA_DE = (hc < 12'd1920 && vc < 12'd1080);       

wire [30:0] random_data;


/* Enables pseudo-random seeding of initial state */

random lfsr(
   .clock(HDMI_CLK),
   .lfsr(random_data)
);


/* Video timings explained: https://timetoexplore.net/blog/video-timings-vga-720p-1080p */

always @(posedge HDMI_CLK) begin
   hc <= hc + 1'd1;
   
   if(hc == 12'd2199) begin                              // End of line reached
      hc <= 12'd0;
      vc <= (vc == 12'd1124) ? 12'b0 : vc + 1'd1;        // End of frame reached
   end

   if(hc == 12'd2007) VGA_HS <= 1'b1;                    // Horizontal sync pulse
   if(hc == 12'd2051) VGA_HS <= 1'b0;
   if(vc == 12'd1084) VGA_VS <= 1'b1;                    // Vertical sync pulse
   if(vc == 12'd1089) VGA_VS <= 1'b0;
   
end

endmodule

