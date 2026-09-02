`timescale 1ns / 1ps

module dilation(
    input clk,
    input reset_n,
    input stream_en,
    input D00,D01,D02,
    input D10,D11,D12,
    input D20,D21,D22,
    
    input window_valid,
    input active_valid,
    
    output reg dilation_data,
    output reg dilation_valid

    );
    
    wire w_dilation_data;
    assign w_dilation_data=(active_valid)?(D00||D01||D02||D10||D11||D12||D20||D21||D22):1'b0;
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            dilation_data<=1'b0;
            dilation_valid<=1'b0;
        end
        else if(stream_en)begin
            if(window_valid)begin
                dilation_data<=w_dilation_data;
                dilation_valid<=window_valid;
            end
            else begin
                dilation_valid<=1'b0;
            end
        end
    end
    
        
    
endmodule
