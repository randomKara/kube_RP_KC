# Analyse de la Complexité d'HAProxy Ingress pour ce Projet

Ce document analyse pourquoi l'utilisation de HAProxy Ingress s'est avérée excessivement complexe par rapport aux besoins initiaux du projet (authentification OIDC pour une application Flask via Keycloak et un reverse proxy Apache).

## Contexte Initial

L'objectif était de remplacer un contrôleur Ingress (Nginx) par HAProxy Ingress tout en conservant l'architecture existante :

- Client -> Ingress -> Pod (Apache Reverse Proxy + Flask App)
- Apache gère l'authentification OIDC avec Keycloak.
- Keycloak tourne dans son propre Pod.

## Problème Principal : Complexité de Configuration Multi-Niveaux

La difficulté majeure ne réside pas dans HAProxy Ingress lui-même, mais dans la **gestion de la configuration à travers de multiples composants interdépendants**, en particulier pour la gestion du protocole (HTTP/HTTPS) et des URLs de redirection.

Chaque couche (Ingress, Apache, Keycloak) nécessite des configurations spécifiques qui doivent être parfaitement alignées, rendant le processus sujet aux erreurs et difficile à déboguer.

## Points de Complexité Détaillés

1.  **Choix et Configuration de l'Implémentation HAProxy Ingress** :
    *   Nous avons d'abord utilisé une image (`haproxytech/kubernetes-ingress`) nécessitant la création manuelle de toutes les ressources RBAC, déploiement, service, etc. (`haproxy-ingress/haproxy-ingress.yaml`). Cette approche, bien que flexible, est verbeuse et demande une connaissance approfondie des permissions et arguments nécessaires.
    *   Des erreurs subtiles sont apparues (permissions manquantes pour `EndpointSlices`, arguments de contrôleur spécifiques, variables d'environnement `POD_NAME`/`POD_NAMESPACE` non définies par défaut etc...).
    *   Le passage à une implémentation communautaire (`quay.io/jcmoraisjr/haproxy-ingress`) a simplifié certains aspects mais a introduit d'autres complexités (permissions `runAsUser: 0` requises pour l'écriture dans certains chemins, ajout manuel des variables d'environnement etc...).

2.  **Gestion Réseau (Spécifique à Minikube, mais Révélateur)** :
    *   **Exposition du Service** : Le type `LoadBalancer` étant peu fiable avec `minikube tunnel`, nous avons dû basculer vers `NodePort`. Cela impose l'utilisation de ports spécifiques (ex: 30080) dans les URLs d'accès externes, ce qui n'était pas l'objectif initial (pas de port visible dans l'URL).
    *   **DNS / `/etc/hosts`** : La nécessité de mapper manuellement les noms d'hôtes (`auth-oidc.test`, `auth-keycloak.test`) à l'IP de Minikube dans le fichier `/etc/hosts` local ajoute une étape de configuration externe au déploiement Kubernetes lui-même.

3.  **Cauchemar de la Configuration HTTP/HTTPS** :
    *   **Multiples Points de Configuration** : Pour que les redirections OIDC fonctionnent correctement (surtout avec HTTPS), il fallait aligner :
        *   **Keycloak** : Variables d'environnement (`KC_HOSTNAME_URL`, `KC_HOSTNAME_ADMIN_URL`) dans `keycloak/deployment.yaml` ET les `redirectUris` dans le `realm.json` (géré via `keycloak/configmap.yaml`).
        *   **HAProxy Ingress** : Annotations sur chaque ressource Ingress (`ingress.yaml`, `keycloak/ingress.yaml`) pour gérer la redirection SSL (`haproxy.org/ssl-redirect`). Potentiellement aussi des paramètres globaux dans le ConfigMap HAProxy (`haproxy-ingress/haproxy-ingress.yaml`).
        *   **Apache (mod_auth_openidc)** : Directives `OIDCProviderMetadataURL`, `OIDCRedirectURI`, `OIDCSSLValidateServer`, et potentiellement `OIDCXForwardedHeaders` dans `reverse-proxy/configmap.yaml`.
    *   **Conflits et Incohérences** : Nous avons rencontré des erreurs où Keycloak recevait un `redirect_uri` en HTTP alors qu'il attendait HTTPS (ou vice-versa), ou l'URL contenait un port interne non attendu. L'utilisation de `hostNetwork: true` pour HAProxy (pour lier les ports 80/443) ajoutait une autre couche de complexité potentielle.
    *   **Abandon de HTTPS** : Face à l'impossibilité d'aligner facilement toutes ces configurations pour HTTPS, la solution de repli a été de **tout configurer en HTTP**, ce qui va à l'encontre des bonnes pratiques de sécurité et de l'objectif initial.

4.  **Configuration Interne (Apache vers Keycloak)** :
    *   Le conteneur Apache, essayant de contacter Keycloak via son nom d'hôte externe (`auth-keycloak.test`), échouait car ce nom n'est pas résolu à l'intérieur du cluster par défaut.
    *   Il a fallu modifier la configuration Apache (`reverse-proxy/configmap.yaml`) pour utiliser le **nom du service Kubernetes** (`keycloak-service:8080`) dans `OIDCProviderMetadataURL`, ajoutant une dépendance à la découverte de services internes.

5.  **Nombre de Fichiers et Interdépendances** :
    *   La configuration est répartie sur de nombreux fichiers : déploiements, services, configmaps pour chaque composant, plus les fichiers d'Ingress et la configuration HAProxy elle-même.
    *   Une modification (ex: passer de HTTP à HTTPS) nécessite des changements coordonnés dans au moins 4 ou 5 fichiers YAML différents, augmentant le risque d'erreurs.

## Conclusion

Bien que HAProxy Ingress soit un outil puissant et configurable, son intégration dans cette architecture spécifique (avec un proxy Apache OIDC intermédiaire et Keycloak) a entraîné une **complexité de configuration significative**. La gestion des protocoles (HTTP/HTTPS) et des URLs à travers les différentes couches (Ingress -> Apache -> Keycloak -> Client) était particulièrement ardue.

La configuration actuelle, bien que fonctionnelle en HTTP après de multiples ajustements, démontre que l'empilement de couches de proxy et d'authentification, combiné aux spécificités de l'environnement de déploiement (Minikube), peut rendre une solution techniquement possible mais pratiquement trop complexe.