import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class QuarantineDialog extends StatelessWidget {
  final int totalCount;
  final String totalHumanSize;
  final bool isDirectDelete;
  final VoidCallback onConfirm;

  const QuarantineDialog({
    super.key,
    required this.totalCount,
    required this.totalHumanSize,
    this.isDirectDelete = false,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final badgeBg = isDirectDelete ? AppTheme.peachPastel : AppTheme.matchaPastel;
    final badgeIconColor = isDirectDelete ? Colors.red.shade700 : AppTheme.matchaDark;
    final title = isDirectDelete ? 'Konfirmasi Hapus Permanen' : 'Konfirmasi Karantina';
    final infoText = isDirectDelete
        ? 'PERHATIAN: Kamu akan menghapus $totalCount file ($totalHumanSize) secara permanen langsung dari disk. File yang dihapus tidak dapat di-restore!'
        : 'Kamu akan mengamankan $totalCount file ($totalHumanSize) ke Karantina. File TIDAK langsung dihapus permanen dan bisa di-restore kapan saja.';
    final buttonLabel = isDirectDelete ? 'Hapus Permanen Sekarang' : 'Pindahkan ke Karantina';
    final buttonColor = isDirectDelete ? Colors.red.shade700 : AppTheme.charcoal;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isDirectDelete ? Icons.delete_forever_outlined : Icons.shield_outlined,
                    color: badgeIconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        'Selalu tanya sebelum bertindak',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDirectDelete
                    ? AppTheme.peachPastel.withValues(alpha: 0.45)
                    : AppTheme.surfaceOatmeal,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isDirectDelete ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: isDirectDelete ? Colors.red.shade700 : AppTheme.charcoal,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      infoText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(buttonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
