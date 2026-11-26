import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/engine_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class QuarantineView extends StatelessWidget {
  const QuarantineView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final index = state.quarantineIndex;
    final entries = index?.entries ?? [];

    return Column(
      children: [
        // Top Header Info
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Brankas Karantina Aman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total tersimpan di karantina: ${index?.humanTotalSize ?? '0 B'} (${entries.length} file)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => state.refreshQuarantine(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Segarkan'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.matchaPastel.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppTheme.matchaDark, size: 34),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Karantina Masih Kosong',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'File yang kamu amankan dari Rekomendasi Bersih akan tersimpan di sini.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: entries.length,
                  itemBuilder: (context, idx) {
                    final entry = entries[idx];
                    return _buildQuarantineCard(context, entry, state);
                  },
                ),
        ),

        // Bottom Actions
        if (entries.any((e) => e.isSelected))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  '${entries.where((e) => e.isSelected).length} file dipilih',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    final count = await state.restoreSelectedQuarantine();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$count file berhasil dikembalikan ke lokasi aslinya!'),
                          backgroundColor: AppTheme.matchaDark,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore_page_outlined, size: 18),
                  label: const Text('Restore ke Lokasi Asli'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Permanen?'),
                        content: const Text(
                          'Tindakan ini akan menghapus file dari disk secara permanen dan tidak dapat dikembalikan lagi.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                            child: const Text('Hapus Permanen'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final count = await state.purgeSelectedQuarantine();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$count file dihapus secara permanen.'),
                            backgroundColor: AppTheme.charcoal,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: const Text('Hapus Permanen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuarantineCard(BuildContext context, QuarantineEntry entry, AppState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: entry.isSelected
              ? AppTheme.charcoal.withOpacity(0.25)
              : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: entry.isSelected,
            activeColor: AppTheme.charcoal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (_) => state.toggleQuarantineItem(entry),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.filename,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      entry.humanSize,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Asal: ${entry.originalPath}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
