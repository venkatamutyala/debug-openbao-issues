kind delete cluster --name openbao-vault || true
kind create cluster --name openbao-vault --config kind-config.yaml
kubectl cluster-info --context kind-openbao-vault

# deploy metrics server
kubectl apply -f components.yaml


kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.yaml

#wait for cert-manager webhooks to get ready
sleep 60; 

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
apiVersion: v1
kind: Namespace
metadata:
    name: openbao-vault
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault-ca-issuer
  namespace: openbao-vault
  annotations:
    argocd.argoproj.io/sync-wave: "-11"
spec:
  ca:
    secretName: vault-ca-secret
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-selfsigned-ca
  namespace: openbao-vault
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/sync-wave: "-10"
spec:
  isCA: true
  commonName: Vault CA
  secretName: vault-ca-secret
  duration: 87660h0m0s # 10 years
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: vault-certificate
  namespace: openbao-vault
  annotations:
    argocd.argoproj.io/sync-wave: "-9"
spec:
  secretName: vault-tls
  duration: 9528h0m0s
  renewBefore: 1080h0m0s
  dnsNames:
  - '*.openbao-vault.svc.cluster.local'
  - '*.vault-internal'
  - '*.vault-internal.openbao-vault.svc.cluster.local'
  - '*.openbao-vault'
  ipAddresses:
  - '127.0.0.1'
  issuerRef:
    name: vault-ca-issuer
  commonName: vault cert
EOF


sleep 10;

helm repo add openbao https://openbao.github.io/openbao-helm
helm install openbao openbao/openbao --version 0.19.1 -f openbao-values.yaml -n openbao-vault --create-namespace

