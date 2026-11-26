import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class DiskSummaryCard extends StatelessWidget {
  const DiskSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final disk = state.disks.isNotEmpty ? state.disks.first : null;
    final reclaimable = state.scanResult?.humanReclaimable ?? '0 B';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.matchaPastel,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cleaning_services_rounded, color: AppTheme.matchaDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rapih Euy v1.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      disk?.name ?? 'Penyimpanan Utama',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Two-column Stats (similar to Mockup: Current Balance & Bonus Balance)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ruang Terpakai',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      disk != null ? disk.humanUsed : '--',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'dari ${disk?.humanTotal ?? '--'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: AppTheme.borderLight,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bisa Dibersihkan',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reclaimable,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.matchaDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${state.scanResult?.totalCandidates ?? 0} file terdeteksi',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (disk?.usagePercentage ?? 50.0) / 100.0,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceOatmeal,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.charcoal),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Action Pill Buttons (like Deposit & Withdraw in Mockup)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: state.isScanning ? null : () => state.runQuickScan(),
                  icon: state.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(state.isScanning ? 'Memindai...' : 'Pindai Cepat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.charcoal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => state.setNavIndex(2), // Navigate to Quarantine
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('Karantina'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
