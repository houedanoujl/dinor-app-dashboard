import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { useCacheStore } from './cache'
import { useAuthStore } from './auth'

export const useApiStore = defineStore('api', () => {
  // State
  const loading = ref(new Set())
  const errors = ref(new Map())
  const baseURL = ref(getBaseURL())
  
  // Cache store
  const cacheStore = useCacheStore()

  // Auth store
  const authStore = useAuthStore()

  function getBaseURL() {
    if (import.meta.env.DEV) {
      return '/api/v1'
    }
    return `${window.location.origin}/api/v1`
  }

  // Actions
  function setLoading(key, isLoading) {
    if (isLoading) {
      loading.value.add(key)
    } else {
      loading.value.delete(key)
    }
  }

  function setError(key, error) {
    if (error) {
      errors.value.set(key, error)
    } else {
      errors.value.delete(key)
    }
  }

  function isLoading(key) {
    return loading.value.has(key)
  }

  function getError(key) {
    return errors.value.get(key)
  }

  function clearError(key) {
    errors.value.delete(key)
  }

  async function request(endpoint, options = {}) {
    const cacheKey = `${endpoint}_${JSON.stringify(options)}`
    console.log('🌐 [API Store] Nouvelle requête:', { endpoint, options, cacheKey })
    
    // Vérifier le cache PWA d'abord (sauf pour POST/PUT/DELETE ou si forceRefresh est activé)
    if ((!options.method || options.method === 'GET') && !options.forceRefresh) {
      console.log('🔍 [API Store] Vérification du cache PWA...')
      const cached = await checkPWACache(endpoint, options)
      if (cached) {
        console.log('⚡ [API Store] Données trouvées dans le cache PWA:', cached)
        return cached
      } else {
        console.log('❌ [API Store] Aucune donnée dans le cache PWA')
      }
    } else if (options.forceRefresh) {
      console.log('🔄 [API Store] Rechargement forcé - cache ignoré')
    }

    setLoading(cacheKey, true)
    setError(cacheKey, null)

    try {
      const url = `${baseURL.value}${endpoint}`
      console.log('📡 [API Store] URL complète:', url)
      
      const config = {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          ...options.headers
        },
        ...options
      }
      
      // Ajouter le token d'authentification si disponible
      if (authStore.token) {
        config.headers.Authorization = `Bearer ${authStore.token}`
        console.log('🔐 [API Store] Token d\'authentification ajouté')
      }
      
      console.log('⚙️ [API Store] Configuration de la requête:', config)

      console.log('🚀 [API Store] Envoi de la requête fetch...')
      const response = await fetch(url, config)
      console.log('📩 [API Store] Réponse reçue:', { status: response.status, ok: response.ok })
      
      if (!response.ok) {
        console.error('❌ [API Store] Erreur HTTP:', response.status, response.statusText)
        
        // Gestion spécifique des erreurs 401 (non autorisé)
        if (response.status === 401) {
          console.warn('🔐 [API Store] Erreur 401 - Session expirée ou utilisateur non connecté')
          
          // Effacer l'authentification si elle existe
          if (authStore.token) {
            console.log('🗑️ [API Store] Suppression de la session expirée')
            authStore.clearAuth()
          }
          
          // Créer une erreur explicite pour guider l'utilisateur
          const authError = new Error('Vous devez être connecté pour effectuer cette action. Veuillez vous connecter ou créer un compte.')
          authError.type = 'AUTH_REQUIRED'
          authError.status = 401
          authError.actionRequired = 'LOGIN_OR_REGISTER'
          
          throw authError
        }
        
        // Pour les erreurs 422, on doit récupérer les détails de validation
        let errorData = null
        try {
          errorData = await response.json()
          console.log('📄 [API Store] Données d\'erreur détaillées:', errorData)
        } catch (jsonError) {
          console.warn('⚠️ [API Store] Impossible de parser les données d\'erreur JSON')
        }
        
        // Gestion des autres erreurs HTTP
        let errorMessage = `Erreur ${response.status}`
        
        switch (response.status) {
          case 403:
            errorMessage = 'Accès non autorisé. Vous n\'avez pas les permissions nécessaires.'
            break
          case 404:
            errorMessage = 'Ressource non trouvée.'
            break
          case 422:
            if (errorData?.message) {
              errorMessage = errorData.message
            } else {
              errorMessage = 'Données invalides. Veuillez vérifier vos informations.'
            }
            break
          case 429:
            errorMessage = 'Trop de requêtes. Veuillez patienter avant de réessayer.'
            break
          case 500:
            errorMessage = 'Erreur du serveur. Veuillez réessayer plus tard.'
            break
          case 503:
            errorMessage = 'Service temporairement indisponible. Veuillez réessayer plus tard.'
            break
          default:
            errorMessage = `Erreur de connexion (${response.status}). Veuillez vérifier votre connexion internet.`
        }
        
        const httpError = new Error(errorMessage)
        httpError.status = response.status
        httpError.type = 'HTTP_ERROR'
        
        // Ajouter les données d'erreur détaillées pour les erreurs de validation
        if (errorData) {
          httpError.response = { data: errorData }
        }
        
        throw httpError
      }

      console.log('🔄 [API Store] Parsing JSON...')
      const data = await response.json()
      console.log('✅ [API Store] Données JSON reçues:', data)
      
      // Mettre en cache les requêtes GET réussies dans le cache PWA
      if (!options.method || options.method === 'GET') {
        console.log('💾 [API Store] Mise en cache PWA...')
        await setPWACache(endpoint, data, options)
      }

      return data
    } catch (error) {
      console.error('💥 [API Store] Erreur lors de la requête:', error)
      setError(cacheKey, error.message)
      throw error
    } finally {
      setLoading(cacheKey, false)
      console.log('🏁 [API Store] Fin de la requête:', endpoint)
    }
  }

  // Fonction pour vérifier le cache PWA
  async function checkPWACache(endpoint, options = {}) {
    try {
      const key = `${endpoint}_${JSON.stringify(options.params || {})}`;
      
      const response = await fetch('/api/pwa/cache/get', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ key })
      });

      if (response.ok) {
        const result = await response.json();
        if (result.success && result.cached) {
          return result.data;
        }
      }
    } catch (error) {
      console.log('ℹ️ [API Store] Cache PWA non accessible:', error.message);
    }
    return null;
  }

  // Fonction pour mettre en cache dans la PWA
  async function setPWACache(endpoint, data, options = {}) {
    try {
      const key = `${endpoint}_${JSON.stringify(options.params || {})}`;
      const ttl = options.cacheTTL || 3600; // Utiliser le TTL de l'option ou 1h par défaut
      
      await fetch('/api/pwa/cache/set', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ key, value: data, ttl })
      });
    } catch (error) {
      // Cache PWA non disponible - c'est normal en développement
      console.log('ℹ️ [API Store] Cache PWA non accessible pour la sauvegarde');
    }
  }

  // Déterminer le type de contenu depuis l'endpoint
  function getContentType(endpoint) {
    if (endpoint.includes('/recipes')) return 'recipes'
    if (endpoint.includes('/tips')) return 'tips'
    if (endpoint.includes('/events')) return 'events'
    if (endpoint.includes('/dinor-tv')) return 'videos'
    if (endpoint.includes('/categories')) return 'categories'
    return null
  }

  // Extraire les paramètres pertinents pour le cache
  function extractParams(options) {
    const url = new URL(`http://example.com${options.url || ''}`)
    const params = {}
    
    for (const [key, value] of url.searchParams) {
      params[key] = value
    }
    
    return params
  }

  // Méthodes spécifiques
  async function get(endpoint, params = {}, options = {}) {
    const queryString = new URLSearchParams(params).toString()
    const fullEndpoint = queryString ? `${endpoint}?${queryString}` : endpoint
    return request(fullEndpoint, { ...options, method: 'GET' })
  }

  // Méthode GET qui force le rechargement sans cache
  async function getFresh(endpoint, params = {}, options = {}) {
    const queryString = new URLSearchParams(params).toString()
    const fullEndpoint = queryString ? `${endpoint}?${queryString}` : endpoint
    // Invalider le cache avant de faire la requête
    invalidateCache(endpoint)
    return request(fullEndpoint, { ...options, method: 'GET', forceRefresh: true })
  }

  async function post(endpoint, data, options = {}) {
    return request(endpoint, {
      ...options,
      method: 'POST',
      body: JSON.stringify(data)
    })
  }

  async function put(endpoint, data, options = {}) {
    return request(endpoint, {
      ...options,
      method: 'PUT',
      body: JSON.stringify(data)
    })
  }

  async function del(endpoint, options = {}) {
    return request(endpoint, {
      ...options,
      method: 'DELETE'
    })
  }

  // Invalider le cache pour un pattern donné
  function invalidateCache(pattern) {
    const cacheInfo = cacheStore.getCacheInfo()
    const keysToRemove = cacheInfo.keys.filter(key => 
      key.includes(pattern) || new RegExp(pattern).test(key)
    )
    
    keysToRemove.forEach(key => cacheStore.remove(key))
  }

  // Précharger des données
  async function preload(endpoints) {
    const promises = endpoints.map(({ endpoint, params, options }) => 
      get(endpoint, params, { ...options, priority: 'low' }).catch(() => null)
    )
    
    return Promise.allSettled(promises)
  }

  return {
    // State
    loading,
    errors,
    baseURL,
    
    // Getters
    isLoading,
    getError,
    
    // Actions
    setLoading,
    setError,
    clearError,
    request,
    get,
    getFresh,
    post,
    put,
    del,
    invalidateCache,
    preload
  }
})