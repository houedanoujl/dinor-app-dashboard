import '../services/navigation_service.dart';
/**
 * EVENT_DETAIL_SCREEN_UNIFIED.DART - VERSION UNIFIÉE DU DÉTAIL ÉVÉNEMENT
 * - Utilise les nouveaux composants unifiés
 * - Interface cohérente avec les autres types de contenu
 * - Pagination des commentaires intégrée
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Components unifiés
import '../components/common/unified_content_header.dart';
import '../components/common/unified_video_player.dart';
import '../components/common/unified_comments_section.dart';
import '../components/common/unified_content_actions.dart';

// Services
import '../services/api_service.dart';
import '../services/share_service.dart';
import '../services/likes_service.dart';
import '../composables/use_auth_handler.dart';

class EventDetailScreenUnified extends ConsumerStatefulWidget {
  final String id;
  
  const EventDetailScreenUnified({super.key, required this.id});

  @override
  ConsumerState<EventDetailScreenUnified> createState() => _EventDetailScreenUnifiedState();
}

class _EventDetailScreenUnifiedState extends ConsumerState<EventDetailScreenUnified> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _event;
  bool _loading = true;
  String? _error;
  bool _userLiked = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  Future<void> _loadEventDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final data = await apiService.get('/events/${widget.id}');

      if (data['success'] == true) {
        print('📅 [EventDetailUnified] Données reçues: ${data['data']}');
        setState(() {
          _event = data['data'];
          _loading = false;
        });
        await _checkUserLike();
      } else {
        throw Exception(data['message'] ?? 'Erreur lors du chargement de l\'événement');
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _checkUserLike() async {
    if (_event != null) {
      final likesState = ref.read(likesProvider);
      final isLiked = likesState.getLikes('event', widget.id)?.isLiked ?? false;
      setState(() => _userLiked = isLiked);
    }
  }

  Future<void> _handleLikeAction() async {
    final authState = ref.read(useAuthHandlerProvider);
    
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour liker cet événement'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final success = await ref.read(likesProvider.notifier).toggleLike('event', widget.id);
      
      if (success) {
        setState(() => _userLiked = !_userLiked);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_userLiked ? '❤️ Événement ajouté aux favoris' : '💔 Événement retiré des favoris'),
            backgroundColor: const Color(0xFFE53E3E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      print('❌ [EventDetailUnified] Erreur parsing date: $dateString');
      return dateString;
    }
  }

  String _getEventDate() {
    if (_event == null) return '';
    
    // Essayer différents champs possibles pour la date
    final possibleDateFields = ['date', 'event_date', 'start_date', 'scheduled_date'];
    for (final field in possibleDateFields) {
      final value = _event![field];
      if (value != null && value.toString().isNotEmpty) {
        print('📅 [EventDetailUnified] Date trouvée dans $field: $value');
        return _formatDate(value.toString());
      }
    }
    
    print('⚠️ [EventDetailUnified] Aucune date trouvée dans: ${_event!.keys.toList()}');
    return '';
  }

  String _getEventTime() {
    if (_event == null) return '';
    
    // Essayer différents champs possibles pour l'heure
    final possibleTimeFields = ['time', 'event_time', 'start_time', 'scheduled_time'];
    for (final field in possibleTimeFields) {
      final value = _event![field];
      if (value != null && value.toString().isNotEmpty) {
        print('🕐 [EventDetailUnified] Heure trouvée dans $field: $value');
        return _formatTime(value.toString());
      }
    }
    
    print('⚠️ [EventDetailUnified] Aucune heure trouvée dans: ${_event!.keys.toList()}');
    return 'Non défini';
  }

  String _formatTime(String timeString) {
    // Si c'est déjà au bon format (HH:mm), le retourner
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(timeString)) {
      return timeString;
    }
    
    // Essayer de parser comme DateTime ISO pour extraire l'heure
    try {
      final dateTime = DateTime.parse(timeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // Si ce n'est pas parsable, retourner tel quel
      return timeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_loading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_event == null) {
      return _buildNotFoundState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Hero Image avec composant unifié
          SliverToBoxAdapter(
            child: UnifiedContentHeader(
              imageUrl: _event!['image'] ?? _event!['thumbnail'] ?? '',
              contentType: 'event',
              customOverlay: Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    if (_event!['category'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4D03F).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _event!['category']['name'] ?? _event!['category'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu de l'événement
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Stats avec composant unifié
                  UnifiedContentStats(
                    stats: [
                      {
                        'icon': LucideIcons.calendar,
                        'text': _getEventDate(),
                      },
                      {
                        'icon': LucideIcons.clock,
                        'text': _getEventTime(),
                      },
                      {
                        'icon': LucideIcons.heart,
                        'text': '${_event!['likes_count'] ?? 0}',
                      },
                      {
                        'icon': LucideIcons.messageCircle,
                        'text': '${_event!['comments_count'] ?? 0}',
                      },
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Titre de l'événement
                  Text(
                    _event!['title'] ?? 'Sans titre',
                    style: const TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (_event!['description'] != null && _event!['description'].isNotEmpty) ...[
                    _buildSection(
                      'Description',
                      Text(
                        _event!['description'],
                        style: const TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 16,
                          color: Color(0xFF4A5568),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Vidéo de l'événement
                  if (_event!['video_url'] != null) ...[
                    _buildSection(
                      'Vidéo de l\'événement',
                      UnifiedVideoPlayer(
                        videoUrl: _event!['video_url'],
                        title: 'Voir la vidéo de l\'événement',
                        subtitle: 'Appuyez pour ouvrir',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Détails de l'événement
                  _buildEventDetails(),
                  const SizedBox(height: 24),

                  // Actions avec composant unifié
                  UnifiedContentActions(
                    contentType: 'event',
                    contentId: widget.id,
                    title: _event!['title'] ?? 'Événement',
                    description: _event!['description'] ?? 'Découvrez cet événement : ${_event!['title']}',
                    shareUrl: 'https://new.dinorapp.com/events/${widget.id}',
                    imageUrl: _event!['image'] ?? _event!['thumbnail'],
                    initialLiked: _userLiked,
                    initialLikeCount: _event!['likes_count'] ?? 0,
                    onRefresh: _loadEventDetails,
                    isLoading: _loading,
                  ),

                  // Comments avec composant unifié
                  const SizedBox(height: 24),
                  UnifiedCommentsSection(
                    contentType: 'event',
                    contentId: widget.id,
                    contentTitle: _event!['title'] ?? 'Événement',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: () => NavigationService.pop(),
          heroTag: 'back_fab',
          backgroundColor: Colors.white,
          child: const Icon(LucideIcons.arrowLeft, color: Color(0xFF2D3748)),
        ),
        const SizedBox(height: 16),
        // Bouton Like flottant
        FloatingActionButton(
          onPressed: () => _handleLikeAction(),
          heroTag: 'like_fab',
          backgroundColor: _userLiked ? const Color(0xFFE53E3E) : Colors.white,
          child: Icon(
            _userLiked ? LucideIcons.heart : LucideIcons.heart,
            color: _userLiked ? Colors.white : const Color(0xFFE53E3E),
          ),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () {
            if (_event != null) {
              ref.read(shareServiceProvider).shareContent(
                type: 'event',
                id: widget.id,
                title: _event!['title'] ?? 'Événement',
                description: _event!['description'] ?? 'Découvrez cet événement',
                shareUrl: 'https://new.dinorapp.com/events/${widget.id}',
                imageUrl: _event!['image'] ?? _event!['thumbnail'],
              );
            }
          },
          heroTag: 'share_fab',
          backgroundColor: const Color(0xFFE53E3E),
          child: const Icon(LucideIcons.share2, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4D03F)),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement de l\'événement...',
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 16,
                color: Color(0xFF718096),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Erreur'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => NavigationService.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              size: 64,
              color: Color(0xFFE53E3E),
            ),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 14,
                color: Color(0xFF718096),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEventDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4D03F),
                foregroundColor: const Color(0xFF2D3748),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Center(
        child: Text(
          'Événement non trouvé',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 18,
            color: Color(0xFF2D3748),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _buildEventDetails() {
    final date = _getEventDate();
    final time = _getEventTime();
    final location = _event!['location'] ?? _event!['venue'] ?? '';
    final organizer = _event!['organizer'] ?? _event!['organiser'] ?? '';

    if (date.isEmpty && time == 'Non défini' && location.isEmpty && organizer.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails de l\'événement',
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          if (date.isNotEmpty) ...[
            _buildDetailRow(LucideIcons.calendar, 'Date', date),
            const SizedBox(height: 12),
          ],
          if (time != 'Non défini') ...[
            _buildDetailRow(LucideIcons.clock, 'Heure', time),
            const SizedBox(height: 12),
          ],
          if (location.isNotEmpty) ...[
            _buildDetailRow(LucideIcons.mapPin, 'Lieu', location),
            const SizedBox(height: 12),
          ],
          if (organizer.isNotEmpty) ...[
            _buildDetailRow(LucideIcons.user, 'Organisateur', organizer),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFF4D03F),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}