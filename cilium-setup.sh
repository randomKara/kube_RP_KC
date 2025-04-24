#!/bin/bash

# Script d'installation de Cilium sur Minikube
# Script adapté pour une utilisation avec le projet Flask/Apache-OIDC/Keycloak

echo "===== Installation de Cilium sur Minikube ====="

# Vérification si Minikube est en cours d'exécution
if minikube status | grep -q "kubelet: Stopped"; then
  echo "Démarrage de Minikube avec les paramètres nécessaires pour Cilium..."
  minikube start --network-plugin=cni --cni=false
else
  echo "Minikube est déjà en cours d'exécution."
fi

# Vérification de l'installation de l'outil cilium CLI
if ! command -v cilium &> /dev/null; then
  echo "Installation de l'outil CLI Cilium..."
  curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
  tar -xzvf cilium-linux-amd64.tar.gz
  chmod +x cilium
  sudo mv cilium /usr/local/bin/
  rm -f cilium-linux-amd64.tar.gz
else
  echo "L'outil CLI Cilium est déjà installé."
fi

# Installation de Cilium sur le cluster
echo "Installation de Cilium..."
cilium install

# Attente que Cilium soit prêt
echo "Attente que Cilium soit prêt..."
cilium status --wait

# Application des politiques réseau Cilium
echo "Application des politiques réseau Cilium..."
kubectl apply -f cilium-policies/

echo "===== Installation de Cilium terminée ====="
echo "Vous pouvez vérifier l'état de Cilium avec la commande : cilium status" 