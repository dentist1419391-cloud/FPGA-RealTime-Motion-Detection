`timescale 1ns / 1ps

module erosion(
    input clk,
    input reset_n,
    input stream_en,
    input E00,E01,E02,
    input E10,E11,E12,
    input E20,E21,E22,
    
    input window_valid,
    input active_valid,
    
    output reg erosion_data,
    output reg erosion_valid

    );
    
    wire w_erosion_data;
    assign w_erosion_data=(active_valid)?(E00&&E01&&E02&&E10&&E11&&E12&&E20&&E21&&E22):1'b0;
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            erosion_data<=1'b0;
            erosion_valid<=1'b0;
        end
        else if(stream_en)begin
            if(window_valid)begin
                erosion_data<=w_erosion_data;
                erosion_valid<=window_valid;
            end
            else begin
                erosion_valid<=1'b0;
            end
        end
    end
    
        
    
endmodule
