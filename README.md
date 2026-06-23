# Pac-Man on AWS EKS Auto Mode

This repository deploys the open source [font/pacman](https://github.com/font/pacman) Node.js Pac-Man application to Amazon EKS Auto Mode with a complete GitHub Actions CI/CD pipeline.

The repository is prepared for AWS OIDC IAM Role authentication. It does not contain AWS access keys, secret values, or commands that create AWS resources outside the GitHub Actions workflow.

## Repository Layout

```text
app/                    Pac-Man application source code
kubernetes/             Production-ready Kubernetes manifests
eksctl/                 EKS Auto Mode cluster configuration
.github/workflows/      GitHub Actions CI/CD workflow
diagrams/               Architecture diagram in draw.io format
screenshots/            Placeholder for deployment evidence
Dockerfile              Production container image build
.gitignore              Local and generated file exclusions
```

## Architecture

```text
Developer push
  -> GitHub Actions
  -> AWS OIDC IAM Role
  -> Amazon ECR image repository
  -> eksctl creates or updates EKS Auto Mode
  -> kubectl deploys Pac-Man and MongoDB
  -> EKS Auto Mode provisions compute, EBS storage, and NLB
  -> Users access Pac-Man through the Network Load Balancer
```

See [diagrams/architecture.drawio](diagrams/architecture.drawio) for the editable draw.io architecture diagram.

## Components

- **Amazon EKS Auto Mode** manages compute, load balancing, and block storage for the cluster.
- **eksctl** creates or updates the EKS cluster using `eksctl/cluster.yaml`.
- **GitHub Actions** builds, pushes, and deploys the application automatically.
- **Amazon ECR** stores the Pac-Man Docker image.
- **Pac-Man Deployment** runs two web replicas with rolling updates, probes, resource requests, and limits.
- **Pac-Man LoadBalancer Service** is NLB-ready with `loadBalancerClass: eks.amazonaws.com/nlb`.
- **MongoDB StatefulSet** stores game data on persistent EBS-backed volumes through `volumeClaimTemplates`.
- **gp3 StorageClass** uses the EKS Auto Mode EBS provisioner `ebs.csi.eks.amazonaws.com`.
- **MongoDB Service** is named `mongo`, matching the application environment configuration.

## Required GitHub Repository Variables

Configure these values in GitHub under **Settings -> Secrets and variables -> Actions -> Variables** before running the workflow:

| Variable | Example | Description |
| --- | --- | --- |
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-actions-eks-deploy` | IAM role assumed by GitHub Actions through OIDC |
| `AWS_REGION` | `us-east-1` | AWS region for ECR and EKS |
| `ECR_REPOSITORY` | `pacman` | ECR repository name |
| `EKS_CLUSTER_NAME` | `pacman-auto-mode` | EKS cluster name |

The workflow includes placeholder defaults so the repository structure is complete, but real AWS values must be configured before deployment.

## AWS OIDC IAM Role Preparation

Create an IAM OIDC provider for GitHub Actions and an IAM role trusted by this repository. The role should allow the workflow to:

- Call `sts:AssumeRoleWithWebIdentity`.
- Create, describe, and update EKS clusters through `eksctl`.
- Create and manage ECR repositories and images.
- Read caller identity and update kubeconfig.
- Create Kubernetes resources through the EKS cluster access granted to the role.
- Allow CloudFormation, IAM, EC2, EKS, ECR, ELB, and EBS operations required by `eksctl` and EKS Auto Mode.

Use least privilege for production. Start with an admin-scoped bootstrap role only if your organization permits it, then reduce permissions after the first successful deployment.

## CI/CD Flow

On every push to `main`, or manual workflow dispatch:

1. GitHub Actions checks out the repository.
2. The workflow assumes `AWS_ROLE_ARN` using GitHub OIDC.
3. `kubectl` and `eksctl` are installed on the runner.
4. The ECR repository is created if it does not already exist.
5. Docker builds the Pac-Man image from `Dockerfile`.
6. The image is tagged with the Git commit SHA and `latest`.
7. Both tags are pushed to Amazon ECR.
8. `eksctl` creates the EKS Auto Mode cluster if missing, or updates Auto Mode config if it exists.
9. The workflow updates kubeconfig for the cluster.
10. Kubernetes manifests are rendered with the new image URI and applied.
11. The workflow waits for the Pac-Man Deployment and MongoDB StatefulSet rollouts.

## Kubernetes Manifests

The manifests live in `kubernetes/` and are applied through `kustomization.yaml`.

EKS Auto Mode includes AWS-managed storage capability, but it does not create a StorageClass automatically. This repository includes `kubernetes/storageclass.yaml`, which defines encrypted `gp3` EBS volumes through `ebs.csi.eks.amazonaws.com`.

MongoDB environment variables used by the Pac-Man Deployment:

```text
MONGO_SERVICE_HOST=mongo
MONGO_DATABASE=pacman
MY_MONGO_PORT=27017
MONGO_USE_SSL=false
MONGO_VALIDATE_SSL=false
MONGO_URL=mongodb://mongo:27017/pacman
```

The Pac-Man Service is configured as:

- `type: LoadBalancer`
- `loadBalancerClass: eks.amazonaws.com/nlb`
- Internet-facing NLB scheme
- IP target mode
- HTTP health checks on `/`
- Cross-zone load balancing enabled

## Local Validation

You can validate file structure without creating AWS resources:

```bash
git status
docker build -t pacman-local .
kubectl kustomize kubernetes
```

Do not run the GitHub Actions workflow until the AWS OIDC role and repository variables are configured.

## Deployment

1. Create or choose an AWS account and region.
2. Configure GitHub OIDC for the repository.
3. Create the IAM role and set `AWS_ROLE_ARN`.
4. Set `AWS_REGION`, `ECR_REPOSITORY`, and `EKS_CLUSTER_NAME` repository variables.
5. Push to `main` or run the workflow manually.
6. After rollout, get the application URL:

```bash
kubectl get svc pacman -n pacman
```

Open the `EXTERNAL-IP` or DNS hostname once the NLB finishes provisioning.

## Troubleshooting

### OIDC authentication fails

Check that `AWS_ROLE_ARN` is correct, the role trust policy includes this repository, and workflow permissions include `id-token: write`.

### EKS cluster creation fails

Confirm the role has permissions for EKS, CloudFormation, EC2, IAM, EBS, and ELB operations. Also verify that the selected region supports EKS Auto Mode.

### Pods are pending

Check Auto Mode node provisioning and pod events:

```bash
kubectl describe pod -n pacman -l app.kubernetes.io/name=pacman
kubectl get events -n pacman --sort-by=.lastTimestamp
```

### MongoDB PVC is pending

Verify EKS Auto Mode storage is enabled and the `gp3` StorageClass exists:

```bash
kubectl get storageclass
kubectl describe pvc -n pacman
```

### NLB does not appear

Confirm the service has `loadBalancerClass: eks.amazonaws.com/nlb` and that the cluster subnets are tagged for EKS Auto Mode. Clusters created with `eksctl` normally receive the required tags.

## Cleanup

To remove Kubernetes workloads:

```bash
kubectl delete -k kubernetes
```

To delete the EKS cluster and managed infrastructure:

```bash
eksctl delete cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"
```

To delete the ECR repository and images:

```bash
aws ecr delete-repository \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  --force
```

Cleanup commands intentionally require explicit local AWS authentication and are not run by this repository.
