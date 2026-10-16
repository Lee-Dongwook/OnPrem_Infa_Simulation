# [Troubleshooting Report] kube-prometheus-stack 배포 시 발생한 DiskPressure 및 Evicted 장애 해결

### 개요

- 대상 환경: Ubuntu 24.04 (Multipass 3-node 클러스터: 1 Control-plane, 2 Workers)

- 발생 시점: kube-prometheus-stack Helm 차트 배포 직후

- 증상:
  - prometheus-stack-kube-prom-operator, grafana, alertmanager 등의 핵심 파드가 Pending 상태로 머묾.
  - node-exporter 파드가 Evicted 상태로 지속적으로 축출됨.
  - 노드 상태 확인 시 워커 노드(k8s-worker-01, k8s-worker-02)에 DiskPressure=True 테인트가 발생함.

### 원인 분석

- 디스크 공간 부족 및 Kubelet Eviction Threshold 도달:
  - Multipass VM의 기본 디스크 할당 용량이 제한된 상태에서 Longhorn 및 컨테이너 런타임 캐시가 누적됨.
  - 쿠버네티스 Kubelet의 디스크 압박 임계값을 초과하여, 스케줄러가 워커 노드에 새 파드를 할당하지 못하고(FailedScheduling) 기존 파드를 강제 축출(Evicted)함.

- 이전 네임스페이스 삭제 지연 (Terminating Hang):
  - 이전 설치 실패로 생성된 monitoring 네임스페이스가 파이널라이저(Finalizer)로 인해 Terminating 상태에 갇혀 리소스 정리가 지연됨.

### 해결 조치 (Troubleshooting Steps)

1. 멈춰 있는 네임스페이스 강제 청소 (Terminating 해결)

```bash
multipass exec k8s-control-plane -- kubectl patch namespace monitoring --type=json -p='[{"op": "remove", "path": "/spec/finalizers"}]'
```

네임스페이스 삭제가 멈춰 있을 경우 파이널라이저를 강제로 제거하여 즉시 삭제를 유도

2. 노드 레벨 가비지 컬렉션 및 디스크 확보

```bash
multipass exec k8s-worker-01 -- sudo crictl rmi --prune
multipass exec k8s-worker-02 -- sudo crictl rmi --prune
```

컨테이너 런타임의 미사용 이미지 및 캐시를 정리하여 디스크 여유 공간을 확보.

```bash
multipass exec k8s-worker-01 -- sudo journalctl --vacuum-time=1s
multipass exec k8s-worker-02 -- sudo journalctl --vacuum-time=1s
```

3. 실패 및 축출된 파드 정리

상태가 꼬인 파드들을 강제 삭제하여 쿠버네티스가 정상 상태의 노드에 다시 스케줄링하도록 유도

```bash
multipass exec k8s-control-plane -- kubectl delete pods -n monitoring --field-selector=status.phase=Failed
```

4. 모니터링 스택 재배포

디스크 압박(DiskPressure) 상태가 해제된 것을 확인한 후 Helm 차트를 다시 설치

```bash
multipass exec k8s-control-plane -- kubectl create namespace monitoring
multipass exec k8s-control-plane -- helm install prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --timeout 10m
```

### 결과

DiskPressure 조건이 해제되면서 Pending 및 Evicted 상태이던 파드들이 정상적으로 스케줄링 및 초기화(ContainerCreating -> Running) 단계로 진입

로컬/가상머신(Multipass) 환경에서 쿠버네티스를 운영할 때는 기본 디스크 크기가 작게 잡히므로, 무거운 차트(Prometheus/Longhorn 등)를 올릴 때 디스크 사용량 및 Kubelet Eviction 임계값 관리가 필수적임을 확인
