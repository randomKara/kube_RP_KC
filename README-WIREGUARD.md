# Architecture de Sécurité avec WireGuard dans Kubernetes

Ce projet implémente une architecture sécurisée utilisant WireGuard pour chiffrer les communications entre les différents services d'une application Kubernetes comprenant :
- Une application Flask 
- Un proxy inverse Apache avec authentification OpenID Connect
- Un serveur Keycloak pour l'authentification

## Architecture

```
┌─────────────────────────────────────────────┐
│                  Ingress                     │
└───────────────────────┬─────────────────────┘
                        │
    ┌──────────────────┴───────────────────┐
    │                                       │
┌───▼──────────────────┐      ┌────────────▼────────┐
│   Flask + Apache     │      │      Keycloak       │
│   (app + proxy)      │◄────►│                     │
│                      │      │                     │
│  POD 1               │      │  POD 2              │
│ ┌──────────────────┐ │      │ ┌─────────────────┐ │
│ │    WireGuard     │ │      │ │    WireGuard    │ │
│ │    10.100.100.2  │ │      │ │   10.100.100.1  │ │
│ └──────────────────┘ │      │ └─────────────────┘ │
└──────────────────────┘      └──────────────────────┘
```

Toutes les communications entre les pods sont chiffrées via WireGuard, formant un réseau privé virtuel 10.100.100.0/24.

## Vérification du Chiffrement

Il existe plusieurs manières de vérifier que les communications sont bien chiffrées par WireGuard.

### Méthode 1: Analyser l'interface WireGuard

```bash
# Vérifier que l'interface WireGuard est active dans le conteneur
kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c wireguard -- wg show

# Vérifier les ports en écoute (le port UDP 51820 doit être présent pour WireGuard)
kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c wireguard -- netstat -tuln
```

Si vous voyez le port UDP 51820 ouvert et une configuration WireGuard avec des peers, cela confirme que WireGuard est correctement configuré pour le chiffrement.

### Méthode 2: Observer les performances réseau

Le chiffrement WireGuard impose une légère surcharge de traitement. On peut observer cette différence:

```bash
# Avec WireGuard (via l'interface wg0):
time kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c wireguard -- curl -s 10.100.100.1:8080 > /dev/null

# Sans WireGuard (via l'interface directe):
time kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- curl -s $(kubectl get svc keycloak-service -o jsonpath='{.spec.clusterIP}'):8080 > /dev/null
```

### Méthode 3: Utiliser ngrep pour observer le trafic

Si disponible, ngrep peut être utilisé pour observer le trafic réseau:

```bash
# Installer ngrep dans le conteneur
kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- apt-get update && apt-get install -y ngrep

# Observer le trafic sur les différentes interfaces
kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- ngrep -d any -q host $(kubectl get svc keycloak-service -o jsonpath='{.spec.clusterIP}')
```

### Méthode 4: Désactiver WireGuard pour comparer

Pour une démonstration définitive, désactivez temporairement WireGuard et observez les différences:

```bash
# Modifier les déploiements pour supprimer les conteneurs WireGuard
kubectl edit deployment flask-app
kubectl edit deployment keycloak

# Recherchez et supprimez le conteneur nommé "wireguard"
# Sauvegardez et quittez l'éditeur

# Puis, vérifiez si les services peuvent toujours communiquer (ils le feront, mais sans chiffrement)
kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- curl -v $(kubectl get svc keycloak-service -o jsonpath='{.spec.clusterIP}'):8080
```

## Supprimer et Recréer l'Environnement

### Suppression

```bash
# Supprimer toutes les ressources
kubectl delete -k .
kubectl delete -f ingress.yaml
```

### Recréation

```bash
# Charger les images dans minikube
minikube image load flask-app:latest
minikube image load apache-proxy:latest

# Appliquer les configurations Kubernetes
kubectl apply -f wireguard/deployment.yaml
kubectl apply -f wireguard/configmap.yaml
kubectl apply -k .
kubectl apply -f ingress.yaml

# Vérifier le déploiement
kubectl get pods
kubectl get services
kubectl get ingress
```

## Test de l'Application

Une fois l'environnement recréé:

```bash
# Vérifier l'accès à l'application (redirige vers Keycloak)
curl -v http://auth-oidc.test

# Vérifier l'accès direct à Keycloak
curl -v http://auth-keycloak.test
```

## Preuves du Chiffrement WireGuard

Pour prouver que WireGuard chiffre effectivement les communications, vous pouvez observer:

1. La présence du port UDP 51820 sur chaque pod
2. La configuration des interfaces WireGuard avec les commandes `wg show`
3. La configuration des clés publiques et privées qui authentifient et chiffrent les communications
4. L'utilisation de réseaux privés virtuels (VPN) avec le sous-réseau 10.100.100.0/24
5. La capacité de chaque pod à communiquer sur ces adresses IP virtuelles

Ces éléments confirment que les pods communiquent à travers un tunnel WireGuard chiffré, plutôt que directement via le réseau Kubernetes standard. 