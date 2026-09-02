# FPGA Real-Time Motion Detection System

Zynq-7000 FPGA 기반 **3-Frame Difference 실시간 움직임 영역 검출 시스템**

Pcam 5C Demo의 Camera Input 및 기본 Video I/O 구조를 기반으로,  
**3-Frame Difference 영상처리 RTL과 3중 VDMA 기반 Frame Buffer 구조를 구성하여**  
1920×1080 @ 30fps 영상에서 움직임 영역을 검출하고 Bounding Box로 출력

---

## 1. 개발 환경

| 항목 | 내용 |
|---|---|
| Board | Digilent Zybo Z7-20 |
| SoC | Xilinx Zynq-7000 |
| Camera | Digilent Pcam 5C |
| HDL | Verilog HDL |
| Software | C |
| Tool | Vivado / Vitis 2020.1 |
| Interface | AXI4-Stream, AXI4-Lite, AXI VDMA |
| Resolution | 1920 × 1080 @ 30fps |
| Processing Clock | 150 MHz |

---

## 2. 구현 내용

**Pcam 5C Demo의 Camera Input 및 기본 Video I/O 구조를 활용하고, 영상처리 및 Multi-Frame 구조를 확장**

### PS / PL 역할 분리

| 영역 | 구현 내용 |
|---|---|
| **PS** | Camera 초기화, VDMA / DDR Address 설정, Frame Delay / GenlockEn 설정, ROI 제어 |
| **PL** | AXI4-Stream 기반 Verilog RTL Pixel Pipeline, 3-Frame Difference, Morphology, Bounding Box / Overlay |

### 주요 구현

- **AXI4-Stream 기반 영상처리 RTL Pipeline 설계**
  - RGB to Gray, Frame Difference, Threshold, Motion Detection, Morphology, Bounding Box, Overlay
- **AXI4-Lite 기반 ROI Control Interface 구성**
- **3개의 VDMA MM2S Read Channel 기반 3-Frame Architecture 구성**
- **Genlock Master / Slave, Frame Delay 설정을 통한 VDMA Frame Synchronization**
- DDR Frame Buffer 기반 1080p Frame 저장 및 처리
- VDMA Memory Path의 **HP Port 분산을 통한 전송 경로 개선**
- AXIS FIFO와 `TVALID / TREADY` Handshake를 통한 **Pixel Alignment**
- Vivado **STA / ILA**, PS Software를 통한 시스템 검증

---

## 3. 알고리즘

### 3-Frame Difference

기존 2-Frame Difference 방식의 단일 프레임 구간 검출 한계를 보완하기 위해  
연속된 세 프레임의 두 차분 결과를 OR 연산하는 방식 적용

```text
D1 = |F(n)   - F(n-1)|
D2 = |F(n-1) - F(n-2)|

Motion = (D1 > Threshold) OR (D2 > Threshold)
```

- 두 구간 중 하나에서 움직임 검출 시 Motion 영역 유지
- 시간축 검출 연속성 향상
- 3×3 Erosion → Dilation을 통한 Binary Motion Mask 잡음 제거
- ROI 내부 Motion Pixel의 최소 / 최대 좌표를 이용한 Bounding Box 생성

---

## 4. 시스템 구조

1080p 영상의 프레임 단위 저장 및 처리를 위해 **DDR 기반 Frame Buffer** 구성  
연속된 세 프레임을 동시에 공급하기 위해 **3개의 VDMA MM2S Read Channel** 적용

- VDMA0 → Frame N
- VDMA1 → Frame N-1
- VDMA2 → Frame N-2
- Genlock Master / Slave 및 Frame Delay 설정을 통한 Frame Synchronization
- 추가 Frame Buffer를 이용한 Read / Write 충돌 방지

### 3-VDMA Pipeline Architecture

<p align="center">
  <img src="docs/3vdma_architecture_block_diagram.png" width="850">
</p>

### Vivado Block Design

<p align="center">
  <img src="docs/system_bd.png" width="100%">
</p>

### Custom RTL Pipeline

<p align="center">
  <img src="docs/custom_motion_pipeline_bd.png" width="950">
</p>

### Multi-VDMA / HP Port 구조

<p align="center">
  <img src="docs/multi_vdma_structure.png" width="850">
</p>

---

## 5. Latency / Throughput

정상적인 `TVALID / TREADY` 상태 기준 **1 pixel/clk Streaming Pipeline**

| IP | 기능 | Latency | Throughput |
|---|---|---:|---:|
| RGB to Gray | RGB888 → 8-bit Gray | 1 clk | 1 pixel/clk |
| Frame Difference | 입력 Frame 동기화 및 Pixel 차분 | 1 clk | 1 pixel/clk |
| Threshold | Motion Binary Mask 생성 | 1 clk | 1 pixel/clk |
| Motion Calculation | 두 Binary Mask 동기화 및 OR 연산 | 1 clk | 1 pixel/clk |
| Morphology | 3×3 Erosion → Dilation | 7 clk | 1 pixel/clk |
| Box Calculation | ROI 내부 Bounding Box 좌표 계산 | 2 clk | 1 pixel/clk |
| Overlay | 원본 RGB에 Bounding Box 표시 | 1 clk | 1 pixel/clk |
| **Total** |  | **14 clk** | **1 pixel/clk** |

### 성능 요약

| 항목 | 결과 |
|---|---:|
| Processing Clock | **150 MHz** |
| Pipeline Latency | **14 clk / 93.3 ns** |
| Throughput | **1 pixel/clk** |
| Video Output | **1920×1080 @ 30fps** |
| STA | **150 MHz Timing Closure 달성** |

---

## 6. 트러블슈팅

### 6.1 단일 HP Port 공유 병목

**문제**

- 3개의 VDMA Read Channel을 단일 HP Port에 연결
- 약 1.12 GB/s의 Read Traffic이 단일 경로에 집중
- AXI Interconnect Arbitration 및 Burst 간 공백 발생
- ILA 1024 Sample 관측 구간에서 **85.6% Stream 전송률** 확인

<p align="center">
  <img src="docs/axis_handshake_with_stall.png" width="800">
</p>

**해결**

- 각 VDMA Memory Path를 **3개의 HP Port로 분산**
- 단일 HP Path의 Arbitration 부담 완화 및 데이터 전송 여유 확보
- 동일한 1024 Sample 관측 구간에서 **100% 연속 Stream 전송 확인**
- 1080p 영상 출력 안정화

<p align="center">
  <img src="docs/axis_handshake_continuous.png" width="800">
</p>

---

### 6.2 원본 RGB와 처리 결과의 Pixel 정렬

**문제**

- Original RGB Path와 Box Calculation Path 사이 **13 clk 고정 Latency**
- AXI4-Stream Stall에 따른 추가 **2~5 clk 가변 지연**
- 가변 지연으로 인해 고정 Shift Register Delay만으로 동일 좌표 Pixel 정렬 불가

<p align="center">
  <img src="docs/pixel_alignment_architecture.png" width="700">
</p>

**해결**

- Original RGB Path에 **AXIS FIFO 적용**
- Overlay 단계에서 두 입력이 모두 유효할 때 Data가 전달되도록 `TVALID / TREADY` Handshake 제어
- Backpressure에 따른 가변 지연 흡수 및 Pixel Sequence 정렬

---

### 6.3 Morphology 경계 처리

**문제**

- 영상 경계에서 3×3 Window를 구성하는 일부 이웃 Pixel 부재
- 경계 Pixel 제외 시 출력 영상 크기 감소

**해결**

- 영상 외부 Pixel 값을 `0`으로 가정하는 **Zero Padding 적용**
- 경계에서도 3×3 Window 연산 수행
- 입력과 동일한 출력 해상도 유지

<p align="center">
  <img src="docs/morphology_zero_padding.png" width="300">
</p>

---

## 7. 검증 및 결과

### FPGA 동작 검증

- Vivado ILA를 통한 AXI4-Stream Pipeline 동작 관측
- 각 Processing Stage의 `TVALID / TREADY` 및 Pipeline Latency 확인
- HP Port 분산 전후 Stream 전송 상태 비교

<p align="center">
  <img src="docs/ila_pipeline_latency.png" width="800">
</p>

### VDMA 동기화 검증

- PS Software에서 VDMA Frame Address 및 Frame Pointer 확인
- 각 MM2S Channel이 의도한 Frame Buffer를 참조하는지 검증
- Genlock / Frame Delay 설정을 통한 연속 3-Frame 공급 확인

<p align="center">
  <img src="docs/vdma_sync_verification.png" width="650">
</p>

### 최종 결과

- **1920×1080 @ 30fps 실시간 영상 처리**
- 3-Frame Difference 기반 Motion 영역 검출
- Morphology 기반 Noise 제거
- 움직임 영역 Bounding Box 실시간 출력
- **150 MHz Timing Closure 달성**

<p align="center">
  <img src="docs/final_output.png" width="450">
</p>

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
