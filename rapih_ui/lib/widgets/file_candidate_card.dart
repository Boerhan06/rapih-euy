import 'package:flutter/material.dart';
import '../models/engine_models.dart';
import '../theme/app_theme.dart';

class FileCandidateCard extends StatelessWidget {
  final ScannedFile file;
  final VoidCallback onToggle;

  const FileCandidateCard({
    super.key,
    required this.file,
    required this.onToggle,
  });

  IconData _getCategoryIcon() {
    switch (file.category) {
      case FileCategory.windowsTemp:
        return Icons.auto_delete_outlined;
      case FileCategory.duplicate:
        return Icons.copy_rounded;
      case FileCategory.largeForgotten:
        return Icons.archive_outlined;
      case FileCategory.oldInstaller:
        return Icons.download_done_rounded;
      case FileCategory.emptyFolder:
        return Icons.folder_open_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getBadgeBg() {
    switch (file.category) {
      case FileCategory.windowsTemp:
        return AppTheme.matchaPastel;
      case FileCategory.duplicate:
        return AppTheme.butterPastel;
      case FileCategory.largeForgotten:
        return AppTheme.peachPastel;
      default:
        return AppTheme.surfaceOatmeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: file.isSelected
              ? AppTheme.charcoal.withOpacity(0.25)
              : AppTheme.borderLight,
          width: file.isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox (Selalu tanya aku principle)
          Checkbox(
            value: file.isSelected,
            activeColor: AppTheme.charcoal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            onChanged: (_) => onToggle(),
          ),

          const SizedBox(width: 8),

          // Category Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getBadgeBg(),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getCategoryIcon(),
              color: AppTheme.charcoal,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          // File Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filename & Category Chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.filename,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getBadgeBg(),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        file.category.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Path & Reason
                Text(
                  file.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  file.path,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // File Size
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                file.humanSize,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (file.lastModified != null)
                Text(
                  file.lastModified!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
