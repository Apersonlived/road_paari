import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/poi_model.dart';
import '../../../data/api/api_client.dart';
import '../../../providers/poi_provider.dart';

class POIDetailScreen extends StatelessWidget {
  final POI poi;
  const POIDetailScreen({super.key, required this.poi});

  @override
  Widget build(BuildContext context) {
    // Get category name from provider
    final categories = context.read<POIProvider>().categories;
    final category = categories.firstWhere(
      (c) => c.id == poi.categoryId,
      orElse: () => POICategory(id: -1, name: 'Uncategorized'),
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // ── Hero image / app bar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                poi.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
              background: poi.imageUrl != null
                  ? Image.network(
                      ApiClient.resolveImageUrl(poi.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, __) {
                        debugPrint('Hero image failed: $error');
                        debugPrint('URL: ${ApiClient.resolveImageUrl(poi.imageUrl!)}');
                        return _headerPlaceholder();
                      },
                    )
                  : _headerPlaceholder(),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Info chips row ────────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Category chip
                      if (poi.categoryId != null)
                        _InfoChip(
                          icon: Icons.category_outlined,
                          label: category.name,
                          color: AppColors.primary,
                        ),

                      // Distance chip
                      if (poi.distanceMeters != null)
                        _InfoChip(
                          icon: Icons.near_me,
                          label: poi.distanceMeters! < 1000
                              ? '${poi.distanceMeters!.toStringAsFixed(0)}m away'
                              : '${(poi.distanceMeters! / 1000).toStringAsFixed(1)}km away',
                          color: Colors.blue,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── About ─────────────────────────────────────────────────
                  if (poi.description != null && poi.description!.isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      poi.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Location ──────────────────────────────────────────────
                  if (poi.latitude != null && poi.longitude != null) ...[
                    const Text(
                      'Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Coordinates',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lat: ${poi.latitude!.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Lng: ${poi.longitude!.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      child: const Center(
        child: Icon(Icons.place, size: 64, color: Colors.white54),
      ),
    );
  }
}

// ── Reusable info chip ────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}