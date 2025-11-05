#!/bin/bash
# manage-secrets.sh: Creates or deletes 200 ExternalSecrets based on a flag.

# --- Configuration ---
LABEL="app=bulk-secret"
SECRET_COUNT=400
# --- End Configuration ---

# Function to create secrets
create_secrets() {
  echo "Creating ${SECRET_COUNT} ExternalSecrets with label '${LABEL}'..."
  
  for i in $(seq 1 ${SECRET_COUNT}); do
    cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: fetchedsecret${i}
  labels:
    app: bulk-secret # <-- Label for easy bulk deletion
spec:
  dataFrom:
    - extract:
        key: secret/foo${i}
  refreshInterval: 2s
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-backend
  target:
    name: fetchedsecret${i}
    template:
      type: Opaque
EOF
  done
  
  echo "Done creating ${SECRET_COUNT} ExternalSecrets."
}

# Function to delete secrets using the label (fastest way)
delete_secrets() {
  echo "Deleting all ExternalSecrets with label '${LABEL}'..."
  kubectl delete externalsecret -l ${LABEL} --ignore-not-found=true
  echo "Done deleting ExternalSecrets."
}

# Function to show usage
usage() {
  echo "Usage: $0 [create|delete]"
  echo "  create: Creates ${SECRET_COUNT} ExternalSecret resources."
  echo "  delete: Deletes all ExternalSecret resources with the '${LABEL}' label."
  exit 1
}

# --- Main Script Logic ---
# Check the first argument ($1)
case "$1" in
  create)
    create_secrets
    ;;
  delete)
    delete_secrets
    ;;
  *)
    # If no flag or an invalid flag is given, show usage
    usage
    ;;
esac