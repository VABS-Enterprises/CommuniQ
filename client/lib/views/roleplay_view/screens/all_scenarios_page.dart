import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';

class AllScenariosPage extends StatelessWidget {
  const AllScenariosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allCategories = [
      {'title': 'Assertiveness', 'icon': Icons.bolt, 'scenario': 'Say no politely to extra work', 'persona': 'Strict Boss'},
      {'title': 'Leadership', 'icon': Icons.groups, 'scenario': 'Guide a struggling team member through a project delay', 'persona': 'Friendly Mentor'},
      {'title': 'Negotiation', 'icon': Icons.handshake, 'scenario': 'Negotiate a larger budget for your department', 'persona': 'Angry Client'},
      {'title': 'Small Talk', 'icon': Icons.chat_bubble_outline, 'scenario': 'Network at a corporate event', 'persona': 'Friendly Stranger'},
      {'title': 'Feedback', 'icon': Icons.feedback, 'scenario': 'Give constructive feedback to a peer', 'persona': 'Defensive Colleague'},
      {'title': 'Interview', 'icon': Icons.work, 'scenario': 'Answer behavioral interview questions', 'persona': 'Strict Hiring Manager'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'All Scenarios',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: allCategories.length,
                  itemBuilder: (context, index) {
                    final item = allCategories[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoleplaySetupScreen(
                              mode: 'prefilled',
                              category: item['title'],
                              scenario: item['scenario'],
                              persona: item['persona'],
                              difficulty: 'Medium',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              item['icon'],
                              color: AppColors.primaryLight,
                              size: 28,
                            ),
                            const Spacer(),
                            Text(
                              item['title'],
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
