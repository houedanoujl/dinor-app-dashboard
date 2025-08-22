/// COMMENTS_SERVICE.DART - SERVICE DE GESTION DES COMMENTAIRES
/// 
/// FONCTIONNALITÉS :
/// - Récupération des commentaires par type de contenu (tips, recipes, events)
/// - Ajout de nouveaux commentaires avec authentification
/// - Mise en cache des commentaires pour performance
/// - Pagination et chargement progressif
/// - Gestion des erreurs et états de chargement
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import '../composables/use_auth_handler.dart';

class Comment {
  final String id;
  final String content;
  final String authorName;
  final String? authorAvatar;
  final DateTime createdAt;
  final bool isOwner;
  final int likesCount;
  final bool isLiked;

  Comment({
    required this.id,
    required this.content,
    required this.authorName,
    this.authorAvatar,
    required this.createdAt,
    this.isOwner = false,
    this.likesCount = 0,
    this.isLiked = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      authorName: json['author_name'] ?? json['user_name'] ?? 'Utilisateur anonyme',
      authorAvatar: json['author_avatar'] ?? json['user_avatar'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isOwner: json['is_owner'] ?? false,
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'created_at': createdAt.toIso8601String(),
      'is_owner': isOwner,
      'likes_count': likesCount,
      'is_liked': isLiked,
    };
  }
}

class CommentsState {
  final List<Comment> comments;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int currentPage;

  CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
  });

  CommentsState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class CommentsService extends StateNotifier<Map<String, CommentsState>> {
  static const String baseUrl = 'https://new.dinorapp.com/api/v1';
  static const int perPage = 10;
  final ApiService _apiService;
  final Ref _ref;

  CommentsService(this._apiService, this._ref) : super({});

  // Récupérer les commentaires pour un contenu spécifique
  Future<void> loadComments(String contentType, String contentId, {bool refresh = false}) async {
    final key = '${contentType}_$contentId';
    
    if (refresh) {
      state = {
        ...state,
        key: CommentsState(isLoading: true),
      };
    } else {
      final currentState = state[key] ?? CommentsState();
      if (currentState.isLoading) return;
      
      state = {
        ...state,
        key: currentState.copyWith(isLoading: true, error: null),
      };
    }

    try {
      print('📝 [CommentsService] Chargement des commentaires pour $contentType:$contentId');
      
      // Vérifier le cache d'abord (seulement si ce n'est pas un refresh)
      if (!refresh) {
        final cachedComments = await _getCachedComments(contentType, contentId);
        if (cachedComments.isNotEmpty) {
          state = {
            ...state,
            key: CommentsState(
              comments: cachedComments,
              isLoading: false,
              hasMore: false,
            ),
          };
          print('✅ [CommentsService] Commentaires chargés depuis le cache: ${cachedComments.length}');
          return;
        }
      }

      // Charger depuis l'API avec l'endpoint standard
      final result = await _apiService.get('/comments', params: {
        'type': contentType,
        'id': contentId,
        'per_page': perPage.toString(),
        'sort': 'desc', // Du plus récent au plus ancien
      });

      if (result['success'] == true) {
        final commentsData = result['data'] ?? result['comments'] ?? [];
        
        final comments = (commentsData as List)
            .whereType<Map<String, dynamic>>() // Vérification de type
            .map((json) => Comment.fromJson(json as Map<String, dynamic>))
            .toList();

        // Trier les commentaires du plus récent au plus ancien (au cas où l'API ne le ferait pas)
        comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Si c'est un refresh et que l'API retourne moins de commentaires que ce qu'on a localement,
        // préserver les commentaires locaux récents (protection contre les problèmes de synchronisation)
        List<Comment> finalComments = comments;
        if (refresh) {
          final currentState = state[key] ?? CommentsState();
          if (currentState.comments.isNotEmpty && comments.length < currentState.comments.length) {
            // Garder les commentaires locaux récents qui ne sont pas encore sur le serveur
            final localRecentComments = currentState.comments
                .where((local) => !comments.any((server) => server.id == local.id))
                .where((local) => local.createdAt.isAfter(DateTime.now().subtract(const Duration(minutes: 5))))
                .toList();
            
            if (localRecentComments.isNotEmpty) {
              finalComments = [...localRecentComments, ...comments];
              finalComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              print('🔄 [CommentsService] Préservation de ${localRecentComments.length} commentaires locaux récents');
            }
          }
        }

        // Mettre en cache seulement les commentaires validés par le serveur
        await _cacheComments(contentType, contentId, comments);

        state = {
          ...state,
          key: CommentsState(
            comments: finalComments,
            isLoading: false,
            hasMore: comments.length >= perPage,
          ),
        };

        print('✅ [CommentsService] Commentaires chargés: ${finalComments.length} (${comments.length} du serveur)');
      } else {
        throw Exception(result['error'] ?? 'Erreur de chargement');
      }
    } catch (e) {
      print('❌ [CommentsService] Erreur chargement commentaires: $e');
      state = {
        ...state,
        key: (state[key] ?? CommentsState()).copyWith(
          isLoading: false,
          error: 'Erreur de chargement des commentaires',
        ),
      };
    }
  }

  // Charger plus de commentaires (pagination)
  Future<void> loadMoreComments(String contentType, String contentId) async {
    final key = '${contentType}_$contentId';
    final currentState = state[key];
    
    if (currentState == null || !currentState.hasMore || currentState.isLoadingMore) {
      return;
    }

    state = {
      ...state,
      key: currentState.copyWith(isLoadingMore: true),
    };

    try {
      final nextPage = currentState.currentPage + 1;
      
      final result = await _apiService.get('/comments', params: {
        'type': contentType,
        'id': contentId,
        'page': nextPage.toString(),
        'per_page': perPage.toString(),
        'sort': 'desc', // Du plus récent au plus ancien
      });

      if (result['success'] == true) {
        final commentsData = result['data'] ?? result['comments'] ?? [];
        
        final newComments = (commentsData as List)
            .whereType<Map<String, dynamic>>() // Vérification de type
            .map((json) => Comment.fromJson(json as Map<String, dynamic>))
            .toList();

        // Trier les nouveaux commentaires
        newComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final allComments = [...currentState.comments, ...newComments];

        state = {
          ...state,
          key: currentState.copyWith(
            comments: allComments,
            isLoadingMore: false,
            hasMore: newComments.length >= perPage,
            currentPage: nextPage,
          ),
        };

        print('✅ [CommentsService] Commentaires additionnels chargés: ${newComments.length}');
      }
    } catch (e) {
      print('❌ [CommentsService] Erreur chargement commentaires supplémentaires: $e');
      state = {
        ...state,
        key: currentState.copyWith(isLoadingMore: false),
      };
    }
  }

  // Ajouter un nouveau commentaire
  Future<bool> addComment(String contentType, String contentId, String content, {String? authorName, String? authorEmail}) async {
    try {
      print('📝 [CommentsService] Ajout commentaire pour $contentType:$contentId');
      
      // Obtenir les informations de l'utilisateur connecté
      final authState = _ref.read(useAuthHandlerProvider);
      
      final body = {
        'type': contentType,
        'id': contentId,
        'content': content,
      };
      
      // Toujours ajouter author_name et author_email (requis par l'API)
      if (authState.isAuthenticated) {
        // Utilisateur connecté : utiliser ses vraies données
        body['author_name'] = authState.userName ?? 'Utilisateur';
        body['author_email'] = authState.userEmail ?? 'user@dinorapp.com';
        print('📝 [CommentsService] Commentaire d\'utilisateur connecté: ${authState.userName}');
      } else {
        // Utilisateur non connecté : utiliser les données fournies ou par défaut
        body['author_name'] = authorName ?? 'Utilisateur Anonyme';
        body['author_email'] = authorEmail ?? 'anonymous@dinorapp.com';
        print('📝 [CommentsService] Commentaire anonyme: ${body['author_name']}');
      }
      
      // Utiliser ApiService qui gère déjà l'authentification correctement
      final result = await _apiService.post('/comments', body);
      
      if (result['success'] == true) {
        // Créer un commentaire temporaire pour affichage immédiat
        final newComment = Comment(
          id: result['data']?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          content: content,
          authorName: authState.isAuthenticated ? (authState.userName ?? 'Utilisateur') : (authorName ?? 'Utilisateur Anonyme'),
          authorAvatar: null,
          createdAt: DateTime.now(),
          isOwner: true,
          likesCount: 0,
          isLiked: false,
        );

        // Ajouter le commentaire immédiatement à la liste locale
        final key = '${contentType}_$contentId';
        final currentState = state[key] ?? CommentsState();
        final updatedComments = [newComment, ...currentState.comments];
        
        state = {
          ...state,
          key: currentState.copyWith(comments: updatedComments),
        };

        // Recharger immédiatement depuis le serveur pour synchroniser
        Future.delayed(const Duration(milliseconds: 500), () async {
          try {
            await loadComments(contentType, contentId, refresh: true);
            print('✅ [CommentsService] Commentaires synchronisés depuis le serveur');
          } catch (e) {
            print('⚠️ [CommentsService] Erreur lors de la synchronisation: $e');
            // En cas d'échec de synchronisation, maintenir le commentaire local visible
            // et tenter une nouvelle synchronisation après 3 secondes
            Future.delayed(const Duration(seconds: 3), () async {
              try {
                await loadComments(contentType, contentId, refresh: true);
                print('✅ [CommentsService] Synchronisation de rattrapage réussie');
              } catch (e2) {
                print('⚠️ [CommentsService] Échec synchronisation de rattrapage: $e2');
              }
            });
          }
        });

        print('✅ [CommentsService] Commentaire ajouté avec succès (affichage immédiat)');
        return true;
      } else {
        final errorMsg = result['message'] ?? result['error'] ?? 'Erreur inconnue';
        print('❌ [CommentsService] Erreur API: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ [CommentsService] Erreur ajout commentaire: $e');
      return false;
    }
  }

  // Supprimer un commentaire
  Future<bool> deleteComment(String contentType, String contentId, String commentId) async {
    try {
      final result = await _apiService.delete('/comments/$commentId');

      if (result['success'] == true) {
        // Retirer le commentaire de la liste locale
        final key = '${contentType}_$contentId';
        final currentState = state[key];
        
        if (currentState != null) {
          final updatedComments = currentState.comments
              .where((comment) => comment.id != commentId)
              .toList();
          
          state = {
            ...state,
            key: currentState.copyWith(comments: updatedComments),
          };
        }
        
        print('✅ [CommentsService] Commentaire supprimé');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ [CommentsService] Erreur suppression commentaire: $e');
      return false;
    }
  }

  // Obtenir l'état des commentaires pour un contenu
  CommentsState getCommentsState(String contentType, String contentId) {
    final key = '${contentType}_$contentId';
    return state[key] ?? CommentsState();
  }

  // Méthodes privées pour le cache
  Future<List<Comment>> _getCachedComments(String contentType, String contentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'comments_${contentType}_$contentId';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        return jsonList.map((json) => Comment.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ [CommentsService] Erreur lecture cache: $e');
    }
    
    return [];
  }

  Future<void> _cacheComments(String contentType, String contentId, List<Comment> comments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'comments_${contentType}_$contentId';
      final jsonList = comments.map((comment) => comment.toJson()).toList();
      await prefs.setString(cacheKey, json.encode(jsonList));
    } catch (e) {
      print('❌ [CommentsService] Erreur mise en cache: $e');
    }
  }
}

// Provider pour le service de commentaires
final commentsServiceProvider = StateNotifierProvider<CommentsService, Map<String, CommentsState>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return CommentsService(apiService, ref);
});

// Provider helper pour obtenir l'état des commentaires d'un contenu spécifique
final commentsProvider = Provider.family<CommentsState, String>((ref, key) {
  final commentsState = ref.watch(commentsServiceProvider);
  return commentsState[key] ?? CommentsState();
});