# Testing Gateway API

End-to-end guide for validating the `gateway` values on a local Kubernetes cluster using [Envoy Gateway](https://gateway.envoyproxy.io/) as the controller.

With `gateway.create: true`, the chart manages both the `Gateway` and `HTTPRoute` resources. The only external prerequisite is a `GatewayClass`.

## Prerequisites

- [OrbStack](https://orbstack.dev/) with Kubernetes enabled (`orbctl use kubernetes`)
- `kubectl` pointing at the OrbStack cluster (`kubectl config use-context orbstack`)
- `helm` >= 3.x
- `curl`

Verify the cluster is reachable:

```bash
kubectl cluster-info
```

## Step 1 - Install Gateway API CRDs

Gateway API is not bundled with Kubernetes. Install the standard CRDs first:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

Verify:

```bash
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
```

Expected output shows both CRDs with `ESTABLISHED` status.

## Step 2 - Install Envoy Gateway

Envoy Gateway is the reference implementation for the Gateway API project.

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.2.1 \
  --namespace envoy-gateway-system \
  --create-namespace
```

Wait for the controller to be ready:

```bash
kubectl rollout status deployment/envoy-gateway -n envoy-gateway-system
```

## Step 3 - Create GatewayClass

The `GatewayClass` registers Envoy as the controller. Create the namespace and apply:

```bash
kubectl create namespace opencti

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```

> The `Gateway` resource itself is created by the chart (via `gateway.create: true`). You don't need to apply it manually.

## Step 4 - Deploy OpenCTI

```bash
helm install opencti ./charts/opencti \
  --namespace opencti \
  --values charts/opencti/docs/examples/values-gateway-test.yaml \
  --timeout 10m \
  --wait
```

The chart creates three resources for Gateway API:

- `Gateway/opencti-gw-test-gateway` - the entry point (port 80)
- `HTTPRoute/opencti-gw-test` - routes traffic to the OpenCTI server service
- `Service/opencti-gw-test-server` - the ClusterIP backend

> The `readyChecker` waits for OpenSearch, MinIO, RabbitMQ, and Redis before starting the server. First install takes 3–5 minutes while images are pulled.

Wait for the Gateway to get an address (OrbStack assigns a local IP to the LoadBalancer):

```bash
kubectl get gateway opencti-gw-test-gateway -n opencti --watch
```

The `ADDRESS` column will populate once Envoy Gateway provisions the LoadBalancer. This usually takes 30–60 seconds.

## Step 5 - Verify

### Gateway is programmed

```bash
kubectl get gateway opencti-gw-test-gateway -n opencti \
  -o jsonpath='{.status.conditions}' | jq '.[] | select(.type=="Programmed")'
```

The `status` field should be `"True"`.

### HTTPRoute is accepted

```bash
kubectl get httproute opencti-gw-test -n opencti \
  -o jsonpath='{.status.parents}' | jq '.[].conditions[] | select(.type=="Accepted")'
```

The `status` field should be `"True"` and `reason` should be `"Accepted"`.

### Envoy proxy pod is running

```bash
kubectl get pods -n envoy-gateway-system
kubectl get pods -n opencti -l gateway.envoyproxy.io/owning-gateway-name=opencti-gw-test-gateway
```

### All OpenCTI pods are ready

```bash
kubectl get pods -n opencti
```

## Step 6 - Access OpenCTI

Get the Gateway's external IP (assigned by OrbStack):

```bash
GW_IP=$(kubectl get gateway opencti-gw-test-gateway -n opencti \
  -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: $GW_IP"
```

### Option A - curl with Host header (no DNS change needed)

```bash
curl -s -o /dev/null -w "%{http_code}" \
  -H "Host: opencti.local" \
  http://$GW_IP/
```

Expected: `200` or `301`.

Test the health endpoint:

```bash
curl -s -H "Host: opencti.local" http://$GW_IP/health | jq .
```

### Option B - add to /etc/hosts (access via browser)

```bash
echo "$GW_IP opencti.local" | sudo tee -a /etc/hosts
```

Open [http://opencti.local](http://opencti.local) in a browser.

Login with:

- **Email**: `admin@opencti.io`
- **Password**: `changeme`

## Troubleshooting

### HTTPRoute not accepted

```bash
kubectl describe httproute opencti-gw-test -n opencti
```

Common causes:

- `gateway.className` in values doesn't match the `GatewayClass` name
- GatewayClass not created (Step 3 skipped)
- Gateway API CRDs not installed (Step 1 skipped)

### Gateway has no address

```bash
kubectl describe gateway opencti-gw-test-gateway -n opencti
kubectl logs -n envoy-gateway-system deploy/envoy-gateway
```

OrbStack must have Kubernetes running with LoadBalancer support. Verify with `orb status`.

### OpenCTI pod stuck in Init

```bash
kubectl logs -n opencti -l app.kubernetes.io/name=opencti -c ready-checker
```

One of the dependencies (OpenSearch, MinIO, RabbitMQ, Redis) hasn't started yet. Check:

```bash
kubectl get pods -n opencti
```

## Cleanup

```bash
helm uninstall opencti -n opencti
kubectl delete namespace opencti
helm uninstall eg -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system
kubectl delete gatewayclass envoy
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

Remove the `/etc/hosts` entry if you added one:

```bash
sudo sed -i '' '/opencti.local/d' /etc/hosts
```
