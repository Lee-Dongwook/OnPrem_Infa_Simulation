# K8s Cluster 초기화 및 Worker Node 조인

### 1. 마스터 노드 (k8s-control-plane) 초기화

마스터 노드에서 `kubeadm init` 을 실행하여 제어 플레인을 구성한다.
이때 Pod들이 통신할 수 있는 네트워크 대역 (Pod CIDR)을 Calico CNI 규격에 맞게 지정해준다.

```bash
multipass shell k8s-control-plane
```

Pod CIDR: 192.168.0.0/16으로 지정하였다.

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

초기화 실행 후 `kubeadm join <마스터\_IP>:6443 --token <토큰> --discoverytoken-ca-cert-hash sha256:<해시>` 값을 얻을 수 있다.

마스터 노드에서는 kubectl을 사용할 수 있도록 설정을 복사한 후 종료한다.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
exit
```

### 2. 워커 노드들을 클러스터에 조인(Join)

앞서 마스터 노드 초기화 시 얻은 `kubeadm join`을 Worker 1 노드와 Worker 2 노드에 각각 조인 연결한다.

```bash
multipass exec k8s-worker-01 -- sudo kubeadm join <마스터_IP>:6443 --token <토큰> --discovery-token-ca-cert-hash sha256:<해시>
```

```bash
multipass exec k8s-worker-02 -- sudo kubeadm join <마스터_IP>:6443 --token <토큰> --discovery-token-ca-cert-hash sha256:<해시>
```

### 3. CNI(Calico) 설치 및 클러스터 상태 확인

노드를 모두 조인 시킨 후, 네트워크 플러그인(Calico)을 마스터 노드에 설치하여 노드 간 통신을 활성화 한다.

```bash
multipass shell k8s-control-plane
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
```

위 설정을 모두 완료한 후, 각 노드들의 실행 상태를 점검하기 위해

```bash
kubectl get nodes
```

를 실행한다.
