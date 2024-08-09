# OpenCTI Helm Chart

[OpenCTI](https://opencti.io) is an open source platform allowing organizations to manage their cyber threat intelligence knowledge and observables. It has been created in order to structure, store, organize and visualize technical and non-technical information about cyber threats.

## Usage

Charts are available in:

* [Chart Repository](https://helm.sh/docs/topics/chart_repository/)
* [OCI Artifacts](https://helm.sh/docs/topics/registries/)

### Chart Repository

#### Add repository

```console
helm repo add opencti https://devops-ia.github.io/helm-opencti
helm repo update
```

#### Install Helm chart

```console
helm install [RELEASE_NAME] opencti/opencti
```

This install all the Kubernetes components associated with the chart and creates the release.

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

### OCI Registry

Charts are also available in OCI format. The list of available charts can be found [here](https://github.com/devops-ia/helm-opencti/pkgs/container/helm-opencti%2Fopencti).

#### Install Helm chart

```console
helm install [RELEASE_NAME] oci://ghcr.io/devops-ia/helm-opencti/opencti --version=[version]
```

## OpenCTI chart

Can be found in [opencti chart](charts/opencti).
