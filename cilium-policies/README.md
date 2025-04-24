# Utilisation de Cilium dans le projet

Ce document explique l'intégration de Cilium comme CNI (Container Network Interface) dans notre projet Kubernetes.

## Vue d'ensemble

Cilium est une solution CNI open-source qui fournit une connectivité, sécurité, et observabilité réseau pour les applications conteneurisées. Cilium utilise eBPF (extended Berkeley Packet Filter) pour sa mise en œuvre, ce qui lui permet d'offrir des fonctionnalités avancées tout en étant performant.

## Prérequis

- Minikube v1.35.0 ou ultérieur
- kubectl v1.29.0 ou ultérieur
- Interface CLI Cilium

## Installation

Pour installer Cilium dans votre environnement Minikube, exécutez le script d'installation :

```bash
./cilium-setup.sh
```

Ce script :
1. Vérifie si Minikube est en cours d'exécution et le démarre si nécessaire
2. Installe l'interface CLI Cilium si elle n'est pas déjà installée
3. Installe Cilium dans le cluster Kubernetes
4. Applique les politiques réseau Cilium définies dans le répertoire `cilium-policies/`

## Politiques réseau

Nous avons défini trois politiques réseau pour sécuriser l'application :

1. **flask-app-policy.yaml** : Limite l'accès à l'application Flask uniquement depuis le proxy Apache (sidecar)
2. **keycloak-policy.yaml** : Contrôle l'accès au serveur Keycloak, autorisant uniquement le trafic depuis le proxy Apache
3. **ingress-policy.yaml** : Autorise l'accès externe via l'Ingress au proxy Apache sur le port 80

## Vérification

Pour vérifier l'état de Cilium :

```bash
cilium status
```

Pour vérifier que les politiques réseau sont correctement appliquées :

```bash
kubectl get cnp
```

## Dépannage

Si vous rencontrez des problèmes avec Cilium :

1. Vérifiez l'état des pods Cilium :
   ```bash
   kubectl get pods -n kube-system -l k8s-app=cilium
   ```

2. Consultez les logs des pods Cilium :
   ```bash
   kubectl logs -n kube-system -l k8s-app=cilium
   ```

3. Réinstallez Cilium si nécessaire :
   ```bash
   cilium uninstall
   ./cilium-setup.sh
   ```

## Ressources supplémentaires

- [Documentation officielle de Cilium](https://docs.cilium.io/)
- [Guide d'utilisation de l'interface CLI Cilium](https://docs.cilium.io/en/stable/installation/cli/) 