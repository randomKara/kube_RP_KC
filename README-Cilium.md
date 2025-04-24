# Intégration de Cilium comme CNI dans notre Cluster Kubernetes

## Introduction

Ce document explique l'intégration de Cilium comme Container Network Interface (CNI) dans notre cluster Kubernetes déployant une application Flask, un reverse proxy Apache pour l'authentification OIDC, et un serveur Keycloak pour la gestion des identités.

## Qu'est-ce que Cilium ?

Cilium est une solution de réseau et de sécurité open-source qui utilise eBPF (extended Berkeley Packet Filter) pour assurer une connectivité, une sécurité et une observabilité réseau pour les applications cloud-native. Contrairement aux CNI traditionnels, Cilium opère à la couche application (L7) et peut fournir une visibilité et un contrôle sur le trafic HTTP, gRPC, et Kafka.

## Avantages de Cilium

- **Politiques réseau avancées** : Contrôle précis des communications entre services
- **Observabilité** : Visibilité détaillée du trafic réseau
- **Performance** : Utilisation d'eBPF pour une performance optimale
- **Sécurité** : Protection contre les menaces réseau grâce à des politiques granulaires
- **Compatible Kubernetes** : S'intègre parfaitement avec l'écosystème Kubernetes

## Architecture de notre solution

Notre architecture comprend :
- **Application Flask** : Application web principale
- **Proxy Apache** : Déployé comme sidecar dans le même pod que Flask, gère l'authentification OIDC
- **Keycloak** : Serveur d'identité pour l'authentification et l'autorisation
- **Cilium** : Fournit la connectivité réseau entre les composants et implémente les politiques de sécurité

## Prérequis

- Minikube v1.35.0 ou ultérieur
- kubectl v1.29.0 ou ultérieur
- Interface CLI Cilium (installation automatisée via notre script)

## Installation

1. Clonez ce dépôt :
   ```bash
   git clone <repo-url>
   cd kube_manifests
   ```

2. Exécutez le script d'installation :
   ```bash
   ./cilium-setup.sh
   ```

Ce script automatise les étapes suivantes :
- Démarrage de Minikube avec les paramètres appropriés pour Cilium
- Installation de l'interface CLI Cilium
- Déploiement de Cilium dans le cluster
- Application des politiques réseau Cilium

## Politiques réseau implémentées

### 1. Politique pour l'application Flask

La politique `flask-app-policy.yaml` définit :
- Accès limité à l'application Flask uniquement depuis le proxy Apache (sidecar)
- Communication sortante limitée au service DNS nécessaire

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "flask-app-policy"
spec:
  endpointSelector:
    matchLabels:
      app: flask-app
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: flask-app  # Apache proxy dans le même pod (sidecar)
    toPorts:
    - ports:
      - port: "5000"
        protocol: TCP
  egress:
  - toEndpoints:
    - matchLabels: {}
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
      - port: "53"
        protocol: TCP
```

### 2. Politique pour Keycloak

La politique `keycloak-policy.yaml` définit :
- Accès limité au serveur Keycloak uniquement depuis le proxy Apache
- Communication sortante limitée au service DNS nécessaire

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "keycloak-policy"
spec:
  endpointSelector:
    matchLabels:
      app: keycloak
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: flask-app  # Apache proxy dans le pod flask-app
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
  egress:
  - toEndpoints:
    - matchLabels: {}
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
      - port: "53"
        protocol: TCP
```

### 3. Politique pour l'accès externe (Ingress)

La politique `ingress-policy.yaml` définit :
- Accès externe vers le proxy Apache sur le port 80
- Permet aux utilisateurs d'accéder à l'application via le navigateur

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "ingress-policy"
spec:
  endpointSelector:
    matchLabels:
      app: flask-app  # Pod où se trouve le reverse proxy Apache
  ingress:
  - fromEntities:
    - "world"
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
```

## Vérification de l'installation

Pour vérifier l'état de Cilium :
```bash
cilium status
```

Pour vérifier les politiques réseau :
```bash
kubectl get cnp
```

Pour voir les détails d'une politique spécifique :
```bash
kubectl describe cnp flask-app-policy
```

## Dépannage

### Problèmes courants

1. **Cilium ne démarre pas correctement**
   ```bash
   kubectl get pods -n kube-system -l k8s-app=cilium
   kubectl logs -n kube-system -l k8s-app=cilium
   ```

2. **Les politiques ne sont pas appliquées**
   ```bash
   kubectl get cnp -o wide
   ```

3. **Problèmes de connectivité entre les services**
   - Vérifier que les politiques autorisent le trafic nécessaire
   - Utiliser `cilium connectivity test` pour tester la connectivité

### Réinstallation

Si nécessaire, réinstallez Cilium :
```bash
cilium uninstall
./cilium-setup.sh
```

## Monitoring

Pour surveiller le trafic réseau, vous pouvez activer Hubble (interface d'observabilité de Cilium) :
```bash
cilium hubble enable
```

## Amélioration future

- Activation de Hubble pour une meilleure observabilité
- Implémentation de politiques réseau plus détaillées basées sur les URL et les méthodes HTTP
- Configuration de métriques Prometheus pour le monitoring

## Ressources

- [Documentation officielle de Cilium](https://docs.cilium.io/)
- [Guide des politiques réseau Cilium](https://docs.cilium.io/en/stable/network/kubernetes/policy/)
- [Tutoriels Cilium](https://docs.cilium.io/en/stable/tutorials/) 