# Pac-Man CI/CD Deployment on AWS EKS Auto Mode

This repository is a complete DevOps project submission for deploying the open source [font/pacman](https://github.com/font/pacman) Node.js Pac-Man application to AWS with a fully automated CI/CD pipeline.

The solution uses GitHub Actions, AWS OIDC IAM Role authentication, Amazon ECR, `eksctl`, Amazon EKS Auto Mode, Kubernetes manifests, MongoDB StatefulSet storage, EBS-backed persistent volumes, and a public Network Load Balancer.

No AWS access keys, private credentials, or secret values are stored in this repository.

## Project Overview

The project automates the full path from source code to a running Pac-Man application on Kubernetes:

- Pac-Man source code is stored under `app/`.
- GitHub Actions builds a production Docker image.
- The image is pushed to Amazon ECR.
- `eksctl` creates or updates an Amazon EKS Auto Mode cluster.
- Kubernetes manifests deploy the Pac-Man web app and MongoDB.
- MongoDB runs as a StatefulSet with persistent EBS storage.
- The Pac-Man application is exposed publicly through an AWS Network Load Balancer.
- A separate manual workflow verifies MongoDB persistence by writing and reading a test document.

## Repository Structure

```text
app/                    Pac-Man application source code
kubernetes/             Kubernetes namespace, app, service, MongoDB, and storage manifests
eksctl/                 EKS Auto Mode cluster configuration
.github/workflows/      CI/CD and MongoDB persistence verification workflows
diagrams/               Editable draw.io architecture diagram
screenshots/            Final validation screenshots
Dockerfile              Production Docker image definition
.gitignore              Local, dependency, and generated file exclusions
README.md               Final project documentation
```

## Architecture

The editable architecture diagram is available at [diagrams/architecture.drawio](diagrams/architecture.drawio).

```text
User Browser
    |
    v
AWS Network Load Balancer
    |
    v
Kubernetes Service: pacman
    |
    v
Pac-Man Deployment, 2 replicas, port 8080
    |
    v
MongoDB Service: mongo
    |
    v
MongoDB StatefulSet: mongo-0
    |
    v
PersistentVolumeClaim -> EBS gp3 volume
```

AWS and CI/CD control plane:

```text
Developer Push
    |
    v
GitHub Repository
    |
    v
GitHub Actions
    |
    v
AWS OIDC Assume Role
    |
    +--> Amazon ECR image repository
    |
    +--> eksctl creates or updates EKS Auto Mode
    |
    +--> kubectl applies Kubernetes manifests
```

## CI/CD Flow

The main workflow runs on every push to `main` and can also be started manually.

```text
Developer push
-> GitHub Actions
-> OIDC Assume Role
-> Build Docker Image
-> Push to ECR
-> Create/Update EKS Cluster
-> kubectl apply
-> rollout verification
-> application available
```

Detailed pipeline steps:

1. Checkout the repository.
2. Configure AWS credentials using GitHub OIDC and `AWS_ROLE_ARN`.
3. Install `kubectl` and `eksctl`.
4. Create or verify the ECR repository.
5. Build the Docker image from `Dockerfile`.
6. Tag the image with the Git commit SHA and `latest`.
7. Push both tags to Amazon ECR.
8. Render the `eksctl` cluster configuration from repository variables.
9. Create the EKS Auto Mode cluster if it does not exist.
10. Update the EKS Auto Mode configuration if the cluster already exists.
11. Update kubeconfig for the GitHub Actions runner.
12. Render and apply Kubernetes manifests.
13. Print Kubernetes debug information.
14. Verify rollout status for the Pac-Man Deployment and MongoDB StatefulSet.

## AWS OIDC Authentication

The workflow uses GitHub Actions OIDC instead of static AWS access keys.

Required repository variables:

| Variable | Example | Purpose |
| --- | --- | --- |
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-actions-eks-deploy` | IAM role assumed by GitHub Actions |
| `AWS_REGION` | `us-east-1` | AWS region for ECR and EKS |
| `ECR_REPOSITORY` | `pacman` | ECR repository name |
| `EKS_CLUSTER_NAME` | `pacman-auto-mode` | EKS cluster name |

The IAM role trust policy must allow this GitHub repository to call `sts:AssumeRoleWithWebIdentity`. The role also needs permissions for ECR, EKS, EC2, IAM, CloudFormation, ELB, and EBS operations required by `eksctl`, Kubernetes, and EKS Auto Mode.

## ECR Image Build and Push

The workflow creates the ECR repository when it is missing, then builds and pushes the Pac-Man image.

The Docker image is built from the repository root using the production `Dockerfile`.

Important container hardening details:

- Runs on `node:20-alpine`.
- Installs production dependencies only.
- Runs as numeric non-root UID/GID `10001:10001`.
- Keeps application port `8080`.
- Avoids string-only Docker users so Kubernetes can validate `runAsNonRoot`.

## EKS Auto Mode

The cluster is defined in [eksctl/cluster.yaml](eksctl/cluster.yaml):

```yaml
autoModeConfig:
  enabled: true
```

EKS Auto Mode is responsible for managed Kubernetes infrastructure behavior such as compute placement, load balancing integration, and block storage integration. The workflow uses `eksctl` to create the cluster on the first deployment and update Auto Mode configuration on later runs.

## Kubernetes Deployment

Kubernetes resources are stored in [kubernetes/](kubernetes/).

Pac-Man application:

- `Deployment` named `pacman`.
- Namespace `pacman`.
- Two replicas.
- Container port `8080`.
- Rolling update strategy.
- Readiness and liveness probes.
- CPU and memory requests and limits.
- Numeric non-root security context:

```yaml
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
allowPrivilegeEscalation: false
readOnlyRootFilesystem: false
```

MongoDB connection environment:

```text
MONGO_SERVICE_HOST=mongo
MONGO_DATABASE=pacman
MY_MONGO_PORT=27017
MONGO_USE_SSL=false
MONGO_VALIDATE_SSL=false
MONGO_URL=mongodb://mongo:27017/pacman
```

## MongoDB StatefulSet

MongoDB runs as a Kubernetes `StatefulSet` named `mongo` with a stable pod identity:

```text
mongo-0
```

The internal service is named `mongo`, which matches the Pac-Man application configuration. This gives the app a stable database endpoint:

```text
mongodb://mongo:27017/pacman
```

MongoDB is intentionally not exposed publicly. It is reachable only inside the Kubernetes cluster.

## Persistent Volume and EBS Storage

MongoDB persistence is implemented with `volumeClaimTemplates` in the StatefulSet. Each MongoDB pod receives persistent storage through a `PersistentVolumeClaim`.

The repository includes a `gp3` StorageClass:

```yaml
provisioner: ebs.csi.eks.amazonaws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
```

This provisions encrypted EBS-backed storage for MongoDB data.

## LoadBalancer Exposure

The Pac-Man service is exposed with a Kubernetes `LoadBalancer` service using EKS Auto Mode NLB support:

```yaml
type: LoadBalancer
loadBalancerClass: eks.amazonaws.com/nlb
```

NLB-related annotations configure:

- Internet-facing scheme.
- IP target mode.
- HTTP health check on `/`.
- Cross-zone load balancing.

After deployment, the application is available through the external DNS name shown by:

```bash
kubectl get svc pacman -n pacman
```

## MongoDB Persistence Verification

The repository includes a manual workflow named **Verify MongoDB Persistence**.

It connects to the EKS cluster, writes a document into MongoDB, then reads it back:

```bash
kubectl exec -n pacman mongo-0 -- mongosh pacman --eval 'db.testPersistence.insertOne({project:"pacman", createdAt:new Date()})'
kubectl exec -n pacman mongo-0 -- mongosh pacman --eval 'db.testPersistence.find().pretty()'
```

The insert and read output is printed directly in the GitHub Actions logs. This validates that the MongoDB pod, service, PVC, and EBS-backed storage path are working.

## Screenshots

Final validation screenshots are stored in [screenshots/](screenshots/).

| Screenshot | Evidence |
| --- | --- |
| [01-github-actions-success.png](screenshots/01-github-actions-success.png) | GitHub Actions workflow runs completing successfully |
| [02-pacman-running-browser.png](screenshots/02-pacman-running-browser.png) | Pac-Man application reachable in a browser |
| [03-ecr-repository.png](screenshots/03-ecr-repository.png) | Amazon ECR repository created for the Pac-Man image |
| [04-eks-cluster-active.png](screenshots/04-eks-cluster-active.png) | EKS cluster active in AWS console |

## Problems Solved

This project includes the implementation fixes discovered during real deployment:

- **GitHub OIDC Role connection**: the workflow authenticates to AWS using OIDC and does not use long-lived AWS access keys.
- **EKS Auto Mode cluster automation**: `eksctl` creates or updates the EKS cluster from version-controlled configuration.
- **Unsupported `eksctl --approve` flag**: removed `--approve` from `eksctl update auto-mode-config` for compatibility with `eksctl v0.227.0`.
- **Pac-Man `CreateContainerConfigError`**: debug output showed Kubernetes could not verify a string-based Docker user with `runAsNonRoot`.
- **Non-numeric Docker user**: fixed by running the image as numeric UID/GID `10001:10001`.
- **Kubernetes security context alignment**: Deployment now declares `runAsUser: 10001` and `runAsGroup: 10001`.
- **MongoDB persistence verification**: added a manual workflow that inserts and reads a MongoDB test document.

## Final Validation

The completed project validates the following:

- GitHub Actions CI/CD workflow succeeds.
- Docker image is built and pushed to Amazon ECR.
- EKS Auto Mode cluster is active.
- Kubernetes manifests apply successfully.
- Pac-Man Deployment runs with two replicas.
- Pac-Man is reachable from a browser through the LoadBalancer.
- MongoDB StatefulSet is running.
- MongoDB PVC/EBS storage is provisioned.
- Manual MongoDB persistence workflow writes and reads test data.
- LoadBalancer external DNS exists for application access.

## Troubleshooting

### OIDC Authentication Fails

Check:

- `AWS_ROLE_ARN` repository variable.
- IAM role trust policy for this repository.
- Workflow permissions include `id-token: write`.
- AWS region matches the target resources.

### EKS Cluster Creation or Update Fails

Check:

- IAM permissions for EKS, EC2, IAM, CloudFormation, ELB, ECR, and EBS.
- Selected AWS region supports EKS Auto Mode.
- `eksctl` version is compatible with the commands in the workflow.

### Pac-Man Pods Do Not Start

Use:

```bash
kubectl get pods -n pacman -o wide
kubectl describe deployment pacman -n pacman
kubectl describe pods -n pacman
kubectl logs deployment/pacman -n pacman --all-containers=true --tail=200
kubectl get events -n pacman --sort-by=.metadata.creationTimestamp
```

If `CreateContainerConfigError` mentions `runAsNonRoot` and a non-numeric user, confirm that the Dockerfile uses `USER 10001:10001` and the Deployment uses `runAsUser: 10001`.

### MongoDB PVC Is Pending

Use:

```bash
kubectl get storageclass
kubectl get pvc -n pacman
kubectl describe pvc -n pacman
```

Confirm that the `gp3` StorageClass exists and uses `ebs.csi.eks.amazonaws.com`.

### LoadBalancer DNS Is Missing

Use:

```bash
kubectl describe svc pacman -n pacman
kubectl get events -n pacman --sort-by=.metadata.creationTimestamp
```

Confirm that the service uses `loadBalancerClass: eks.amazonaws.com/nlb` and that EKS Auto Mode is enabled for the cluster.

## Cleanup

Delete Kubernetes resources:

```bash
kubectl delete -k kubernetes
```

Delete the EKS cluster and AWS-managed infrastructure:

```bash
eksctl delete cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"
```

Delete the ECR repository and images:

```bash
aws ecr delete-repository \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  --force
```

Cleanup is intentionally manual so production resources are not removed accidentally by CI/CD.
