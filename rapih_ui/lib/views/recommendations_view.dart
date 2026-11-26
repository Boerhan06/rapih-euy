import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/engine_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/file_candidate_card.dart';
import '../widgets/quarantine_dialog.dart';

class RecommendationsView extends StatelessWidget {
  const RecommendationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final files = state.filteredFiles;

    return Column(
      children: [
        // Top Filter Bar & Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Search Box
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        onChanged: state.setSearchQuery,
                        decoration: const InputDecoration(
                          hintText: 'Cari nama file atau direktori...',
                          prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Sort Dropdown
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOatmeal,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.sortBy,
                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.charcoal),
                        items: const [
                          DropdownMenuItem(value: 'size_desc', child: Text('Ukuran Terbesar')),
                          DropdownMenuItem(value: 'name_asc', child: Text('Nama File')),
                          DropdownMenuItem(value: 'category', child: Text('Kategori')),
                        ],
                        onChanged: (v) {
                          if (v != null) state.setSortBy(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Filter Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Semua Kategori',
                      isSelected: state.selectedCategoryFilter == null,
                      onTap: () => state.setCategoryFilter(null),
                    ),
                    _buildFilterChip(
                      label: 'Temp Windows',
                      isSelected: state.selectedCategoryFilter == FileCategory.windowsTemp,
                      onTap: () => state.setCategoryFilter(FileCategory.windowsTemp),
                    ),
                    _buildFilterChip(
                      label: 'File Duplikat',
                      isSelected: state.selectedCategoryFilter == FileCategory.duplicate,
                      onTap: () => state.setCategoryFilter(FileCategory.duplicate),
                    ),
                    _buildFilterChip(
                      label: 'File Besar (>100MB)',
                      isSelected: state.selectedCategoryFilter == FileCategory.largeForgotten,
                      onTap: () => state.setCategoryFilter(FileCategory.largeForgotten),
                    ),
                    _buildFilterChip(
                      label: 'Installer Bekas',
                      isSelected: state.selectedCategoryFilter == FileCategory.oldInstaller,
                      onTap: () => state.setCategoryFilter(FileCategory.oldInstaller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Select All / Deselect All Action Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Ditemukan ${files.length} kandidat file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => state.toggleAllFileSelection(true),
                child: const Text('Pilih Semua'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => state.toggleAllFileSelection(false),
                child: const Text('Batal Pilih'),
              ),
            ],
          ),
        ),

        // File List
        Expanded(
          child: files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppTheme.matchaPastel,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.matchaDark,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Semuanya Rapih & Bersih!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tidak ditemukan file sampah pada kategori yang dipilih.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return FileCandidateCard(
                      file: file,
                      onToggle: () => state.toggleFileSelection(file),
                    );
                  },
                ),
        ),

        // Bottom Action Bar (Fixed bar like Mockup bottom cards)
        if (state.selectedFilesCount > 0)
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
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.selectedFilesCount} file terpilih',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Bisa bebaskan: ${state.selectedFilesHumanBytes}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.matchaDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => QuarantineDialog(
                              totalCount: state.selectedFilesCount,
                              totalHumanSize: state.selectedFilesHumanBytes,
                              isDirectDelete: true,
                              onConfirm: () async {
                                final res = await state.deleteSelectedFilesDirectly();
                                if (context.mounted) {
                                  final skippedNote = res.skippedCount > 0
                                      ? ' (${res.skippedCount} dilewati karena terkunci sistem)'
                                      : '';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${res.deletedCount} file dihapus langsung (${res.humanFreed} dibebaskan)$skippedNote',
                                      ),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                        icon: Icon(Icons.delete_forever_outlined, size: 18, color: Colors.red.shade700),
                        label: Text(
                          'Hapus Langsung',
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => QuarantineDialog(
                              totalCount: state.selectedFilesCount,
                              totalHumanSize: state.selectedFilesHumanBytes,
                              isDirectDelete: false,
                              onConfirm: () async {
                                final count = await state.quarantineSelectedFiles();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$count file berhasil dipindahkan ke Karantina!'),
                                      backgroundColor: AppTheme.charcoal,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.shield_outlined, size: 18),
                        label: const Text('Amankan ke Karantina'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.charcoal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.charcoal : AppTheme.surfaceOatmeal,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
