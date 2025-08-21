import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class KenBurnsSlideshowService {
  /// Image unique pour l'effet Ken Burns
  static const List<String> _defaultImages = [
    'assets/images/01.jpg',
  ];
  
  /// Durée de l'animation Ken Burns (3 secondes)
  static const Duration _imageDuration = Duration(seconds: 3);
}

/// Widget diaporama Ken Burns animé
class KenBurnsSlideshowWidget extends StatefulWidget {
  final Duration totalDuration;
  final List<String> images;
  
  const KenBurnsSlideshowWidget({
    super.key,
    required this.totalDuration,
    this.images = KenBurnsSlideshowService._defaultImages,
  });
  
  @override
  State<KenBurnsSlideshowWidget> createState() => _KenBurnsSlideshowWidgetState();
}

class _KenBurnsSlideshowWidgetState extends State<KenBurnsSlideshowWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _kenBurnsController;
  
  final KenBurnsAnimation _animation = const KenBurnsAnimation(
    startScale: 1.1,
    endScale: 1.3,
    startOffset: Offset(-0.05, -0.05),
    endOffset: Offset(0.05, 0.05),
  );
  
  @override
  void initState() {
    super.initState();
    
    print('🎬 [KenBurnsSlideshow] Initialisation avec image unique');
    print('🎬 [KenBurnsSlideshow] Durée: ${widget.totalDuration.inMilliseconds}ms');
    
    // Animation Ken Burns (3 secondes)
    _kenBurnsController = AnimationController(
      duration: KenBurnsSlideshowService._imageDuration,
      vsync: this,
    );
    
    // Démarrer l'animation
    _startAnimation();
  }
  
  void _startAnimation() {
    print('🎬 [KenBurnsSlideshow] Démarrage de l\'animation Ken Burns');
    _kenBurnsController.forward();
  }
  
  @override
  void dispose() {
    _kenBurnsController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Affichage simple avec animation Ken Burns sur image unique
    final currentImagePath = widget.images[0]; // Toujours la première image
    
    print('🧡 [KenBurnsSlideshow] 🎭 Affichage image: $currentImagePath');
    
    return Container(
      key: const ValueKey('ken_burns_container'), // Clé unique
      width: double.infinity,
      height: double.infinity,
      child: AnimatedBuilder(
        animation: _kenBurnsController,
        builder: (context, child) {
          final scale = Tween<double>(
            begin: _animation.startScale,
            end: _animation.endScale,
          ).animate(CurvedAnimation(
            parent: _kenBurnsController,
            curve: Curves.easeInOut,
          )).value;
          
          final offset = Tween<Offset>(
            begin: _animation.startOffset,
            end: _animation.endOffset,
          ).animate(CurvedAnimation(
            parent: _kenBurnsController,
            curve: Curves.easeInOut,
          )).value;
          
          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(
                offset.dx * MediaQuery.of(context).size.width * 0.1,
                offset.dy * MediaQuery.of(context).size.height * 0.1,
              ),
              child: Image.asset(
                currentImagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('❌ [KenBurnsSlideshow] Erreur chargement image: $error');
                  return Container(
                    color: Colors.red,
                    child: const Center(
                      child: Icon(Icons.error, color: Colors.white, size: 48),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Classe pour définir les paramètres d'animation Ken Burns
class KenBurnsAnimation {
  final double startScale;
  final double endScale;
  final Offset startOffset;
  final Offset endOffset;
  
  const KenBurnsAnimation({
    required this.startScale,
    required this.endScale,
    required this.startOffset,
    required this.endOffset,
  });
}