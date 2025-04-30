#!/bin/bash

# Créer le répertoire pour les clés si nécessaire
mkdir -p wireguard/keys

echo "Génération des clés avec Docker..."

# Générer la clé privée pour Keycloak
docker run --rm -v $(pwd)/wireguard/keys:/keys alpine/wireguard sh -c "wg genkey > /keys/keycloak.private"
# Générer la clé publique pour Keycloak
docker run --rm -v $(pwd)/wireguard/keys:/keys alpine/wireguard sh -c "cat /keys/keycloak.private | wg pubkey > /keys/keycloak.public"

# Générer la clé privée pour l'application
docker run --rm -v $(pwd)/wireguard/keys:/keys alpine/wireguard sh -c "wg genkey > /keys/application.private"
# Générer la clé publique pour l'application
docker run --rm -v $(pwd)/wireguard/keys:/keys alpine/wireguard sh -c "cat /keys/application.private | wg pubkey > /keys/application.public"

# Générer la clé privée pour le reverse proxy
docker run --rm -v $(pwd)/wireguard/keys:/keys alpine/wireguard sh -c "wg genkey > /keys/reverse-proxy.private"
# Générer la clé publique pour le reverse proxy
docker run --rm -v $(pwd)/wireguard/keys:/keys alpine/wireguard sh -c "cat /keys/reverse-proxy.private | wg pubkey > /keys/reverse-proxy.public"

# Lire les clés générées
KEYCLOAK_PRIVATE_KEY=$(cat wireguard/keys/keycloak.private)
KEYCLOAK_PUBLIC_KEY=$(cat wireguard/keys/keycloak.public)
APPLICATION_PRIVATE_KEY=$(cat wireguard/keys/application.private)
APPLICATION_PUBLIC_KEY=$(cat wireguard/keys/application.public)
REVERSE_PROXY_PRIVATE_KEY=$(cat wireguard/keys/reverse-proxy.private)
REVERSE_PROXY_PUBLIC_KEY=$(cat wireguard/keys/reverse-proxy.public)

# Échapper les caractères spéciaux pour sed
KEYCLOAK_PRIVATE_KEY=$(echo $KEYCLOAK_PRIVATE_KEY | sed 's/\//\\\//g')
KEYCLOAK_PUBLIC_KEY=$(echo $KEYCLOAK_PUBLIC_KEY | sed 's/\//\\\//g')
APPLICATION_PRIVATE_KEY=$(echo $APPLICATION_PRIVATE_KEY | sed 's/\//\\\//g')
APPLICATION_PUBLIC_KEY=$(echo $APPLICATION_PUBLIC_KEY | sed 's/\//\\\//g')
REVERSE_PROXY_PRIVATE_KEY=$(echo $REVERSE_PROXY_PRIVATE_KEY | sed 's/\//\\\//g')
REVERSE_PROXY_PUBLIC_KEY=$(echo $REVERSE_PROXY_PUBLIC_KEY | sed 's/\//\\\//g')

# Remplacer les placeholders dans le fichier de configuration
echo "Mise à jour du fichier de configuration..."
sed -i "s/KEYCLOAK_PRIVATE_KEY/$KEYCLOAK_PRIVATE_KEY/g" wireguard/configmap.yaml
sed -i "s/KEYCLOAK_PUBLIC_KEY/$KEYCLOAK_PUBLIC_KEY/g" wireguard/configmap.yaml
sed -i "s/APPLICATION_PRIVATE_KEY/$APPLICATION_PRIVATE_KEY/g" wireguard/configmap.yaml
sed -i "s/APPLICATION_PUBLIC_KEY/$APPLICATION_PUBLIC_KEY/g" wireguard/configmap.yaml
sed -i "s/REVERSE_PROXY_PRIVATE_KEY/$REVERSE_PROXY_PRIVATE_KEY/g" wireguard/configmap.yaml
sed -i "s/REVERSE_PROXY_PUBLIC_KEY/$REVERSE_PROXY_PUBLIC_KEY/g" wireguard/configmap.yaml

echo "Configuration WireGuard initialisée avec succès !" 