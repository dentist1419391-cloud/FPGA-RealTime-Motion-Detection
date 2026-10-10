
# FPGA Real-Time Motion Detection System

Zynq-7000 FPGA 기반 3-Frame Difference 실시간 움직임 영역 검출 시스템

Digilent Pcam 5C Demo의 카메라 입력 및 기본 Video I/O 구조를 기반으로,
AXI4-Stream 영상처리 RTL과 3개의 VDMA MM2S Read Channel을 이용한 3-Frame 처리 구조를 구성하고
1920×1080 30fps 영상에서 움직임 영역을 검출하여 Bounding Box로 출력했습니다.

### 주요 구현 및 성과

- AXI4-Stream 기반 3-Frame Difference 영상처리 RTL 설계
- 3개의 VDMA MM2S Read Channel 기반 3-Frame 처리 구조
- AXIS FIFO 기반 원본 영상과 처리 결과의 픽셀 정렬
- VDMA Read Channel의 HP Port 분산
- 1920×1080 30fps 실시간 영상 처리
- 150 MHz 환경에서 Custom RTL 타이밍 검증

---

## 1. 개발 환경

| 구분 | 내용 |
|---|---|
| 보드 | Digilent Zybo Z7-20 |
| SoC | Xilinx Zynq-7000 |
| 카메라 | Digilent Pcam 5C |
| HDL | Verilog HDL |
| PS 소프트웨어 | C |
| 개발 환경 | Vivado / Vitis 2020.1 |
| 주요 인터페이스 / IP | AXI4-Stream, AXI4-Lite, AXI VDMA |
| 카메라 입력 | 1920×1080 30fps |
| 디스플레이 출력 | 1920×1080 60Hz |
| Custom RTL 클럭 | 150 MHz |

---

## 2. 구현 범위

Pcam 5C Demo의 카메라 입력과 기본 Video I/O 구조를 활용하고,
영상처리 RTL과 3-Frame 처리 구조를 직접 구성했습니다.

### Reference Design 활용

- Pcam 5C Camera 초기화 및 기본 Video Input / Output Pipeline

### 직접 설계 및 구성

- 3-Frame Difference 기반 AXI4-Stream 영상처리 RTL
- 3×3 Morphology 및 Bounding Box Overlay
- AXI4-Lite 기반 ROI Control Interface
- 3개의 VDMA MM2S Read Channel 기반 3-Frame 처리 구조
- Frame Delay / Genlock 기반 프레임 동기화
- AXIS FIFO 기반 픽셀 정렬
- VDMA Read Channel의 HP Port 분산

### PS / PL 역할

| 영역 | 역할 |
|---|---|
| PS | Pcam Demo 제공 SW 기반 Camera 초기화, VDMA 설정, Frame Delay / Genlock 설정, ROI 제어 |
| PL | AXI4-Stream 기반 영상처리 RTL, 3-Frame Difference, Morphology, Bounding Box, Overlay |

---

## 3. 영상처리 알고리즘

### 3-Frame Difference

2-Frame Difference 방식에서 빠른 움직임이 특정 프레임 구간에서
순간적으로 누락될 수 있는 점을 보완하기 위해 연속된 세 프레임을 사용했습니다.

```text
D1 = |F(n)   - F(n-1)|
D2 = |F(n-1) - F(n-2)|

Motion = (D1 > Threshold) OR (D2 > Threshold)
```

두 차분 결과를 OR하여 어느 한 구간에서 움직임이 검출되면
Motion 영역이 유지되도록 구성했습니다.

이후 Binary Motion Mask에 3×3 Erosion과 Dilation을 적용해 작은 잡음 영역을 제거하고,
ROI 내부 Motion Pixel의 최소/최대 좌표를 이용해 Bounding Box를 생성했습니다.

### 영상처리 파이프라인

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

1080p 영상을 프레임 단위로 저장하고 처리하기 위해 DDR Frame Buffer를 사용했습니다.

연속된 세 프레임을 영상처리 RTL에 동시에 공급하기 위해
3개의 VDMA MM2S Read Channel을 구성했습니다.

- VDMA0 → Frame N
- VDMA1 → Frame N-1
- VDMA2 → Frame N-2
- VDMA의 Frame Delay / Genlock을 이용한 프레임 동기화
- DDR Frame Buffer 기반 3-Frame 처리

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

### VDMA / HP Port 구조

<p align="center">
  <img src="docs/multi_vdma_structure.png" width="850">
</p>

---

## 5. Latency / Throughput

정상적인 `TVALID / TREADY` Handshake 상태에서
영상처리 파이프라인은 1 pixel/clk로 데이터를 처리하도록 설계했습니다.

| IP | 기능 | Latency | Throughput |
|---|---|---:|---:|
| RGB to Gray | RGB888 → 8-bit Gray | 1 clk | 1 pixel/clk |
| Frame Difference | 프레임 간 Pixel 차분 | 1 clk | 1 pixel/clk |
| Threshold | Binary Motion Mask 생성 | 1 clk | 1 pixel/clk |
| Motion Calculation | 두 Binary Mask OR 연산 | 1 clk | 1 pixel/clk |
| Morphology | 3×3 Erosion → Dilation | 7 clk | 1 pixel/clk |
| Box Calculation | ROI 내부 Bounding Box 좌표 계산 | 2 clk | 1 pixel/clk |
| Overlay | 원본 RGB에 Bounding Box 표시 | 1 clk | 1 pixel/clk |
| Total |  | 14 clk | 1 pixel/clk |

### 성능 결과

| 항목 | 결과 |
|---|---:|
| Custom RTL 클럭 | 150 MHz |
| 파이프라인 Latency | 14 clk / 93.3 ns |
| Throughput | 1 pixel/clk |
| 영상 출력 | 1920×1080 30fps |

---

## 6. 트러블슈팅

### 6.1 단일 HP0 공유에 따른 데이터 공급 지연 분석

#### 1. 문제 발생 및 데이터 흐름 점검

2-Frame에서 3-Frame 처리 구조로 확장하면서
VDMA MM2S Read Channel을 2개에서 3개로 늘렸습니다.

초기에는 세 Read Channel을 하나의 AXI Interconnect를 통해 HP0에 연결했으나,
영상이 정상적으로 출력되지 않았습니다.

```text
VDMA0 Read ─┐
VDMA1 Read ─┼─ AXI Interconnect ─ HP0 ─ DDR
VDMA2 Read ─┘
```

Vivado ILA로 각 VDMA의 AXI4-Stream 신호와 영상처리 Pipeline을 단계적으로 확인했습니다.

그 결과 특정 VDMA 채널에서 `TVALID` 공급 공백이 발생했고,
다른 채널에서는 `TREADY`가 Low로 전환되며 Backpressure가 전파되는 현상을 관측했습니다.

영상처리 모듈이 여러 입력 스트림을 함께 처리하는 구조이므로,
한 채널의 데이터 공급 공백이 다른 채널의 전송까지 대기시키는 것으로 판단했습니다.

아래는 Overlay 입력에서 관측한 대표적인 AXI4-Stream 전송 공백 파형입니다.

<p align="center">
  <img src="docs/axis_handshake_with_stall.png" width="800">
</p>

---

#### 2. 요구 대역폭 분석

디스플레이 출력: 1920×1080 60Hz, RGB888

세 VDMA Read Channel이 각각 60Hz로 프레임 데이터를 읽는 조건에서
요구 대역폭을 계산했습니다.

```text
1개의 Read Channel 요구 대역폭
= 1920 × 1080 × 60 × 3 Byte
= 373,248,000 Byte/s
= 373.248 MB/s

3개의 Read Channel 요구 대역폭
= 373.248 × 3
= 1,119.744 MB/s

HP Port 이론 대역폭
= 150 MHz × 8 Byte
= 1,200 MB/s

HP Port 이론 대역폭 대비 요구량
= 1,119.744 / 1,200 × 100
= 93.312%
```

세 Read Channel의 합산 요구량이 단일 HP Port 이론 대역폭의 약 93.3%를 차지해,
대역폭 여유가 크지 않은 구조임을 확인했습니다.

이에 단일 HP0 포트의 실제 전송 대역폭이 시스템 요구량을 충족하는지 측정했습니다.

---

#### 3. RTL 카운터 기반 HP0 전송 대역폭 측정

##### 측정 방법

HP0 Read Data Channel의 `RVALID`, `RREADY`를 RTL Counter에 연결하고,
`RVALID && RREADY`가 성립한 Cycle을 Count했습니다.

150MHz 클럭 기준 1초 동안 측정했으며,
64-bit Data Width를 기준으로 Handshake 1회당 8Byte로 계산했습니다.

| 신호 | 의미 |
|---|---|
| `RVALID` | 유효한 Read Data 전달 |
| `RREADY` | Read Data 수신 가능 |
| `RVALID && RREADY` | 실제 Read Data 전송 |
| `start` | 측정 시작 |
| `done` | 측정 완료 |
| `handshake_count` | 측정 구간 동안 발생한 Read Data 전송 횟수 |

##### 측정 구성

HP0의 `RVALID / RREADY`를 RTL Counter에 연결한 전송량 측정 구성

<p align="center">
  <img src="docs/before_hp_split_measurement_setup.png" height="300">
</p>

##### 측정 결과

VIO를 이용해 1초 동안의 Handshake Count를 확인했습니다.

```text
handshake_count = 139,968,262
done = 1
```

<p align="center">
  <img src="docs/hp0_handshake_count.png" width="900">
</p>

##### 측정 결과 분석

실제 전송 비율

```text
전송 비율
= Handshake Count / 전체 Clock Cycle × 100

= 139,968,262 / 150,000,000 × 100
= 93.312175%
```

실제 전송 대역폭

```text
측정 대역폭
= Handshake Count × 8 Byte / 1 second

= 139,968,262 × 8
= 1,119,746,096 Byte/s
= 1,119.746 MB/s
```

시스템 요구 대역폭과 비교

```text
요구 대역폭 : 1,119.744 MB/s
측정 대역폭 : 1,119.746 MB/s
차이        :     0.002 MB/s
```

측정 결과, HP0의 평균 전송 대역폭은
세 VDMA Read Channel의 계산상 요구 대역폭과 거의 일치했습니다.

따라서 단순한 평균 전송 대역폭 부족만으로
영상 출력 중단 문제를 설명하기 어렵다고 판단했습니다.

다만 평균 전송량을 충족하더라도,
각 Read Channel에 데이터가 공급되는 순간적인 시점과 속도가
항상 일정하다는 의미는 아니므로 추가 분석을 진행했습니다.

---

#### 4. 순간 데이터 공급량 분석 및 Line Buffer 상태 확인

HP0 포트와 세 VDMA Read Channel의 데이터 전송 폭을 비교했습니다.

HP0는 64-bit 데이터 폭으로 동작하므로,
150MHz 클럭 기준 한 Cycle에 최대 8Byte를 전송할 수 있습니다.

반면 각 VDMA Read Channel은 RGB888 데이터를
AXI4-Stream으로 1 pixel/clk씩 출력하도록 구성했습니다.

따라서 세 Read Channel이 동시에 전송하는 순간에는
총 9Byte/clk의 데이터가 소비됩니다.

```text
HP0 Port 최대 공급량
= 64 bit / 8
= 8 Byte/clk

VDMA Read Channel 1개 소비량
= 24 bit / 8
= 3 Byte/clk

VDMA Read Channel 3개 동시 소비량
= 3 Byte × 3
= 9 Byte/clk

순간 공급량과 소비량 차이
= 9 - 8
= 1 Byte/clk
```

즉, 세 채널이 동시에 데이터를 전송할 때
순간적인 소비 요구량이 단일 HP0 포트의 최대 공급 능력을 초과할 수 있는 구조였습니다.

이러한 차이를 각 VDMA의 내부 Line Buffer가 흡수해야 하지만,
데이터 소비가 집중되는 구간에서 버퍼에 저장된 데이터가 일시적으로 고갈될 가능성이 있다고 판단했습니다.

이를 검증하기 위해 세 VDMA의
`mm2s_buffer_empty` 신호를 활성화하고 Vivado ILA로 관측했습니다.

##### Line Buffer Empty 관측 결과

세 VDMA에서 각각 Line Buffer가 일시적으로 비는 현상을 확인했습니다.

일부 채널에서는 `mm2s_buffer_empty`가 주기적으로 High로 전환되는 패턴이 나타났습니다.

<p align="center">
  <img src="docs/vdma_linebuffer_empty.png" width="900">
</p>

이전에 관측했던 AXI4-Stream의 `TVALID` 공급 공백과
Line Buffer Empty 발생을 종합하여,
단일 HP0 포트의 순간적인 데이터 공급 제약이
VDMA 내부 버퍼 고갈 및 영상처리 Pipeline의 전송 공백에 영향을 주었을 가능성이 높다고 판단했습니다.

단, `mm2s_buffer_empty`는 Line Buffer의 Empty 상태를 나타내는 신호로,
이 신호만으로 실제 FIFO Underflow 발생이나
최종 Video Out의 Underflow를 확정할 수는 없습니다.

---

#### 5. HP Port 분산

세 VDMA Read Channel이 단일 HP0 포트를 공유하는 구조를 개선하기 위해,
각 Read 채널을 서로 다른 HP Port로 분산했습니다.

```text
VDMA0 Read  ─ HP0
VDMA1 Read  ─ HP1
VDMA2 Read  ─ HP3

VDMA0 Write ─ HP2
```

이를 통해 세 Read Channel의 데이터 전송 요청이
하나의 HP 포트에 집중되지 않도록 구성했습니다.

각 Read Channel이 별도의 HP 인터페이스를 사용하도록 변경하여
개별 포트에서 처리해야 하는 전송 부담을 줄였습니다.

---

#### 6. AXI4-Stream 전송 결과

HP Port 분산 후 1920×1080 30fps 영상 출력이 정상화되었습니다.

동일한 Overlay 입력에서 캡처한 1,024 Cycle 구간에서
연속적인 AXI4-Stream Handshake를 확인했습니다.

<p align="center">
  <img src="docs/axis_handshake_continuous.png" width="800">
</p>

단일 HP Port를 공유할 때 발생했던 영상 출력 중단 문제가
HP Port 분산 이후 해결된 것을 확인했습니다.

---

#### 7. 구성별 비교

| 항목 | 단일 HP0 공유 | HP Port 분산 후 |
|---|---|---|
| VDMA Read Channel | 3개가 HP0 공유 | HP0, HP1, HP3 분산 |
| 전체 요구 대역폭 | 1,119.744 MB/s | 1,119.744 MB/s |
| HP0 이론 최대 대역폭 | 1,200 MB/s | 1,200 MB/s |
| HP0 실측 대역폭 | 1,119.746 MB/s | 별도 실측값 미기재 |
| HP0 전송 비율 | 93.312% | 별도 실측값 미기재 |
| 순간 동시 소비 요구량 | 9 Byte/clk | 채널별 3 Byte/clk |
| Line Buffer | Empty 발생 관측 | 추가 비교 측정 필요 |
| AXI4-Stream | 데이터 공급 공백 발생 | 정상 전송 확인 |
| 영상 출력 | 미출력 | 정상 |

전체 평균 대역폭은 요구량을 충족했지만,
세 VDMA가 동시에 데이터를 소비하는 구간에서는
단일 HP 포트의 순간 공급 능력을 초과할 수 있음을 확인했습니다.

또한 Line Buffer Empty 발생과 AXI4-Stream 전송 공백을 관측했고,
HP Port를 분산한 뒤 영상 출력이 정상화되었습니다.

이를 통해 실시간 영상처리 시스템에서는
전체 평균 대역폭뿐 아니라 순간적인 데이터 공급 능력과
채널별 버퍼 상태도 중요하다는 점을 확인했습니다.

---

### 6.2 원본 영상과 처리 결과의 픽셀 정렬

**문제**

- 원본 RGB 영상과 영상처리 결과를 결합하는 과정에서 Pixel 위치 불일치 발생

<p align="center">
  <img src="docs/pixel_alignment_architecture.png" width="700">
</p>

**분석**

- 원본 RGB 경로와 영상처리 경로 사이에 서로 다른 처리 지연 존재
- 초기에는 Shift Register 기반 고정 지연으로 Pixel 위치 정렬
- Vivado ILA에서 `TVALID / TREADY` 신호를 관측한 결과, AXI4-Stream Backpressure 발생 시 영상처리 경로에 추가적인 가변 지연이 발생함을 확인
- Backpressure에 따른 가변 지연을 처리하기 위해 고정 Delay 방식 대신 버퍼링 구조가 필요하다고 판단

**해결**

- 원본 RGB 경로의 Shift Register 기반 고정 지연 구조를 AXIS FIFO 기반 버퍼링 구조로 변경
- Overlay 단계에서 두 입력의 `TVALID / TREADY` 상태를 고려해 데이터 전달
- Backpressure 발생 시 FIFO를 통해 원본 Pixel의 전달 시점 제어

**결과**

- Backpressure 발생 상황에서도 원본 영상과 영상처리 결과의 Pixel Sequence 정렬 유지

---

### 6.3 Morphology 경계 처리

**문제**

- 3×3 Morphology 연산 시 영상 가장자리에서 일부 이웃 Pixel 부재
- 경계 Pixel을 제외하면 출력 영상 크기가 입력보다 작아짐

**해결**

- 영상 외부 Pixel 값을 `0`으로 처리하는 Zero Padding 적용
- 영상 경계에서도 3×3 Window 연산 수행
- 입력과 동일한 출력 해상도 유지

<p align="center">
  <img src="docs/morphology_zero_padding.png" width="300">
</p>

---

## 7. 시스템 검증

### 시스템 통합 및 AXI4-Stream 검증

영상처리 RTL을 FPGA 시스템에 통합한 뒤,
Vivado ILA를 활용하여 실제 데이터 흐름과 인터페이스 동작을 검증했습니다.

- `TVALID / TREADY` Handshake
- 영상 데이터 흐름
- 파이프라인 지연
- Backpressure 발생 상태
- HP Port 분산 전후 Stream 전송 상태

<p align="center">
  <img src="docs/ila_pipeline_latency.png" width="800">
</p>

### VDMA 프레임 동기화 검증

PS Software를 통해 각 VDMA의 프레임 동작 상태를 확인하고,
3개의 MM2S Channel이 의도한 프레임을 공급하는지 검증했습니다.

- 각 VDMA의 프레임 동작 상태 확인
- Frame Delay 설정 확인
- Genlock 동작 확인
- 연속된 3개의 프레임이 영상처리 파이프라인에 공급되는지 검증

<p align="center">
  <img src="docs/vdma_sync_verification.png" width="650">
</p>

---

## 8. 타이밍 / 자원 사용량

<p align="center">
  <img src="docs/implementation_summary.png" width="950">
</p>

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
| 총 소비전력 | 1.979 W |

전체 Design에는 Pcam Demo 기반 경로의 Negative Slack이 남아 있으며,
추가한 Custom RTL 경로에서는 타이밍 위반이 발생하지 않았습니다.

자원 사용량은 Pcam Demo와 Custom RTL을 포함한 전체 시스템 기준

---

## 9. 최종 결과

- 3-Frame Difference 기반 실시간 움직임 검출 RTL 구현
- 3개의 VDMA MM2S Read Channel 기반 3-Frame 처리 및 프레임 동기화
- AXIS FIFO 기반 원본 영상과 처리 결과의 픽셀 정렬
- HP Port 분산을 통한 메모리 대역폭 병목 완화 및 영상 출력 정상화
- Custom RTL 150 MHz 타이밍 검증
- 1920×1080 30fps Motion Detection 및 Bounding Box 실시간 출력

https://github.com/user-attachments/assets/9a3a67aa-2736-4b05-ba71-554f5b7c8f1a
