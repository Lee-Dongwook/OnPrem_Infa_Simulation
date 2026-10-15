# OnPrem_Infa_Simulation

Mac 위에서 Multipass VM 3대로 kubeadm 기반 온프렘 Kubernetes 클러스터를 처음부터 직접 구축한 기록이다.
VM → 클러스터 → 네트워킹(CNI, LoadBalancer) → 스토리지 → 외부 진입점 순서로 쌓았고,
마지막에 샘플 앱 하나로 전체 경로를 E2E로 검증했다.

```
Host ─▶ MetalLB IP ─▶ Envoy Gateway ─▶ HTTPRoute ─▶ Service ─▶ Pod ─▶ PVC(local-path)
```

## 구성

| 노드 | 역할 | 사양 | IP |
|---|---|---|---|
| k8s-control-plane | control-plane | 2 CPU / 3G / 10G | 192.168.252.2 |
| k8s-worker-01 | worker | 1 CPU / 2G / 10G | 192.168.252.3 |
| k8s-worker-02 | worker | 1 CPU / 2G / 10G | 192.168.252.4 |

| 영역 | 선택 | 버전 |
|---|---|---|
| OS / 런타임 | Ubuntu 24.04 / containerd | 2.4.2 |
| Kubernetes | kubeadm | v1.30.14 |
| CNI | Calico (Pod CIDR `192.168.0.0/16`) | v3.28.0 |
| LoadBalancer | MetalLB L2 (`192.168.252.100-150`) | v0.14.8 |
| Storage | local-path-provisioner (default SC) | v0.0.30 |
| 진입점 | Envoy Gateway (Gateway API) | v1.9.2 |

## 진행 기록

| 단계 | 내용 | 문서 | 파일 |
|---|---|---|---|
| 1 | VM 생성, 공통 설정(swap off, 커널 모듈, sysctl, containerd, kubeadm) | [01](docs/01_VM_Common.md) | `scripts/init-vms.sh`, `scripts/setup-node.sh` |
| 2 | `kubeadm init`, 워커 조인, Calico 설치 | [02](docs/02_K8s_Cluster_Init_Worker_Node_Join.md) | - |
| 3 | MetalLB IP 풀 설정, LoadBalancer 서비스 확인 | [03](docs/03_MetalLB_OnPrem_LoadBalancer.md) | `manifests/02-metallb/` |
| 4 | local-path 설치, default StorageClass 지정, PVC 테스트 | [04](docs/04_Storage_Local_Path.md) | `manifests/03-storage/` |
| 5 | Envoy Gateway 설치, 샘플 앱으로 E2E와 데이터 영속성 검증 | [05](docs/05_Gateway_API_Sample_App.md) | `manifests/04-gateway/` |

## 알게 된 점

- **매니페스트 적용 방법**: 호스트에서 `multipass transfer`로 마스터 노드에 복사한 뒤 마스터 노드에서 `kubectl apply`를 실행한다.
- **local-path의 한계**: 볼륨이 노드에 고정되므로 RWO 앱은 `replicas: 1`과 `strategy: Recreate`로 띄운다. 노드 장애까지 대비하려면 분산 스토리지가 필요하다.
- **Ingress 대신 Gateway API**: ingress-nginx는 2026년 3월에 유지보수가 종료되었다.
- **k8s 1.30과 Envoy Gateway v1.9.2**: `tlsroutes`, `xbackends` CRD는 CEL 문법 문제로 등록되지 않는다. HTTPRoute는 영향이 없다.

## 다음 단계 후보

- 모니터링 (kube-prometheus-stack)
- GitOps (ArgoCD)
- 분산 스토리지 (Longhorn) — 노드 장애 대응 실습 시
