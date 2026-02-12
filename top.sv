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
    counter <= counter + 1'b1;
    if (counter) begin
        vgaclk <= ~vgaclk;
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
graphics gfx (
    .hc(hc),
    .vc(vc),
    .addr(pixAddr),
    .color(color8)
);
// Split 8-bit packed color into 3:3:2
assign input_red = color8[7:5];
assign input_green = color8[4:2];
assign input_blue = color8[1:0];

vga DUT1 (
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