import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import '../composables/use_auth_handler.dart';

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService(ref.read(apiServiceProvider));
});

class ShareService {
  final ApiService _apiService;

  ShareService(this._apiService);

  /// Récupérer les données de partage depuis l'API
  Future<Map<String, dynamic>?> _getShareData({
    required String type,
    required String id,
    String? platform,
  }) async {
    try {
      print('📡 [ShareService] Récupération données de partage: $type/$id');
      
      final shareData = await _apiService.getCompleteShareData(
        type: type,
        id: id,
        platform: platform,
      );
      
      if (shareData != null) {
        print('✅ [ShareService] Données de partage récupérées: ${shareData['url']}');
        return shareData;
      } else {
        print('❌ [ShareService] Impossible de récupérer les données de partage');
        return null;
      }
    } catch (error) {
      print('💥 [ShareService] Erreur récupération données de partage: $error');
      return null;
    }
  }

  /// Tracker le partage dans l'API
  Future<void> _trackShare({
    required String type,
    required String id,
    required String platform,
  }) async {
    try {
      await _apiService.trackShare(
        type: type,
        id: id,
        platform: platform,
      );
      print('✅ [ShareService] Partage tracké: $type/$id sur $platform');
    } catch (error) {
      print('❌ [ShareService] Erreur tracking partage: $error');
    }
  }

  /// Partage natif via l'API système avec URL depuis l'API
  Future<void> shareContent({
    required String type,
    required String id,
    required String title,
    String? description,
    String? shareUrl,
    String? imageUrl,
  }) async {
    try {
      print('📤 [ShareService] Partage natif: $title');
      
      final shareData = await _getShareData(type: type, id: id);
      final urlToShare = shareData?['url'] as String? ?? shareUrl;
      final textToShare = shareData?['description'] as String? ?? description ?? title;

      if (urlToShare != null) {
        await Share.share(
          '$title\n\n$textToShare\n\n$urlToShare',
          subject: title,
        );
        await _trackShare(type: type, id: id, platform: 'native');
        print('✅ [ShareService] Partage réussi');
      } else {
        print('❌ [ShareService] Aucune URL de partage disponible');
      }
    } catch (error) {
      print('❌ [ShareService] Erreur partage: $error');
      rethrow;
    }
  }

  /// Partage via WhatsApp avec URL depuis l'API
  Future<void> shareToWhatsApp({
    required String title,
    required String text,
    String? url,
    String? type,
    String? id,
  }) async {
    try {
      print('📱 [ShareService] Partage WhatsApp: $title');
      
      // Si on a un type et un ID, récupérer l'URL depuis l'API
      if (type != null && id != null) {
        final shareData = await _getShareData(type: type, id: id, platform: 'whatsapp');
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          text = shareData['description'] as String? ?? text;
        }
      }
      
      String shareText = '$title\n\n$text';
      if (url != null) {
        shareText += '\n\n$url';
      }
      
      final whatsappUrl = 'whatsapp://send?text=${Uri.encodeComponent(shareText)}';
      
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
        print('✅ [ShareService] Partage WhatsApp lancé');
        
        // Tracker le partage
        if (type != null && id != null) {
          await _trackShare(type: type, id: id, platform: 'whatsapp');
        }
      } else {
        // Fallback au partage natif
        await shareContent(
          type: type ?? 'unknown', 
          id: id ?? '0', 
          title: title, 
          description: text, 
          shareUrl: url,
        );
      }
    } catch (error) {
      print('❌ [ShareService] Erreur partage WhatsApp: $error');
      // Fallback au partage natif
      await shareContent(
        type: type ?? 'unknown', 
        id: id ?? '0', 
        title: title, 
        description: text, 
        shareUrl: url,
      );
    }
  }

  /// Partage via Facebook avec URL depuis l'API
  Future<void> shareToFacebook({
    required String title,
    required String url,
    String? text,
    String? type,
    String? id,
  }) async {
    try {
      print('📘 [ShareService] Partage Facebook: $title');
      
      // Si on a un type et un ID, récupérer l'URL depuis l'API
      if (type != null && id != null) {
        final shareData = await _getShareData(type: type, id: id, platform: 'facebook');
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          text = shareData['description'] as String? ?? text;
        }
      }
      
      if (url == null) {
        print('❌ [ShareService] URL requise pour Facebook');
        return;
      }
      
      final facebookUrl = 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}';
      
      if (await canLaunchUrl(Uri.parse(facebookUrl))) {
        await launchUrl(Uri.parse(facebookUrl));
        print('✅ [ShareService] Partage Facebook lancé');
        
        // Tracker le partage
        if (type != null && id != null) {
          await _trackShare(type: type, id: id, platform: 'facebook');
        }
      } else {
        // Fallback au partage natif
        await shareContent(
          type: type ?? 'unknown', 
          id: id ?? '0', 
          title: title, 
          description: text ?? 'Découvrez ceci sur Dinor', 
          shareUrl: url,
        );
      }
    } catch (error) {
      print('❌ [ShareService] Erreur partage Facebook: $error');
      // Fallback au partage natif
      await shareContent(
        type: type ?? 'unknown', 
        id: id ?? '0', 
        title: title, 
        description: text ?? 'Découvrez ceci sur Dinor', 
        shareUrl: url,
      );
    }
  }

  /// Partage via Twitter/X avec URL depuis l'API
  Future<void> shareToTwitter({
    required String title,
    required String url,
    String? text,
    String? type,
    String? id,
  }) async {
    try {
      print('🐦 [ShareService] Partage Twitter: $title');
      
      // Si on a un type et un ID, récupérer l'URL depuis l'API
      if (type != null && id != null) {
        final shareData = await _getShareData(type: type, id: id, platform: 'twitter');
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          text = shareData['description'] as String? ?? text;
        }
      }
      
      String shareText = '$title $url';
      if (text != null) {
        shareText = '$text $url';
      }
      
      final twitterUrl = 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareText)}';
      
      if (await canLaunchUrl(Uri.parse(twitterUrl))) {
        await launchUrl(Uri.parse(twitterUrl));
        print('✅ [ShareService] Partage Twitter lancé');
        
        // Tracker le partage
        if (type != null && id != null) {
          await _trackShare(type: type, id: id, platform: 'twitter');
        }
      } else {
        // Fallback au partage natif
        await shareContent(
          type: type ?? 'unknown', 
          id: id ?? '0', 
          title: title, 
          description: text ?? 'Découvrez ceci sur Dinor', 
          shareUrl: url,
        );
      }
    } catch (error) {
      print('❌ [ShareService] Erreur partage Twitter: $error');
      // Fallback au partage natif
      await shareContent(
        type: type ?? 'unknown', 
        id: id ?? '0', 
        title: title, 
        description: text ?? 'Découvrez ceci sur Dinor', 
        shareUrl: url,
      );
    }
  }

  /// Partage via Email avec URL depuis l'API
  Future<void> shareViaEmail({
    required String title,
    required String url,
    String? text,
    String? type,
    String? id,
  }) async {
    try {
      print('📧 [ShareService] Partage Email: $title');
      
      // Si on a un type et un ID, récupérer l'URL depuis l'API
      if (type != null && id != null) {
        final shareData = await _getShareData(type: type, id: id, platform: 'email');
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          text = shareData['description'] as String? ?? text;
        }
      }
      
      final subject = title;
      final body = '${text ?? 'Découvrez ceci sur Dinor'}\n\n$url';
      final mailtoUrl = 'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      
      if (await canLaunchUrl(Uri.parse(mailtoUrl))) {
        await launchUrl(Uri.parse(mailtoUrl));
        print('✅ [ShareService] Partage Email lancé');
        
        // Tracker le partage
        if (type != null && id != null) {
          await _trackShare(type: type, id: id, platform: 'email');
        }
      } else {
        // Fallback au partage natif
        await shareContent(
          type: type ?? 'unknown', 
          id: id ?? '0', 
          title: title, 
          description: text ?? 'Découvrez ceci sur Dinor', 
          shareUrl: url,
        );
      }
    } catch (error) {
      print('❌ [ShareService] Erreur partage Email: $error');
      // Fallback au partage natif
      await shareContent(
        type: type ?? 'unknown', 
        id: id ?? '0', 
        title: title, 
        description: text ?? 'Découvrez ceci sur Dinor', 
        shareUrl: url,
      );
    }
  }

  /// Partage via SMS avec URL depuis l'API
  Future<void> shareViaSMS({
    required String title,
    required String url,
    String? text,
    String? type,
    String? id,
  }) async {
    try {
      print('💬 [ShareService] Partage SMS: $title');
      
      // Si on a un type et un ID, récupérer l'URL depuis l'API
      if (type != null && id != null) {
        final shareData = await _getShareData(type: type, id: id, platform: 'sms');
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          text = shareData['description'] as String? ?? text;
        }
      }
      
      String smsText = '$title\n\n${text ?? 'Découvrez ceci sur Dinor'}\n\n$url';
      final smsUrl = 'sms:?body=${Uri.encodeComponent(smsText)}';
      
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
        print('✅ [ShareService] Partage SMS lancé');
        
        // Tracker le partage
        if (type != null && id != null) {
          await _trackShare(type: type, id: id, platform: 'sms');
        }
      } else {
        // Fallback au partage natif
        await shareContent(
          type: type ?? 'unknown', 
          id: id ?? '0', 
          title: title, 
          description: text ?? 'Découvrez ceci sur Dinor', 
          shareUrl: url,
        );
      }
    } catch (error) {
      print('❌ [ShareService] Erreur partage SMS: $error');
      // Fallback au partage natif
      await shareContent(
        type: type ?? 'unknown', 
        id: id ?? '0', 
        title: title, 
        description: text ?? 'Découvrez ceci sur Dinor', 
        shareUrl: url,
      );
    }
  }

  /// Copier dans le presse-papier
  Future<bool> copyToClipboard(String text) async {
    try {
      print('📋 [ShareService] Copie dans le presse-papiers: $text');
      
      await Clipboard.setData(ClipboardData(text: text));
      print('✅ [ShareService] Texte copié');
      return true;
    } catch (error) {
      print('❌ [ShareService] Erreur copie presse-papiers: $error');
      return false;
    }
  }

  /// Partage de recette avec formatage spécial et URL depuis l'API
  Future<void> shareRecipe({
    required String title,
    required String description,
    required String url,
    String? imageUrl,
    String? cookingTime,
    String? servings,
    String? type = 'recipe',
    String? id,
  }) async {
    try {
      print('🍳 [ShareService] Partage recette: $title');
      
      // Si on a un ID, récupérer l'URL depuis l'API
      if (id != null) {
        final shareData = await _getShareData(type: type!, id: id);
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          description = shareData['description'] as String? ?? description;
          imageUrl = shareData['image'] as String? ?? imageUrl;
        }
      }
      
      String shareText = '$title\n\n';
      
      if (description.isNotEmpty) {
        shareText += '$description\n\n';
      }
      
      if (cookingTime != null) {
        shareText += '⏱️ Temps de cuisson: $cookingTime\n';
      }
      
      if (servings != null) {
        shareText += '👥 Pour $servings personnes\n\n';
      }
      
      shareText += 'Découvrez cette recette sur Dinor:\n$url';
      
      await shareContent(
        title: title,
        description: shareText,
        shareUrl: url,
        type: type ?? 'recipe',
        id: id ?? '0',
        imageUrl: imageUrl,
      );
    } catch (error) {
      print('❌ [ShareService] Erreur partage recette: $error');
      rethrow;
    }
  }

  /// Partage d'astuce avec formatage spécial et URL depuis l'API
  Future<void> shareTip({
    required String title,
    required String content,
    required String url,
    String? imageUrl,
    String? type = 'tip',
    String? id,
  }) async {
    try {
      print('💡 [ShareService] Partage astuce: $title');
      
      // Si on a un ID, récupérer l'URL depuis l'API
      if (id != null) {
        final shareData = await _getShareData(type: type!, id: id);
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          content = shareData['description'] as String? ?? content;
          imageUrl = shareData['image'] as String? ?? imageUrl;
        }
      }
      
      final shareText = '$title\n\n$content\n\nDécouvrez cette astuce sur Dinor:\n$url';
      
      await shareContent(
        title: title,
        description: shareText,
        shareUrl: url,
        type: type ?? 'tip',
        id: id ?? '0',
        imageUrl: imageUrl,
      );
    } catch (error) {
      print('❌ [ShareService] Erreur partage astuce: $error');
      rethrow;
    }
  }

  /// Partage d'événement avec formatage spécial et URL depuis l'API
  Future<void> shareEvent({
    required String title,
    required String description,
    required String url,
    String? date,
    String? location,
    String? imageUrl,
    String? type = 'event',
    String? id,
  }) async {
    try {
      print('📅 [ShareService] Partage événement: $title');
      
      // Si on a un ID, récupérer l'URL depuis l'API
      if (id != null) {
        final shareData = await _getShareData(type: type!, id: id);
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          description = shareData['description'] as String? ?? description;
          imageUrl = shareData['image'] as String? ?? imageUrl;
        }
      }
      
      String shareText = '$title\n\n';
      
      if (description.isNotEmpty) {
        shareText += '$description\n\n';
      }
      
      if (date != null) {
        shareText += '📅 Date: $date\n';
      }
      
      if (location != null) {
        shareText += '📍 Lieu: $location\n\n';
      }
      
      shareText += 'Découvrez cet événement sur Dinor:\n$url';
      
      await shareContent(
        title: title,
        description: shareText,
        shareUrl: url,
        type: type ?? 'event',
        id: id ?? '0',
        imageUrl: imageUrl,
      );
    } catch (error) {
      print('❌ [ShareService] Erreur partage événement: $error');
      rethrow;
    }
  }

  /// Partage de vidéo avec formatage spécial et URL depuis l'API
  Future<void> shareVideo({
    required String title,
    required String description,
    required String url,
    String? duration,
    String? imageUrl,
    String? type = 'video',
    String? id,
  }) async {
    try {
      print('🎥 [ShareService] Partage vidéo: $title');
      
      // Si on a un ID, récupérer l'URL depuis l'API
      if (id != null) {
        final shareData = await _getShareData(type: type!, id: id);
        if (shareData != null) {
          url = shareData['url'] as String? ?? url;
          title = shareData['title'] as String? ?? title;
          description = shareData['description'] as String? ?? description;
          imageUrl = shareData['image'] as String? ?? imageUrl;
        }
      }
      
      String shareText = '$title\n\n';
      
      if (description.isNotEmpty) {
        shareText += '$description\n\n';
      }
      
      if (duration != null) {
        shareText += '⏱️ Durée: $duration\n\n';
      }
      
      shareText += 'Regardez cette vidéo sur Dinor:\n$url';
      
      await shareContent(
        title: title,
        description: shareText,
        shareUrl: url,
        type: type ?? 'video',
        id: id ?? '0',
        imageUrl: imageUrl,
      );
    } catch (error) {
      print('❌ [ShareService] Erreur partage vidéo: $error');
      rethrow;
    }
  }
} 