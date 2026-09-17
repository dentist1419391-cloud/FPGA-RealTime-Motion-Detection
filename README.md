# FPGA Real-Time Motion Detection System

Zynq-7000 FPGA 기반 **3-Frame Difference 실시간 움직임 영역 검출 시스템**

Digilent Pcam 5C Demo의 Camera Input 및 기본 Video I/O 구조를 기반으로  
**AXI4-Stream 영상처리 RTL과 3개의 VDMA MM2S Read Channel을 이용한 3-Frame 처리 구조**를 구성했습니다.

Camera Input은 1920×1080 30fps로 동작하며,  
Display Output은 1920×1080 60Hz Timing으로 구성했습니다.

연속된 3개의 Frame을 이용해 움직임 영역을 검출하고,  
Morphology 처리 후 Bounding Box를 생성하여 실시간 영상에 Overlay했습니다.

---

## 1. 주요 구현 및 성과

- AXI4-Stream 기반 3-Frame Difference 영상처리 RTL 설계
- RGB to Gray, Frame Difference, Threshold 구현
- 3×3 Erosion / Dilation 기반 Morphology 구현
- Bounding Box Calculation 및 Overlay 구현
- 3개의 VDMA MM2S Read Channel 기반 3-Frame 처리 구조 구성
- VDMA Frame Delay / Genlock 기반 Frame 동기화
- AXI4-Lite 기반 ROI Control Interface 구성
- Vivado ILA 기반 AXI4-Stream 데이터 흐름 및 Backpressure 분석
- AXIS FIFO 기반 원본 영상과 처리 결과의 Pixel Sequence 정렬
- 단일 HP Port 공유에 따른 VDMA Read 경로 병목 분석
- HP Port 분산 후 **1920×1080 30fps 영상 출력 정상화**
- 150 MHz 환경에서 Custom RTL Timing 검증

---

## 2. 개발 환경

| 구분 | 내용 |
|---|---|
| Board | Digilent Zybo Z7-20 |
| SoC | Xilinx Zynq-7000 |
| Camera | Digilent Pcam 5C |
| HDL | Verilog HDL |
| PS Software | C |
| Tool | Vivado / Vitis |
| 주요 Interface / IP | AXI4-Stream, AXI4-Lite, AXI VDMA |
| Camera Input | 1920×1080 30fps |
| Display Timing | 1920×1080 60Hz |
| Custom RTL Clock | 150 MHz |

---

## 3. 구현 범위

Pcam 5C Demo의 Camera 초기화 및 기본 Video Input / Output 구조를 활용하고,  
3-Frame 영상처리 Pipeline과 VDMA 기반 Frame Read 구조를 추가했습니다.

### Reference Design 활용

- Pcam 5C Camera 초기화
- 기본 Video Input / Output Pipeline
- DDR Frame Buffer 기반 영상 입출력 구조

### 직접 설계 및 구성

- AXI4-Stream 기반 영상처리 RTL
- RGB to Gray
- Frame Difference
- Threshold
- 3-Frame Motion Calculation
- 3×3 Erosion / Dilation
- Bounding Box Calculation
- Overlay
- AXI4-Lite 기반 ROI Control Interface
- 3개의 VDMA MM2S Read Channel 기반 3-Frame 처리 구조
- Frame Delay / Genlock 기반 Frame 동기화
- PS Software 기반 VDMA 동작 상태 확인
- AXIS FIFO 기반 Pixel Sequence 정렬
- VDMA Read 경로의 HP Port 분산
- Vivado ILA 기반 데이터 흐름 및 Backpressure 분석
- HP Port Read Data Handshake 기반 실제 전송 대역폭 측정
- STA 기반 Custom RTL Timing 검증

### PS / PL 역할

| 영역 | 역할 |
|---|---|
| **PS** | Camera 초기화, VDMA 설정, Frame Delay / Genlock 설정, ROI 제어, VDMA 동작 상태 확인 |
| **PL** | AXI4-Stream 영상처리, 3-Frame Difference, Morphology, Bounding Box, Overlay |

---

## 4. 영상처리 알고리즘

### 4.1 3-Frame Difference

2-Frame Difference 방식에서는 빠른 움직임이 특정 Frame 구간에서  
순간적으로 누락될 수 있어 연속된 3개의 Frame을 사용했습니다.

```text
D1 = |F(n)   - F(n-1)|
D2 = |F(n-1) - F(n-2)|

Motion = (D1 > Threshold) OR (D2 > Threshold)
```

두 차분 결과 중 하나라도 움직임으로 판단되면  
Motion 영역으로 유지하도록 구성했습니다.

이후 Binary Motion Mask에 3×3 Erosion과 Dilation을 적용해  
작은 Noise 영역을 제거하고, ROI 내부 Motion Pixel의 최소/최대 좌표를 이용해  
Bounding Box를 생성했습니다.

### 4.2 영상처리 Pipeline

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

## 5. 시스템 구조

1080p 영상을 Frame 단위로 저장하고 처리하기 위해 DDR Frame Buffer를 사용했습니다.

연속된 세 Frame을 영상처리 RTL에 동시에 공급하기 위해  
3개의 VDMA MM2S Read Channel을 구성했습니다.

```text
VDMA0 → Frame N
VDMA1 → Frame N-1
VDMA2 → Frame N-2
```

Frame Delay / Genlock을 이용해 각 VDMA가  
연속된 Frame을 공급하도록 구성했습니다.

### 5.1 3-VDMA Pipeline Architecture

<p align="center">
  <img src="docs/3vdma_architecture_block_diagram.png" width="850">
</p>

### 5.2 Vivado Block Design

<p align="center">
  <img src="docs/system_bd.png" width="100%">
</p>

### 5.3 Custom RTL Pipeline

<p align="center">
  <img src="docs/custom_motion_pipeline_bd.png" width="950">
</p>

### 5.4 VDMA / HP Port 구조

<p align="center">
  <img src="docs/multi_vdma_structure.png" width="850">
</p>

---

## 6. 영상처리 Pipeline 성능

정상적인 AXI4-Stream Handshake가 연속적으로 유지되는 조건에서  
영상처리 Pipeline은 **1 pixel/clk**로 데이터를 처리하도록 설계했습니다.

| IP | 기능 | Latency | Throughput |
|---|---|---:|---:|
| RGB to Gray | RGB888 → 8-bit Gray | 1 clk | 1 pixel/clk |
| Frame Difference | Frame 간 Pixel 차분 | 1 clk | 1 pixel/clk |
| Threshold | Binary Motion Mask 생성 | 1 clk | 1 pixel/clk |
| Motion Calculation | 두 Binary Mask OR 연산 | 1 clk | 1 pixel/clk |
| Morphology | 3×3 Erosion → Dilation | 7 clk | 1 pixel/clk |
| Box Calculation | ROI 내부 Bounding Box 좌표 계산 | 2 clk | 1 pixel/clk |
| Overlay | 원본 RGB에 Bounding Box 표시 | 1 clk | 1 pixel/clk |
| **Total** |  | **14 clk** | **1 pixel/clk** |

### 성능 결과

| 항목 | 결과 |
|---|---:|
| Custom RTL Clock | 150 MHz |
| Pipeline Latency | 14 clk / 93.3 ns |
| Throughput | 1 pixel/clk |
| Camera Input | 1920×1080 30fps |
| Display Timing | 1920×1080 60Hz |

> Pipeline Latency와 1 pixel/clk Throughput은 정상적인 AXI4-Stream Handshake 조건을 기준으로 합니다.

---

# 7. 트러블슈팅

## 7.1 3중 VDMA 구성 후 영상 출력 실패

### 문제

2-Frame 처리 구조를 3-Frame Difference 구조로 확장하면서  
VDMA MM2S Read Channel이 2개에서 3개로 증가했습니다.

초기에는 3개의 VDMA MM2S Read Channel을  
하나의 AXI Interconnect를 통해 단일 HP0 Port에 연결했습니다.

```text
VDMA0 ─┐
VDMA1 ─┼─ AXI Interconnect ─ HP0 ─ DDR
VDMA2 ─┘
```

3-Frame 구조로 변경한 이후 영상이 정상적으로 출력되지 않았습니다.

---

### 1) AXI4-Stream 데이터 흐름 확인

Vivado ILA로 영상처리 Pipeline의 여러 RTL 구간을 단계적으로 관측했습니다.  
Overlay 입력을 포함한 여러 구간에서 AXI4-Stream 데이터 전송 공백을 확인했으며,  
아래는 그중 Overlay 입력에서 관측한 대표 파형입니다.

<p align="center">
  <img src="docs/axis_handshake_with_stall.png" width="800">
</p>

ILA로 영상 Stream의 전송 공백을 확인한 뒤,  
단일 HP0 공유 경로의 대역폭 여유를 추가로 분석했습니다.

---

### 2) VDMA Read 요구 대역폭 계산

Camera Frame Update는 1920×1080 30fps이지만,  
Display Output은 1920×1080 60Hz Timing으로 동작합니다.

따라서 VDMA MM2S Read 대역폭은 60Hz 기준으로 계산했습니다.

한 개의 VDMA Read Channel에 필요한 대역폭은:

```text
1920 × 1080 × 60 × 3 Byte
= 373,248,000 Byte/s
= 373.248 MB/s
```

3개의 VDMA Read Channel 전체 요구 대역폭은:

```text
373.248 MB/s × 3
= 1,119.744 MB/s
≈ 1.12 GB/s
```

HP Port는 64-bit Data Width, 150 MHz Clock으로 동작하므로  
이론적인 최대 대역폭은:

```text
150 MHz × 64 bit
= 150,000,000 × 8 Byte
= 1.2 GB/s
```

3개의 VDMA Read Channel이 요구하는 대역폭은  
단일 HP Port 이론 대역폭의 약 **93.31%**에 해당합니다.

```text
1.119744 GB/s / 1.2 GB/s
≈ 93.31 %
```

---

### 3) HP0 실제 전송 대역폭 측정

이론적인 대역폭 계산 이후  
실제 보드에서 HP0의 AXI Read Data Channel을 직접 측정했습니다.

AXI Interconnect의 `M00_AXI`와 Zynq PS의 `S_AXI_HP0` 사이에서  
Read Data Channel의 `RVALID`와 `RREADY`를 Counter에 연결했습니다.

#### 측정 신호

| Signal | 의미 |
|---|---|
| `RVALID` | 유효한 Read Data 전달 |
| `RREADY` | Read Data 수신 가능 |
| `RVALID && RREADY` | 실제 Read Data 전송 발생 |
| `start` | 측정 시작 |
| `done` | 측정 완료 |
| `handshake_count` | 측정 시간 동안 발생한 Read Data 전송 횟수 |

HP Port Data Width는 64-bit이므로  
한 번의 Handshake에서 8 Byte가 전송됩니다.

150 MHz Clock에서 150,000,000 Cycle 동안  
`RVALID && RREADY`가 동시에 High인 Cycle을 Count하여  
1초간 실제 Read Data 전송량을 측정했습니다.

```text
실제 전송 대역폭
= handshake_count × 8 Byte / 1 sec
```

---

### 4) HP Port 분리 전 측정

#### 측정 구성

<p align="center">
  <img src="docs/before_hp_split_measurement_setup.png" width="900">
</p>

3개의 VDMA MM2S Read Channel이 단일 HP0를 공유하는 상태에서  
1초 동안 Read Data Handshake를 측정했습니다.

<p align="center">
  <img src="docs/before_hp_split_vio.png" width="850">
</p>

측정 결과:

```text
handshake_count = 138,561,478
```

150 MHz의 전체 Clock 중 실제 Read Data 전송이 발생한 비율은:

```text
138,561,478 / 150,000,000
≈ 92.37 %
```

이를 실제 전송 대역폭으로 환산하면:

```text
138,561,478 × 8 Byte
= 1,108,491,824 Byte/s
≈ 1,108.49 MB/s
≈ 1.108 GB/s
```

3개의 VDMA Read Channel 요구 대역폭과 비교하면:

```text
Required : 1,119.744 MB/s
Measured : 1,108.492 MB/s

Difference
≈ 11.252 MB/s
```

단일 HP0 공유 구조에서 측정된 Read Data 전송 대역폭이  
3개의 VDMA Read Channel 요구 대역폭보다 낮은 것을 확인했습니다.

---

### 5) 해결 - HP Port 분산

3개의 VDMA MM2S Read Channel을  
서로 다른 HP Port로 분산했습니다.

```text
VDMA0 ─ HP Port
VDMA1 ─ HP Port
VDMA2 ─ HP Port
```

---

### 6) HP Port 분산 후 측정

#### 측정 구성

<p align="center">
  <img src="docs/after_hp_split_measurement_setup.png" width="900">
</p>

포트 분산 후 한 개의 VDMA Read Channel이 연결된 HP 경로에서  
동일한 방법으로 1초 동안 Read Data Handshake를 측정했습니다.

<p align="center">
  <img src="docs/after_hp_split_vio.png" width="850">
</p>

측정 결과:

```text
handshake_count = 46,656,000
```

실제 전송 대역폭은:

```text
46,656,000 × 8 Byte
= 373,248,000 Byte/s
= 373.248 MB/s
```

이는 한 개의 VDMA Read Channel이 요구하는 대역폭과 일치합니다.

```text
Required
= 1920 × 1080 × 60 × 3 Byte
= 373.248 MB/s

Measured
= 373.248 MB/s
```

---

### 7) AXI4-Stream 연속 전송 확인

HP Port 분산 후 영상처리 Pipeline의 AXI4-Stream을 다시 ILA로 관측했습니다.

분산 후 캡처한 **1,024 Cycle 구간에서 연속적인 AXI4-Stream Handshake**를 확인했습니다.

<p align="center">
  <img src="docs/axis_handshake_continuous.png" width="800">
</p>

구성 변경 전에는 Overlay 입력을 포함한 여러 RTL 구간에서 데이터 전송 공백이 관측됐습니다.  
HP Port 분산 후에는 Overlay 입력에서 캡처한 1,024 Cycle 구간의 연속적인 데이터 전달을 확인했습니다.

최종적으로 **1920×1080 30fps 영상 출력이 정상화**됐습니다.

---

### 8) HP Port 분리 전후 비교

| 항목 | 단일 HP0 공유 | HP Port 분산 후 |
|---|---:|---:|
| HP Port당 VDMA Read Channel | 3 | 1 |
| HP Clock | 150 MHz | 150 MHz |
| HP Data Width | 64 bit | 64 bit |
| HP 이론 대역폭 | 1.2 GB/s | 1.2 GB/s |
| 요구 대역폭 | 1,119.744 MB/s | 373.248 MB/s |
| 1초 Handshake Count | 138,561,478 | 46,656,000 |
| 실제 전송 대역폭 | 1,108.492 MB/s | 373.248 MB/s |
| 실제 데이터 전송 비율 | 92.37% | 31.104% |
| 결과 | 요구 대역폭 미달 | 요구 대역폭 충족 |

영상 Stream에서 데이터 전송 공백을 확인한 후  
VDMA Read 요구 대역폭과 HP0의 실제 전송 대역폭을 비교해 원인을 분석했습니다.

이후 VDMA Read Channel을 여러 HP Port로 분산하고,  
각 Channel의 요구 대역폭이 실제로 공급되는 것을 다시 측정해  
구조 변경 효과를 확인했습니다.

---

## 7.2 원본 영상과 처리 결과의 Pixel 정렬

### 문제

원본 RGB 영상과 영상처리 결과를 Overlay하는 과정에서  
Pixel 위치가 맞지 않는 현상이 발생했습니다.

<p align="center">
  <img src="docs/pixel_alignment_architecture.png" width="700">
</p>

### 분석

초기에는 원본 RGB 경로와 영상처리 경로 사이의  
고정 처리 지연을 Shift Register로 보정했습니다.

하지만 Vivado ILA에서 `TVALID / TREADY`를 관측한 결과,  
AXI4-Stream Backpressure가 발생할 경우  
영상처리 경로의 실제 전달 지연이 일정하지 않게 변하는 것을 확인했습니다.

고정 Delay만으로는 두 경로의 Pixel 전달 시점을  
안정적으로 맞추기 어렵다고 판단했습니다.

### 해결

원본 RGB 경로의 Shift Register 기반 Delay 구조를  
AXIS FIFO 기반 Buffering 구조로 변경했습니다.

Overlay 단계에서 두 입력의 `TVALID / TREADY` 상태를 함께 고려하고,  
두 경로가 모두 준비되었을 때 Pixel을 전달하도록 구성했습니다.

### 결과

Backpressure가 발생하는 상황에서도  
원본 영상과 영상처리 결과의 Pixel Sequence 정렬을 유지했습니다.

---

## 7.3 Morphology 경계 처리

### 문제

3×3 Morphology 연산에서는 영상 가장자리 Pixel에 대해  
일부 이웃 Pixel이 존재하지 않습니다.

경계 Pixel을 제외할 경우  
출력 영상의 크기가 입력보다 작아지는 문제가 발생합니다.

### 해결

영상 외부 Pixel 값을 `0`으로 처리하는 Zero Padding을 적용했습니다.

영상 경계에서도 3×3 Window 연산을 수행하면서  
입력과 동일한 출력 해상도를 유지했습니다.

<p align="center">
  <img src="docs/morphology_zero_padding.png" width="300">
</p>

---

## 8. 시스템 검증

### 8.1 AXI4-Stream Pipeline 검증

영상처리 RTL을 FPGA 시스템에 통합한 뒤  
Vivado ILA를 활용해 실제 데이터 흐름과 Interface 동작을 확인했습니다.

주요 관측 신호:

- `TVALID`
- `TREADY`
- `TDATA`
- `TUSER`
- `TLAST`

확인 항목:

- AXI4-Stream Handshake
- 영상 Data Flow
- Pipeline Latency
- Backpressure 발생 상태
- HP Port 분산 전후 Stream 전달 상태

<p align="center">
  <img src="docs/ila_pipeline_latency.png" width="800">
</p>

---

### 8.2 VDMA Frame 동기화 확인

PS Software를 통해 각 VDMA의 동작 상태를 확인하고,  
3개의 MM2S Channel이 의도한 Frame을 공급하는지 검증했습니다.

확인 항목:

- 각 VDMA의 Frame 동작 상태
- Frame Delay 설정
- Genlock 동작
- 연속된 3개의 Frame 공급 여부

<p align="center">
  <img src="docs/vdma_sync_verification.png" width="650">
</p>

---

## 9. Timing / Resource Utilization

전체 시스템은 Digilent Pcam 5C Demo의 Camera / Video I/O 구조를 기반으로  
Custom Motion Detection RTL을 추가하여 구성했습니다.

<p align="center">
  <img src="docs/implementation_summary.png" width="950">
</p>

전체 Integrated Design의 Implementation 결과는 다음과 같습니다.

| 항목 | 결과 |
|---|---:|
| WNS | -2.450 ns |
| TNS | -4.864 ns |
| WHS | -1.038 ns |
| THS | -2.033 ns |
| LUT | 11,325 |
| FF | 16,623 |
| BRAM | 19 |
| DSP | 0 |
| Total Power | 1.979 W |

전체 Design에는 Pcam 5C Demo 기반 기존 경로에서 발생하는  
Negative Slack이 남아 있습니다.

Timing Report의 Failing Path를 확인한 결과,  
본 프로젝트에서 추가한 Custom Motion Processing RTL  
(Frame Difference, Motion Calculation, Morphology, Bounding Box, Overlay) 경로에서는  
Timing Violation이 발생하지 않았습니다.

따라서 전체 Reference Design의 Timing Closure가 아니라,  
**150 MHz 환경에서 추가한 Custom RTL의 Timing 조건을 검증**했습니다.

위 Resource Utilization은 Custom RTL만의 사용량이 아니라  
Pcam Demo 기반 Video I/O 구조와 Custom RTL을 포함한  
전체 Integrated System의 Implementation 결과입니다.

---

## 10. 최종 결과

- AXI4-Stream 기반 3-Frame Difference 영상처리 RTL 구현
- RGB to Gray / Frame Difference / Morphology / Bounding Box / Overlay 구현
- 3개의 VDMA MM2S Read Channel 기반 3-Frame 처리 구조 구성
- Frame Delay / Genlock 기반 Frame 동기화
- Vivado ILA 기반 AXI4-Stream 데이터 흐름 및 Backpressure 분석
- 영상 Stream의 전송 공백 확인 후 HP0 Read 경로의 실제 전송 대역폭 측정
- 단일 HP0 공유 구조에서 약 1.108 GB/s의 Read Data 전송 대역폭 측정
- VDMA Read Channel의 HP Port 분산
- 분산 후 Channel당 373.248 MB/s 요구 대역폭 공급 확인
- 분산 후 1,024 Cycle 구간에서 연속적인 AXI4-Stream Handshake 확인
- AXIS FIFO 기반 Pixel Sequence 정렬
- 150 MHz 환경에서 Custom RTL Timing 검증
- **1920×1080 30fps Motion Detection 및 Bounding Box 영상 출력 정상화**

<p align="center">
  <img src="docs/final_output.png" width="900">
</p>

https://github.com/user-attachments/assets/9a3a67aa-2736-4b05-ba71-554f5b7c8f1a
