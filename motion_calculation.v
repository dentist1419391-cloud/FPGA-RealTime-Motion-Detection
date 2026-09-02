`timescale 1ns / 1ps
module motion_calculation(
    input s_axis_aclk,
    input s_axis_aresetn,
    
    input [7:0] s_axis_tdata,
    input s_axis_tlast,
    input s_axis_tuser,
    input s_axis_tvalid,
    output s_axis_tready,
    
    output [23:0] m_axis_tdata,
    output m_axis_tlast,
    output m_axis_tuser,
    output m_axis_tvalid,
    input m_axis_tready
    );
    wire clk;
    wire reset_n;
    assign clk=s_axis_aclk;
    assign reset_n=s_axis_aresetn;
    
    wire [23:0] motion_data;
    assign motion_data=(s_axis_tdata>8'd50)?24'hff0000:24'h000000;
    
    reg [23:0] m_axis_tdata_reg;
    reg m_axis_tlast_reg;
    reg m_axis_tuser_reg;
    reg m_axis_tvalid_reg;
    assign s_axis_tready=(!m_axis_tvalid_reg)||m_axis_tready;
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            m_axis_tdata_reg<={24{1'b0}};
            m_axis_tlast_reg<=1'b0;
            m_axis_tuser_reg<=1'b0;
            m_axis_tvalid_reg<=1'b0;
        end
        else if(s_axis_tready)begin
            if(s_axis_tvalid)begin
                m_axis_tdata_reg<=motion_data;
                m_axis_tuser_reg<=s_axis_tuser;
                m_axis_tlast_reg<=s_axis_tlast;
                m_axis_tvalid_reg<=1'b1;
            end
            else begin
                m_axis_tdata_reg<={24{1'b0}};
                m_axis_tuser_reg<=1'b0;
                m_axis_tlast_reg<=1'b0;
                m_axis_tvalid_reg<=1'b0;
            end
        end
    end
    
    assign m_axis_tdata=m_axis_tdata_reg;
    assign m_axis_tuser=m_axis_tuser_reg;
    assign m_axis_tlast=m_axis_tlast_reg;
    assign m_axis_tvalid=m_axis_tvalid_reg;
    
    
endmodule
