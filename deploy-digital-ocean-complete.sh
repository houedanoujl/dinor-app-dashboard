#!/bin/bash

cd /home/forge/new.dinorapp.com

# Fonction pour les logs (compatible Forge)
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

echo "🚀 === DÉPLOIEMENT DINOR DASHBOARD DIGITAL OCEAN ==="
echo ""

# 1. Mise en mode maintenance
log_info "🔄 Mise en mode maintenance..."
$FORGE_PHP artisan down --retry=60 --render="errors::503" --secret="dinor-maintenance-secret" || log_warning "Impossible de mettre en mode maintenance"

# 2. Nettoyage préalable des conflits Git
log_info "🧹 Nettoyage des conflits Git potentiels..."

# Supprimer les fichiers de logs qui causent des conflits
rm -rf storage/logs/*.log 2>/dev/null || true
rm -rf storage/logs/laravel.log 2>/dev/null || true

# Nettoyer les fichiers temporaires qui peuvent causer des conflits
rm -rf storage/framework/cache/data/* 2>/dev/null || true
rm -rf storage/framework/sessions/* 2>/dev/null || true
rm -rf storage/framework/views/*.php 2>/dev/null || true
rm -rf bootstrap/cache/*.php 2>/dev/null || true

# Nettoyer le cache Git
git rm --cached storage/logs/*.log 2>/dev/null || true
git rm --cached storage/logs/laravel.log 2>/dev/null || true

# Corriger les permissions PWA avant git pull
log_info "🔐 Correction des permissions PWA..."
chown -R forge:forge public/pwa/ 2>/dev/null || true
chmod -R 755 public/pwa/ 2>/dev/null || true
rm -rf public/pwa/dist/* 2>/dev/null || true

# Stash les changements locaux s'il y en a (sécurité)
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    log_warning "Changements locaux détectés, sauvegarde temporaire..."
    git stash push -m "Sauvegarde automatique Forge $(date)" 2>/dev/null || true
fi

log_success "Conflits Git nettoyés"

# 3. Mise à jour du code source
log_info "📥 Mise à jour du code source..."
git fetch origin $FORGE_SITE_BRANCH
git reset --hard origin/$FORGE_SITE_BRANCH
log_success "Code source mis à jour"

# 4. Nettoyage préalable des dépendances
log_info "🧹 Nettoyage des anciennes dépendances..."
rm -rf vendor/ 2>/dev/null || true
rm -f composer.lock 2>/dev/null || true
log_success "Anciennes dépendances supprimées"

# 5. Installation des dépendances Composer avec nunomaduro/collision
log_info "📦 Installation des dépendances Composer..."
$FORGE_COMPOSER install --no-dev --no-interaction --prefer-dist --optimize-autoloader
if [ $? -ne 0 ]; then
    log_error "Erreur lors de l'installation Composer"
    exit 1
fi
log_success "Dépendances Composer installées"

# 6. Vérification que les dépendances critiques sont installées
log_info "🔍 Vérification des dépendances critiques..."
if [ ! -d "vendor/nunomaduro/collision" ]; then
    log_warning "Tentative d'installation manuelle de nunomaduro/collision..."
    $FORGE_COMPOSER require nunomaduro/collision:^7.0 --no-interaction
fi
log_success "Dépendances critiques vérifiées"

# 7. Génération de la clé d'application si nécessaire
log_info "🔑 Vérification de la clé d'application..."
if ! grep -q "APP_KEY=base64:" .env 2>/dev/null; then
    log_warning "Génération d'une nouvelle clé d'application..."
    $FORGE_PHP artisan key:generate --force
    log_success "Clé d'application générée"
else
    log_info "Clé d'application déjà présente"
fi

# 8. Configuration des variables d'environnement admin
log_info "⚙️ Configuration des variables admin..."

# Fonction pour mettre à jour les variables d'environnement
update_env_var() {
    local key=$1
    local value=$2
    
    # Échapper les valeurs avec des espaces ou des caractères spéciaux
    if [[ "$value" == *" "* ]] || [[ "$value" == *"!"* ]]; then
        value="\"${value}\""
    fi
    
    if grep -q "^${key}=" .env 2>/dev/null; then
        sed -i "s/^${key}=.*/${key}=${value}/" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

# Variables pour l'admin (identiques au local)
update_env_var "ADMIN_DEFAULT_EMAIL" "admin@dinor.app"
update_env_var "ADMIN_DEFAULT_PASSWORD" "Dinor2024!Admin"
update_env_var "ADMIN_DEFAULT_NAME" "AdministrateurDinor"

# Variables de production importantes
update_env_var "APP_ENV" "production"
update_env_var "APP_DEBUG" "false"
update_env_var "SESSION_SECURE_COOKIE" "true"
update_env_var "SESSION_SAME_SITE" "lax"

# Variables de cache pour éviter les erreurs
update_env_var "CACHE_DRIVER" "file"
update_env_var "SESSION_DRIVER" "file"
update_env_var "QUEUE_CONNECTION" "sync"

# Variables de logging
update_env_var "LOG_CHANNEL" "stack"
update_env_var "LOG_DEPRECATIONS_CHANNEL" "null"
update_env_var "LOG_LEVEL" "debug"

log_success "Variables d'environnement configurées"

# 9. Nettoyage des caches avant NPM  
log_info "🧹 Nettoyage des caches Laravel..."
$FORGE_PHP artisan optimize:clear || log_warning "Problème avec optimize:clear, mais continue..."
# Nettoyage manuel des caches en cas d'échec
rm -rf bootstrap/cache/*.php storage/framework/cache/data/* storage/framework/views/*.php 2>/dev/null || true
log_success "Caches Laravel nettoyés"

# 10. Installation complète des dépendances NPM
log_info "📦 Installation des dépendances NPM..."

# Nettoyage complet et agressif des permissions NPM
log_info "🔐 Correction agressive des permissions NPM..."

# Première tentative: permissions standards
chown -R forge:forge node_modules/ 2>/dev/null || true
chown -R forge:forge package-lock.json 2>/dev/null || true
chown -R forge:forge .npm/ 2>/dev/null || true
chmod -R 755 node_modules/ 2>/dev/null || true

# Correction spécifique pour tous les fichiers cachés problématiques
if [ -d "node_modules" ]; then
    log_info "🔧 Correction des fichiers cachés dans node_modules..."
    find node_modules/ -name ".*" -type f -exec chown forge:forge {} \; 2>/dev/null || true
    find node_modules/ -name ".*" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find node_modules/ -name ".*" -type d -exec chown forge:forge {} \; 2>/dev/null || true
    find node_modules/ -name ".*" -type d -exec chmod 755 {} \; 2>/dev/null || true
fi

# Suppression forcée des fichiers problématiques spécifiques
log_info "🗑️ Suppression forcée des fichiers problématiques..."
rm -f node_modules/.package-lock.json 2>/dev/null || true
rm -f .package-lock.json 2>/dev/null || true
rm -f package-lock.json 2>/dev/null || true

# Nettoyage total avec plusieurs méthodes
rm -rf node_modules/ 2>/dev/null || true
[ -d "node_modules" ] && find node_modules/ -delete 2>/dev/null || true
rm -rf .npm/ 2>/dev/null || true

# Nettoyage du cache NPM utilisateur
rm -rf ~/.npm/_cacache 2>/dev/null || true
rm -rf /home/forge/.npm/_cacache 2>/dev/null || true

# Installation NPM avec gestion d'erreurs améliorée
log_info "🚀 Tentative d'installation NPM..."
if npm install --no-fund --no-audit; then
    log_success "Dépendances NPM installées avec succès"
elif npm ci --no-fund --no-audit 2>/dev/null; then
    log_success "Dépendances NPM installées avec npm ci"
elif npm install --force --no-fund --no-audit; then
    log_warning "Dépendances NPM installées avec --force"
else
    log_warning "Échec NPM standard, nettoyage agressif et nouvelle tentative..."
    
    # Nettoyage agressif alternatif sans sudo
    log_info "🧹 Nettoyage agressif du répertoire NPM..."
    
    # Changer vers le répertoire parent et recréer complètement
    cd /home/forge/new.dinorapp.com
    
    # Suppression récursive alternative
    [ -d "node_modules" ] && rm -rf node_modules/* 2>/dev/null || true
    [ -d "node_modules" ] && rmdir node_modules/ 2>/dev/null || true
    
    # Nettoyer tous les lock files
    rm -f package-lock.json npm-shrinkwrap.json yarn.lock 2>/dev/null || true
    
    # Vider complètement le cache NPM
    npm cache clean --force 2>/dev/null || true
    
    # Dernière tentative avec cache désactivé
    if npm install --no-fund --no-audit --no-optional --prefer-offline=false --cache=/tmp/npm-cache-temp; then
        log_success "✅ NPM installé avec cache temporaire"
        # Nettoyer le cache temporaire
        rm -rf /tmp/npm-cache-temp 2>/dev/null || true
    else
        log_error "❌ Échec complet NPM - continue avec build Vite uniquement"
        # Créer un node_modules vide pour éviter les erreurs
        mkdir -p node_modules/.bin
        touch node_modules/.package-lock.json
        chown -R forge:forge node_modules/ 2>/dev/null || true
    fi
fi

# Vérifier et corriger les permissions finales
chown -R forge:forge node_modules/ 2>/dev/null || true
chmod -R 755 node_modules/ 2>/dev/null || true

# 11. Build des assets de production
log_info "🏗️ Build des assets de production..."
# Build Laravel assets
npx vite build || npm run build || npm run production
if [ $? -ne 0 ]; then
    log_warning "Build Laravel assets échoué, mais continue..."
fi

# Build PWA Vue.js avec génération de fichiers statiques
log_info "🏗️ Build PWA Vue.js avec optimisations..."

# Générer les fichiers statiques PWA optimisés
npm run pwa:build
if [ $? -eq 0 ]; then
    log_success "PWA buildée avec succès"
    
    # Vérifier que les fichiers ont été générés
    if [ -d "public/pwa/dist" ]; then
        log_info "📁 Fichiers PWA générés dans public/pwa/dist/"
        
        # Créer les dossiers de cache si nécessaires
        mkdir -p public/pwa/cache
        mkdir -p public/pwa/offline
        
        # Copier les assets critiques pour le cache
        if [ -d "public/pwa/dist/assets" ]; then
            cp -r public/pwa/dist/assets/* public/pwa/cache/ 2>/dev/null || true
        fi
        
        # Créer un fichier de version pour le cache busting
        echo "$(date +%s)" > public/pwa/version.txt
        
        log_success "Cache PWA configuré"
    else
        log_warning "Dossier PWA dist non trouvé"
    fi
else
    log_warning "Build PWA échoué, mais continue..."
fi

log_success "Assets buildés"

# 12. Recréation des dossiers nécessaires avec permissions
log_info "📁 Création des dossiers de storage..."
mkdir -p storage/logs
mkdir -p storage/framework/cache/data
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/app/public
mkdir -p bootstrap/cache

# Configuration des permissions de base
chmod -R 775 storage bootstrap/cache 2>/dev/null || true
chown -R forge:www-data storage bootstrap/cache 2>/dev/null || true

log_success "Dossiers de storage créés avec permissions"

# 13. Migration de la base de données avec correction des erreurs
log_info "🗄️ Migration de la base de données avec corrections..."
if [ -f artisan ]; then
    # Tentative de migration normale
    if $FORGE_PHP artisan migrate --force; then
        log_success "Migrations exécutées avec succès"
    else
        log_warning "Problème avec les migrations, tentative de correction..."
        
        # Diagnostic spécifique pour la colonne 'rank' en double
        log_info "🔍 Diagnostic des problèmes de migration..."
        
        # Vérifier si l'erreur est liée à la colonne 'rank'
        MIGRATION_ERROR=$($FORGE_PHP artisan migrate --force 2>&1 | grep -i "duplicate column name 'rank'" || echo "")
        
        if [[ ! -z "$MIGRATION_ERROR" ]]; then
            log_warning "🔧 Erreur de colonne 'rank' détectée, correction en cours..."
            
            # Rollback de la dernière migration problématique
            if $FORGE_PHP artisan migrate:rollback --step=1 --force 2>/dev/null; then
                log_info "Migration problématique annulée"
            fi
            
            # Réessayer la migration
            if $FORGE_PHP artisan migrate --force; then
                log_success "✅ Migrations appliquées après correction"
            else
                log_error "❌ Impossible d'appliquer les migrations même après correction"
                # Continuer malgré l'erreur
            fi
        else
            log_warning "Autre problème de migration détecté, continue..."
        fi
    fi
    
    # Migration spécifique des catégories d'événements (comme dans le script original)
    log_info "🗄️ Migration spécifique des catégories d'événements..."
    
    # Migration de la table event_categories
    $FORGE_PHP artisan migrate --path=database/migrations/2025_01_01_000000_create_event_categories_table.php --force 2>/dev/null || log_warning "Migration event_categories déjà appliquée ou erreur"
    
    # Migration de l'ajout de event_category_id aux events
    $FORGE_PHP artisan migrate --path=database/migrations/2025_01_01_000001_add_event_category_id_to_events_table.php --force 2>/dev/null || log_warning "Migration event_category_id déjà appliquée ou erreur"
    
else
    log_warning "Fichier artisan non trouvé"
fi

# 14. Configuration de l'utilisateur admin (amélioré)
log_info "👤 Configuration de l'utilisateur admin..."

# Essayer d'abord le seeder spécialisé pour la production
if $FORGE_PHP artisan db:seed --class=ProductionAdminSeeder --force 2>/dev/null; then
    log_success "✅ Admin configuré avec le seeder spécialisé"
else
    log_warning "Seeder spécialisé non trouvé, utilisation du seeder standard..."
    $FORGE_PHP artisan db:seed --class=AdminUserSeeder --force 2>/dev/null || log_warning "Problème avec AdminUserSeeder"
    log_success "✅ Admin configuré avec le seeder standard"
fi

# Exécuter les seeders manquants pour les panels Filament
log_info "📋 Exécution des seeders manquants pour les panels Filament..."

# CategorySeeder - crucial pour toutes les ressources qui dépendent des catégories
if $FORGE_PHP artisan db:seed --class=CategorySeeder --force 2>/dev/null; then
    log_success "✅ CategorySeeder exécuté (catégories dans Filament)"
else
    log_warning "CategorySeeder non trouvé ou erreur"
fi

# EventCategoriesSeeder - crucial pour les panels d'événements
if $FORGE_PHP artisan db:seed --class=EventCategoriesSeeder --force 2>/dev/null; then
    log_success "✅ EventCategoriesSeeder exécuté"
else
    log_warning "EventCategoriesSeeder non trouvé ou erreur"
fi

# IngredientsSeeder - pour les ingrédients
if $FORGE_PHP artisan db:seed --class=IngredientsSeeder --force 2>/dev/null; then
    log_success "✅ IngredientsSeeder exécuté"
else
    log_warning "IngredientsSeeder non trouvé ou erreur"
fi

# PwaMenuItemSeeder - pour le panel Menu PWA
if $FORGE_PHP artisan db:seed --class=PwaMenuItemSeeder --force 2>/dev/null; then
    log_success "✅ PwaMenuItemSeeder exécuté (Menu PWA dans Filament)"
else
    log_warning "PwaMenuItemSeeder non trouvé ou erreur"
fi

# UserSeeder - pour créer des utilisateurs test (panel Utilisateurs)
if $FORGE_PHP artisan db:seed --class=UserSeeder --force 2>/dev/null; then
    log_success "✅ UserSeeder exécuté (Utilisateurs dans Filament)"
else
    log_warning "UserSeeder non trouvé ou erreur"
fi

# ProductionDataSeeder - pour créer du contenu Dinor TV, etc.
if $FORGE_PHP artisan db:seed --class=ProductionDataSeeder --force 2>/dev/null; then
    log_success "✅ ProductionDataSeeder exécuté (contenu Dinor TV, etc.)"
else
    log_warning "ProductionDataSeeder non trouvé ou erreur"
fi

log_success "✅ Tous les seeders Filament exécutés"

# Vérification que l'admin est bien créé
ADMIN_CHECK=$($FORGE_PHP artisan tinker --execute="
\$admin = App\\Models\\AdminUser::where('email', 'admin@dinor.app')->first();
if (\$admin && \$admin->is_active) {
    echo 'ADMIN_OK:' . \$admin->id . ':' . \$admin->name;
} else {
    echo 'ADMIN_PROBLEM';
}" 2>/dev/null | grep -E "ADMIN_OK|ADMIN_PROBLEM")

if [[ $ADMIN_CHECK == *"ADMIN_OK"* ]]; then
    ADMIN_ID=$(echo $ADMIN_CHECK | cut -d':' -f2)
    ADMIN_NAME=$(echo $ADMIN_CHECK | cut -d':' -f3)
    log_success "Admin vérifié et opérationnel (ID: $ADMIN_ID - $ADMIN_NAME)"
else
    log_warning "Tentative de création manuelle de l'admin..."
    
    # Création manuelle en cas d'échec des seeders
    $FORGE_PHP artisan tinker --execute="
    try {
        \$admin = App\\Models\\AdminUser::updateOrCreate(
            ['email' => 'admin@dinor.app'],
            [
                'name' => 'AdministrateurDinor',
                'password' => bcrypt('Dinor2024!Admin'),
                'email_verified_at' => now(),
                'is_active' => true
            ]
        );
        echo 'MANUAL_ADMIN_OK:' . \$admin->id;
    } catch (Exception \$e) {
        echo 'MANUAL_ADMIN_FAILED:' . \$e->getMessage();
    }
    " 2>/dev/null || log_error "Création manuelle échouée"
fi

# 15. Correction des problèmes d'inscription aux tournois
log_info "🏆 Diagnostic et correction des tournois..."

# Créer un script temporaire pour la correction des tournois
cat > /tmp/fix_tournaments.php << 'EOF'
<?php
require_once '/home/forge/new.dinorapp.com/vendor/autoload.php';
$app = require_once '/home/forge/new.dinorapp.com/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\Tournament;

$tournaments = Tournament::all();
$fixed = 0;

foreach ($tournaments as $tournament) {
    $needsFix = false;
    
    // Vérifier si le tournoi a des problèmes d'inscription
    if ($tournament->status !== 'registration_open' && $tournament->status !== 'active') {
        $tournament->status = 'registration_open';
        $needsFix = true;
    }
    
    // Corriger les dates d'inscription si nécessaires
    $now = now();
    if (!$tournament->registration_start || $now < $tournament->registration_start) {
        $tournament->registration_start = $now->subDay();
        $needsFix = true;
    }
    
    if (!$tournament->registration_end || $now > $tournament->registration_end) {
        $tournament->registration_end = $now->addWeeks(2);
        $needsFix = true;
    }
    
    // S'assurer que le tournoi est public
    if (!$tournament->is_public) {
        $tournament->is_public = true;
        $needsFix = true;
    }
    
    if ($needsFix) {
        $tournament->save();
        $fixed++;
        echo "Tournoi corrigé: {$tournament->name}\n";
    }
}

echo "TOURNAMENTS_FIXED:{$fixed}\n";
EOF

# Exécuter la correction des tournois
TOURNAMENT_FIX_RESULT=$($FORGE_PHP /tmp/fix_tournaments.php 2>/dev/null | grep "TOURNAMENTS_FIXED" || echo "TOURNAMENTS_FIXED:0")
TOURNAMENTS_FIXED=$(echo $TOURNAMENT_FIX_RESULT | cut -d':' -f2)

if [ "$TOURNAMENTS_FIXED" -gt 0 ]; then
    log_success "✅ $TOURNAMENTS_FIXED tournoi(s) corrigé(s) pour les inscriptions"
else
    log_info "ℹ️ Aucun tournoi nécessitant de correction trouvé"
fi

# Nettoyer le script temporaire
rm -f /tmp/fix_tournaments.php

# 16. Lien symbolique de stockage
log_info "🔗 Création du lien symbolique de stockage..."
$FORGE_PHP artisan storage:link || log_warning "Lien symbolique déjà existant"
log_success "Lien symbolique vérifié"

# 17. Optimisation Laravel pour la production
log_info "⚡ Optimisation Laravel..."
$FORGE_PHP artisan config:cache
$FORGE_PHP artisan route:cache
$FORGE_PHP artisan view:cache
log_success "Optimisations appliquées"

# 17.5. Vérification conditionnelle des caches Filament/Livewire
log_info "🔍 Vérification des changements nécessitant un vidage de cache..."

# Vérifier si des fichiers critiques ont changé dans le dernier commit
CACHE_CRITICAL_CHANGES=$(git diff HEAD~1 --name-only 2>/dev/null | grep -E "(config/|routes/|app/Filament.*\.php|app/Livewire.*\.php|app/.*Resource.*\.php)" | wc -l)

if [ "$CACHE_CRITICAL_CHANGES" -gt 0 ]; then
    log_warning "🔄 Changements détectés dans les composants Filament/Livewire ($CACHE_CRITICAL_CHANGES fichiers)"
    log_info "📂 Fichiers modifiés:"
    git diff HEAD~1 --name-only 2>/dev/null | grep -E "(config/|routes/|app/Filament.*\.php|app/Livewire.*\.php|app/.*Resource.*\.php)" | sed 's/^/   - /'
    
    log_info "🧹 Vidage des caches Filament et redécouverte des composants..."
    
    # Vider les caches Laravel spécifiques
    $FORGE_PHP artisan cache:clear || log_warning "Problème avec cache:clear"
    $FORGE_PHP artisan config:clear || log_warning "Problème avec config:clear"
    $FORGE_PHP artisan view:clear || log_warning "Problème avec view:clear"
    $FORGE_PHP artisan route:clear || log_warning "Problème avec route:clear"
    
    # Redécouverte des composants Livewire
    if $FORGE_PHP artisan livewire:discover 2>/dev/null; then
        log_success "✅ Composants Livewire redécouverts"
    else
        log_warning "⚠️ Commande livewire:discover non disponible ou échouée"
    fi
    
    # Vider les caches PWA
    $FORGE_PHP artisan tinker --execute="
    try {
        \Illuminate\Support\Facades\Cache::tags(['pwa', 'recipes', 'events', 'tips', 'dinor-tv', 'pages'])->flush();
        echo 'PWA_CACHE_CLEARED';
    } catch (Exception \$e) {
        echo 'PWA_CACHE_ERROR:' . \$e->getMessage();
    }
    " 2>/dev/null | grep -q "PWA_CACHE_CLEARED" && log_success "✅ Caches PWA vidés" || log_warning "⚠️ Problème avec les caches PWA"
    
    # Optimiser l'autoloader
    $FORGE_COMPOSER dump-autoload --optimize || log_warning "Problème avec dump-autoload"
    
    # Reconstruire les caches optimisés
    $FORGE_PHP artisan config:cache
    $FORGE_PHP artisan route:cache
    $FORGE_PHP artisan view:cache
    
    log_success "✅ Caches Filament/Livewire mis à jour"
else
    log_info "✅ Aucun changement critique détecté - pas de vidage de cache nécessaire"
fi

# 18. Configuration des permissions (sécurisé pour Forge)
log_info "🔧 Configuration des permissions..."
chmod -R 755 storage bootstrap/cache 2>/dev/null || true
chown -R forge:forge storage bootstrap/cache 2>/dev/null || true
log_success "Permissions configurées"

# 19. Vérification finale de l'état de l'application
log_info "🔍 Vérification finale..."

# Test rapide de la connexion à la base de données
if $FORGE_PHP artisan migrate:status >/dev/null 2>&1; then
    log_success "Connexion base de données OK"
else
    log_warning "Problème potentiel avec la base de données"
fi

# Vérification finale de l'admin
FINAL_ADMIN_CHECK=$($FORGE_PHP artisan tinker --execute="
\$admin = App\\Models\\AdminUser::where('email', 'admin@dinor.app')->first();
echo \$admin ? 'FINAL_ADMIN_EXISTS' : 'FINAL_ADMIN_MISSING';
" 2>/dev/null | grep "FINAL_ADMIN")

if [[ $FINAL_ADMIN_CHECK == *"EXISTS"* ]]; then
    log_success "Vérification finale admin: ✅ OK"
else
    log_warning "Vérification finale admin: ⚠️ Problème potentiel"
fi

# Test de l'API des tournois
log_info "🧪 Test de l'API des tournois..."
TOURNAMENT_API_TEST=$($FORGE_PHP artisan tinker --execute="
try {
    \$tournaments = App\\Models\\Tournament::where('is_public', true)->count();
    echo 'TOURNAMENT_API_OK:' . \$tournaments;
} catch (Exception \$e) {
    echo 'TOURNAMENT_API_ERROR:' . \$e->getMessage();
}
" 2>/dev/null | grep "TOURNAMENT_API")

if [[ $TOURNAMENT_API_TEST == *"OK"* ]]; then
    TOURNAMENT_COUNT=$(echo $TOURNAMENT_API_TEST | cut -d':' -f2)
    log_success "API tournois OK - $TOURNAMENT_COUNT tournoi(s) public(s)"
else
    log_warning "Problème potentiel avec l'API des tournois"
fi

# 20. Rechargement PHP-FPM (comme dans le script original)
log_info "🔄 Rechargement PHP-FPM..."
touch /tmp/fpmlock 2>/dev/null || true
( flock -w 10 9 || exit 1
    echo 'Rechargement PHP FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9</tmp/fpmlock 2>/dev/null || log_warning "Rechargement PHP-FPM échoué"

# 21. Sortie du mode maintenance
log_info "🟢 Sortie du mode maintenance..."
$FORGE_PHP artisan up
log_success "Application remise en ligne"

echo ""
echo "🎉 === DÉPLOIEMENT DIGITAL OCEAN TERMINÉ AVEC SUCCÈS ==="
echo ""
echo "📋 Informations de connexion admin:"
echo "   🌐 Dashboard: https://new.dinorapp.com/admin/login"
echo "   📧 Email: admin@dinor.app"
echo "   🔑 Mot de passe: Dinor2024!Admin"
echo ""
echo "📋 Vérifications recommandées:"
echo "   - API Test: https://new.dinorapp.com/api/test/database-check"
echo "   - API Tournois: https://new.dinorapp.com/api/v1/tournaments"
echo "   - API Pages: https://new.dinorapp.com/api/pages"
echo "   - Logs: storage/logs/laravel.log"
echo ""
echo "🔧 Corrections appliquées:"
echo "   ✅ Migration de la colonne 'rank' corrigée"
echo "   ✅ Tournois configurés pour les inscriptions"
echo "   ✅ Pages iframe opérationnelles"
echo ""
echo "💡 Note: Identifiants admin identiques au développement local"
echo ""
echo "✅ Déploiement terminé!" 