# FPGA Real-Time Motion Detection System

Zynq-7000 FPGA 기반 **3-Frame Difference 실시간 움직임 영역 검출 시스템**

Digilent Pcam 5C Demo의 Camera Input 및 기본 Video I/O 구조를 기반으로,
**AXI4-Stream 기반 영상처리 RTL과 3중 VDMA 기반 Multi-Frame 구조를 확장하여**
1920×1080 30fps 영상에서 움직임 영역을 검출하고 Bounding Box로 출력했습니다.

### 주요 구현 및 성과

- AXI4-Stream 기반 3-Frame Difference 영상처리 RTL 설계
- 3개의 VDMA MM2S Read Channel 기반 Multi-Frame 구조 구성
- AXI4-Lite 기반 ROI Control Interface 구성
- PS Software 기반 VDMA Frame 동기화 검증
- Vivado ILA 기반 Data Flow 및 Backpressure 분석
- AXIS FIFO 기반 원본 영상과 처리 결과의 Pixel Alignment
- VDMA-DDR Data Path 분석 및 HP Port 분산
- **1920×1080 30fps 실시간 영상 처리**
- **150 MHz Timing Closure 달성**

---

## 1. 개발 환경

| 구분 | 내용 |
|---|---|
| Board | Digilent Zybo Z7-20 |
| SoC | Xilinx Zynq-7000 |
| Camera | Digilent Pcam 5C |
| HDL | Verilog HDL |
| Software | C |
| Tool | Vivado / Vitis 2020.1 |
| Interface | AXI4-Stream, AXI4-Lite, AXI VDMA |
| Resolution | 1920 × 1080 30fps |
| Processing Clock | 150 MHz |

---

## 2. 구현 범위

Pcam 5C Demo의 Camera Input과 기본 Video I/O 구조를 활용하고,
영상처리 RTL과 Multi-Frame 처리 구조를 확장했습니다.

### Reference Design 활용

- Pcam 5C Camera 초기화
- MIPI CSI-2 기반 Camera Input
- Demosaic, Gamma 등 기본 Video Input Pipeline
- 기본 Video Output 구조

### 직접 설계 및 구성

- AXI4-Stream 기반 Custom Video Processing RTL
- RGB to Gray, Frame Difference, Threshold
- 3×3 Morphology
- Bounding Box 계산 및 Overlay
- AXI4-Lite 기반 ROI Control Interface
- 3개의 VDMA MM2S Read Channel 기반 3-Frame 구조
- Frame Delay / Genlock을 이용한 VDMA Frame Synchronization
- PS Software 기반 VDMA Frame 동기화 검증
- AXIS FIFO 기반 Pixel Alignment
- VDMA Memory Path의 HP Port 분산
- Vivado ILA 기반 Data Flow 및 Backpressure 검증
- STA 기반 Timing 검증

### PS / PL 역할

| 영역 | 역할 |
|---|---|
| **PS** | Pcam Demo 기반 Camera 초기화, VDMA 설정, Frame Delay / Genlock 설정, ROI 제어, VDMA Frame 동기화 검증 |
| **PL** | AXI4-Stream 기반 영상처리 RTL, 3-Frame Difference, Morphology, Bounding Box, Overlay |

---

## 3. 영상처리 알고리즘

### 3-Frame Difference

기존 2-Frame Difference 방식에서 빠른 움직임이 특정 프레임 구간에서
순간적으로 누락되는 문제를 보완하기 위해 연속된 세 프레임을 사용했습니다.

```text
D1 = |F(n)   - F(n-1)|
D2 = |F(n-1) - F(n-2)|

Motion = (D1 > Threshold) OR (D2 > Threshold)
```

두 차분 결과를 OR하여 어느 한 구간에서 움직임이 검출되면
Motion 영역이 유지되도록 구성했습니다.

이후 Binary Motion Mask에 3×3 Erosion과 Dilation을 적용하고,
ROI 내부 Motion Pixel의 최소 / 최대 좌표를 이용해 Bounding Box를 생성했습니다.

### Processing Pipeline

```text
RGB
 ↓
RGB to Gray
 ↓
Frame Difference
 ↓
Threshold
 ↓
3-Frame Motion Calculation
 ↓
3×3 Erosion
 ↓
3×3 Dilation
 ↓
Bounding Box Calculation
 ↓
Overlay
```

---

## 4. 시스템 구조

1080p 영상의 Frame 단위 저장 및 처리를 위해 DDR Frame Buffer를 사용했습니다.

연속된 세 Frame을 동시에 영상처리 RTL에 공급하기 위해
3개의 VDMA MM2S Read Channel을 구성했습니다.

- VDMA0 → Frame N
- VDMA1 → Frame N-1
- VDMA2 → Frame N-2
- Frame Delay / Genlock을 이용한 Frame Synchronization
- DDR Frame Buffer 기반 Multi-Frame 처리

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

정상적인 `TVALID / TREADY` Handshake 상태에서
영상처리 Pipeline은 **1 pixel/clk Throughput**으로 동작하도록 설계했습니다.

| IP | 기능 | Latency | Throughput |
|---|---|---:|---:|
| RGB to Gray | RGB888 → 8-bit Gray | 1 clk | 1 pixel/clk |
| Frame Difference | 입력 Frame 동기화 및 Pixel 차분 | 1 clk | 1 pixel/clk |
| Threshold | Binary Motion Mask 생성 | 1 clk | 1 pixel/clk |
| Motion Calculation | 두 Binary Mask 동기화 및 OR | 1 clk | 1 pixel/clk |
| Morphology | 3×3 Erosion → Dilation | 7 clk | 1 pixel/clk |
| Box Calculation | ROI 내부 Bounding Box 좌표 계산 | 2 clk | 1 pixel/clk |
| Overlay | 원본 RGB에 Bounding Box 표시 | 1 clk | 1 pixel/clk |
| **Total** |  | **14 clk** | **1 pixel/clk** |

### 성능 결과

| 항목 | 결과 |
|---|---:|
| Processing Clock | **150 MHz** |
| Pipeline Latency | **14 clk / 93.3 ns** |
| Throughput | **1 pixel/clk** |
| Video Output | **1920×1080 30fps** |
| STA | **150 MHz Timing Closure** |

---

## 6. 트러블슈팅

### 6.1 3중 VDMA 확장 후 Memory 병목

**문제**

- 2-Frame 구조를 3-Frame 구조로 확장한 뒤 영상 끊김 발생
- 3개의 VDMA Read Channel이 단일 HP Port를 공유
- 약 1.12 GB/s의 Read Traffic이 하나의 Memory Path에 집중

**분석**

- 개별 Processing RTL의 동작을 ILA로 확인
- Data Path를 단계적으로 관측하여 VDMA의 Data 공급 구간 분석
- AXI Burst 사이에서 Data 공급 공백 확인
- 1024 Sample 관측 구간에서 **85.6% Stream 전송률** 확인

<p align="center">
  <img src="docs/axis_handshake_with_stall.png" width="800">
</p>

**해결**

- 각 VDMA Memory Path를 **3개의 HP Port로 분산**
- 단일 HP Path의 Arbitration 부담 완화
- VDMA-DDR Data Path의 전송 여유 확보

**결과**

- 동일한 1024 Sample 관측 구간에서 **100% 연속 Stream 전송 확인**
- 1920×1080 30fps 영상 출력 안정화

<p align="center">
  <img src="docs/axis_handshake_continuous.png" width="800">
</p>

---

### 6.2 원본 영상과 처리 결과의 Pixel 정렬

**문제**

- Original RGB Path와 Processing Path 사이 고정 Latency 존재
- 초기에는 Shift Register 기반 Fixed Delay로 두 경로의 Pixel 위치 정렬
- 실제 시스템에서 AXI4-Stream Backpressure 발생 시 추가적인 가변 지연 발생
- Fixed Delay만으로는 원본 RGB와 처리 결과를 안정적으로 정렬하기 어려움

<p align="center">
  <img src="docs/pixel_alignment_architecture.png" width="700">
</p>

**분석**

- Vivado ILA에서 `TVALID / TREADY`를 관측
- Backpressure 발생 시 Processing Path의 Data 전달 시점이 변하는 것을 확인
- 고정 Cycle Delay가 아닌 Handshake 기반 정렬이 필요하다고 판단

**해결**

- Original RGB Path에 **AXIS FIFO 적용**
- Overlay 단계에서 두 입력의 `TVALID / TREADY` Handshake를 기준으로 Data 전달
- Backpressure 발생 시 FIFO에 원본 Pixel을 유지하도록 구성

**결과**

- 가변 지연에 따른 Pixel 위치 불일치 해결
- 원본 RGB와 처리 결과의 Pixel Sequence 정렬

---

### 6.3 Morphology 경계 처리

**문제**

- 3×3 Morphology 연산 시 영상 가장자리에서 일부 이웃 Pixel 부재
- 경계 Pixel을 제외하면 출력 영상 크기가 입력보다 작아짐

**해결**

- 영상 외부 Pixel을 `0`으로 처리하는 **Zero Padding 적용**
- 영상 경계에서도 3×3 Window 연산 수행
- 입력과 동일한 출력 해상도 유지

<p align="center">
  <img src="docs/morphology_zero_padding.png" width="300">
</p>

---

## 7. 시스템 검증

### RTL / AXI4-Stream 검증

Custom RTL의 기능을 RTL Simulation으로 검증한 뒤
FPGA 시스템에 통합했습니다.

시스템 통합 이후 Vivado ILA를 활용하여 다음 항목을 검증했습니다.

- `TVALID / TREADY` Handshake
- Pipeline Data Flow
- Processing Latency
- Backpressure 발생 상태
- HP Port 분산 전후 Stream 전송 상태

<p align="center">
  <img src="docs/ila_pipeline_latency.png" width="800">
</p>

### VDMA Frame 동기화 검증

PS Software를 통해 VDMA의 Frame 동작 상태를 확인하고,
3개의 MM2S Channel이 의도한 Frame을 공급하는지 검증했습니다.

- 각 VDMA의 Frame 동작 상태 확인
- Frame Delay 설정 상태 확인
- Genlock을 통한 VDMA 동작 관계 확인
- 연속된 3개의 Frame이 영상처리 Pipeline에 공급되는지 검증

<p align="center">
  <img src="docs/vdma_sync_verification.png" width="650">
</p>

---

## 8. 최종 결과

- AXI4-Stream 기반 3-Frame Difference 영상처리 RTL 설계
- 3개의 VDMA MM2S Channel 기반 Multi-Frame 구조 구성
- PS Software 기반 VDMA Frame 동기화 검증
- Backpressure 분석 및 AXIS FIFO 기반 Pixel Alignment
- VDMA-DDR Data Path 분석 및 HP Port 분산
- **1920×1080 30fps 실시간 Motion Detection**
- **150 MHz Timing Closure**
- 움직임 영역 Bounding Box 실시간 출력

<p align="center">
  <img src="https://github.com/user-attachments/assets/9a3a67aa-2736-4b05-ba71-554f5b7c8f1a" width="850">
</p>
