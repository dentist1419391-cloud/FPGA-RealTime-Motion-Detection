`timescale 1ns / 1ps
module overlay
#(
    parameter CORE_DELAY=12
)
(
    input s_axis_aclk,
    input s_axis_aresetn,
    
    //current_frame (vdma0)
    input [23:0] s_axis_tdata_rgb,
    input s_axis_tlast_rgb,
    output s_axis_tready_rgb,
    input s_axis_tuser_rgb,
    input s_axis_tvalid_rgb,
    
    //motion calculation
    input [23:0] s_axis_tdata_overlay,
    input s_axis_tlast_overlay,
    output s_axis_tready_overlay,
    input s_axis_tuser_overlay,
    input s_axis_tvalid_overlay,
    
    //motion caculation output
    output [23:0] m_axis_tdata,
    output m_axis_tlast,
    output m_axis_tuser,
    output m_axis_tvalid,
    input m_axis_tready

    );
    wire clk=s_axis_aclk;
    wire reset_n=s_axis_aresetn;
    
    reg [23:0] r_core_tdata_rgb[CORE_DELAY-1:0];
    reg [CORE_DELAY-1:0] r_core_tuser_rgb;
    reg [CORE_DELAY-1:0] r_core_tlast_rgb;
    reg [CORE_DELAY-1:0] r_core_tvalid_rgb;
    
    integer i;
    reg [23:0] m_axis_tdata_reg;
    reg m_axis_tlast_reg;
    reg m_axis_tuser_reg;
    reg m_axis_tvalid_reg;
    
    wire out_ready=!m_axis_tvalid_reg||m_axis_tready;
    assign s_axis_tready_rgb=out_ready;
    assign s_axis_tready_overlay=out_ready;
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            for(i=0;i<CORE_DELAY;i=i+1)begin
                r_core_tdata_rgb[i]<={24{1'b0}};
                r_core_tuser_rgb[i]<=1'b0;
                r_core_tlast_rgb[i]<=1'b0;
                r_core_tvalid_rgb[i]<=1'b0;
            end
        end
        else if(out_ready)begin
            r_core_tdata_rgb[0]<=s_axis_tdata_rgb;
            for(i=0;i<CORE_DELAY-1;i=i+1)begin
                r_core_tdata_rgb[i+1]<=r_core_tdata_rgb[i];
            end
            r_core_tuser_rgb<={r_core_tuser_rgb[CORE_DELAY-2:0],s_axis_tuser_rgb};
            r_core_tlast_rgb<={r_core_tlast_rgb[CORE_DELAY-2:0],s_axis_tlast_rgb};
            r_core_tvalid_rgb<={r_core_tvalid_rgb[CORE_DELAY-2:0],s_axis_tvalid_rgb};
        end
    end
    wire s_axis_tuser_rgb_d=r_core_tuser_rgb[CORE_DELAY-1];
    wire s_axis_tlast_rgb_d=r_core_tlast_rgb[CORE_DELAY-1];
    wire s_axis_tvalid_rgb_d=r_core_tvalid_rgb[CORE_DELAY-1];
    wire [23:0] s_axis_tdata_rgb_d=r_core_tdata_rgb[CORE_DELAY-1];
    wire pixel_fire=s_axis_tvalid_overlay&&s_axis_tready_overlay&&s_axis_tvalid_rgb_d&&s_axis_tready_rgb&&out_ready;
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            m_axis_tdata_reg<={24{1'b0}};
            m_axis_tuser_reg<=1'b0;
            m_axis_tlast_reg<=1'b0;
            m_axis_tvalid_reg<=1'b0;
        end
        else if(out_ready)begin
            if(pixel_fire)begin
                if(s_axis_tdata_overlay==24'hff0000)begin
                    m_axis_tdata_reg<=24'hff0000;
                    m_axis_tuser_reg<=s_axis_tuser_rgb_d;
                    m_axis_tlast_reg<=s_axis_tlast_rgb_d;
                    m_axis_tvalid_reg<=s_axis_tvalid_rgb_d;
                end
                else begin
                    m_axis_tdata_reg<=s_axis_tdata_rgb_d;
                    m_axis_tuser_reg<=s_axis_tuser_rgb_d;
                    m_axis_tlast_reg<=s_axis_tlast_rgb_d;
                    m_axis_tvalid_reg<=s_axis_tvalid_rgb_d;
                end
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
