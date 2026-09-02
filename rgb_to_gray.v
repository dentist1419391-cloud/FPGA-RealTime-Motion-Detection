`timescale 1ns / 1ps

module rgb_gray
#(
    parameter DWIDTH=24
)
(

    input s_axis_aclk,
    input s_axis_aresetn,
    input  [DWIDTH-1:0] s_axis_tdata,
    input [2:0] s_axis_tkeep,
    input s_axis_tuser,
    input s_axis_tlast,
    input s_axis_tvalid,
    output s_axis_tready,
    
    output  [7:0] m_axis_tdata,
    output m_axis_tkeep,
    output m_axis_tuser,
    output m_axis_tlast,
    output m_axis_tvalid,
    input m_axis_tready
    
    );
    wire clk;
    wire reset_n;
    
    assign clk=s_axis_aclk;
    assign reset_n=s_axis_aresetn;
    
    wire [7:0] rgb_r=s_axis_tdata[23:16];
    wire [7:0] rgb_g=s_axis_tdata[15:8];
    wire [7:0] rgb_b=s_axis_tdata[7:0];
    
    wire [7:0] gray_result;
    assign gray_result=(rgb_r>>2)+(rgb_g>>1)+(rgb_b>>2);
    
    
    reg [7:0] m_axis_tdata_reg;
    reg m_axis_tkeep_reg;
    reg m_axis_tuser_reg;
    reg m_axis_tlast_reg;
    reg m_axis_tvalid_reg;
    
    assign m_axis_tdata=m_axis_tdata_reg;
    assign m_axis_tkeep=m_axis_tkeep_reg;
    assign m_axis_tuser=m_axis_tuser_reg;
    assign m_axis_tlast=m_axis_tlast_reg;
    assign m_axis_tvalid=m_axis_tvalid_reg;
    
    assign s_axis_tready=(!m_axis_tvalid_reg)||(m_axis_tready);
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            m_axis_tdata_reg<={8{1'b0}};
            m_axis_tkeep_reg<=1'b0;
            m_axis_tuser_reg<=1'b0;
            m_axis_tlast_reg<=1'b0;
            m_axis_tvalid_reg<=1'b0;
        end
        else if(s_axis_tready)begin
            if(s_axis_tvalid)begin
                m_axis_tdata_reg<=gray_result;
                m_axis_tkeep_reg<=1'b1;
                m_axis_tuser_reg<=s_axis_tuser;
                m_axis_tlast_reg<=s_axis_tlast;
                m_axis_tvalid_reg<=s_axis_tvalid;
            end
            else begin
                m_axis_tdata_reg<={8{1'b0}};
                m_axis_tkeep_reg<=1'b0;
                m_axis_tuser_reg<=1'b0;
                m_axis_tlast_reg<=1'b0;;
                m_axis_tvalid_reg<=1'b0;;
            end
        end
    end
    
                       
    
    
endmodule
