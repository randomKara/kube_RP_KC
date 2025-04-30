#!/bin/bash

# Create a directory for the keys
mkdir -p wireguard/keys

# Generate keys for keycloak
wg genkey > wireguard/keys/keycloak.private
cat wireguard/keys/keycloak.private | wg pubkey > wireguard/keys/keycloak.public

# Generate keys for application
wg genkey > wireguard/keys/application.private
cat wireguard/keys/application.private | wg pubkey > wireguard/keys/application.public

# Generate keys for reverse-proxy
wg genkey > wireguard/keys/reverse-proxy.private
cat wireguard/keys/reverse-proxy.private | wg pubkey > wireguard/keys/reverse-proxy.public

echo "WireGuard keys generated in wireguard/keys/" 