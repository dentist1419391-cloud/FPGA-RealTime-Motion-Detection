`timescale 1ns / 1ps

module substraction
#(
    parameter DWIDTH=24
 )
 (
    input s_axis_aclk,
    input s_axis_aresetn,
    
    //current_frame (vdma0)
    input [7:0] s_axis_tdata_vdma0,
    input s_axis_tlast_vdma0,
    input s_axis_tkeep_vdma0,
    output s_axis_tready_vdma0,
    input s_axis_tuser_vdma0,
    input s_axis_tvalid_vdma0,
    
    //previous frame(mm2s)
    input [7:0] s_axis_tdata_vdma1,
    input s_axis_tkeep_vdma1,
    input s_axis_tlast_vdma1,
    output s_axis_tready_vdma1,
    input s_axis_tuser_vdma1,
    input s_axis_tvalid_vdma1,
    
    //motion caculation output
    output [7:0] m_axis_tdata,
    output m_axis_tlast,
    output m_axis_tuser,
    output m_axis_tvalid,
    input m_axis_tready
);
    wire clk=s_axis_aclk;
    wire reset_n=s_axis_aresetn;
    
    reg [7:0] m_axis_tdata_reg;  //substraction output
    reg m_axis_tlast_reg;
    reg m_axis_tuser_reg;
    reg m_axis_tvalid_reg;
    
    assign m_axis_tdata=m_axis_tdata_reg;
    assign m_axis_tlast=m_axis_tlast_reg;
    assign m_axis_tuser=m_axis_tuser_reg;
    assign m_axis_tvalid=m_axis_tvalid_reg;
    
    
    assign s_axis_tready_vdma0=s_axis_tvalid_vdma1&(~m_axis_tvalid_reg||m_axis_tready);
    assign s_axis_tready_vdma1=s_axis_tvalid_vdma0&(~m_axis_tvalid_reg||m_axis_tready);
    
    
    wire [7:0] diff_result;
    
    wire [7:0] cur_gray=s_axis_tdata_vdma0;
    wire [7:0] prev_gray=s_axis_tdata_vdma1;
    
    assign diff_result=(cur_gray>prev_gray)?(cur_gray-prev_gray):(prev_gray-cur_gray);  

    
      
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
             m_axis_tlast_reg<=1'b0;
             m_axis_tuser_reg<=1'b0;
             m_axis_tdata_reg<={DWIDTH{1'b0}};
             m_axis_tvalid_reg<=1'b0;
        end
        else if(m_axis_tready||~m_axis_tvalid_reg)begin
            if(s_axis_tvalid_vdma0&s_axis_tvalid_vdma1&s_axis_tready_vdma0&s_axis_tready_vdma1)begin
                m_axis_tdata_reg<=diff_result;
                m_axis_tvalid_reg<=s_axis_tvalid_vdma0&&s_axis_tvalid_vdma1;
                m_axis_tlast_reg<=s_axis_tlast_vdma0&&s_axis_tlast_vdma1;
                m_axis_tuser_reg<=s_axis_tuser_vdma0&&s_axis_tuser_vdma1;
            end
            else begin
                m_axis_tdata_reg<={8{1'b0}};
                m_axis_tvalid_reg<=1'b0;
                m_axis_tlast_reg<=1'b0;
                m_axis_tuser_reg<=1'b0;
           end
           //data
       end
   end
        
    
    
    
endmodule
