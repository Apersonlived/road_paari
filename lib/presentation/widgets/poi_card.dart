import 'package:flutter/material.dart';
import '../../data/api/api_client.dart';
import '../../data/models/poi_model.dart';

class POICard extends StatelessWidget {
  final POI poi;
  final bool showActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const POICard({
    super.key,
    required this.poi,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // POI Image — nullable, show placeholder if null
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: poi.imageUrl != null
                    ? Image.network(
                        ApiClient.resolveImageUrl(poi.imageUrl!),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, __) {
                        debugPrint('Hero image failed: $error');
                        debugPrint('URL: ${ApiClient.resolveImageUrl(poi.imageUrl!)}');
                        return _imagePlaceholder();
                      },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    : _imagePlaceholder(),
              ),

              const SizedBox(width: 12),

              // POI Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poi.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Description
                    if (poi.description != null) ...[
                      Text(
                        poi.description!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Coordinates (if available)
                    if (poi.latitude != null && poi.longitude != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 13,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${poi.latitude!.toStringAsFixed(4)}, '
                            '${poi.longitude!.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),

                    // Distance badge (for nearby results)
                    if (poi.distanceMeters != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          poi.distanceMeters! < 1000
                              ? '${poi.distanceMeters!.toStringAsFixed(0)}m away'
                              : '${(poi.distanceMeters! / 1000).toStringAsFixed(1)}km away',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Action Buttons (admin only)
              if (showActions) ...[
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      color: Colors.grey[700],
                      tooltip: 'Edit',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      tooltip: 'Delete',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.place, color: Colors.grey, size: 32),
    );
  }
}
