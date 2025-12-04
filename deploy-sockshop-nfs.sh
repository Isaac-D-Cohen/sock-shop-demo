#!/usr/bin/env bash
set -e

echo ">>> Creating host storage directories..."
sudo mkdir -p /data/kind/nfs
sudo chmod 777 /data/kind/nfs

echo ">>> Deleting old cluster (if exists)..."
kind delete cluster || true

sudo rm -rf /data/kind/nfs

echo ">>> Creating kind cluster from your config..."
kind create cluster --config kind-config.yaml

echo ">>> Labeling worker nodes to match OpenShift-style selectors..."
# Wait until nodes are registered
sleep 5

# Label only workers, not control-plane
kubectl get nodes --no-headers | awk '/worker/ {print $1}' | while read NODE; do
  echo "Labeling node: $NODE"
  kubectl label node "$NODE" node-role.kubernetes.io/worker="" --overwrite
done

echo ">>> Installing local-path-provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

echo ">>> Setting local-path as the default StorageClass..."
kubectl get storageclass -o name | while read sc; do
  kubectl annotate "$sc" storageclass.kubernetes.io/is-default-class- --overwrite || true
done

kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true --overwrite

echo ">>> Deploying Sock-Shop..."
kubectl apply -k sock-shop-demo/manifests/overlays/single

echo ">>> Waiting for pods to become Ready..."
kubectl wait --for=condition=Ready pods --all --timeout=300s || true

echo
echo "================================"
echo " Sock-Shop Deployment Completed! "
echo "================================"
kubectl get pods
