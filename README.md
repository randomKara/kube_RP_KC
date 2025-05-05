# Architecture de Sécurité Kubernetes avec WireGuard, Cilium et Authentification OIDC

Ce projet déploie un cluster Kubernetes sécurisé, intégrant WireGuard pour le chiffrement des communications, Cilium comme CNI (Container Network Interface) pour la sécurité réseau avancée, et une authentification OIDC via Keycloak et un reverse proxy Apache.

## Architecture Générale

L'architecture comprend :

-   Une application Flask.
-   Un reverse proxy Apache (sidecar) avec authentification OpenID Connect (OIDC).
-   Un serveur Keycloak pour la gestion des identités.
-   WireGuard pour chiffrer les communications entre les pods.
-   Cilium pour la gestion des politiques réseau.

```
┌─────────────────────────────────────────────┐
│                  Ingress                    │
└───────────────────────┬─────────────────────┘
                        │
    ┌───────────────────┴──────────────────┐
    │                                      │
┌───▼──────────────────┐      ┌────────────▼────────┐
│   Flask + Apache     │      │      Keycloak       │
│   (app + proxy)      │◄────►│                     │
│                      │      │                     │
│  POD 1               │      │  POD 2              │
│ ┌──────────────────┐ │      │ ┌─────────────────┐ │
│ │    WireGuard     │ │      │ │    WireGuard    │ │
│ │    10.100.100.2  │ │      │ │   10.100.100.1  │ │
│ └──────────────────┘ │      │ └─────────────────┘ │
└──────────────────────┘      └─────────────────────┘
```

## WireGuard : Chiffrement des Communications

Toutes les communications entre les pods sont chiffrées via WireGuard, formant un réseau privé virtuel 10.100.100.0/24.

### Vérification du Chiffrement WireGuard

1.  **Analyser l'interface WireGuard :**

    ```bash
    # Vérifier que l'interface WireGuard est active dans le conteneur
    kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c wireguard -- wg show

    # Vérifier les ports en écoute (le port UDP 51820 doit être présent pour WireGuard)
    kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c wireguard -- netstat -tuln
    ```

    Confirmer la présence du port UDP 51820 et une configuration WireGuard avec des peers.
2.  **Observer les performances réseau :**

    ```bash
    # Avec WireGuard (via l'interface wg0):
    time kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c wireguard -- curl -s 10.100.100.1:8080 > /dev/null

    # Sans WireGuard (via l'interface directe):
    time kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- curl -s $(kubectl get svc keycloak-service -o jsonpath='{.spec.clusterIP}'):8080 > /dev/null
    ```
3.  **Utiliser `ngrep` pour observer le trafic :**

    ```bash
    # Installer ngrep dans le conteneur
    kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- apt-get update && apt-get install -y ngrep

    # Observer le trafic sur les différentes interfaces
    kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- ngrep -d any -q host $(kubectl get svc keycloak-service -o jsonpath='{.spec.clusterIP}')
    ```
4.  **Désactiver WireGuard pour comparer :**

    ```bash
    # Modifier les déploiements pour supprimer les conteneurs WireGuard
    kubectl edit deployment flask-app
    kubectl edit deployment keycloak

    # Recherchez et supprimez le conteneur nommé "wireguard"
    # Sauvegardez et quittez l'éditeur

    # Puis, vérifiez si les services peuvent toujours communiquer (ils le feront, mais sans chiffrement)
    kubectl exec -it $(kubectl get pods -l app=flask-app -o jsonpath='{.items[0].metadata.name}') -c flask-app -- curl -v $(kubectl get svc keycloak-service -o jsonpath='{.spec.clusterIP}'):8080
    ```

### Preuves du Chiffrement WireGuard

1.  Présence du port UDP 51820 sur chaque pod.
2.  Configuration des interfaces WireGuard avec `wg show`.
3.  Configuration des clés publiques et privées.
4.  Utilisation du VPN avec le sous-réseau 10.100.100.0/24.
5.  Communication entre les pods via ces adresses IP virtuelles.

## Cilium : Sécurité et Connectivité Réseau

Cilium est utilisé comme CNI pour fournir une connectivité réseau, une sécurité et une observabilité avancées. Il utilise eBPF pour une performance optimale.

### Politiques Réseau Cilium

1.  **flask-app-policy.yaml :** Limite l'accès à l'application Flask uniquement depuis le proxy Apache (sidecar).
2.  **keycloak-policy.yaml :** Contrôle l'accès au serveur Keycloak, autorisant uniquement le trafic depuis le proxy Apache.
3.  **ingress-policy.yaml :** Autorise l'accès externe via l'Ingress au proxy Apache sur le port 80.

### Installation de Cilium

```bash
./cilium-setup.sh
```

Ce script automatise :

-   Le démarrage de Minikube avec les paramètres appropriés pour Cilium.
-   L'installation de l'interface CLI Cilium.
-   Le déploiement de Cilium dans le cluster.
-   L'application des politiques réseau Cilium.

### Vérification de Cilium

```bash
cilium status
kubectl get cnp
kubectl describe cnp flask-app-policy
```

## Authentification OIDC avec Keycloak

L'authentification est gérée par Keycloak et un reverse proxy Apache (mod\_auth\_openidc).

### Configuration

-   **Application Flask :** Fournit les informations utilisateur après authentification.
-   **Reverse Proxy Apache :** Gère l'authentification OIDC.
-   **Keycloak :** Serveur d'identité initialisé avec un realm et des utilisateurs prédéfinis.

### Déploiement

1.  **Démarrer Minikube :**

    ```bash
    minikube start
    minikube addons enable ingress
    minikube tunnel
    ```
2.  **Construire les images Docker :**

    ```bash
    ./build-images.sh
    ```
3.  **Charger les images dans Minikube :**

    ```bash
    minikube image load flask-app:latest
    minikube image load apache-proxy:latest
    ```
4.  **Déployer les services :**

    ```bash
    kubectl apply -f keycloak/configmap.yaml
    kubectl apply -f keycloak/deployment.yaml
    kubectl apply -f keycloak/ingress.yaml
    kubectl wait --for=condition=ready pod --selector=app=keycloak --timeout=180s
    kubectl apply -f reverse-proxy/configmap.yaml
    kubectl apply -f application/deployment.yaml
    kubectl apply -f reverse-proxy/service.yaml
    kubectl apply -f ingress.yaml
    ```
5.  **Configurer les entrées DNS :**

    ```bash
    INGRESS_IP=$(kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
    echo $INGRESS_IP
    sudo sh -c "echo \"$INGRESS_IP auth-oidc.test\" >> /etc/hosts"
    sudo sh -c "echo \"$INGRESS_IP auth-keycloak.test\" >> /etc/hosts"
    ```

### Accès à l'Application

Accéder à l'application via : `http://auth-oidc.test`

### Utilisateurs par Défaut

-   **Utilisateur normal :**
    -   Nom d'utilisateur : testuser
    -   Mot de passe : password
    -   Rôle : user
-   **Administrateur :**
    -   Nom d'utilisateur : admin
    -   Mot de passe : admin
    -   Rôles : admin, user

## Suppression et Recréation de l'Environnement

### Suppression

```bash
kubectl delete -k .
kubectl delete -f ingress.yaml
```

### Recréation

```bash
minikube image load flask-app:latest
minikube image load apache-proxy:latest
kubectl apply -f wireguard/deployment.yaml
kubectl apply -f wireguard/configmap.yaml
kubectl apply -k .
kubectl apply -f ingress.yaml
```

## Dépannage

-   **Minikube :** Si le tunnel se déconnecte, redémarrez-le (`minikube tunnel`).
-   **Keycloak :** Attendez que Keycloak soit initialisé (`kubectl logs -f $(kubectl get pods -l app=keycloak -o name)`).
-   **Ingress :** Vérifiez l'état du contrôleur (`kubectl -n ingress-nginx get pods` et les logs).
-   **Authentification :** Vérifiez les logs du reverse proxy Apache (`kubectl logs $(kubectl get pods -l app=flask-app -o name) -c apache-proxy`).
-   **ImagePullBackOff :** Assurez-vous que les images sont chargées dans Minikube et supprimez le pod (`kubectl delete pod $(kubectl get pods -l app=flask-app -o name | cut -d/ -f2)`).

## Ressources

-   [Documentation officielle de Cilium](https://docs.cilium.io/)
-   [Guide des politiques réseau Cilium](https://docs.cilium.io/en/stable/network/kubernetes/policy/)
-   [Tutoriels Cilium](https://docs.cilium.io/en/stable/tutorials/)
