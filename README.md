# Kubernetes OIDC Authentication Cluster

Ce projet déploie un cluster Kubernetes avec trois composants principaux :

1. Une application Flask simple
2. Un reverse proxy Apache avec l'authentification OIDC (en sidecar)
3. Un serveur Keycloak pour la gestion des identités

## Architecture

Dans cette architecture, le reverse proxy Apache est déployé en tant que sidecar dans le même pod que l'application Flask. Cela permet une communication directe et sécurisée entre le proxy et l'application.

## Configuration

- **Application Flask** : Service web simple qui affiche les informations utilisateur.
- **Reverse Proxy Apache** : Apache avec mod_auth_openidc qui gère l'authentification OIDC, déployé comme sidecar.
- **Keycloak** : Serveur d'identité qui initialise un realm avec des utilisateurs prédéfinis.

## Déploiement

1. Construire les images Docker :
   ```bash
   cd kube_manifests
   ./build-images.sh
   ```

2. Déployer sur Kubernetes :
   ```bash
   kubectl apply -k .
   ```

3. Ajouter une entrée dans /etc/hosts :
   ```
   127.0.0.1 auth-oidc.test
   ```

4. Accéder à l'application via :
   ```
   http://auth-oidc.test
   ```

## Tests avec curl

Pour tester l'accès à l'application :
```bash
# Cette commande devrait rediriger vers la page de login Keycloak
curl -i http://auth-oidc.test
```

## Utilisateurs par défaut

- **Utilisateur normal** :
  - Nom d'utilisateur : testuser
  - Mot de passe : password
  - Rôle : user

- **Administrateur** :
  - Nom d'utilisateur : admin
  - Mot de passe : admin
  - Rôles : admin, user 