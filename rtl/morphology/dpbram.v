`timescale 1ns / 1ps

module dpbram
#(
    parameter IMAGE_WIDTH=1920,
    parameter IMAGE_HEIGHT=1080
 )
 (
    input clk,
    
    input ce0,
    input we0,
    input [10:0] addr0,
    input d0,
    output reg q0,
    
    input ce1,
    input we1,
    input [10:0] addr1,
    input d1,
    output reg q1
);

(*ram_style="block"*) reg ram[0:IMAGE_WIDTH-1];

always@(posedge clk)begin
    if(ce0)begin
        if(we0)begin
            ram[addr0]<=d0;
        end
        else begin
            q0<=ram[addr0];
        end
    end
end

always@(posedge clk)begin
    if(ce1)begin
        if(we1)begin
            ram[addr1]<=d1;
        end
        else begin
            q1<=ram[addr1];
        end
    end
end

    
endmodule
