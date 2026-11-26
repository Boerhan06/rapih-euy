import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/engine_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class OrganizerView extends StatelessWidget {
  const OrganizerView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.organizeResult;

    return Column(
      children: [
        // Header & Folder Selector
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
                  children: const [
                    Text(
                      'Smart Auto-Organizer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Otomatis kelompokkan file acak ke subfolder Dokumen, Gambar, Setup, dan Arsip.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: state.isOrganizing ? null : () => state.scanOrganizer(),
                icon: state.isOrganizing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.folder_copy_outlined, size: 18),
                label: Text(state.isOrganizing ? 'Menganalisis...' : 'Analisis Downloads'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.charcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Plan Items List
        Expanded(
          child: plan == null || plan.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceOatmeal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppTheme.charcoal, size: 34),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Rencana Rapih',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Klik "Analisis Downloads" untuk melihat simulasi perapihan file.',
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
                  itemCount: plan.items.length,
                  itemBuilder: (context, index) {
                    final item = plan.items[index];
                    return _buildOrganizeCard(context, item, state);
                  },
                ),
        ),

        // Bottom Action Bar
        if (plan != null && plan.items.any((i) => i.isSelected))
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
                  '${plan.items.where((i) => i.isSelected).length} file siap dipindahkan',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final count = await state.executeOrganize();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$count file berhasil dirapihkan ke foldernya!'),
                          backgroundColor: AppTheme.charcoal,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                  label: const Text('Eksekusi Rapihkan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.matchaDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrganizeCard(BuildContext context, OrganizePlanItem item, AppState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: item.isSelected
              ? AppTheme.charcoal.withOpacity(0.25)
              : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: AppTheme.charcoal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            onChanged: (_) => state.toggleOrganizeItem(item),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.humanSize,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.matchaPastel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Subfolder: ${item.targetFolderName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.matchaDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
