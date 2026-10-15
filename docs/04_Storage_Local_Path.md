# Storage / Local Path Provisioner

### 1. Local Path Provisioner 설치

마스터 노드(k8s-control-plane)에서 Rancher의 local-path-provisioner를 설치한다.
PVC가 생성되면 Pod가 스케줄된 노드의 로컬 디스크(`/opt/local-path-provisioner`)에 볼륨을 자동으로 만들어 준다.

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
```

### 2. Default StorageClass 지정

`storageClassName`을 생략한 PVC도 local-path를 쓰도록 기본 StorageClass로 지정한다.

```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl get sc
```

`local-path (default)`로 표시되면 지정된 것이다.

### 3. PVC + Pod 테스트

호스트에서 `manifests/03-storage/test-pvc-pod.yaml`을 마스터 노드로 복사한 뒤 적용한다.

```bash
multipass transfer manifests/03-storage/test-pvc-pod.yaml k8s-control-plane:/tmp/test-pvc-pod.yaml
multipass shell k8s-control-plane
kubectl apply -f /tmp/test-pvc-pod.yaml
kubectl get pvc local-pvc
```

`VOLUMEBINDINGMODE`가 `WaitForFirstConsumer`이므로, PVC는 Pod가 생성되어 노드가 정해진 다음에 `Bound` 상태가 된다.

### 참고: local-path의 한계

볼륨은 특정 노드의 디스크에 고정된다. 그 노드가 죽으면 Pod는 다른 노드로 옮겨 갈 수 없다.
노드 장애까지 견뎌야 하는 경우에는 Longhorn, Rook-Ceph 같은 분산 스토리지나 NFS가 필요하다.
