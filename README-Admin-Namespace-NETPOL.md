# Namespace-scoped NetworkPolicy Lab

This lab demonstrates how to use standard Kubernetes `NetworkPolicy` to implement:

- Default-deny for ingress and egress.
- Least-privilege traffic between application pods.
- DNS egress where required.
- External egress with `ipBlock`.

The focus of this lab is namespace-level security inside:

- `team-alpha`
- `team-beta`

These policies are managed as regular Kubernetes `NetworkPolicy` objects and can be applied by namespace owners or platform teams depending on RBAC. [237][69]

---

## What this lab covers

### 1. Baseline connectivity

Start with namespaces and pods only, no policies. Verify that traffic is allowed by default.

### 2. Default-deny

Apply namespace-level default-deny policies for ingress and egress.

### 3. Least privilege

Allow only the required flows, such as:

- `alpha-client -> alpha-server`
- `myapp -> postgres`
- DNS egress
- external payment API egress using `ipBlock`

### 4. Validation

Use the Makefile playbook to test each stage step by step.

---

## Files used in this lab

- `resources/namespace/team-namespaces.yaml`
- `resources/pod/team-alpha/...`
- `resources/pod/team-beta/...`
- `resources/netpol/...`

---

## Main Make targets

Run the guided playbook:

```bash
make run-networkpolicy-default-deny-playbook
```

Run the myapp-specific lab:

```bash
make run-myapp-least-privilege-playbook
```

---

## Why this lab is separate

This README is intentionally limited to namespace-scoped `NetworkPolicy`.

Cluster-wide admin controls such as `AdminNetworkPolicy` and `BaselineAdminNetworkPolicy`
are documented separately in [README-Admin-NETPOL.md](README-Admin-NETPOL.md). [285][69]

---

## Future note

For cluster-wide guardrails, use the admin-stage lab instead of extending this namespace lab.
The admin lab is separate because its CRDs and schema are different, and the policy model is controlled at the cluster level rather than by namespace owners.