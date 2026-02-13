module pingPong #(
  parameter int DEPTH = 768,
  parameter int ADDR_W = 10
)(
  input logic vgaclk,
  input logic rst,

  input logic frameStart,  // 1 when hc==0 && vc==0, signal sent by vga module

  // VGA read
  input logic [ADDR_W-1:0] rdAddr,
  output logic [7:0] rdData,

  // Writer (your animation logic)
  input logic we,
  input logic [ADDR_W-1:0] wrAddr,
  input logic [7:0] wrData
);
  logic bufSel; // 0: front=buf0  1: front=buf1

  logic [7:0] buf0 [0:DEPTH-1];
  logic [7:0] buf1 [0:DEPTH-1];

  // swap at start of frame
  always_ff @(posedge vgaclk or posedge rst) begin
    if (rst) bufSel <= 1'b0;
    else if (frameStart) bufSel <= ~bufSel;
  end

  // combinational read from FRONT buffer
  always_comb begin
    rdData = (bufSel == 1'b0) ? buf0[rdAddr] : buf1[rdAddr];
  end

  // synchronous write into BACK buffer
  always_ff @(posedge vgaclk) begin
    if (we) begin
      if (bufSel == 1'b0) buf1[wrAddr] <= wrData; // write back
      else buf0[wrAddr] <= wrData;
    end
  end

endmodule
