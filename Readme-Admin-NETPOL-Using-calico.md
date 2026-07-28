# Optional Stage – Calico Cluster-wide Guardrails

> Note for future use:
> This stage demonstrates cluster-wide guardrails using Calico `GlobalNetworkPolicy`
> on Calico v3.31.3. The upstream ANP CRDs were installed earlier for learning
> purposes, but the working admin-stage lab in this environment is implemented
> with Calico-native policy resources that match the installed CNI.

This optional stage extends the lab beyond namespace-scoped `NetworkPolicy` to
cluster-wide admin guardrails using Calico `GlobalNetworkPolicy`.

It is designed for platform and security engineers and shows how to enforce
cluster-wide rules that apply across namespaces.

---

## Why Calico GlobalNetworkPolicy?

Plain Kubernetes `NetworkPolicy` is namespace-scoped. That is good for app teams,
but it is not enough for cluster-wide admin guardrails.

Calico `GlobalNetworkPolicy` is cluster-scoped and is the right mechanism in this
environment because the cluster is running Calico v3.31.3.

Calico global policy lets the platform team enforce rules that apply across the
entire cluster, without depending on namespace owners to manage them.

---

## Practical use cases

This stage includes two practical examples:

- `deny-alpha-external-egress.yaml`, which blocks external egress from `team-alpha`.
- `deny-alpha-to-beta.yaml`, which blocks traffic from `team-alpha` to `team-beta`
  on TCP 5678.

These examples show two different kinds of cluster-wide admin guardrails:

- external traffic control.
- cross-namespace traffic control.

---

## Files used

- `resources/calico-global-netpol/deny-alpha-external-egress.yaml`
- `resources/calico-global-netpol/deny-alpha-to-beta.yaml`

---

## Make targets

Use these targets from `Makefile_NetworkPolicy`:

```bash
make -f Makefile_NetworkPolicy calico-admin-apply-deny-alpha-external-egress
make -f Makefile_NetworkPolicy calico-admin-test-deny-alpha-external-egress
make -f Makefile_NetworkPolicy calico-admin-apply-deny-alpha-to-beta
make -f Makefile_NetworkPolicy calico-admin-test-deny-alpha-to-beta
make -f Makefile_NetworkPolicy calico-admin-cleanup
```

---

## Expected behavior

After the policies are applied:

- `alpha-client -> example.com` should be blocked.
- `alpha-client -> beta-server:5678` should be blocked.
- `beta-client -> beta-server:5678` should still work.

This demonstrates that the admin guardrails are cluster-wide and do not affect
unrelated traffic.

---

## Policy summary

### External egress guardrail
This policy denies outbound traffic from `team-alpha` to external destinations.

### Namespace-to-namespace guardrail
This policy denies egress from `team-alpha` to `team-beta` on TCP 5678.

Together, these policies demonstrate a practical platform-security model for
cluster-wide policy enforcement with Calico.

---

## Summary

This admin stage is separate from the namespace-scoped NetworkPolicy lab so that
each concept stays clear:

- namespace lab = default-deny and least-privilege with standard NetworkPolicy
- admin lab = cluster-wide guardrails with Calico GlobalNetworkPolicy