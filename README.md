# FPGA Real-Time Motion Detection System

Zynq-7000 FPGA 기반 실시간 움직임 영역 검출 시스템입니다.

3-Frame Difference 기반 움직임 검출 알고리즘을 Verilog RTL로 구현하고,
AXI4-Stream 기반 영상처리 파이프라인과 3개의 VDMA MM2S 채널을 이용하여
1920×1080 30fps 실시간 영상 처리를 구현했습니다.

## Key Features

- Zynq PS/PL 기반 영상처리 시스템
- Verilog RTL 기반 AXI4-Stream Pixel Pipeline
- 3-Frame Difference 기반 움직임 검출
- 3×3 Erosion / Dilation Morphology
- Bounding Box 검출 및 Overlay
- AXI4-Lite 기반 ROI 제어
- 3-VDMA Frame Buffer Architecture
- Vivado ILA 기반 On-board Debugging
- 150 MHz Processing Clock
- 1 pixel/clk Throughput
- 1920×1080 @ 30fps

## Development Environment

- Board: Zybo Z7-20
- Camera: Pcam 5C
- FPGA: Zynq-7000
- HDL: Verilog HDL
- Software: C
- Tool: Vivado / Vitis
- Interface: AXI4-Stream, AXI4-Lite, AXI VDMA

## Repository Structure

```text
.
├── rtl/       # Custom Verilog RTL
├── vivado/    # Vivado block design and constraints
├── docs/      # Architecture, verification and result images
└── README.md
