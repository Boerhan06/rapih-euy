enum FileCategory {
  windowsTemp,
  duplicate,
  largeForgotten,
  oldInstaller,
  emptyFolder,
  documents,
  media,
  archives,
  installers,
  developer,
  miscellaneous;

  static FileCategory fromString(String val) {
    switch (val.toLowerCase()) {
      case 'windowstemp':
        return FileCategory.windowsTemp;
      case 'duplicate':
        return FileCategory.duplicate;
      case 'largeforgotten':
        return FileCategory.largeForgotten;
      case 'oldinstaller':
        return FileCategory.oldInstaller;
      case 'emptyfolder':
        return FileCategory.emptyFolder;
      case 'documents':
        return FileCategory.documents;
      case 'media':
        return FileCategory.media;
      case 'archives':
        return FileCategory.archives;
      case 'installers':
        return FileCategory.installers;
      case 'developer':
        return FileCategory.developer;
      default:
        return FileCategory.miscellaneous;
    }
  }

  String get label {
    switch (this) {
      case FileCategory.windowsTemp:
        return 'Temp & Cache';
      case FileCategory.duplicate:
        return 'Duplikat Identik';
      case FileCategory.largeForgotten:
        return 'File Besar Terlupakan';
      case FileCategory.oldInstaller:
        return 'Installer Bekas';
      case FileCategory.emptyFolder:
        return 'Folder Kosong';
      case FileCategory.documents:
        return 'Dokumen';
      case FileCategory.media:
        return 'Media';
      case FileCategory.archives:
        return 'Arsip & Zip';
      case FileCategory.installers:
        return 'Setup & App';
      case FileCategory.developer:
        return 'Dev & Code';
      case FileCategory.miscellaneous:
        return 'Lainnya';
    }
  }
}

class ScannedFile {
  final String id;
  final String path;
  final String filename;
  final int sizeBytes;
  final String humanSize;
  final FileCategory category;
  final String reason;
  final String? lastModified;
  final String? hash;
  final bool recommendedForDeletion;
  bool isSelected;

  ScannedFile({
    required this.id,
    required this.path,
    required this.filename,
    required this.sizeBytes,
    required this.humanSize,
    required this.category,
    required this.reason,
    this.lastModified,
    this.hash,
    required this.recommendedForDeletion,
    this.isSelected = true,
  });

  factory ScannedFile.fromJson(Map<String, dynamic> json) {
    return ScannedFile(
      id: json['id'] as String,
      path: json['path'] as String,
      filename: json['filename'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      humanSize: json['human_size'] as String,
      category: FileCategory.fromString(json['category'] as String),
      reason: json['reason'] as String,
      lastModified: json['last_modified'] as String?,
      hash: json['hash'] as String?,
      recommendedForDeletion: json['recommended_for_deletion'] as bool? ?? false,
      isSelected: json['recommended_for_deletion'] as bool? ?? false,
    );
  }
}

class ScanResult {
  final int totalScannedFiles;
  final int totalCandidates;
  final int totalReclaimableBytes;
  final String humanReclaimable;
  final List<ScannedFile> items;
  final int scanDurationMs;

  ScanResult({
    required this.totalScannedFiles,
    required this.totalCandidates,
    required this.totalReclaimableBytes,
    required this.humanReclaimable,
    required this.items,
    required this.scanDurationMs,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      totalScannedFiles: (json['total_scanned_files'] as num).toInt(),
      totalCandidates: (json['total_candidates'] as num).toInt(),
      totalReclaimableBytes: (json['total_reclaimable_bytes'] as num).toInt(),
      humanReclaimable: json['human_reclaimable'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => ScannedFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      scanDurationMs: (json['scan_duration_ms'] as num).toInt(),
    );
  }
}

class OrganizePlanItem {
  final String sourcePath;
  final String filename;
  final String targetFolderName;
  final String targetPath;
  final String category;
  final int sizeBytes;
  final String humanSize;
  bool isSelected;

  OrganizePlanItem({
    required this.sourcePath,
    required this.filename,
    required this.targetFolderName,
    required this.targetPath,
    required this.category,
    required this.sizeBytes,
    required this.humanSize,
    this.isSelected = true,
  });

  factory OrganizePlanItem.fromJson(Map<String, dynamic> json) {
    return OrganizePlanItem(
      sourcePath: json['source_path'] as String,
      filename: json['filename'] as String,
      targetFolderName: json['target_folder_name'] as String,
      targetPath: json['target_path'] as String,
      category: json['category'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      humanSize: json['human_size'] as String,
      isSelected: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'source_path': sourcePath,
        'filename': filename,
        'target_folder_name': targetFolderName,
        'target_path': targetPath,
        'category': category,
        'size_bytes': sizeBytes,
        'human_size': humanSize,
      };
}

class OrganizeResult {
  final int totalItems;
  final List<OrganizePlanItem> items;

  OrganizeResult({required this.totalItems, required this.items});

  factory OrganizeResult.fromJson(Map<String, dynamic> json) {
    return OrganizeResult(
      totalItems: (json['total_items'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => OrganizePlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuarantineEntry {
  final String id;
  final String originalPath;
  final String quarantinePath;
  final String filename;
  final int sizeBytes;
  final String humanSize;
  final String quarantinedAt;
  final String reason;
  final String? hash;
  bool isSelected;

  QuarantineEntry({
    required this.id,
    required this.originalPath,
    required this.quarantinePath,
    required this.filename,
    required this.sizeBytes,
    required this.humanSize,
    required this.quarantinedAt,
    required this.reason,
    this.hash,
    this.isSelected = false,
  });

  factory QuarantineEntry.fromJson(Map<String, dynamic> json) {
    return QuarantineEntry(
      id: json['id'] as String,
      originalPath: json['original_path'] as String,
      quarantinePath: json['quarantine_path'] as String,
      filename: json['filename'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      humanSize: json['human_size'] as String,
      quarantinedAt: json['quarantined_at'] as String,
      reason: json['reason'] as String,
      hash: json['hash'] as String?,
      isSelected: false,
    );
  }
}

class QuarantineIndex {
  final List<QuarantineEntry> entries;
  final int totalSizeBytes;
  final String humanTotalSize;

  QuarantineIndex({
    required this.entries,
    required this.totalSizeBytes,
    required this.humanTotalSize,
  });

  factory QuarantineIndex.fromJson(Map<String, dynamic> json) {
    return QuarantineIndex(
      entries: (json['entries'] as List<dynamic>)
          .map((e) => QuarantineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSizeBytes: (json['total_size_bytes'] as num).toInt(),
      humanTotalSize: json['human_total_size'] as String,
    );
  }
}

class DiskStats {
  final String name;
  final String mountPoint;
  final int totalSpaceBytes;
  final int availableSpaceBytes;
  final int usedSpaceBytes;
  final String humanTotal;
  final String humanAvailable;
  final String humanUsed;
  final double usagePercentage;

  DiskStats({
    required this.name,
    required this.mountPoint,
    required this.totalSpaceBytes,
    required this.availableSpaceBytes,
    required this.usedSpaceBytes,
    required this.humanTotal,
    required this.humanAvailable,
    required this.humanUsed,
    required this.usagePercentage,
  });

  factory DiskStats.fromJson(Map<String, dynamic> json) {
    return DiskStats(
      name: json['name'] as String,
      mountPoint: json['mount_point'] as String,
      totalSpaceBytes: (json['total_space_bytes'] as num).toInt(),
      availableSpaceBytes: (json['available_space_bytes'] as num).toInt(),
      usedSpaceBytes: (json['used_space_bytes'] as num).toInt(),
      humanTotal: json['human_total'] as String,
      humanAvailable: json['human_available'] as String,
      humanUsed: json['human_used'] as String,
      usagePercentage: (json['usage_percentage'] as num).toDouble(),
    );
  }
}

class DirectDeleteResult {
  final int deletedCount;
  final int skippedCount;
  final int freedBytes;
  final String humanFreed;
  final List<String> deletedPaths;

  DirectDeleteResult({
    required this.deletedCount,
    required this.skippedCount,
    required this.freedBytes,
    required this.humanFreed,
    required this.deletedPaths,
  });

  factory DirectDeleteResult.fromJson(Map<String, dynamic> json) {
    return DirectDeleteResult(
      deletedCount: (json['deleted_count'] as num).toInt(),
      skippedCount: (json['skipped_count'] as num).toInt(),
      freedBytes: (json['freed_bytes'] as num).toInt(),
      humanFreed: json['human_freed'] as String,
      deletedPaths: (json['deleted_paths'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}
