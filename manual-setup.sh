#!/bin/bash

echo "🚀 Script de configuration manuelle Dinor Dashboard"
echo "=================================================="

# Fonction pour vérifier si un conteneur existe
check_container() {
    if docker ps -a --format 'table {{.Names}}' | grep -q "$1"; then
        echo "✅ Conteneur $1 trouvé"
        return 0
    else
        echo "❌ Conteneur $1 non trouvé"
        return 1
    fi
}

# Fonction pour exécuter une commande dans le conteneur
exec_in_container() {
    local container=$1
    local command=$2
    echo "🔧 Exécution dans $container: $command"
    docker exec -it "$container" bash -c "$command"
}

echo ""
echo "1️⃣ Vérification de Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

echo "✅ Docker est installé"

echo ""
echo "2️⃣ Arrêt des conteneurs existants..."
docker compose down

echo ""
echo "3️⃣ Construction des conteneurs..."
docker compose build --no-cache

echo ""
echo "4️⃣ Démarrage des conteneurs..."
docker compose up -d

echo ""
echo "5️⃣ Attente du démarrage des services..."
sleep 30

echo ""
echo "6️⃣ Vérification du statut des conteneurs..."
docker compose ps

echo ""
echo "7️⃣ Vérification des logs..."
docker compose logs --tail=10

# Si le conteneur app existe, continuer avec la configuration Laravel
if check_container "dinor-app"; then
    echo ""
    echo "8️⃣ Configuration Laravel..."
    
    echo "📦 Installation des dépendances Composer..."
    exec_in_container "dinor-app" "composer install --optimize-autoloader"
    
    echo "🔑 Génération de la clé d'application..."
    exec_in_container "dinor-app" "php artisan key:generate"
    
    echo "🗄️ Exécution des migrations..."
    exec_in_container "dinor-app" "php artisan migrate --force"
    
    echo "🔗 Création du lien symbolique storage..."
    exec_in_container "dinor-app" "php artisan storage:link"
    
    echo "🌱 Optionnel: Peuplement de la base de données..."
    read -p "Voulez-vous ajouter des données de test ? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        exec_in_container "dinor-app" "php artisan db:seed"
        exec_in_container "dinor-app" "php artisan db:seed --class=LikesAndCommentsSeeder"
    fi
    
    echo ""
    echo "✅ Configuration terminée !"
    echo ""
    echo "🌐 Accès aux services :"
    echo "   - Dashboard Admin: http://localhost:8000/admin"
    echo "   - API: http://localhost:8000/api/v1/"
    echo "   - PhpMyAdmin: http://localhost:8080"
    echo ""
    echo "🔐 Identifiants admin par défaut :"
    echo "   - Email: admin@dinor.app"
    echo "   - Mot de passe: Dinor2024!Admin"
    
else
    echo ""
    echo "❌ Le conteneur de l'application n'a pas pu être créé."
    echo "📋 Vérifiez les logs pour plus d'informations :"
    echo "   docker compose logs app"
fi

echo ""
echo "�� Script terminé." 