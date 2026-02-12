module vga(
    // incoming clock signal - 25 MHz
    input vgaclk,
    // incoming reset signal - driven by shift register in top level
    input rst,

    // 8-bit color allocates 3 bits for red, 3 for green, 2 for blue
    input [2:0] input_red,
    input [2:0] input_green,
    input [1:0] input_blue,

    // output horizontal and vertical counters for communication with graphics module
    output logic [9:0] hc_out,
    output logic [9:0] vc_out,

    // VGA outputs
    output logic hsync,
    output logic vsync,
    // expects 12 bits for color
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue
  );

  // 1): VGA protocol constants
  
  localparam HPIXELS  = 640;    // number of visible pixels per horizontal line
  localparam HFP      = 16;    // length (in pixels) of horizontal front porch
  localparam HSPULSE  = 96;    // length (in pixels) of hsync pulse
  localparam HBP      = 48;    // length (in pixels) of horizontal back porch

  localparam VPIXELS  = 480;    // number of visible horizontal lines per frame
  localparam VFP      = 10;    // length (in pixels) of vertical front porch
  localparam VSPULSE  = 2;    // length (in pixels) of vsync pulse
  localparam VBP      = 33;    // length (in pixels) of vertical back porch

 initial
  begin
    if (HPIXELS + HFP + HSPULSE + HBP != 800 ||
        VPIXELS + VFP + VSPULSE + VBP != 525)
    begin
      $error("Expected horizontal pixels to add up to 800 ",
             "and vertical pixels to add up to 525");
    end
  end

  // these registers are for storing the horizontal & vertical counters
  logic [9:0] hc;
  logic [9:0] vc;

  assign hc_out = hc;
  assign vc_out = vc;

  // in the sequential block, we update hc and vc based on their current values
  always_ff @(posedge vgaclk)
  begin
    if (rst) begin 
        hc <= 0;
        vc <= 0;
    end else begin
        if (hc == 799) begin 
            hc <= 0;
            if (vc == 524) begin 
                vc <= 0;
            end else begin
                vc <= vc + 1;
            end
        end else begin
            hc <= hc + 1;
        end
    end
  end

    // 3) hsync and vsync go low when we're within the pulse ranges
    assign hsync = (hc < HPIXELS+HFP) || (hc >= HPIXELS+HFP+HSPULSE);
    assign vsync = (vc < VPIXELS+VFP) || (vc >= VPIXELS+VFP+VSPULSE);

    // In the combinational block, we set red, green, blue outputs
    logic activeVideo;
    assign activeVideo = (hc < HPIXELS) && (vc < VPIXELS);

    always_comb
    begin
    /*  4): check if we're within the active video range;
            if we are, drive the RGB outputs with the input color values
            if not, we're in the blanking interval, so set them all to 0
        NOTE: our inputs are fewer bits than the outputs,so left-shift accordingly!
    */
    // Goes from 3-3-2 to 4-4-4 by shifting left
    if (activeVideo) begin 
        red = input_red << 1;
        green = input_green << 1;
        blue = input_blue << 2;
    end else begin
        red = 4'd0;
        green = 4'd0;
        blue = 4'd0;
    end
  end
endmodule
