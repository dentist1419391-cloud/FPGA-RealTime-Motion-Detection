`timescale 1ns / 1ps
module window
#(
    parameter IMAGE_WIDTH=1920,
    parameter IMAGE_HEIGHT=1080
 )
 (
    input clk,
    input reset_n,
    input stream_en,
    input pixel_valid,
    input pixel_in,
    
    output reg P00,P01,P02,
    output reg P10,P11,P12,
    output reg P20,P21,P22,
    output reg window_valid,
    output reg active_valid
 );
    
    always@(posedge clk or negedge reset_n)begin
        if(!reset_n)begin          
           P00<=0;
           P01<=0;
           P02<=0;
           P10<=0;
           P11<=0;
           P12<=0;
           P20<=0;
           P21<=0;
           P22<=0;
       end
       else if(stream_en)begin
           if(pixel_valid_d)begin
               
               P22<=pixel_in_d;
               P12<=q0_b1;
               P02<=q0_b2;
               P00<=P01;
               P01<=P02;
               P10<=P11;
               P11<=P12;
               P20<=P21;
               P21<=P22;
           end
       end
   end
   
   reg [10:0] x_cnt;
   reg [10:0] y_cnt;
   
   reg [10:0] x_cnt_d;
   reg [10:0] y_cnt_d;
   
   reg pixel_valid_d;
   reg pixel_in_d;
   
   
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
           pixel_valid_d<=1'b0;
           window_valid<=1'b0;
           active_valid<=1'b0;
       end
       else if(stream_en)begin
           pixel_valid_d<=pixel_valid;        
           window_valid<=pixel_valid_d;
           if(x_cnt_d>=2&&y_cnt_d>=2)begin
               active_valid<=1'b1;
           end
           else begin
               active_valid<=1'b0;
           end
       end
   end
   
   always@(posedge clk or negedge reset_n)begin
       if(!reset_n)begin
         x_cnt<={11{1'b0}};
         y_cnt<={11{1'b0}};
         x_cnt_d<={11{1'b0}};
         y_cnt_d<={11{1'b0}};
         pixel_in_d<=1'b0;
       end
       else if(stream_en)begin
           if(pixel_valid)begin       
               x_cnt_d<=x_cnt;
               y_cnt_d<=y_cnt;
               pixel_in_d<=pixel_in;
               if(x_cnt==IMAGE_WIDTH-1)begin
                   x_cnt<={11{1'b0}};
                   if(y_cnt==IMAGE_HEIGHT-1)begin                 
                       y_cnt<={11{1'b0}};
                   end           
                   else begin
                       y_cnt<=y_cnt+1'b1;
                   end
               end
               else begin
                   x_cnt<=x_cnt+1'b1;
               end
           end
       end
   end
   
 
           
   
   
         
        
   
   wire d0_b1;
   wire q0_b1;
   wire d1_b1;
   wire q1_b1;
   
   wire d0_b2;
   wire q0_b2;
   wire d1_b2;
   wire q1_b2;
   
   dpbram
   #(   
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
   ) u_linebuffer1
   (
       .clk(clk),
       .ce0(stream_en&&pixel_valid),
       .we0(1'b0),   //read
       .addr0(x_cnt),
       .d0(d0_b1),
       .q0(q0_b1),
       
       .ce1(stream_en&&pixel_valid_d),
       .we1(1'b1),   //wrtie
       .addr1(x_cnt_d),
       .d1(pixel_in_d),
       .q1(q1_b1)
   );
   
   dpbram
   #(   
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
   ) u_linebuffer2
   (
       .clk(clk),
       .ce0(stream_en&&pixel_valid),
       .we0(1'b0),
       .addr0(x_cnt),
       .d0(d0_b2),
       .q0(q0_b2),
       
       .ce1(stream_en&&pixel_valid_d),
       .we1(1'b1),
       .addr1(x_cnt_d),
       .d1(q0_b1),
       .q1(q1_b2)
   );
   
   
           
     
           
endmodule
