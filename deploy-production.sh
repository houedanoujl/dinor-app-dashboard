#!/bin/bash

# Script de déploiement automatisé pour Dinor Dashboard
# Usage: ./deploy-production.sh

set -e  # Arrêter le script en cas d'erreur

echo "🚀 === DÉPLOIEMENT DINOR DASHBOARD EN PRODUCTION ==="
echo ""

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuration
APP_ENV="production"
APP_URL="https://new.dinorapp.com"
ADMIN_EMAIL="admin@dinor.app"

# Fonction pour afficher des messages colorés
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Fonction pour gérer les erreurs
handle_error() {
    log_error "Erreur détectée à l'étape: $1"
    log_info "Nettoyage en cours..."
    
    # Nettoyer les fichiers temporaires et caches
    php artisan config:clear 2>/dev/null || true
    php artisan cache:clear 2>/dev/null || true
    
    exit 1
}

# Piège pour capturer les erreurs
trap 'handle_error "$(date)"' ERR

# 0. Mise en mode maintenance
log_info "🔄 Mise en mode maintenance..."
php artisan down --retry=60 --render="errors::503" --secret="dinor-maintenance-secret" || log_warning "Impossible de mettre en mode maintenance"

# Vérifier si le fichier .env existe
if [ ! -f .env ]; then
    log_warning "Fichier .env non trouvé. Création à partir de .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        log_success "Fichier .env créé"
    else
        log_error "Fichier .env.example non trouvé!"
        exit 1
    fi
fi

# 1. Nettoyage préalable des conflits Git
log_info "1. Nettoyage des conflits Git potentiels..."

# Supprimer les fichiers de logs qui causent des conflits
rm -rf storage/logs/*.log 2>/dev/null || true
git rm --cached storage/logs/*.log 2>/dev/null || true
git rm --cached storage/logs/laravel.log 2>/dev/null || true

# Nettoyer les fichiers temporaires
rm -rf storage/framework/cache/data/* 2>/dev/null || true
rm -rf storage/framework/sessions/* 2>/dev/null || true
rm -rf storage/framework/views/*.php 2>/dev/null || true
rm -rf bootstrap/cache/*.php 2>/dev/null || true

# Stash les changements locaux s'il y en a
if ! git diff-index --quiet HEAD --; then
    log_warning "Changements locaux détectés, sauvegarde temporaire..."
    git stash push -m "Sauvegarde automatique avant déploiement $(date)"
fi

log_success "Conflits Git nettoyés"

# 2. Mise à jour du code
log_info "2. Mise à jour du code depuis Git..."
if git status > /dev/null 2>&1; then
    git fetch origin main
    git reset --hard origin/main
    log_success "Code mis à jour"
else
    log_warning "Pas de repository Git détecté, passage à l'étape suivante"
fi

# 3. Installation/mise à jour des dépendances
log_info "3. Installation des dépendances Composer..."
if command -v composer > /dev/null 2>&1; then
    # Supprimer le vendor existant pour éviter les conflits
    rm -rf vendor/ 2>/dev/null || true
    
    # Installer les dépendances
    composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist
    log_success "Dépendances Composer installées"
else
    log_error "Composer non trouvé!"
    exit 1
fi

# 4. Génération de la clé d'application si nécessaire
log_info "4. Vérification de la clé d'application..."
if ! grep -q "APP_KEY=base64:" .env; then
    php artisan key:generate --force
    log_success "Clé d'application générée"
else
    log_info "Clé d'application déjà présente"
fi

# 5. Configuration des variables d'environnement importantes
log_info "5. Configuration des variables d'environnement..."

# Fonction pour mettre à jour ou ajouter une variable dans .env
update_env_var() {
    local key=$1
    local value=$2
    
    if grep -q "^${key}=" .env; then
        # La variable existe, la mettre à jour
        sed -i "s/^${key}=.*/${key}=${value}/" .env
    else
        # La variable n'existe pas, l'ajouter
        echo "${key}=${value}" >> .env
    fi
}

# Variables importantes pour la production
update_env_var "APP_ENV" "production"
update_env_var "APP_DEBUG" "false"
update_env_var "APP_URL" "$APP_URL"
update_env_var "SESSION_DOMAIN" ".dinorapp.com"
update_env_var "SESSION_SECURE_COOKIE" "true"
update_env_var "SESSION_SAME_SITE" "lax"
update_env_var "SANCTUM_STATEFUL_DOMAINS" "new.dinorapp.com,dinorapp.com,localhost"

# Variables pour l'admin par défaut
update_env_var "ADMIN_DEFAULT_EMAIL" "$ADMIN_EMAIL"
update_env_var "ADMIN_DEFAULT_PASSWORD" "Dinor2024!Admin"
update_env_var "ADMIN_DEFAULT_NAME" "Administrateur Dinor"

log_success "Variables d'environnement configurées"

# 6. Nettoyage du cache
log_info "6. Nettoyage du cache..."
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
log_success "Cache nettoyé"

# 7. Mise à jour des assets
log_info "7. Compilation des assets..."
if command -v npm > /dev/null 2>&1; then
    # Nettoyer les anciens node_modules
    rm -rf node_modules/ package-lock.json 2>/dev/null || true
    npm install --production
    npm run build 2>/dev/null || npm run production 2>/dev/null || log_warning "Build assets échoué"
    log_success "Assets compilés"
else
    log_warning "NPM non trouvé, assets non compilés"
fi

# 8. Recréer les dossiers de storage nécessaires
log_info "8. Création des dossiers de storage..."
mkdir -p storage/logs
mkdir -p storage/framework/cache/data
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/app/public
chmod -R 755 storage bootstrap/cache
log_success "Dossiers de storage créés"

# 9. Migrations de base de données
log_info "9. Exécution des migrations..."
php artisan migrate --force
log_success "Migrations exécutées"

# 10. Exécution des seeders (y compris AdminUserSeeder)
log_info "10. Exécution des seeders..."
php artisan db:seed --class=AdminUserSeeder --force
log_success "Seeders exécutés - Utilisateur admin créé/mis à jour"

# 11. Optimisation pour la production
log_info "11. Optimisation pour la production..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
log_success "Optimisations appliquées"

# 12. Création du lien symbolique pour le storage
log_info "12. Création du lien symbolique storage..."
php artisan storage:link
log_success "Lien symbolique créé"

# 13. Vérification finale
log_info "13. Vérification de la configuration..."

# Test de connexion à la base de données
if php artisan migrate:status > /dev/null 2>&1; then
    log_success "Connexion base de données OK"
else
    log_error "Problème de connexion à la base de données"
    exit 1
fi

# Vérification de l'utilisateur admin
ADMIN_EXISTS=$(php artisan tinker --execute="echo App\Models\AdminUser::where('email', '$ADMIN_EMAIL')->exists() ? 'yes' : 'no';" 2>/dev/null | tail -1)
if [ "$ADMIN_EXISTS" = "yes" ]; then
    log_success "Utilisateur admin vérifié"
else
    log_error "Utilisateur admin non trouvé"
    exit 1
fi

# 14. Remettre l'application en ligne
log_info "14. Remise en ligne de l'application..."
php artisan up
log_success "Application remise en ligne"

echo ""
echo "🎉 === DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ==="
echo ""
echo "📋 Informations de connexion:"
echo "🌐 URL Dashboard: $APP_URL/admin/login"
echo "📧 Email: $ADMIN_EMAIL"
echo "🔑 Mot de passe: Dinor2024!Admin"
echo ""
echo "📋 URLs API importantes:"
echo "🔗 API Recettes: $APP_URL/api/v1/recipes"
echo "🔗 API Événements: $APP_URL/api/v1/events"
echo "🔗 Test Database: $APP_URL/api/test/database-check"
echo ""
echo "💡 Conseils post-déploiement:"
echo "   - Vérifiez les logs: storage/logs/laravel.log"
echo "   - Testez l'API avec les URLs ci-dessus"
echo "   - Connectez-vous au dashboard pour vérifier"
echo ""
echo "✅ Déploiement terminé!" 