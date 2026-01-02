import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../../../../../core/constants/app_colors.dart';

class RouteInfoCard extends StatelessWidget {
  final RoadInfo roadInfo;

  const RouteInfoCard({Key? key, required this.roadInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final distance = (roadInfo.distance! / 1000).toStringAsFixed(2);
    final duration = (roadInfo.duration! / 60).toStringAsFixed(0);

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.straighten, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Distance: $distance km',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Duration: $duration min',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Optimize Route',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}