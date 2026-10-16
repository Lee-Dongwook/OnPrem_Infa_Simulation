# 분산 스토리지 (Longhorn) / 노드 장애 대응 E2E

기존에 사용하던 `local-path`는 특정 노드의 로컬 디스크에 묶여 있어 노드 장애 시 데이터 유실 위험과 Pod 마이그레이션 제약이 있다. 이를 해결하기 위해 쿠버네티스 노드들의 디스크를 묶어 볼륨을 다중 노드에 실시간 복제(Replication)하는 분산 블록 스토리지 `Longhorn`을 구축한다.

> **사전 요구사항**: Longhorn 엔진이 iSCSI 프로토콜을 통해 볼륨을 다루므로, 모든 노드에 open-iscsi와 nfs-common 패키지가 필수적으로 설치되어 있어야 한다.

### 1. 모든 노드 공통 사전 설정

각 VM(k8s-control-plane, k8s-worker-01, k8s-worker-02)에 접속하여 iSCSI 유틸리티를 설치하고 활성화한다.

```bash
sudo apt-get update
sudo apt-get install -y open-iscsi nfs-common util-linux grep
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

```bash
multipass transfer scripts/setup-longhorn-prereq.sh k8s-control-plane:/tmp/setup-longhorn-prereq.sh
multipass transfer scripts/setup-longhorn-prereq.sh k8s-worker-01:/tmp/setup-longhorn-prereq.sh
multipass transfer scripts/setup-longhorn-prereq.sh k8s-worker-02:/tmp/setup-longhorn-prereq.sh

multipass exec k8s-control-plane -- bash /tmp/setup-longhorn-prereq.sh
multipass exec k8s-worker-01 -- bash /tmp/setup-longhorn-prereq.sh
multipass exec k8s-worker-02 -- bash /tmp/setup-longhorn-prereq.sh
```

### 2. Longhorn 매니페스트 배포

마스터 노드에서 공식 Longhorn 일체형 매니페스트를 배포한다.

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.2/deploy/longhorn.yaml
kubectl wait --timeout=5m -n longhorn-system deployment/longhorn-driver-deployer --for=condition=Available
kubectl get pods -n longhorn-system
```

`longhorn-system` 네임스페이스의 모든 파드가 Running 상태가 되면 배포가 완료된다.

### 3. 기본 StorageClass 변경

앞으로 생성되는 PVC가 local-path 대신 Longhorn 분산 스토리지를 기본으로 사용하도록 변경한다.

```bash
kubectl patch storageclass longhorn -p 'metadata: {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}'
kubectl get sc
```

### 4. 분산 스토리지 E2E 검증

`manifests/05-longhorn/longhorn-test.yaml`: Longhorn PVC와 이를 마운트하는 Nginx 테스트 Pod

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: longhorn-test-pod
spec:
  containers:
    - name: test-container
      image: nginx
      volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: longhorn-vol
  volumes:
    - name: longhorn-vol
      persistentVolumeClaim:
        claimName: longhorn-pvc
```

```bash
multipass transfer manifests/03-storage/longhorn-test.yaml k8s-control-plane:/tmp/longhorn-test.yaml
kubectl apply -f /tmp/longhorn-test.yaml
kubectl get pvc,pod
```

처음 파드가 생성될 때 Longhorn 컨트롤러가 볼륨을 준비하고 복제본을 생성하는 동안 일시적으로 FailedAttachVolume 에러나 ContainerCreating 상태가 발생할 수 있다. 볼륨이 준비된 후 자동으로 Running 상태로 진입한다.
