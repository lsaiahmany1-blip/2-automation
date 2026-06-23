# Screenshots

This folder contains final validation screenshots for the Pac-Man EKS Auto Mode CI/CD project.

| Screenshot name | What it proves | Where it was taken from |
| --- | --- | --- |
| `01-github-actions-success.png` | GitHub Actions workflow runs completed successfully after the deployment fixes. | GitHub repository, Actions tab |
| `02-pacman-running-browser.png` | The Pac-Man application is reachable in a browser through the Kubernetes LoadBalancer. | Browser opened to the Pac-Man application URL |
| `03-ecr-repository.png` | Amazon ECR repository `pacman` exists and is ready to store pushed Docker images. | AWS Console, Amazon ECR private repositories |
| `04-eks-cluster-active.png` | EKS cluster `pacman-auto-mode` is active. | AWS Console, Amazon EKS clusters |

Additional useful screenshots for future evidence:

- MongoDB persistence workflow success logs.
- `kubectl get pods,svc,pvc -n pacman -o wide` output.
- LoadBalancer external DNS record from the Pac-Man Service.
