#!/usr/bin/env bash
set -aeuo pipefail

echo "Running setup.sh"
echo "Waiting until configuration package is installed..."
${KUBECTL} wait configuration.pkg platform-ref-lambda --for=condition=Installed --timeout 5m
echo "Waiting until configuration package is healthy..."
${KUBECTL} wait configuration.pkg platform-ref-lambda --for=condition=Healthy --timeout 5m


echo "Creating cloud credential secret..."
${KUBECTL} -n upbound-system create secret generic aws-creds --from-literal=credentials="${UPTEST_CLOUD_CREDENTIALS}" \
    --dry-run=client -o yaml | ${KUBECTL} apply -f -

#echo "Waiting until provider-aws is healthy..."
#${KUBECTL} wait provider.pkg upbound-provider-aws --for condition=Healthy --timeout 5m

echo "Waiting for all pods to come online..."
"${KUBECTL}" -n upbound-system wait --for=condition=Available deployment --all --timeout=5m

echo "Waiting for all XRDs to be established..."
kubectl wait xrd --all --for condition=Established

echo "Creating a default aws provider config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    secretRef:
      key: credentials
      name: aws-creds
      namespace: upbound-system
    source: Secret
EOF

# Uptest does not currently support checking namespaces
echo "Creating namespaces...."
kubectl create namespace team-1 --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace team-2 --dry-run=client -o yaml | kubectl apply -f -
