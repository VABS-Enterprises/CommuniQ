import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/visual_analysis_models.dart';

/// Interactive Radar & Target Crosshair visualization for Eye Contact & Gaze Focus.
class GazeRadarWidget extends StatelessWidget {
  final Map<GazeDirection, double> distribution;
  final double eyeContactPct;

  const GazeRadarWidget({
    super.key,
    required this.distribution,
    required this.eyeContactPct,
  });

  @override
  Widget build(BuildContext context) {
    final centerPct = (distribution[GazeDirection.center] ?? eyeContactPct).round();
    final leftPct = (distribution[GazeDirection.left] ?? 0.0).round();
    final rightPct = (distribution[GazeDirection.right] ?? 0.0).round();
    final upPct = (distribution[GazeDirection.up] ?? 0.0).round();
    final downPct = (distribution[GazeDirection.down] ?? 0.0).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSunk.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Both halves are intrinsically sized, so on a narrow screen the
              // row had nothing to give and overflowed. The label yields first.
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.center_focus_strong_rounded, color: AppColors.primaryLight, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'GAZE TARGET RADAR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$centerPct% Center Focus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Radar Target Crosshair
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Radar Ring
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
                  ),
                ),
                // Inner Target Ring
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4), width: 1.5),
                  ),
                ),
                // Crosshair Lines
                Container(width: 140, height: 1, color: AppColors.outline.withValues(alpha: 0.4)),
                Container(width: 1, height: 140, color: AppColors.outline.withValues(alpha: 0.4)),

                // CENTER TARGET RETICLE (Eye Contact Focal Point)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.success, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.remove_red_eye_rounded, color: AppColors.success, size: 20),
                  ),
                ),

                // Directional Target Badges
                // TOP (UP GAZE)
                Positioned(
                  top: 0,
                  child: _buildDirectionBadge('UP', '$upPct%', AppColors.sun),
                ),
                // BOTTOM (DOWN GAZE)
                Positioned(
                  bottom: 0,
                  child: _buildDirectionBadge('DOWN', '$downPct%', AppColors.sun),
                ),
                // LEFT GAZE
                Positioned(
                  left: 0,
                  child: _buildDirectionBadge('LEFT', '$leftPct%', AppColors.brand),
                ),
                // RIGHT GAZE
                Positioned(
                  right: 0,
                  child: _buildDirectionBadge('RIGHT', '$rightPct%', AppColors.brand),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Gaze Focus Quality Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Camera Engagement Level',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  Text(
                    '$centerPct%',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: centerPct / 100.0,
                  minHeight: 6,
                  backgroundColor: AppColors.outline,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    centerPct >= 70 ? AppColors.success : AppColors.sun,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionBadge(String label, String pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label $pct',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
