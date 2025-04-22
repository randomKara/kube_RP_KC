#!/bin/bash
set -e

echo "Building Flask application image..."
cd application
docker build -t flask-app:latest .
cd ..

echo "Building Apache proxy image..."
cd reverse-proxy
docker build -t apache-proxy:latest .
cd ..

echo "All images built successfully!"
echo "You can now deploy the Kubernetes manifests with:"
echo "kubectl apply -k ." 