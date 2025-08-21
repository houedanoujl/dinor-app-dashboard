/**
 * CONTENT_CAROUSEL.DART - CONVERSION FIDÈLE DE ContentCarousel.vue
 * 
 * FIDÉLITÉ VISUELLE :
 * - Section header avec titre Open Sans
 * - Bouton "Voir tout" avec icône chevron
 * - Carousel horizontal avec scroll smooth
 * - Cards de 280px de largeur identiques
 * - Gap de 16px entre les cards
 * - États loading et error identiques
 */

import 'package:flutter/material.dart';
import '../../services/navigation_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'section_header.dart';

class ContentCarousel extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final bool loading;
  final String? error;
  final String contentType;
  final String viewAllLink;
  final Function(Map<String, dynamic>) onItemClick;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final bool darkTheme;

  const ContentCarousel({
    Key? key,
    required this.title,
    required this.items,
    this.loading = false,
    this.error,
    required this.contentType,
    required this.viewAllLink,
    required this.onItemClick,
    required this.itemBuilder,
    this.darkTheme = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🎠 [ContentCarousel] Build: title=$title, items=${items.length}, loading=$loading, error=$error');
    
    return Container(
      padding: darkTheme ? const EdgeInsets.all(20) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header avec cartouche moderne
          SectionHeader(
            title: title,
            viewAllLink: viewAllLink,
            darkTheme: darkTheme,
          ),
          
          const SizedBox(height: 24),
          
          // Contenu du carousel avec hauteur réduite
          SizedBox(
            height: 200, // Hauteur réduite
            child: _buildCarouselContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselContent() {
    print('🎠 [ContentCarousel] _buildCarouselContent: loading=$loading, error=$error, items.isEmpty=${items.isEmpty}');
    
    // État de chargement - .carousel-loading CSS
    if (loading) {
      print('🎠 [ContentCarousel] Affichage état loading');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF6750A4),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement...',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Color(0xFF4A5568),
              ),
            ),
          ],
        ),
      );
    }

    // État d'erreur
    if (error != null) {
      print('🎠 [ContentCarousel] Affichage état erreur: $error');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 32,
              color: darkTheme ? Colors.white70 : const Color(0xFFF44336),
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: darkTheme ? Colors.white70 : const Color(0xFF4A5568),
              ),
            ),
          ],
        ),
      );
    }

    // État vide
    if (items.isEmpty) {
      print('🎠 [ContentCarousel] Affichage état vide - aucun item');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(),
              size: 32,
              color: darkTheme ? Colors.white70 : const Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun contenu disponible',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: darkTheme ? Colors.white70 : const Color(0xFF4A5568),
              ),
            ),
          ],
        ),
      );
    }

    // Carousel avec items - .carousel CSS identique
    print('🎠 [ContentCarousel] Affichage carousel avec ${items.length} items');
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(width: 16), // Gap identique
      itemBuilder: (context, index) {
        final item = items[index];
        return SizedBox(
          width: 200, // Largeur réduite pour s'adapter à la hauteur réduite
          child: GestureDetector(
            onTap: () => onItemClick(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.ease,
              child: itemBuilder(item),
            ),
          ),
        );
      },
    );
  }

  IconData _getEmptyIcon() {
    switch (contentType) {
      case 'recipes':
        return LucideIcons.chefHat;
      case 'tips':
        return LucideIcons.lightbulb;
      case 'events':
        return LucideIcons.calendar;
      case 'videos':
        return LucideIcons.playCircle;
      default:
        return LucideIcons.inbox;
    }
  }
}