# Keycloak on a Local Kubernetes Cluster — DevOps Assessment

Fully automated, reproducible deployment of Keycloak onto a local
Kubernetes cluster, provisioned end-to-end with Terraform.

- **Cluster distribution:** [k3d](https://k3d.io/) (k3s running in Docker) — see [Design decisions](#design-decisions) for why this was chosen over a Rancher install, and how to swap it for Rancher Desktop/RKE2 if preferred.
- **IaC tool:** Terraform (`hashicorp/kubernetes`, `hashicorp/helm`, `hashicorp/tls`, `hashicorp/random`, `hashicorp/null` providers)
- **App deployment:** Bitnami `keycloak` Helm chart, driven from Terraform's `helm_release` resource
- **Ingress / TLS:** Traefik (bundled with k3s) + a Terraform-generated self-signed certificate, HTTPS-only
- **Hardening:** default-deny `NetworkPolicy` + explicit allow rules, non-root containers, `ClusterIP`-only services, only port 443 published externally

---

## Repository layout

```
.
├── README.md                       # this file
├── bootstrap.sh                    # installs Docker/kubectl/k3d/helm if missing
├── terraform/
│   ├── providers.tf                 # required_providers + provider config
│   ├── variables.tf                 # all tunables (cluster name, hostname, etc.)
│   ├── cluster.tf                   # provisions the k3d cluster (null_resource)
│   ├── namespace.tf                 # keycloak namespace
│   ├── tls.tf                       # self-signed cert + k8s TLS secret
│   ├── keycloak.tf                  # helm_release for Keycloak (+ bundled Postgres)
│   ├── network-policy.tf            # default-deny + explicit allow NetworkPolicies
│   ├── outputs.tf                   # URL, credentials, kubeconfig path, etc.
│   └── terraform.tfvars.example     # optional overrides
├── scripts/
│   ├── deploy.sh                    # ONE COMMAND to stand up everything
│   ├── get-credentials.sh           # prints Keycloak URL + admin login
│   └── destroy.sh                   # tears down Keycloak + the cluster
└── manifests/
    └── raw-k8s-reference/           # equivalent raw manifests, for reference only
        ├── namespace.yaml
        ├── keycloak-values.yaml
        └── network-policy.yaml
```

---

## Prerequisites

Per the assignment, the EC2 instance already has **Terraform** and **git**
installed. In addition you need:

- Docker (k3d runs k3s nodes as Docker containers)
- `kubectl`
- `k3d` (CLI that drives k3s-in-Docker)
- `helm` (used transparently by Terraform's helm provider)

Run `./bootstrap.sh` once to install anything from that list that's
missing. It is idempotent — safe to re-run.

**Assumptions:**
1. The EC2 instance has outbound internet access (to pull Docker images, the Bitnami Helm chart, and k3s itself).
2. Ports used are local to the instance — `kubectl`/browser access is assumed to happen either directly on the instance or via SSH port-forwarding / a browser on the instance itself (see [Accessing Keycloak remotely](#accessing-keycloak-remotely) if you're driving this from your own laptop instead).
3. This is a **local/assessment** environment, not a production cluster — see the [Assumptions & scope](#assumptions--scope) section for what was deliberately left out.

---

## Quick start

```bash
git clone <this-repo-url>
cd keycloak-k8s-assessment

./bootstrap.sh          # install Docker/kubectl/k3d/helm if needed
                         # (log out/in once if Docker group membership was just added)

./scripts/deploy.sh      # provisions the cluster AND deploys Keycloak
```

`deploy.sh` is fully idempotent — re-running it will not recreate the
cluster or reinstall Keycloak if they already exist/match.

When it finishes, it prints the Keycloak URL and reminds you to add a
`/etc/hosts` entry (also shown below). Get the admin login at any time
with:

```bash
./scripts/get-credentials.sh
```

To tear everything down (cluster included):

```bash
./scripts/destroy.sh
```

---

## Step-by-step (what `deploy.sh` does under the hood)

```bash
cd terraform
terraform init

# Phase 1: bring up the local k3d cluster only
terraform apply -target=null_resource.k3d_cluster -target=time_sleep.wait_for_traefik

# Phase 2: deploy Keycloak, TLS secret, network policies into that cluster
terraform apply
```

### Why a two-phase apply?

Terraform's `kubernetes` and `helm` providers need a kubeconfig file to
talk to the cluster. That kubeconfig is only written *after* the k3d
cluster is created (`cluster.tf`, via `k3d kubeconfig write`). Terraform
providers are configured once at the start of a run, so a config that both
creates a cluster **and** deploys into it with the same providers has a
classic chicken-and-egg problem. The standard, documented workaround (used
here) is to apply the cluster-creation resource first with `-target`, then
run a normal `terraform apply` for everything else. `scripts/deploy.sh`
wraps both steps so you never have to think about it.

### Adding the hostname to `/etc/hosts`

The Keycloak ingress uses the hostname `keycloak.local` (configurable via
`terraform.tfvars`). Since k3d publishes the Traefik load balancer on
`127.0.0.1:443`, add:

```bash
echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
```

Then browse to **https://keycloak.local/** — your browser will warn about
the self-signed certificate; that's expected for a local, DNS-less
cluster (accept/continue). Log in with the credentials from
`./scripts/get-credentials.sh`.

### Accessing Keycloak remotely

If you're running this on an EC2 instance but want to view the console
from your own laptop's browser, either:

- SSH tunnel: `ssh -L 443:127.0.0.1:443 <ec2-user>@<ec2-host>`, then add the `/etc/hosts` entry and browse to `https://keycloak.local/` **on your laptop**, or
- Temporarily open port 443 on the EC2 security group to your IP only, and point your local `/etc/hosts` entry at the EC2 instance's public IP instead of `127.0.0.1`.

The first option is recommended — it keeps the security group closed and
matches the "minimal network exposure" requirement.

---

## Keycloak credentials

Retrieve at any time:

```bash
./scripts/get-credentials.sh
```

which prints:

```
Keycloak URL:      https://keycloak.local:443/
Admin username:    admin
Admin password:    <randomly generated by Terraform, 20 chars>
```

The password is generated by `random_password.keycloak_admin` in
`terraform/keycloak.tf` — a new one is created per deployment rather than
a hardcoded value, and it's stored only in Terraform state and the
in-cluster `keycloak` Secret (never printed to logs or committed to git).
If you'd rather pull it directly from Kubernetes instead of Terraform
state:

```bash
kubectl --kubeconfig terraform/.kube/config -n keycloak get secret keycloak \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

> **Note on Terraform state:** for a real project, state should live in a
> remote backend (S3 + DynamoDB lock, Terraform Cloud, etc.) rather than
> locally, both for collaboration and because it contains the admin
> password in plaintext. Local state was used here to keep the assignment
> self-contained and dependency-free — see [Assumptions & scope](#assumptions--scope).

---

## Design decisions

**Cluster distribution — k3d over a Rancher install.** The brief allows
"any distribution; Rancher preferred." Rancher is a multi-cluster
*management plane* you install on top of an existing Kubernetes cluster
(or that provisions clusters via RKE/RKE2) — it isn't itself a
single-command local cluster distribution, and standing up its full
management UI adds significant resource overhead and a second layer of
auth for a single-node assessment box. k3d (k3s in Docker) is the
lightweight tool RKE/Rancher's own ecosystem uses for local dev clusters,
starts in under a minute, and is trivially scriptable from Terraform via
`local-exec`. Swapping to Rancher Desktop or a real RKE2 cluster only
requires changing `cluster.tf` — `keycloak.tf`, `tls.tf`, and
`network-policy.tf` are distribution-agnostic and would work unchanged
against any CNCF-conformant cluster.

**Helm chart via Terraform, not raw manifests.** The Bitnami Keycloak
chart already correctly wires together the Keycloak StatefulSet/Deployment,
its bundled PostgreSQL dependency, health probes, and a sane default
security context — reimplementing that by hand in raw YAML would mean
re-solving problems the chart maintainers have already solved, with more
room for subtle misconfiguration. Terraform's `helm_release` resource
still gives full IaC reproducibility (chart version pinned, all values
declared in `keycloak.tf`, diffable via `terraform plan`). Equivalent raw
manifests are included under `manifests/raw-k8s-reference/` for reference/
review purposes, but they're not what `deploy.sh` actually applies.

**TLS termination at the Ingress (Traefik), not inside the Keycloak
container.** This is the standard "edge termination" pattern in
Kubernetes and matches Keycloak's own recommended `proxy: edge` config —
Keycloak is told to trust `X-Forwarded-*` headers from Traefik rather than
managing its own certificate. The cert itself is generated by Terraform
(`tls_private_key` / `tls_self_signed_cert`) rather than hand-created,
so the whole chain — cert generation, secret creation, ingress wiring —
is reproducible from `terraform apply` alone with no manual `openssl`
step.

**Network hardening approach.** Three layers:
1. Only port 443 is published from the k3d cluster to the host (no 80, no direct NodePort to Keycloak, no exposed Kubernetes dashboard).
2. Kubernetes `NetworkPolicy`: default-deny all ingress/egress in the `keycloak` namespace, then explicit allows for: Traefik → Keycloak (port 8080 only), Keycloak → Postgres (port 5432 only), and DNS lookups.
3. Pod-level: non-root containers (`runAsNonRoot: true`, fixed UID), `allowPrivilegeEscalation: false`, and CPU/memory requests+limits set so a misbehaving pod can't starve the node.

---

## Assumptions & scope

This is deliberately scoped as a **local assessment environment**, not a
production deployment. Things intentionally left out (and what the
production equivalent would be):

| Left out here | Production equivalent |
|---|---|
| Local Terraform state file | Remote backend (S3 + DynamoDB lock, or Terraform Cloud) |
| Self-signed certificate | cert-manager + a real CA (Let's Encrypt / internal CA) |
| Single k3d server node | Multi-node, multi-AZ cluster (EKS/RKE2) with pod anti-affinity |
| Admin password in Terraform state/output | Secrets manager (Vault, AWS Secrets Manager) injected via External Secrets Operator |
| Bundled single-replica PostgreSQL | Managed/HA Postgres (RDS, or a Postgres operator with replication) |
| No image-scanning/OPA/Gatekeeper policies | Admission control (Kyverno/OPA) enforcing pod security standards cluster-wide |
| No automated backup of Postgres/Keycloak data | Scheduled `pg_dump`/volume snapshots |

None of these affect functional correctness for the assessment's stated
requirements (admin login works, HTTPS-only, minimal exposure) — they're
noted here to be explicit about scope rather than silently glossing over
them.

---

## Time spent

_(Fill in honestly before submitting — this section is intentionally left
as a placeholder since only you know how long you actually spent.)_

- Research / chart & approach selection: `__ hours`
- Terraform + scripting: `__ hours`
- Testing / debugging on the EC2 instance: `__ hours`
- README / documentation: `__ hours`
- **Total:** `__ hours`

---

## Troubleshooting

- **`k3d: command not found` after `bootstrap.sh`** — re-source your shell (`exec $SHELL`) or open a new terminal so the PATH update takes effect.
- **Docker permission denied** — you were just added to the `docker` group; run `newgrp docker` or log out/in once, then retry.
- **`terraform apply` (phase 2) fails because Traefik isn't ready yet** — re-run `./scripts/deploy.sh`; it's idempotent and `time_sleep.wait_for_traefik` in `cluster.tf` can be increased from 20s if your instance is slow.
- **Browser can't reach `keycloak.local`** — confirm the `/etc/hosts` entry (`127.0.0.1 keycloak.local`) and that you're browsing on the same machine `deploy.sh` ran on (or see [Accessing Keycloak remotely](#accessing-keycloak-remotely)).
- **Certificate warning in browser** — expected; this is a self-signed cert for a local cluster (see [Design decisions](#design-decisions)).
