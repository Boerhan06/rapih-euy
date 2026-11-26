import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/disk_summary_card.dart';
import 'organizer_view.dart';
import 'quarantine_view.dart';
import 'recommendations_view.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Left Sidebar (350px width)
          Container(
            width: 350,
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(
                right: BorderSide(color: AppTheme.borderLight, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Disk Summary Card (Styled like Mockup top card)
                        const DiskSummaryCard(),

                        const SizedBox(height: 24),

                        const Text(
                          'MENU UTAMA',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Navigation Pill Items
                        _buildNavItem(
                          context,
                          index: 0,
                          icon: Icons.cleaning_services_outlined,
                          activeIcon: Icons.cleaning_services_rounded,
                          title: 'Rekomendasi Bersih',
                          badgeCount: state.scanResult?.totalCandidates,
                          isActive: state.currentNavIndex == 0,
                          onTap: () => state.setNavIndex(0),
                        ),

                        const SizedBox(height: 8),

                        _buildNavItem(
                          context,
                          index: 1,
                          icon: Icons.auto_awesome_mosaic_outlined,
                          activeIcon: Icons.auto_awesome_mosaic_rounded,
                          title: 'Smart Auto-Rapih',
                          isActive: state.currentNavIndex == 1,
                          onTap: () => state.setNavIndex(1),
                        ),

                        const SizedBox(height: 8),

                        _buildNavItem(
                          context,
                          index: 2,
                          icon: Icons.shield_outlined,
                          activeIcon: Icons.shield_rounded,
                          title: 'Karantina / Vault',
                          badgeCount: state.quarantineIndex?.entries.length,
                          isActive: state.currentNavIndex == 2,
                          onTap: () => state.setNavIndex(2),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Engine Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: state.isEngineLive
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.isEngineLive
                              ? 'Rust Backend Engine Aktif'
                              : 'Mode Preview (Demo Data)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Text(
                        'v1.0',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right Workspace Pane
          Expanded(
            child: IndexedStack(
              index: state.currentNavIndex,
              children: const [
                RecommendationsView(),
                OrganizerView(),
                QuarantineView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    int? badgeCount,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.charcoal : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.white : AppTheme.charcoal,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.matchaPastel : AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppTheme.charcoal : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
