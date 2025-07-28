import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/navigation_service.dart';

class SimpleEventsScreen extends StatefulWidget {
  const SimpleEventsScreen({Key? key}) : super(key: key);

  @override
  State<SimpleEventsScreen> createState() => _SimpleEventsScreenState();
}

class _SimpleEventsScreenState extends State<SimpleEventsScreen> {
  List<dynamic> events = [];
  List<dynamic> allEvents = [];
  List<String> availableTags = [];
  List<String> selectedTags = [];
  String searchQuery = '';
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      print('🔄 [SimpleEvents] Chargement des événements...');
      
      final response = await http.get(
        Uri.parse('https://new.dinorapp.com/api/v1/events'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 [SimpleEvents] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [SimpleEvents] Data reçue: ${data.toString().substring(0, 100)}...');
        
        setState(() {
          if (data['data'] != null) {
            allEvents = data['data'] is List ? data['data'] : [data['data']];
            events = List.from(allEvents);
            _extractTags();
          } else {
            allEvents = [];
            events = [];
          }
          isLoading = false;
          error = null;
        });
        
        print('📅 [SimpleEvents] ${events.length} événements chargés');
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [SimpleEvents] Erreur: $e');
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  void _extractTags() {
    Set<String> tags = {};
    for (var event in allEvents) {
      if (event['tags'] != null) {
        if (event['tags'] is List) {
          for (var tag in event['tags']) {
            if (tag is String) tags.add(tag);
          }
        } else if (event['tags'] is String) {
          tags.add(event['tags']);
        }
      }
    }
    availableTags = tags.toList()..sort();
  }

  void _filterEvents() {
    setState(() {
      events = allEvents.where((event) {
        // Filtre par recherche
        bool matchesSearch = searchQuery.isEmpty || 
          event['title']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) == true ||
          event['description']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) == true ||
          event['location']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) == true;
        
        // Filtre par tags
        bool matchesTags = selectedTags.isEmpty;
        if (!matchesTags && event['tags'] != null) {
          List<String> eventTags = [];
          if (event['tags'] is List) {
            eventTags = event['tags'].whereType<String>().toList();
          } else if (event['tags'] is String) {
            eventTags = [event['tags']];
          }
          matchesTags = selectedTags.every((tag) => eventTags.contains(tag));
        }
        
        return matchesSearch && matchesTags;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _filterEvents();
  }

  void _onTagSelected(String tag) {
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
      } else {
        selectedTags.add(tag);
      }
    });
    _filterEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Événements',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => NavigationService.pop(),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher un événement...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF718096)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE53E3E)),
                ),
                filled: true,
                fillColor: const Color(0xFFF7FAFC),
              ),
            ),
          ),

          // Filtres par tags
          if (availableTags.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtrer par tags:',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map<Widget>((tag) {
                      bool isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (_) => _onTagSelected(tag),
                        backgroundColor: const Color(0xFFF7FAFC),
                        selectedColor: const Color(0xFFE53E3E),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF4A5568),
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Liste des événements
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE53E3E)),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement des événements...',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Color(0xFF4A5568),
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFE53E3E),
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur: $error',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Color(0xFF4A5568),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy,
              size: 64,
              color: Color(0xFFCBD5E0),
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty || selectedTags.isNotEmpty
                ? 'Aucun événement trouvé'
                : 'Aucun événement disponible',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                color: Color(0xFF4A5568),
              ),
            ),
            if (searchQuery.isNotEmpty || selectedTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                    selectedTags.clear();
                  });
                  _filterEvents();
                },
                child: const Text(
                  'Effacer les filtres',
                  style: TextStyle(color: Color(0xFFE53E3E)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: const Color(0xFFE53E3E),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          NavigationService.goToEventDetail(event['id'].toString());
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de l'événement
            if (event['image_url'] != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    event['image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF7FAFC),
                        child: const Icon(
                          Icons.event,
                          size: 48,
                          color: Color(0xFFCBD5E0),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Contenu de la carte
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    event['title'] ?? 'Sans titre',
                    style: const TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  if (event['description'] != null) ...[
                    Text(
                      event['description'],
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Color(0xFF718096),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Tags
                  if (event['tags'] != null && event['tags'].isNotEmpty) ...[
                                         Wrap(
                       spacing: 4,
                       runSpacing: 4,
                       children: (event['tags'] is List 
                         ? event['tags'] 
                         : [event['tags']]).map<Widget>((tag) {
                         return Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             color: const Color(0xFFF7FAFC),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(
                             tag.toString(),
                             style: const TextStyle(
                               fontSize: 10,
                               color: Color(0xFF718096),
                             ),
                           ),
                         );
                       }).toList(),
                     ),
                    const SizedBox(height: 8),
                  ],

                  // Stats
                  Row(
                    children: [
                      if (event['start_date'] != null) ...[
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Color(0xFFE53E3E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(event['start_date']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF718096),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (event['location'] != null) ...[
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Color(0xFF718096),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event['location'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF718096),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (event['likes_count'] != null) ...[
                        const Icon(
                          Icons.favorite,
                          size: 16,
                          color: Color(0xFFE53E3E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event['likes_count']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}