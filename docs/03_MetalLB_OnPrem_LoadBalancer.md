# MetalLB / OnPrem LoadBalancer

### 1. MetalLB 오퍼레이터 설치

마스터 노드 (k8s-control-plane) 터미널에서 다음의 명령어를 실행해 MetalLB를 설치한다.

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
```

### 2. IP Address Pool 설정

호스트 터미널에서

```bash
multipass list
```

를 수행하여 가상 머신들이 사용하는 IP 대역을 확인한다.

여기서 얻은 k8s-control-plane 의 IP 대역 (예시 : `192.168.64.X`) 에 맞게끔 MetalLB 풀도 이와 동일한 서브넷 내 사용하지 않는 대역으로 잡아준다. (예시 : `192.168.64.100 ~ 192.168.64.150`)

이를 이제 `manifest/02-metallb/ip-pool.yaml` 내 작성한다.

```yaml

...
spec:
  addresses:
    - 192.168.64.100 ~ 192.168.64.150
...
```

작성을 완료한 후 호스트 터미널에서, Multipass의 transfer 기능으로 마스터노드 (k8s-control-plane)에 파일을 복사한다.

```bash
multipass transfer manifests/02-metallb/ip-pool.yaml k8s-control-plane:/tmp/ip-pool.yaml
```

마스터 노드에 접속해서 이를 적용한다.

```bash
multipass shell k8s-control-plane
kubectl apply -f /tmp/ip-pool.yaml
```

### 3. Nginx 앱 배포 및 LoadBalancer 할당 확인

간단한 Nginx 웹 서버를 LoadBalancer 타입으로 띄워서 MetalLB가 정상 동작하는지 점검한다.

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
```

```bash
kubectl get svc nginx
```

여기서 EXTERNAL-IP 컬럼 값이 PENDING이 뜨지 않고, 위에서 설정한 IP 대역 내 할당이 되어 나타나면 성공한 상태이다.
