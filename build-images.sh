#!/bin/bash
set -e

# Définir la localisation des Dockerfiles
FLASK_DOCKERFILE="./application/Dockerfile"
APACHE_DOCKERFILE="./reverse-proxy/Dockerfile"

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    echo "Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Construire l'image de l'application Flask
echo "Construction de l'image Flask..."
if [ -f "$FLASK_DOCKERFILE" ]; then
    docker build -t flask-app:latest -f "$FLASK_DOCKERFILE" ./application/
else
    echo "Erreur: Le Dockerfile de Flask n'existe pas à $FLASK_DOCKERFILE"
    exit 1
fi

# Construire l'image du reverse proxy Apache
echo "Construction de l'image Apache..."
if [ -f "$APACHE_DOCKERFILE" ]; then
    docker build -t apache-proxy:latest -f "$APACHE_DOCKERFILE" ./reverse-proxy/
else
    echo "Erreur: Le Dockerfile d'Apache n'existe pas à $APACHE_DOCKERFILE"
    exit 1
fi

echo "Construction des images terminée avec succès!"
echo "Images disponibles:"
docker images | grep -E 'flask-app|apache-proxy'

echo ""
echo "Pour charger ces images dans Minikube, exécutez:"
echo "minikube image load flask-app:latest"
echo "minikube image load apache-proxy:latest" 