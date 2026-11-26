import 'package:flutter/foundation.dart';
import '../models/engine_models.dart';
import '../services/rust_engine_service.dart';

class AppState extends ChangeNotifier {
  final RustEngineService _engine = RustEngineService();

  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  List<DiskStats> _disks = [];
  List<DiskStats> get disks => _disks;

  ScanResult? _scanResult;
  ScanResult? get scanResult => _scanResult;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  OrganizeResult? _organizeResult;
  OrganizeResult? get organizeResult => _organizeResult;

  bool _isOrganizing = false;
  bool get isOrganizing => _isOrganizing;

  QuarantineIndex? _quarantineIndex;
  QuarantineIndex? get quarantineIndex => _quarantineIndex;

  FileCategory? _selectedCategoryFilter;
  FileCategory? get selectedCategoryFilter => _selectedCategoryFilter;

  String _sortBy = 'size_desc'; // 'size_desc', 'age_desc', 'name_asc'
  String get sortBy => _sortBy;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool get isEngineLive => _engine.isLive;

  String _organizeTarget = 'downloads';
  String get organizeTarget => _organizeTarget;

  AppState({bool autoInit = true}) {
    if (autoInit) {
      init();
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  Future<void> init() async {
    await _engine.initEngine();
    await refreshDiskStats();
    await refreshQuarantine();
    await runQuickScan();
  }

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  void setCategoryFilter(FileCategory? category) {
    _selectedCategoryFilter = category;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q.toLowerCase();
    notifyListeners();
  }

  Future<void> refreshDiskStats() async {
    _disks = await _engine.getDiskStats();
    notifyListeners();
  }

  Future<void> refreshQuarantine() async {
    _quarantineIndex = await _engine.listQuarantine();
    notifyListeners();
  }

  Future<void> runQuickScan() async {
    _isScanning = true;
    notifyListeners();

    try {
      _scanResult = await _engine.scanRecommendations();
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
  }

  Future<void> scanOrganizer([String? customPath]) async {
    if (customPath != null && customPath.trim().isNotEmpty) {
      _organizeTarget = customPath.trim();
    }
    _isOrganizing = true;
    notifyListeners();

    try {
      _organizeResult = await _engine.scanOrganizer(path: _organizeTarget);
    } catch (_) {}

    _isOrganizing = false;
    notifyListeners();
  }

  void toggleFileSelection(ScannedFile file) {
    file.isSelected = !file.isSelected;
    notifyListeners();
  }

  void toggleAllFileSelection(bool select) {
    if (_scanResult == null) return;
    for (final f in _scanResult!.items) {
      f.isSelected = select;
    }
    notifyListeners();
  }

  void toggleOrganizeItem(OrganizePlanItem item) {
    item.isSelected = !item.isSelected;
    notifyListeners();
  }

  void toggleQuarantineItem(QuarantineEntry entry) {
    entry.isSelected = !entry.isSelected;
    notifyListeners();
  }

  List<ScannedFile> get filteredFiles {
    if (_scanResult == null) return [];
    var list = _scanResult!.items.where((f) {
      if (_selectedCategoryFilter != null && f.category != _selectedCategoryFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return f.filename.toLowerCase().contains(_searchQuery) ||
            f.path.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'size_desc':
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case 'name_asc':
        list.sort((a, b) => a.filename.compareTo(b.filename));
        break;
      case 'category':
        list.sort((a, b) => a.category.label.compareTo(b.category.label));
        break;
    }
    return list;
  }

  int get selectedFilesCount =>
      _scanResult?.items.where((f) => f.isSelected).length ?? 0;

  int get selectedFilesTotalBytes => _scanResult?.items
          .where((f) => f.isSelected)
          .fold<int>(0, (sum, f) => sum + f.sizeBytes) ??
      0;

  String get selectedFilesHumanBytes {
    final b = selectedFilesTotalBytes;
    if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(2)} GB';
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }

  Future<int> quarantineSelectedFiles() async {
    if (_scanResult == null) return 0;
    final selected = _scanResult!.items.where((f) => f.isSelected).toList();
    if (selected.isEmpty) return 0;

    final paths = selected.map((f) => f.path).toList();
    await _engine.quarantineFiles(paths);

    _scanResult!.items.removeWhere((f) => f.isSelected);
    await refreshQuarantine();
    await refreshDiskStats();
    notifyListeners();
    return selected.length;
  }

  Future<DirectDeleteResult> deleteSelectedFilesDirectly() async {
    if (_scanResult == null) {
      return DirectDeleteResult(
        deletedCount: 0,
        skippedCount: 0,
        freedBytes: 0,
        humanFreed: '0 B',
        deletedPaths: [],
      );
    }
    final selected = _scanResult!.items.where((f) => f.isSelected).toList();
    if (selected.isEmpty) {
      return DirectDeleteResult(
        deletedCount: 0,
        skippedCount: 0,
        freedBytes: 0,
        humanFreed: '0 B',
        deletedPaths: [],
      );
    }

    final paths = selected.map((f) => f.path).toList();
    final result = await _engine.deleteFilesDirectly(paths);
    final deletedSet = result.deletedPaths.toSet();
    _scanResult!.items.removeWhere((f) => deletedSet.contains(f.path));

    await refreshDiskStats();
    notifyListeners();
    return result;
  }

  Future<int> executeOrganize() async {
    if (_organizeResult == null) return 0;
    final selected = _organizeResult!.items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) return 0;

    final count = await _engine.executeOrganize(selected);
    _organizeResult!.items.removeWhere((i) => i.isSelected);
    notifyListeners();
    return count;
  }

  Future<int> restoreSelectedQuarantine() async {
    if (_quarantineIndex == null) return 0;
    final selected = _quarantineIndex!.entries.where((e) => e.isSelected).toList();
    if (selected.isEmpty) return 0;

    final ids = selected.map((e) => e.id).toList();
    final count = await _engine.restoreFiles(ids);
    await refreshQuarantine();
    await refreshDiskStats();
    return count;
  }

  Future<int> purgeSelectedQuarantine() async {
    if (_quarantineIndex == null) return 0;
    final selected = _quarantineIndex!.entries.where((e) => e.isSelected).toList();
    if (selected.isEmpty) return 0;

    final ids = selected.map((e) => e.id).toList();
    final count = await _engine.purgeFiles(ids);
    await refreshQuarantine();
    await refreshDiskStats();
    return count;
  }
}
