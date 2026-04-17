import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class LeaderboardItem extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final bool isCurrentUser;

  const LeaderboardItem({
    super.key,
    required this.rank,
    required this.name,
    required this.score,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final rankWidget = _rankIcon(rank);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.12)
            : const Color(0xFF1F2937).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.5),
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: isCurrentUser
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank icon / number
          SizedBox(
            width: 32,
            child: Center(child: _rankIcon(rank)),
          ),

          const SizedBox(width: 12),

          // Avatar placeholder
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : const Color(0xFF1F2937),
              border: Border.all(
                color: isCurrentUser
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isCurrentUser
                      ? AppColors.primaryLight
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name and "You" tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: isCurrentUser
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 0.5),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Score pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _scoreColor(score).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _scoreColor(score).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '$score%',
              style: TextStyle(
                color: _scoreColor(score),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankIcon(int r) {
    switch (r) {
      case 1:
        return const Text('🥇', style: TextStyle(fontSize: 22));
      case 2:
        return const Text('🥈', style: TextStyle(fontSize: 22));
      case 3:
        return const Text('🥉', style: TextStyle(fontSize: 22));
      default:
        return Text(
          '#$r',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        );
    }
  }

  Color _scoreColor(int s) {
    if (s >= 85) return const Color(0xFF22C55E);
    if (s >= 70) return AppColors.primaryLight;
    return const Color(0xFFFBBF24);
  }
}
