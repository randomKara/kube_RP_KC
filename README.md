# Kubernetes OIDC Authentication Cluster

Ce projet déploie un cluster Kubernetes avec trois composants principaux :

1. Une application Flask simple
2. Un reverse proxy Apache avec l'authentification OIDC (en sidecar)
3. Un serveur Keycloak pour la gestion des identités

## Architecture

Dans cette architecture, le reverse proxy Apache est déployé en tant que sidecar dans le même pod que l'application Flask. Cela permet une communication directe et sécurisée entre le proxy et l'application.

### Diagramme d'architecture

Le diagramme ci-dessous illustre en détail le flux d'authentification OpenID Connect :

![Diagramme de flux](flowchart.png)

#### Explications du diagramme :

- **Flux d'authentification :** Le diagramme montre le parcours complet d'une requête utilisateur, depuis le navigateur jusqu'à l'application Flask, en passant par l'authentification Keycloak.
- **Pattern Sidecar :** L'application Flask et le reverse proxy Apache sont dans le même pod, communiquant via localhost (127.0.0.1).

Pour plus de détaille sur l'architecture, se référer à l'[UML](./UML.png)

## Note sur le Contrôleur Ingress

Ce README utilise **HAProxy Ingress**. Une tentative a été faite pour intégrer HAProxy dans cette architecture spécifique, mais elle a rencontré des **complexités significatives**, notamment dans la gestion de la configuration HTTP/HTTPS et des redirections à travers les différentes couches (HAProxy, Apache OIDC, Keycloak).

Bien que la configuration actuelle soit fonctionnelle en HTTP via NodePort, elle illustre les difficultés rencontrées. Pour une analyse détaillée de ces problèmes et comprendre pourquoi cette approche peut être considérée comme trop complexe pour ce cas d'usage spécifique, veuillez consulter le fichier [README-HAPROXY.md](./README-HAPROXY.md).

Pour des déploiements plus simples, l'utilisation de **Nginx Ingress** (via `minikube addons enable ingress`) est souvent recommandée pour ce type d'architecture.

## Prérequis

- Docker installé
- Minikube installé
- kubectl installé
- Privilèges pour modifier le fichier /etc/hosts

## Configuration

- **Application Flask** : Service web simple qui affiche les informations utilisateur.
- **Reverse Proxy Apache** : Apache avec mod_auth_openidc qui gère l'authentification OIDC, déployé comme sidecar.
- **Keycloak** : Serveur d'identité qui initialise un realm avec des utilisateurs prédéfinis.

## Déploiement complet

### 1. Démarrer Minikube

```bash
# Démarrer minikube avec suffisamment de ressources
minikube start --cpus=4 --memory=8192

# Désactiver l'addon ingress Nginx s'il est activé (car nous utilisons HAProxy)
minikube addons disable ingress

# Démarrer le tunnel minikube (Optionnel, car nous utilisons NodePort, mais peut être utile pour certains environnements)
# minikube tunnel
```

### 2. Construire les images Docker

```bash
cd kube_manifests
./build-images.sh
```

### 3. Charger les images dans Minikube

```bash
# Charger les images dans Minikube
minikube image load flask-app:latest
minikube image load apache-proxy:latest
```

### 4. Déployer les services sur Kubernetes

```bash
# Déployer HAProxy Ingress Controller
kubectl apply -f haproxy-ingress/haproxy-ingress.yaml

# Vérifier que le contrôleur HAProxy est prêt
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=haproxy-ingress -n ingress-haproxy --timeout=180s

# Déployer Keycloak
kubectl apply -f keycloak/configmap.yaml
kubectl apply -f keycloak/deployment.yaml
kubectl apply -f keycloak/ingress.yaml

# Attendre que Keycloak soit prêt (cela peut prendre jusqu'à 2-3 minutes)
kubectl wait --for=condition=ready pod --selector=app=keycloak --timeout=180s

# Déployer Apache et Flask
kubectl apply -f reverse-proxy/configmap.yaml
kubectl apply -f application/deployment.yaml
kubectl apply -f reverse-proxy/service.yaml
kubectl apply -f ingress.yaml
```

### 5. Configurer les entrées DNS

Obtenir l'adresse IP de Minikube:
```bash
MINIKUBE_IP=$(minikube ip)
echo "Adresse IP de Minikube: $MINIKUBE_IP"
```

Ajouter les entrées au fichier /etc/hosts:
```bash
# Supprimer les entrées existantes si nécessaire
sudo sed -i '/auth-oidc.test/d' /etc/hosts
sudo sed -i '/auth-keycloak.test/d' /etc/hosts

# Ajouter les nouvelles entrées
sudo sh -c "echo \"$MINIKUBE_IP auth-oidc.test auth-keycloak.test\" >> /etc/hosts"
```

### 6. Vérification du déploiement

Vérifier que HAProxy Ingress fonctionne:
```bash
kubectl get svc -n ingress-haproxy
kubectl get pods -n ingress-haproxy
```

Vérifier que Keycloak fonctionne correctement:
```bash
# Accès via le nom d'hôte et le port NodePort HTTP (30080 par défaut dans haproxy-ingress.yaml)
curl -s http://auth-keycloak.test:30080/realms/myrealm/.well-known/openid-configuration | head -5
```

Vérifier que l'application redirige vers Keycloak pour l'authentification:
```bash
# Accès via le nom d'hôte et le port NodePort HTTP (30080)
curl -s http://auth-oidc.test:30080 -I
```

## Accès à l'application

Accédez à l'application via votre navigateur en utilisant l'adresse IP de Minikube et le port NodePort HTTP (30080 par défaut dans `haproxy-ingress/haproxy-ingress.yaml`):
```
http://auth-oidc.test:30080
```

Vous serez redirigé vers la page de connexion de Keycloak. Après vous être authentifié, vous serez redirigé vers l'application Flask.

## Utilisateurs par défaut

- **Utilisateur normal** :
  - Nom d'utilisateur : testuser
  - Mot de passe : password
  - Rôle : user

- **Administrateur** :
  - Nom d'utilisateur : admin
  - Mot de passe : admin
  - Rôles : admin, user

## Dépannage

### Si le tunnel Minikube se déconnecte (si utilisé)

Si le tunnel Minikube se déconnecte, redémarrez-le dans un terminal séparé:
```bash
# minikube tunnel (Décommenter si nécessaire)
```

### Si HAProxy Ingress n'est pas accessible

Vérifier l'état du service NodePort:
```bash
kubectl get svc haproxy-ingress -n ingress-haproxy
```

Assurez-vous que vous accédez via l'IP de Minikube et le bon NodePort (30080 pour HTTP, tel que défini dans `haproxy-ingress/haproxy-ingress.yaml`).

### Si Keycloak n'est pas accessible

Attendre que Keycloak soit complètement initialisé (peut prendre jusqu'à 3 minutes):
```bash
kubectl logs -f $(kubectl get pods -l app=keycloak -o name)
```
Vérifier l'accès direct au service Keycloak:
```bash
kubectl port-forward service/keycloak-service 8080:8080 &
curl http://localhost:8080/realms/myrealm/.well-known/openid-configuration
# N'oubliez pas de tuer le port-forward après le test: fg (pour ramener en avant-plan), puis Ctrl+C
```

### Si l'ingress HAProxy ne fonctionne pas correctement

Vérifier l'état du contrôleur HAProxy:
```bash
kubectl -n ingress-haproxy get pods
kubectl -n ingress-haproxy logs $(kubectl -n ingress-haproxy get pods -l app.kubernetes.io/name=haproxy-ingress -o name)
```

Vérifier la configuration des ingress:
```bash
kubectl get ingress
kubectl describe ingress application-ingress
kubectl describe ingress keycloak-ingress
```

Consulter l'analyse détaillée dans [README-HAPROXY.md](./README-HAPROXY.md).

### Si l'authentification échoue

Vérifier les logs du reverse proxy Apache:
```bash
kubectl logs $(kubectl get pods -l app=flask-app -o name) -c apache-proxy
```
Assurez-vous que `OIDCProviderMetadataURL` dans `reverse-proxy/configmap.yaml` pointe vers `http://keycloak-service:8080/...` et que les `redirectUris` dans `keycloak/configmap.yaml` correspondent à ceux attendus (http://auth-oidc.test/...).

### Si les pods sont bloqués en ImagePullBackOff

Si vous rencontrez des erreurs d'extraction d'image (ImagePullBackOff), assurez-vous que les images sont bien chargées dans Minikube:
```bash
minikube image load flask-app:latest
minikube image load apache-proxy:latest
```

Ensuite, supprimez et laissez Kubernetes recréer le pod:
```bash
kubectl delete pod $(kubectl get pods -l app=flask-app -o name | cut -d/ -f2)
```
