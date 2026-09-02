`timescale 1ns / 1ps
module box_cal(
    input s_axis_aclk,
    input s_axis_aresetn,
    
    input wire [10:0] roi_x_min,
    input wire [10:0] roi_x_max,
    input wire [10:0] roi_y_min,
    input wire [10:0] roi_y_max,
    
    input [23:0] s_axis_tdata,
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


    reg [10:0] update_roi_x_min;
    reg [10:0] update_roi_x_max;
    reg [10:0] update_roi_y_min;
    reg [10:0] update_roi_y_max;
    
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            update_roi_x_min<={11{1'b0}};
            update_roi_x_max<={11{1'b0}};
            update_roi_y_min<={11{1'b0}};
            update_roi_y_max<={11{1'b0}};
        end
        else if(out_ready)begin
            if(pixel_fire)begin
                if(x_cnt==1919&&y_cnt==1079)begin
                    update_roi_x_min<=roi_x_min;
                    update_roi_x_max<=roi_x_max;
                    update_roi_y_min<=roi_y_min;
                    update_roi_y_max<=roi_y_max;
                end
            end
        end
    end
                
            
    
    wire clk;
    wire reset_n;
    assign clk=s_axis_aclk;
    assign reset_n=s_axis_aresetn;
    assign s_axis_tready=m_axis_tready||(!m_axis_tvalid_reg);
    reg m_axis_tvalid_reg;
    reg m_axis_tuser_reg;
    reg m_axis_tlast_reg;
    reg [23:0] m_axis_tdata_reg;
    wire out_ready=m_axis_tready||(!m_axis_tvalid_reg);
    
    reg [10:0] x_min, x_max, y_min, y_max;
    wire motion=(s_axis_tdata==24'hff0000)?1'b1:1'b0;
    wire pixel_fire=s_axis_tvalid&&s_axis_tready&&out_ready;
    
    reg [10:0] x_cnt;
    reg [10:0] y_cnt;
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            x_cnt<={11{1'b0}};
            y_cnt<={11{1'b0}};
        end
        else if(out_ready) begin
            if(pixel_fire)begin
                if(s_axis_tuser)begin
                    x_cnt<=11'd1;
                    y_cnt<=11'd0;
                end
                else begin
                    if(s_axis_tlast)begin
                        if(y_cnt==11'd1079)begin
                            x_cnt<=11'd0;
                            y_cnt<=11'd0;
                        end
                        else begin
                            x_cnt<=11'd0;
                            y_cnt<=y_cnt+1'b1;
                        end
                    end
                    else begin
                        x_cnt<=x_cnt+1'b1;
                    end
                end
            end
        end
    end
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin
            x_min<={11{1'b0}};
            x_max<={11{1'b0}};
            y_min<={11{1'b0}};
            y_max<={11{1'b0}};
        end
        else if(out_ready)begin
            if(pixel_fire&&roi_area)begin
                if(x_cnt==update_roi_x_min&&y_cnt==update_roi_y_min)begin
                    if(motion)begin
                        x_min<=update_roi_x_min;
                        x_max<=update_roi_x_min;
                        y_min<=update_roi_y_min;
                        y_max<=update_roi_y_min;
                    end
                    else begin
                        x_min<=update_roi_x_max;
                        x_max<=update_roi_x_min;
                        y_min<=update_roi_y_max;
                        y_max<=update_roi_y_min;
                    end
                end
                else begin
                    if(motion)begin
                        if(x_cnt<x_min)x_min<=x_cnt;
                        if(x_cnt>x_max)x_max<=x_cnt;
                        if(y_cnt<y_min)y_min<=y_cnt;
                        if(y_cnt>y_max)y_max<=y_cnt;
                    end
                end
            end
        end
    end
                        
                        
                    
                 
   
   reg [20:0] motion_count;
   
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
           motion_count<={21{1'b0}};
       end
       else if(out_ready)begin
           if(pixel_fire&&roi_area)begin
               if(x_cnt==update_roi_x_min&&y_cnt==update_roi_y_min)begin
                   if(motion)begin
                       motion_count<=21'd1;
                   end
                   else begin
                       motion_count<=21'd0;
                   end
               end
               else if(motion)begin
                   motion_count<=motion_count+1'b1;
               end
           end
       end
   end
   
   reg [10:0] update_x_min;
   reg [10:0] update_x_max;
   reg [10:0] update_y_min;
   reg [10:0] update_y_max;
   wire roi_area=(x_cnt>=update_roi_x_min)&&(x_cnt<=update_roi_x_max)&&(y_cnt>=update_roi_y_min)&&(y_cnt<=update_roi_y_max);
   
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
           update_x_min<={11{1'b0}};
           update_x_max<={11{1'b0}};
           update_y_min<={11{1'b0}};
           update_y_max<={11{1'b0}};
       end
       else if(out_ready)begin
           if(pixel_fire)begin
               if(s_axis_tuser)begin
                   update_x_min<=x_min;
                   update_x_max<=x_max;
                   update_y_min<=y_min;
                   update_y_max<=y_max;
               end
           end
       end
   end
   
   wire box_en=(motion_count>21'd20)?1'b1:1'b0;
   reg update_box_en;
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
           update_box_en<=1'b0;
       end
       else if(out_ready)begin
           if(pixel_fire)begin
               if(s_axis_tuser)begin
                   update_box_en<=box_en;
               end
           end
       end
   end
   reg [10:0] x_cnt_d1;
   reg [10:0] y_cnt_d1;
   reg pixel_fire_d1;
   reg s_axis_tuser_d1;
   reg s_axis_tlast_d1;
   
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
           x_cnt_d1<={11{1'b0}};
           y_cnt_d1<={11{1'b0}};
           pixel_fire_d1<=1'b0;
           s_axis_tuser_d1<=1'b0;
           s_axis_tlast_d1<=1'b0;
       end
       else if(out_ready)begin
           pixel_fire_d1<=pixel_fire;
           if(pixel_fire)begin
               x_cnt_d1<=x_cnt;
               y_cnt_d1<=y_cnt;
               s_axis_tuser_d1<=s_axis_tuser;
               s_axis_tlast_d1<=s_axis_tlast;
           end
       end
   end
   
   wire box_area=(x_cnt_d1>=update_x_min&&x_cnt_d1<=update_x_max&&y_cnt_d1==update_y_min)||
                    (x_cnt_d1>=update_x_min&&x_cnt_d1<=update_x_max&&y_cnt_d1==update_y_max)||
                    (y_cnt_d1>=update_y_min&&y_cnt_d1<=update_y_max&&x_cnt_d1==update_x_min)||  
                    (y_cnt_d1>=update_y_min&&y_cnt_d1<=update_y_max&&x_cnt_d1==update_x_max); 
                    
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
           m_axis_tdata_reg<={24{1'b0}};
           m_axis_tvalid_reg<=1'b0;
           m_axis_tuser_reg<=1'b0;
           m_axis_tlast_reg<=1'b0;
       end
       else if(out_ready)begin
           if(pixel_fire_d1)begin
               if(update_box_en)begin
                   m_axis_tuser_reg<=s_axis_tuser_d1;
                   m_axis_tlast_reg<=s_axis_tlast_d1;
                   m_axis_tvalid_reg<=1'b1;
                   if(box_area)begin
                       m_axis_tdata_reg<=24'hff0000;
                   end
                   else begin
                       m_axis_tdata_reg<=24'h000000;
                   end
               end
               else begin
                   m_axis_tuser_reg<=s_axis_tuser_d1;
                   m_axis_tlast_reg<=s_axis_tlast_d1;
                   m_axis_tvalid_reg<=1'b1;
                   m_axis_tdata_reg<=24'h000000;
               end
           end
           else begin
               m_axis_tuser_reg<=1'b0;
               m_axis_tlast_reg<=1'b0;
               m_axis_tvalid_reg<=1'b0;
               m_axis_tdata_reg<={24{1'b0}};
           end
       end
   end
   assign m_axis_tuser=m_axis_tuser_reg;
   assign m_axis_tlast=m_axis_tlast_reg;
   assign m_axis_tvalid=m_axis_tvalid_reg;
   assign m_axis_tdata=m_axis_tdata_reg;                
   
   
   
   
                        
            
    
  
endmodule
