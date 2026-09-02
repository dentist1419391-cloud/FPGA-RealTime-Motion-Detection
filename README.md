# FPGA Real-Time Motion Detection System

Zynq-7000 FPGA 기반의 **3-Frame Difference 실시간 움직임 영역 검출 시스템**입니다.

Pcam 5C Demo의 카메라 입력 및 기본 Video I/O 구조를 기반으로,
3개의 VDMA Read Channel과 Verilog RTL 기반 영상처리 Pipeline을 추가하여
**1920×1080 @ 30fps** 영상에서 움직임 영역을 검출하고 Bounding Box로 출력했습니다.

---

## 1. 개발 환경

| 항목 | 내용 |
|---|---|
| Board | Digilent Zybo Z7-20 |
| SoC | Xilinx Zynq-7000 |
| Camera | Digilent Pcam 5C |
| HDL | Verilog HDL |
| Software | C |
| Tool | Vivado / Vitis 2020.x |
| Interface | AXI4-Stream, AXI4-Lite, AXI VDMA |
| Resolution | 1920 × 1080 @ 30fps |
| Processing Clock | 150 MHz |

---

## 2. 구현 범위

본 프로젝트는 **Pcam 5C Demo 기반**으로 구현했습니다.

### Demo 기반 활용

- Pcam 5C Camera Input
- MIPI D-PHY, CSI-2 RX
- Bayer to RGB, Gamma Correction
- 기본 Video Output 구조
- Zynq PS 및 Clock / Reset 구성

### 직접 구현 및 확장

- 2-Frame Difference → **3-Frame Difference 구조 확장**
- 3개의 VDMA MM2S Read Channel 구성
- Genlock / Frame Delay 기반 Frame Synchronization
- AXI4-Stream 기반 Custom RTL Pipeline
- RGB to Gray
- Frame Difference
- Threshold 기반 Motion Detection
- 3-Frame Motion OR
- 3×3 Morphology
- Bounding Box Calculation / Overlay
- AXI4-Lite 기반 ROI Control
- HP Port 분산을 통한 Memory Access 구조 개선
- AXI4-Stream Backpressure를 고려한 Pixel Alignment
- Vivado ILA 및 PS Software 기반 검증

---

## 3. 알고리즘

기존 2-Frame Difference 방식은 연속된 두 프레임 사이의 변화만 반영하기 때문에
빠른 움직임에서 검출 결과가 순간적으로 끊길 수 있습니다.

이를 개선하기 위해 연속된 세 프레임의 두 차분 결과를 OR 연산하는
**3-Frame Difference 방식**을 적용했습니다.

```text
D1 = |F(n)   - F(n-1)|
D2 = |F(n-1) - F(n-2)|

Motion = (D1 > Threshold) OR (D2 > Threshold)
```

이후 3×3 Erosion / Dilation을 적용하여 Binary Motion Mask의 잡음을 제거하고,
움직임 Pixel의 최소 / 최대 좌표를 계산하여 Bounding Box를 생성했습니다.

---

## 4. 시스템 구조

연속된 세 프레임을 동시에 처리하기 위해 DDR Frame Buffer와
3개의 AXI VDMA MM2S Read Channel을 구성했습니다.

- VDMA0 → Frame N
- VDMA1 → Frame N-1
- VDMA2 → Frame N-2

VDMA 간 Frame Synchronization은 Genlock Master / Slave와 Frame Delay 설정을 이용했습니다.

### 3-VDMA Architecture

![3VDMA Architecture](docs/3vdma_architecture_block_diagram.png)

### 전체 Vivado Block Design

![System Block Design](docs/system_bd.png)

### Custom RTL Pipeline

![Custom RTL Pipeline](docs/custom_motion_pipeline_bd.png)

### Multi-VDMA / HP Port 구조

![Multi VDMA Structure](docs/multi_vdma_structure.png)

---

## 5. Latency / Throughput

정상적인 `TVALID / TREADY` 상태를 기준으로
Custom RTL Pipeline은 **1 pixel/clk**의 처리량을 갖도록 구성했습니다.

| Module | 기능 | Latency | Throughput |
|---|---|---:|---:|
| RGB to Gray | RGB888 → 8-bit Gray | 1 clk | 1 pixel/clk |
| Frame Difference | 두 Frame의 절대 차분 | 1 clk | 1 pixel/clk |
| Threshold | Binary Motion Mask 생성 | 1 clk | 1 pixel/clk |
| Motion Calculation | Motion Data 생성 | 1 clk | 1 pixel/clk |
| Morphology | 3×3 Erosion → Dilation | 7 clk | 1 pixel/clk |
| Box Calculation | Bounding Box 좌표 계산 | 2 clk | 1 pixel/clk |
| Overlay | Bounding Box 표시 | 1 clk | 1 pixel/clk |
| **Total** |  | **14 clk** | **1 pixel/clk** |

---

## 6. 트러블슈팅

### 6.1 단일 HP Port 병목

3개의 VDMA Read Channel을 단일 HP Path에 연결한 초기 구조에서
AXI Interconnect Arbitration과 Burst 사이의 공백으로 인해 데이터 공급이 불안정했습니다.

ILA로 1024 Sample을 관측한 결과 약 **85.6%의 전송률**을 확인했습니다.

![Single HP Port](docs/axis_handshake_with_stall.png)

이후 각 VDMA의 Memory Access Path를 여러 HP Port로 분산하여
단일 Path에 집중되던 Traffic을 분산했습니다.

동일한 1024 Sample 관측 구간에서 연속적인 AXI4-Stream 전송을 확인했고,
영상 출력을 안정화했습니다.

![Distributed HP Ports](docs/axis_handshake_continuous.png)

### 6.2 RGB와 처리 결과의 Pixel 정렬

원본 RGB Path와 Motion Processing Path 사이에는 고정 Pipeline Latency가 존재하지만,
AXI4-Stream Backpressure에 의해 추가적인 가변 지연이 발생했습니다.

따라서 고정 Shift Register만으로는 두 경로의 동일 좌표 Pixel을 안정적으로 정렬할 수 없었습니다.

![Pixel Alignment](docs/pixel_alignment_architecture.png)

원본 RGB Path에 AXI4-Stream Data FIFO를 적용하고,
두 입력의 `TVALID / TREADY` 조건을 기준으로 Handshake를 제어하여 Pixel을 정렬했습니다.

### 6.3 Morphology 경계 처리

3×3 Window가 영상 경계를 벗어나는 경우 외부 Pixel을 `0`으로 처리하는
**Zero Padding**을 적용하여 입력과 동일한 해상도를 유지했습니다.

![Morphology Zero Padding](docs/morphology_zero_padding.png)

---

## 7. 검증 및 결과

Custom RTL은 Simulation을 통해 기능을 확인한 뒤 전체 시스템에 통합했습니다.

실제 FPGA에서는 Vivado ILA를 이용하여
각 Processing Stage의 AXI4-Stream Data Flow와 Pipeline 동작을 확인했습니다.

![ILA Verification](docs/ila_pipeline_latency.png)

PS Software에서는 VDMA Frame Address와 Frame Pointer를 확인하여
각 Read Channel이 의도한 Frame Buffer에 접근하는지 검증했습니다.

![VDMA Synchronization](docs/vdma_sync_verification.png)

최종적으로 **1920×1080 @ 30fps** 영상에서 움직임 영역을 실시간으로 검출하고
Bounding Box를 안정적으로 출력했습니다.

![Final Output](docs/final_output.png)

---

## Repository

```text
FPGA-RealTime-Motion-Detection/
├── README.md
├── docs/
└── rtl/
    ├── rgb_to_gray/
    ├── frame_difference/
    ├── motion/
    ├── morphology/
    ├── box_calculation/
    └── overlay/
```
