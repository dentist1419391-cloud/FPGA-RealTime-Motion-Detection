FPGA Real-Time Motion Detection System

Zynq-7000 기반 3-Frame Difference 실시간 움직임 영역 검출 시스템
Verilog RTL · AXI4-Stream · AXI4-Lite · AXI VDMA · DDR Frame Buffer · Vivado ILA

카메라 입력 영상에서 움직임 영역을 실시간으로 검출하고 Bounding Box를 출력하는 FPGA 영상처리 시스템입니다.
Pcam 5C Demo의 카메라 입력 및 기본 Video I/O 구조를 기반으로, 3-Frame Difference 처리를 위한 Custom RTL Pipeline과 Multi-VDMA 구조를 추가하고 시스템 통합, 동기화, 온보드 디버깅을 수행했습니다.

Key Results

Item

Result

Target Board

Zybo Z7-20, Zynq-7000

Camera

Pcam 5C

Resolution

1920 × 1080

Frame Rate

30 fps

Processing Clock

150 MHz

Streaming Throughput

1 pixel/clk

Custom Pipeline Latency

14 clk, 약 93.3 ns

HDL / SW

Verilog HDL / C

Interfaces

AXI4-Stream, AXI4-Lite, AXI VDMA

1. System Architecture

연속된 세 프레임 Frame N, Frame N-1, Frame N-2를 DDR Frame Buffer에서 읽어 동일 좌표의 픽셀을 비교합니다.



Processing Flow

DDR Frame Buffer
      │
      ├── VDMA0 MM2S ── Frame N
      ├── VDMA1 MM2S ── Frame N-1
      └── VDMA2 MM2S ── Frame N-2
                │
                ▼
          RGB to Gray
                │
         ┌──────┴──────┐
         ▼             ▼
  |Fn - Fn-1|    |Fn-1 - Fn-2|
         │             │
      Threshold     Threshold
         └──────┬──────┘
                ▼
             Motion OR
                │
                ▼
       3×3 Erosion / Dilation
                │
                ▼
        Bounding Box Calculation
                │
                ▼
              Overlay
                │
                ▼
            Video Output

2. Implementation Scope

이 프로젝트는 Vivado 2020.1 Pcam 5C Demo 기반으로 시작했습니다.

Demo 기반으로 활용한 영역

Pcam 5C camera initialization / input path

MIPI D-PHY, MIPI CSI-2 RX

Bayer-to-RGB, Gamma Correction

기본 Video Output infrastructure

Zynq PS 및 주변 clock/reset infrastructure

직접 구현 및 확장한 영역

3-Frame Difference 기반 움직임 검출 구조

3개의 VDMA MM2S Read channel을 이용한 multi-frame 공급 구조

VDMA Genlock / Frame Delay 기반 frame synchronization

Verilog RTL 기반 AXI4-Stream pixel processing pipeline

RGB-to-Gray, Frame Difference, Threshold, Motion OR

3×3 Morphology, Bounding Box, Overlay

AXI4-Lite 기반 ROI control

HP port 병목 분석 및 memory path 분산

AXI4-Stream backpressure를 고려한 pixel alignment

Vivado ILA 및 PS software를 이용한 시스템 검증

3. 3-Frame Difference

기존 2-Frame Difference는 한 구간의 변화만 반영하므로 빠른 움직임에서 검출 결과가 순간적으로 끊길 수 있습니다.

D1 = |F(n)   - F(n-1)|
D2 = |F(n-1) - F(n-2)|

Motion = (D1 > Threshold) OR (D2 > Threshold)

두 구간 중 하나에서 움직임이 검출되면 결과를 유지하도록 구성하여 시간축 검출 연속성을 높였습니다.

1080p 전체 프레임은 DDR Frame Buffer에 저장하고, 서로 다른 세 프레임을 동시에 공급하기 위해 3개의 AXI VDMA MM2S Read channel을 사용했습니다.
각 VDMA가 서로 다른 frame을 읽도록 Genlock Master/Slave 및 Frame Delay 관련 register를 설정했습니다.

4. Vivado Implementation

Full Block Design

전체 시스템은 Pcam 입력부, DDR/VDMA, Custom Processing Pipeline, Video Output으로 구성됩니다.



Custom RTL Processing Pipeline

아래 영역은 움직임 검출을 위해 구성한 Custom RTL IP Pipeline입니다.



Multi-VDMA Memory Structure

3개의 VDMA Read channel을 이용해 DDR에 저장된 연속 frame을 공급하고, memory traffic을 Zynq PS의 HP interface로 연결했습니다.



5. Custom RTL

RTL

Function

Latency

Throughput

rgb_to_gray.v

RGB888 → 8-bit grayscale

1 clk

1 pixel/clk

substraction.v

두 입력 frame의 절대 차분

1 clk

1 pixel/clk

motion_calculation.v

Threshold 비교를 통한 binary motion mask 생성

1 clk

1 pixel/clk

motion_or.v

두 motion mask의 OR 연산

1 clk

1 pixel/clk

morphology.v

3×3 Erosion → Dilation

7 clk

1 pixel/clk

box_cal.v

ROI 내부 움직임의 Bounding Box 계산

2 clk

1 pixel/clk

overlay.v

원본 RGB 영상에 Bounding Box overlay

1 clk

1 pixel/clk

정상적인 TVALID/TREADY handshake 상태에서 Custom Processing Pipeline은 1 pixel/clk throughput을 유지합니다.

RTL Source Structure

rtl/
├── rgb_to_gray/
│   └── rgb_to_gray.v
├── frame_difference/
│   └── substraction.v
├── motion/
│   ├── motion_calculation.v
│   └── motion_or.v
├── morphology/
│   ├── morphology.v
│   ├── window.v
│   ├── erosion.v
│   ├── dilation.v
│   └── dpbram.v
├── box_calculation/
│   ├── axi4_lite_v1_0.v
│   ├── axi4_lite_v1_0_S00_AXI.v
│   └── box_cal.v
└── overlay/
    └── overlay.v

6. AXI4-Lite ROI Control

Bounding Box 검출 영역을 PS에서 설정할 수 있도록 AXI4-Lite slave interface를 구성했습니다.

PS에서 ROI의 x_min, x_max, y_min, y_max 값을 register에 설정하고, PL의 Box Calculation logic은 해당 ROI 내부에서 움직임 픽셀의 최소/최대 좌표를 계산하여 Bounding Box를 생성합니다.

ROI 값은 처리 중인 frame에 영향을 주지 않도록 frame boundary 기준으로 반영하도록 구성했습니다.

7. Troubleshooting

7.1 Single HP Port Bottleneck

3-Frame 구조로 확장하면서 3개의 VDMA Read channel이 동시에 DDR에 접근하게 되었고, 초기에는 여러 channel의 traffic을 단일 HP 경로에서 처리했습니다.

ILA로 AXI4-Stream transfer를 관측한 결과, burst 사이 stall이 발생했으며 1024 sample 구간에서 약 85.6%의 전송률을 확인했습니다.

Before: Single HP Path



이후 VDMA의 memory access path를 여러 HP interface로 분산하여 단일 interconnect에서의 arbitration과 burst contention을 완화했습니다.

After: Distributed HP Paths



동일한 1024 sample 관측 구간에서 연속적인 AXI4-Stream transfer를 확인했고 영상 출력을 안정화했습니다.

HP port 분산은 DDR 자체의 물리적 대역폭을 증가시키는 것이 아니라, PL-side AXI 경로의 contention과 arbitration 부담을 줄이기 위한 구조 변경입니다.

7.2 RGB / Processing Result Pixel Alignment

Overlay 단계에는 두 경로의 데이터가 동시에 도착해야 합니다.

Original RGB path

Motion Processing → Bounding Box path

Processing path에는 약 13 clk의 고정 latency가 존재하며, AXI4-Stream의 backpressure에 의해 추가적인 가변 지연이 발생할 수 있습니다.

따라서 고정 Shift Register만으로는 두 경로의 동일 좌표 pixel을 안정적으로 맞출 수 없었습니다.



원본 RGB path에 AXI4-Stream Data FIFO를 적용하고, 두 입력의 TVALID/TREADY 조건을 기준으로 transfer를 제어해 pixel sequence를 정렬했습니다.

7.3 Morphology Boundary Handling

3×3 window 연산은 영상 경계에서 일부 이웃 pixel이 존재하지 않는 문제가 있습니다.



영상 외부 영역을 0으로 간주하는 Zero Padding을 적용하여 입력과 동일한 1920×1080 해상도를 유지하면서 경계에서도 Morphology 연산을 수행했습니다.

8. Verification

FPGA Logic Verification

Custom RTL은 개별 기능 검증 후 실제 FPGA에 통합하고 Vivado ILA를 이용해 AXI4-Stream data flow와 pipeline timing을 확인했습니다.



VDMA Synchronization Verification

PS software에서 VDMA frame address 및 frame pointer를 확인하여 각 Read channel이 의도한 frame buffer에 접근하는지 검증했습니다.



9. Result

최종적으로 1920×1080 @ 30fps 영상에서 움직임 영역을 실시간으로 검출하고 Bounding Box를 안정적으로 출력했습니다.



Hardware setup 사진은 추후 추가 예정입니다.

10. Repository Structure

FPGA-RealTime-Motion-Detection/
├── README.md
├── docs/
│   ├── 3vdma_architecture_block_diagram.png
│   ├── system_bd.png
│   ├── custom_motion_pipeline_bd.png
│   ├── multi_vdma_structure.png
│   ├── axis_handshake_with_stall.png
│   ├── axis_handshake_continuous.png
│   ├── pixel_alignment_architecture.png
│   ├── morphology_zero_padding.png
│   ├── ila_pipeline_latency.png
│   ├── vdma_sync_verification.png
│   └── final_output.png
└── rtl/
    ├── rgb_to_gray/
    ├── frame_difference/
    ├── motion/
    ├── morphology/
    ├── box_calculation/
    └── overlay/

Development Environment

FPGA Board: Digilent Zybo Z7-20

SoC: Xilinx Zynq-7000

Camera: Digilent Pcam 5C

Vivado / Vitis: 2020.x

HDL: Verilog HDL

Software: C

Main Interfaces: AXI4-Stream, AXI4-Lite, AXI VDMA
