# Day 21 practice output — client CSR approve and issue

**Lab reference:** https://kubernetes.io/docs/tasks/tls/certificate-issue-client-csr/

## Generate key + CSR (OpenSSL — same as bare-metal days)

```bash
openssl genrsa -out ht.key 2048
openssl req -new -key ht.key -out ht.csr -subj "/CN=ht"
cat ht.csr | base64 | tr -d "\n"    # paste into csr.yaml spec.request
```

## Apply and approve

```bash
kc apply -f cert-ns.yaml
# namespace/cert-management created

kc apply -f csr.yaml --server-side
# certificatesigningrequest.certificates.k8s.io/ht serverside-applied
```

### Trap — CSR is cluster-scoped

```bash
kc get csr -n cert-manager    # -n is ignored/wrong habit from namespaced resources
kc get csr                    # correct
```

```
NAME   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
ht     kubernetes.io/kube-apiserver-client   kubernetes-admin   24h                 Pending
```

```bash
kc certificate approve ht
# certificatesigningrequest.certificates.k8s.io/ht approved

kc get csr ht
```

```
NAME   CONDITION
ht     Approved,Issued
```

## Retrieve signed cert

```bash
kc get csr ht -o jsonpath='{.status.certificate}' | base64 -d > ht.crt
openssl x509 -in ht.crt -text -noout | grep -E 'Subject:|Not After'
```

## What this proves

| Check | Result |
|-------|--------|
| OpenSSL workflow unchanged from RHEL bare metal | ✓ genrsa → req → sign |
| CSR embedded as base64 in API object | ✓ |
| Admin approve issues cert | ✓ Pending → Approved,Issued |
| Signed cert extractable from status | ✓ decode → ht.crt |
| Private key stays local | ✓ ht.key never sent to API |

## Typo caught

```bash
ubectl apply -f csr.yaml   # zsh: command not found — alias is kc/kubectl
```
