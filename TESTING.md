# Testing OpenCTI Helm Chart

This document provides guidelines for testing the OpenCTI Helm chart. Follow these instructions to ensure the chart works as expected before deployment to production.

## Steps

### 1. Lint Testing

```bash
# Run helm lint to check for any syntax issues
helm lint charts/opencti
```

### 2. Template Testing

```bash
# Generate and verify the template output
helm template opencti charts/opencti --debug
```

### 3. Local installation testing

```bash
# Install the chart in a test namespace
kubectl create namespace opencti-test
helm install opencti-test charts/opencti --namespace opencti-test
```

### 4. Verification steps

1. Check all pods are running:

```bash
kubectl get pods -n opencti-test
```

2. Verify services are exposed:

```bash
kubectl get svc -n opencti-test
```

3. Check platform accessibility:

```bash
kubectl port-forward svc/opencti-test 8080:8080 -n opencti-test
```

4. Validate component health:

- OpenCTI platform UI accessibility
- ElasticSearch connection
- RabbitMQ status
- MinIO/S3 connectivity
- Redis cluster status

### 5. Functional testing

1. **Platform Login**
   - Verify default admin credentials work
   - Test SSO if configured

2. **Data Operations**
   - Create a test entity
   - Import a sample STIX bundle
   - Verify connectors are working

3. **Integration Testing**
   - Test configured connectors
   - Verify data ingestion
   - Check export functionality

### 6. Upgrade testing

```bash
# Test upgrade from previous version
helm upgrade opencti-test charts/opencti --namespace opencti-test
```

### 7. Clean-up

```bash
# Remove test deployment
helm uninstall opencti-test --namespace opencti-test
kubectl delete namespace opencti-test
```

## Automated testing

For CI/CD pipelines, you can use the following tools:

1. [Chart Testing](https://github.com/helm/chart-testing)
2. [Helm Unit Tests](https://github.com/helm-unittest/helm-unittest)

Example CI test command:

```bash
ct lint-and-install --config ct.yaml
```
