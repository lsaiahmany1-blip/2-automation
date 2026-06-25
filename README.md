# Pac-Man CI/CD on AWS EKS Auto Mode

End-to-end DevOps portfolio project for deploying the open source [font/pacman](https://github.com/font/pacman) Node.js application to AWS with GitHub Actions, OIDC authentication, Amazon ECR, EKS Auto Mode, Kubernetes manifests, and persistent MongoDB storage.

The goal of this project is to demonstrate a junior DevOps workflow from source code to a validated Kubernetes deployment, without storing long-lived AWS keys or private credentials in the repository.

## Highlights

- Automated build, push, cluster provisioning, deployment, and rollout validation through GitHub Actions.
- Uses GitHub Actions OIDC to assume an AWS IAM role instead of storing AWS access keys.
- Builds a production Docker image on `node:20-alpine`.
- Pushes immutable commit SHA tags and a `latest` tag to Amazon ECR.
- Creates or updates an Amazon EKS Auto Mode cluster with `eksctl`.
- Deploys Pac-Man and MongoDB with Kubernetes manifests and Kustomize.
- Uses encrypted EBS-backed `gp3` storage for MongoDB persistence.
- Verifies MongoDB persistence through a separate manual workflow.
- Runs the application container as numeric non-root UID/GID `10001:10001`.

## Technologies Used

| Area | Tools |
| --- | --- |
| Cloud | AWS, Amazon EKS Auto Mode, Amazon ECR, IAM OIDC, EBS, Network Load Balancer |
| CI/CD | GitHub Actions, workflow variables, OIDC role assumption |
| Containers | Docker, Amazon ECR |
| Kubernetes | Deployments, Services, StatefulSets, PVCs, StorageClasses, probes, security contexts, Kustomize |
| CLI tooling | `aws`, `eksctl`, `kubectl` |
| Application | Node.js, Express, MongoDB |

## Architecture

The editable architecture diagram is available at [diagrams/architecture.drawio](diagrams/architecture.drawio).

```text
Developer push
  |
  v
GitHub Actions
  |
  +--> Assume AWS role through OIDC
  |
  +--> Build Docker image
  |
  +--> Push image to Amazon ECR
  |
  +--> Create or update EKS Auto Mode cluster
  |
  +--> Apply Kubernetes manifests
  |
  v
Amazon EKS Auto Mode
  |
  +--> Pac-Man Deployment, 2 replicas, port 8080
  |
  +--> MongoDB StatefulSet, internal service, EBS-backed PVC
  |
  v
AWS Network Load Balancer
  |
  v
User Browser
```

## Repository Structure

```text
app/                    Pac-Man application source code
kubernetes/             Kubernetes namespace, app, service, MongoDB, and storage manifests
eksctl/                 EKS Auto Mode cluster configuration
.github/workflows/      CI/CD and MongoDB persistence verification workflows
diagrams/               Editable draw.io architecture diagram
screenshots/            Redacted validation evidence
Dockerfile              Production Docker image definition
.gitignore              Local, dependency, and generated file exclusions
README.md               Portfolio documentation
```

## CI/CD Flow

The main workflow runs on pushes to `main` and can also be started manually.

1. Checkout repository code.
2. Configure AWS credentials using GitHub OIDC and the `AWS_ROLE_ARN` repository variable.
3. Install `kubectl` and `eksctl`.
4. Create or verify the ECR repository.
5. Build the production Docker image.
6. Tag the image with the Git commit SHA and `latest`.
7. Push both tags to Amazon ECR.
8. Render the `eksctl` cluster configuration from repository variables.
9. Create the EKS Auto Mode cluster if it does not exist.
10. Update the EKS Auto Mode configuration if the cluster already exists.
11. Update kubeconfig for the GitHub Actions runner.
12. Render and apply Kubernetes manifests.
13. Print Kubernetes debug information.
14. Verify rollout status for the Pac-Man Deployment and MongoDB StatefulSet.

## Required GitHub Configuration

The workflow expects GitHub repository variables, not committed credentials.

| Variable | Example | Purpose |
| --- | --- | --- |
| `AWS_ROLE_ARN` | `arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ROLE_NAME>` | IAM role assumed by GitHub Actions through OIDC |
| `AWS_REGION` | `us-east-1` | AWS region for ECR and EKS |
| `ECR_REPOSITORY` | `pacman` | ECR repository name |
| `EKS_CLUSTER_NAME` | `pacman-auto-mode` | EKS cluster name |

The IAM role trust policy must allow this repository and branch to call `sts:AssumeRoleWithWebIdentity`. The role needs the permissions required for ECR, EKS, EC2, IAM, CloudFormation, ELB, and EBS operations used by `eksctl`, Kubernetes, and EKS Auto Mode.

## Container Build

The production `Dockerfile` uses a multi-stage build:

- Installs production dependencies only.
- Runs on `node:20-alpine`.
- Uses application port `8080`.
- Runs as numeric non-root UID/GID `10001:10001`.
- Avoids a string-only Docker user so Kubernetes can validate `runAsNonRoot`.

## Kubernetes Deployment

Kubernetes resources are stored in [kubernetes/](kubernetes/).

Pac-Man application:

- Deployment named `pacman`.
- Namespace `pacman`.
- Two replicas.
- Rolling update strategy.
- Readiness and liveness probes.
- CPU and memory requests and limits.
- Security context with `runAsNonRoot`, numeric UID/GID, disabled privilege escalation, and dropped Linux capabilities.

MongoDB:

- StatefulSet named `mongo`.
- Internal service named `mongo`.
- Not exposed publicly.
- EBS-backed persistent storage through a `gp3` StorageClass and `volumeClaimTemplates`.

## MongoDB Persistence Verification

The manual workflow **Verify MongoDB Persistence** connects to the EKS cluster, writes a test document into MongoDB, and reads it back from the StatefulSet Pod. This validates:

- MongoDB Pod health
- Internal MongoDB service routing
- PVC provisioning
- EBS-backed storage path
- Application database availability

## Validation Evidence

Redacted screenshots are stored in [screenshots/](screenshots/).

| Screenshot | Evidence |
| --- | --- |
| [01-github-actions-success.png](screenshots/01-github-actions-success.png) | GitHub Actions workflow runs completed successfully |
| [02-pacman-running-browser.png](screenshots/02-pacman-running-browser.png) | Pac-Man application reachable through the LoadBalancer with endpoint redacted |
| [03-ecr-repository.png](screenshots/03-ecr-repository.png) | Amazon ECR repository exists with account-specific values redacted |
| [04-eks-cluster-active.png](screenshots/04-eks-cluster-active.png) | EKS cluster active in AWS Console with account-specific values redacted |

## Problems Solved

- Replaced static AWS keys with GitHub OIDC role authentication.
- Automated ECR repository creation and Docker image publishing.
- Automated EKS Auto Mode cluster creation/update through `eksctl`.
- Fixed an `eksctl` command compatibility issue by removing an unsupported update flag.
- Added Kubernetes debug output to make failed rollouts easier to diagnose.
- Fixed `runAsNonRoot` validation by using a numeric non-root container user.
- Added a manual MongoDB persistence verification workflow.

## Troubleshooting

### OIDC Authentication Fails

Check:

- `AWS_ROLE_ARN` repository variable is set.
- IAM trust policy matches the repository and branch.
- Workflow permissions include `id-token: write`.
- AWS region matches the target resources.

### EKS Cluster Creation or Update Fails

Check:

- IAM permissions for EKS, EC2, IAM, CloudFormation, ELB, ECR, and EBS.
- Selected AWS region supports EKS Auto Mode.
- `eksctl` version supports the workflow commands.

### Pac-Man Pods Do Not Start

Use:

```bash
kubectl get pods -n pacman -o wide
kubectl describe deployment pacman -n pacman
kubectl describe pods -n pacman
kubectl logs deployment/pacman -n pacman --all-containers=true --tail=200
kubectl get events -n pacman --sort-by=.metadata.creationTimestamp
```

If Kubernetes reports a `runAsNonRoot` problem, confirm the Dockerfile uses `USER 10001:10001` and the Deployment sets `runAsUser: 10001`.

### MongoDB PVC Is Pending

Use:

```bash
kubectl get storageclass
kubectl get pvc -n pacman
kubectl describe pvc -n pacman
```

Confirm the `gp3` StorageClass uses the EKS Auto Mode EBS provisioner:

```text
ebs.csi.eks.amazonaws.com
```

### LoadBalancer DNS Is Missing

Use:

```bash
kubectl describe svc pacman -n pacman
kubectl get events -n pacman --sort-by=.metadata.creationTimestamp
```

Confirm the service uses `loadBalancerClass: eks.amazonaws.com/nlb` and the cluster has EKS Auto Mode load balancing enabled.

## Cleanup

Cleanup is intentionally manual so CI/CD does not accidentally remove infrastructure.

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

## Security Notes

- No AWS access keys, GitHub tokens, kubeconfig files, private keys, `.env` files, or Terraform state files are intentionally stored in this repository.
- GitHub Actions uses OIDC instead of long-lived AWS credentials.
- Screenshots are redacted before public sharing.
- Public documentation uses placeholders for AWS account IDs, IAM role names, ECR registry URLs, public endpoints, local usernames, hostnames, and local paths.
