# Gateway API (Envoy Gateway) / Sample App E2E

지금까지 구축한 VM, 네트워킹(Calico, MetalLB), 스토리지(local-path)가 함께 동작하는지
아래 경로를 앱 하나로 한 번에 검증한다.

```
Host → MetalLB IP → Envoy Gateway → HTTPRoute → Service → Pod → PVC
```

> ingress-nginx는 2026년 3월에 유지보수가 종료되었으므로, Ingress 대신 Gateway API를 사용한다.

### 1. Envoy Gateway 설치

마스터 노드에서 설치한다. Gateway API CRD도 함께 설치된다.

```bash
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.9.2/install.yaml
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

> **k8s v1.30 주의**: `tlsroutes`, `xbackends` CRD 두 개는 1.30이 지원하지 않는 CEL 문법을 써서
> `Invalid` 에러를 내며 등록되지 않는다. 이번에 쓰는 Gateway, HTTPRoute와는 무관하므로 무시한다.
> TLSRoute가 필요해지면 클러스터를 1.31 이상으로 올린다.

### 2. Gateway + 샘플 앱 배포

- `manifests/04-gateway/gateway.yaml`: GatewayClass(`eg`)와 HTTP 80 포트를 여는 Gateway(`web-gateway`)
- `manifests/04-gateway/sample-app.yaml`: PVC, nginx Deployment, Service, HTTPRoute

```bash
# 호스트
multipass transfer manifests/04-gateway/gateway.yaml k8s-control-plane:/tmp/gateway.yaml
multipass transfer manifests/04-gateway/sample-app.yaml k8s-control-plane:/tmp/sample-app.yaml

# 마스터 노드
kubectl apply -f /tmp/gateway.yaml -f /tmp/sample-app.yaml
kubectl wait --timeout=3m gateway/web-gateway --for=condition=Programmed
kubectl get gateway web-gateway
```

Envoy Gateway가 `envoy-gateway-system` 네임스페이스에 LoadBalancer Service를 만들고,
MetalLB가 IP 풀에서 주소를 할당한다. `ADDRESS` 컬럼에 그 IP가 표시된다. (예: `192.168.252.101`)

샘플 앱 Deployment는 `replicas: 1`, `strategy: Recreate`로 설정한다.
local-path 볼륨은 RWO라서 한 노드의 한 Pod에만 붙을 수 있기 때문이다.

### 3. E2E 확인 (호스트에서)

```bash
curl http://192.168.252.101/
```

처음에는 `403 Forbidden`이 나온다. 볼륨이 비어 있어 index.html이 없기 때문이며, 경로 자체는 정상이다.

```bash
kubectl exec deploy/web -- sh -c 'echo "hello from onprem PVC" > /usr/share/nginx/html/index.html'
curl http://192.168.252.101/        # hello from onprem PVC
```

### 4. 데이터 영속성 확인

Pod를 지웠다가 새 Pod가 뜬 뒤에도 같은 응답이 오는지 확인한다.

```bash
kubectl delete pod -l app=web
kubectl wait --timeout=2m deploy/web --for=condition=Available
curl http://192.168.252.101/        # hello from onprem PVC
```

새 Pod에서도 응답이 같으면 네트워킹부터 스토리지까지 전체 경로가 정상이다.
