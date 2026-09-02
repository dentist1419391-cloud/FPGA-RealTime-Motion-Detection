`timescale 1ns / 1ps

module morphology
#(
    parameter CORE_DELAY=6,
    parameter IMAGE_WIDTH=1920,
    parameter IMAGE_HEIGHT=1080
 )
 (
 
    input s_axis_aclk,
    input s_axis_aresetn,
    input [23:0] s_axis_tdata,
    input s_axis_tuser,
    input s_axis_tlast,
    input s_axis_tvalid,
    output s_axis_tready,
    
    output  [23:0] m_axis_tdata,
    output m_axis_tuser,
    output m_axis_tlast,
    output m_axis_tvalid,
    input m_axis_tready
    
    );
    wire clk;
    wire reset_n;
    
    assign clk=s_axis_aclk;
    assign reset_n=s_axis_aresetn;
    
    reg [23:0] m_axis_tdata_reg;
    reg m_axis_tuser_reg;
    reg m_axis_tlast_reg;
    reg m_axis_tvalid_reg;
    
    
    assign out_ready=(!m_axis_tvalid_reg)||m_axis_tready;
    assign stream_en=out_ready;
    assign s_axis_tready=out_ready;
    assign pixel_fire=s_axis_tvalid&&s_axis_tready;
    assign pixel_in=(s_axis_tdata==24'hff0000)?1'b1:1'b0;
        
    wire E00,E01,E02,E10,E11,E12,E20,E21,E22;
    wire D00,D01,D02,D10,D11,D12,D20,D21,D22;
    wire window_valid_erosion;
    wire active_valid_erosion;
    
    window
    #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    )u_window_erosion
    (
        .clk(clk),
        .reset_n(reset_n),
        .stream_en(stream_en),
        .pixel_valid(pixel_fire),
        .pixel_in(pixel_in),
        .P00(E00),
        .P01(E01),
        .P02(E02),
        .P10(E10),
        .P11(E11),
        .P12(E12),
        .P20(E20),
        .P21(E21),
        .P22(E22),
        .window_valid(window_valid_erosion),
        .active_valid(active_valid_erosion)
    );
    wire erosion_data;
    wire erosion_valid;
    erosion u_erosion
    (
        .clk(clk),
        .reset_n(reset_n),
        .stream_en(stream_en),
        .E00(E00),
        .E01(E01),
        .E02(E02),
        .E10(E10),
        .E11(E11),
        .E12(E12),
        .E20(E20),
        .E21(E21),
        .E22(E22),
        .window_valid(window_valid_erosion),
        .active_valid(active_valid_erosion),
        .erosion_data(erosion_data),
        .erosion_valid(erosion_valid)
    );
    wire window_valid_dilation;
    wire active_valid_dilation;
    window
    #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    )u_window_dilation
    (
        .clk(clk),
        .reset_n(reset_n),
        .stream_en(stream_en),
        .pixel_valid(erosion_valid),
        .pixel_in(erosion_data),
        .P00(D00),
        .P01(D01),
        .P02(D02),
        .P10(D10),
        .P11(D11),
        .P12(D12),
        .P20(D20),
        .P21(D21),
        .P22(D22),
        .window_valid(window_valid_dilation),
        .active_valid(active_valid_dilation)
    );
    wire dilation_data;
    wire dilation_valid;
    dilation u_dilation
    (
        .clk(clk),
        .reset_n(reset_n),
        .stream_en(stream_en),
        .D00(D00),
        .D01(D01),
        .D02(D02),
        .D10(D10),
        .D11(D11),
        .D12(D12),
        .D20(D20),
        .D21(D21),
        .D22(D22),
        .window_valid(window_valid_dilation),
        .active_valid(active_valid_dilation),
        .dilation_data(dilation_data),
        .dilation_valid(dilation_valid)
    );
    wire [23:0] w_result;
    assign w_result=(dilation_data==1'b1)?24'hff0000:24'd0;
    reg [CORE_DELAY-1:0] r_core_tvalid_reg;
    reg [CORE_DELAY-1:0] r_core_tuser_reg;
    reg [CORE_DELAY-1:0] r_core_tlast_reg;
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            r_core_tvalid_reg<={CORE_DELAY{1'b0}};
            r_core_tuser_reg<={CORE_DELAY{1'b0}};
            r_core_tlast_reg<={CORE_DELAY{1'b0}};
            
        end
        else if(out_ready)begin            
            r_core_tvalid_reg<={r_core_tvalid_reg[CORE_DELAY-2:0],s_axis_tvalid};
            r_core_tuser_reg<={r_core_tuser_reg[CORE_DELAY-2:0],s_axis_tuser};
            r_core_tlast_reg<={r_core_tlast_reg[CORE_DELAY-2:0],s_axis_tlast};           
       end
   end
   
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
            m_axis_tdata_reg<={24{1'b0}};
            m_axis_tuser_reg<=1'b0;
            m_axis_tlast_reg<=1'b0;
            m_axis_tvalid_reg<=1'b0;
        end
        else if(out_ready)begin
            m_axis_tdata_reg<=w_result;     
            m_axis_tuser_reg<=r_core_tuser_reg[CORE_DELAY-1];     
            m_axis_tlast_reg<=r_core_tlast_reg[CORE_DELAY-1];     
            m_axis_tvalid_reg<=r_core_tvalid_reg[CORE_DELAY-1];     
       end
   end
   assign m_axis_tdata=m_axis_tdata_reg;
   assign m_axis_tuser=m_axis_tuser_reg;
   assign m_axis_tlast=m_axis_tlast_reg;
   assign m_axis_tvalid=m_axis_tvalid_reg;

endmodule
           
    
    
        
