`timescale 1ns / 1ps

module motion_or
#(
    parameter DWIDTH=24
 )
 (
    input s_axis_aclk,
    input s_axis_aresetn,
    
    //current_frame (vdma0)
    input [23:0] s_axis_tdata_diff1,
    input s_axis_tlast_diff1,
    output s_axis_tready_diff1,
    input s_axis_tuser_diff1,
    input s_axis_tvalid_diff1,
    
    //previous frame(mm2s)
    input [23:0] s_axis_tdata_diff2,
    input s_axis_tlast_diff2,
    output s_axis_tready_diff2,
    input s_axis_tuser_diff2,
    input s_axis_tvalid_diff2,
    
    //motion caculation output
    output [23:0] m_axis_tdata,
    output m_axis_tlast,
    output m_axis_tuser,
    output m_axis_tvalid,
    input m_axis_tready
);
    wire clk=s_axis_aclk;
    wire reset_n=s_axis_aresetn;
    
    reg [23:0] m_axis_tdata_reg;  //substraction output
    reg m_axis_tlast_reg;
    reg m_axis_tuser_reg;
    reg m_axis_tvalid_reg;
    
    assign m_axis_tdata=m_axis_tdata_reg;
    assign m_axis_tlast=m_axis_tlast_reg;
    assign m_axis_tuser=m_axis_tuser_reg;
    assign m_axis_tvalid=m_axis_tvalid_reg;
    wire out_ready=~m_axis_tvalid_reg||m_axis_tready;
    wire pixel_fire=s_axis_tvalid_diff1&s_axis_tvalid_diff2&s_axis_tready_diff1&s_axis_tready_diff2;
    
    
    assign s_axis_tready_diff1=s_axis_tvalid_diff2&out_ready;
    assign s_axis_tready_diff2=s_axis_tvalid_diff1&out_ready;
    
    wire motion_diff1;
    wire motion_diff2;
    assign motion_diff1=(s_axis_tdata_diff1==24'hff0000)?1'b1:1'b0;
    assign motion_diff2=(s_axis_tdata_diff2==24'hff0000)?1'b1:1'b0;
    
    wire [23:0] or_result;
    assign or_result=(motion_diff1||motion_diff2)?24'hff0000:24'h000000;    
      
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
             m_axis_tlast_reg<=1'b0;
             m_axis_tuser_reg<=1'b0;
             m_axis_tdata_reg<={DWIDTH{1'b0}};
             m_axis_tvalid_reg<=1'b0;
        end
        else if(out_ready)begin
            if(pixel_fire)begin
                m_axis_tdata_reg<=or_result;
                m_axis_tvalid_reg<=1'b1;
                m_axis_tlast_reg<=s_axis_tlast_diff1;
                m_axis_tuser_reg<=s_axis_tuser_diff1;
            end
            else begin
                m_axis_tdata_reg<={DWIDTH{1'b0}};
                m_axis_tvalid_reg<=1'b0;
                m_axis_tlast_reg<=1'b0;
                m_axis_tuser_reg<=1'b0;
            end
       //data
   end
   end
   
        
    
    
    
endmodule
