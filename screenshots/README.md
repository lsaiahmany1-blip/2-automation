# Screenshots

This folder contains redacted validation screenshots for the Pac-Man EKS Auto Mode CI/CD project. Public evidence should prove the deployment worked without exposing AWS account IDs, IAM principals, ECR registry URLs, LoadBalancer hostnames, local usernames, hostnames, or local filesystem paths.

| Screenshot | Evidence |
| --- | --- |
| `01-github-actions-success.png` | GitHub Actions workflows completed successfully after deployment and validation fixes. |
| `02-pacman-running-browser.png` | Pac-Man application was reachable through the Kubernetes LoadBalancer, with endpoint details redacted. |
| `03-ecr-repository.png` | Amazon ECR repository `pacman` existed and was ready for image pushes, with account-specific values redacted. |
| `04-eks-cluster-active.png` | EKS cluster `pacman-auto-mode` was active, with account-specific console details redacted. |

Useful future evidence to add:

- MongoDB persistence workflow success logs with sensitive values redacted.
- `kubectl get pods,svc,pvc -n pacman -o wide` output with public endpoints redacted.
- ECR image scan results or GitHub Actions artifact summary.
