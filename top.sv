module top (
    input logic clk,
    input logic rst_btn,
    output logic hsync,
    output logic vsync,
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b
);

// For clock divder we need 25Mhz, given 100Mhz divide by 4
// 60Hz * 800 * 525 = 25,200,000 Hz
// count to every other every posedge to divide by 4:
// 1 0 1 0 1 0 1 0 1 100Mhz
// 1   0   1   0   1 Posedge of 100Mhz or 50 Mhz
// 1       0       1 25Mhz
logic vgaclk;
logic counter; // 1 bit counter to count every other posedge of clk
always_ff @(posedge clk) begin
    if (rst_btn) begin
        counter <= 1'b0;
        vgaclk  <= 1'b0;
    end else begin
    counter <= counter + 1'b1;
    if (counter) begin
        vgaclk <= ~vgaclk;
    end
    end
end

// reset logic: we want to hold reset for a few cycles after the button is pressed,
// so we use a shift register to create a longer reset signal
logic [3:0] rstShift; // 3 is the highest bit, (oldest)
logic rst;
always_ff @(posedge vgaclk or posedge rst_btn) begin
  if (rst_btn)
    rstShift <= 4'b1111;
  else
    rstShift <= rstShift << 1;
end
assign rst = rstShift[3];


// VGA counters for graphics
logic [9:0] hc, vc;

// Graphics color (3:3:2)
logic [2:0] input_red;
logic [2:0] input_green;
logic [1:0] input_blue;

// Graphics module (blocking + address)
logic [7:0] color8; // 8-bit packed color from graphics module
logic [15:0] pixAddr; // pixel address from graphics module

// Frame start pulse for buffer swap
logic frameStart;
assign frameStart = (hc == 10'd0) && (vc == 10'd0);
// Frame counter (increments once per frame) MAKING A MOVING BAR
logic [23:0] frameCount;
always_ff @(posedge vgaclk or posedge rst) begin
  if (rst) frameCount <= '0;
  else if (frameStart) frameCount <= frameCount + 1;
end

graphics gfx (
    .hc(hc),
    .vc(vc),
    .frame(frameCount),
    .addr(pixAddr),
    .color(color8)
);
// Active video gate (640x480)
localparam int HPIXELS = 640;
localparam int VPIXELS = 480;
logic activeVideo;
assign activeVideo = (hc < HPIXELS) && (vc < VPIXELS);

// Ping-pong expects 10-bit addresses for 0..767
logic [9:0] pixAddrPP;
assign pixAddrPP = pixAddr[9:0]; // just take the lower 10 bits, since we only have 768 pixels (0..767)

logic [7:0] color8PP; // data read from ping pong RAM

pingPong #(
    .DEPTH(768),
    .ADDR_W(10)
) DUT1 (
    .vgaclk(vgaclk),
    .rst(rst),
    .frameStart(frameStart),
    .rdAddr(pixAddrPP),
    .rdData(color8PP),
    .we(activeVideo), // only write when we're in active video, prevent tearing
    .wrAddr(pixAddrPP),
    .wrData(color8)
);
// Split 8-bit packed color into 3:3:2
assign input_red = color8PP[7:5];
assign input_green = color8PP[4:2];
assign input_blue = color8PP[1:0];

vga DUT2 (
    .vgaclk(vgaclk),
    .rst(rst),
    .input_red(input_red),
    .input_green(input_green),
    .input_blue(input_blue),
    .hc_out(hc),
    .vc_out(vc),
    .hsync(hsync),
    .vsync(vsync),
    .red(vga_r),
    .green(vga_g),
    .blue(vga_b)
);

endmodule