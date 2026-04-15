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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: isCurrentUser
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank icon / number
          SizedBox(
            width: 36,
            child: Center(child: rankWidget),
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
                  : AppColors.surface,
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
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isCurrentUser
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: isCurrentUser
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Score
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _scoreColor(score).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: _scoreColor(score).withValues(alpha: 0.3)),
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
