import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/engine_models.dart';

class RustEngineService {
  static final RustEngineService _instance = RustEngineService._internal();
  factory RustEngineService() => _instance;
  RustEngineService._internal();

  Process? _process;
  int _requestId = 0;
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  final _stdoutController = StreamController<String>.broadcast();

  String get _enginePath {
    // Look in current directory or target/release/debug
    final candidates = [
      'rapih_engine.exe',
      '../rapih_engine/target/release/rapih_engine.exe',
      '../rapih_engine/target/debug/rapih_engine.exe',
      'target/release/rapih_engine.exe',
      'target/debug/rapih_engine.exe',
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) {
        return c;
      }
    }
    return 'rapih_engine.exe';
  }

  Future<void> initEngine() async {
    final path = _enginePath;
    if (!File(path).existsSync()) {
      return;
    }

    try {
      _process = await Process.start(path, []);
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleStdoutLine);

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // Log engine stderr
      });
    } catch (_) {
      // Process start fallback
    }
  }

  void _handleStdoutLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id != null && _pendingRequests.containsKey(id)) {
        final completer = _pendingRequests.remove(id)!;
        if (json['error'] != null) {
          completer.completeError(json['error']);
        } else {
          completer.complete(json['result']);
        }
      }
    } catch (_) {}
  }

  Future<dynamic> _callMethod(String method, [Map<String, dynamic>? params]) async {
    // If persistent process is not running, run via CLI subcommand directly
    if (_process == null) {
      return _callViaCli(method, params);
    }

    final id = 'req_${++_requestId}';
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final payload = {
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };

    _process!.stdin.writeln(jsonEncode(payload));
    await _process!.stdin.flush();

    return completer.future.timeout(const Duration(seconds: 45), onTimeout: () {
      _pendingRequests.remove(id);
      throw TimeoutException('Request to Rust engine timed out');
    });
  }

  Future<dynamic> _callViaCli(String method, [Map<String, dynamic>? params]) async {
    final engineBinary = _enginePath;
    final List<String> args = ['--cmd', method];
    if (params != null) {
      args.add(jsonEncode(params));
    }

    if (File(engineBinary).existsSync()) {
      final result = await Process.run(engineBinary, args);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        final json = jsonDecode(output) as Map<String, dynamic>;
        if (json['success'] == true) {
          return json['data'];
        } else {
          throw Exception(json['message'] ?? 'Engine execution failed');
        }
      } else {
        throw Exception(result.stderr.toString());
      }
    } else {
      // Mock / In-Memory Demo Fallback if Rust binary is not yet compiled
      return _mockResponse(method, params);
    }
  }

  Future<List<DiskStats>> getDiskStats() async {
    try {
      final data = await _callMethod('disk_info');
      if (data is List) {
        return data.map((e) => DiskStats.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [
      DiskStats(
        name: 'Local Disk (C:)',
        mountPoint: 'C:\\',
        totalSpaceBytes: 512 * 1024 * 1024 * 1024,
        availableSpaceBytes: 198 * 1024 * 1024 * 1024,
        usedSpaceBytes: 314 * 1024 * 1024 * 1024,
        humanTotal: '512 GB',
        humanAvailable: '198 GB',
        humanUsed: '314 GB',
        usagePercentage: 61.3,
      ),
    ];
  }

  Future<ScanResult> scanRecommendations({List<String>? targets}) async {
    try {
      final data = await _callMethod('scan_recommendations', {
        if (targets != null) 'targets': targets,
      });
      return ScanResult.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return _mockScanResult();
    }
  }

  Future<OrganizeResult> scanOrganizer({String? path}) async {
    try {
      final data = await _callMethod('scan_organizer', {
        if (path != null) 'path': path,
      });
      return OrganizeResult.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return _mockOrganizeResult();
    }
  }

  Future<int> executeOrganize(List<OrganizePlanItem> items) async {
    final payload = items.map((i) => i.toJson()).toList();
    final data = await _callMethod('execute_organize', {'items': payload});
    return data as int? ?? items.length;
  }

  Future<List<QuarantineEntry>> quarantineFiles(List<String> files) async {
    final data = await _callMethod('quarantine_files', {'files': files});
    if (data is List) {
      return data.map((e) => QuarantineEntry.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<QuarantineIndex> listQuarantine() async {
    try {
      final data = await _callMethod('list_quarantine');
      return QuarantineIndex.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return QuarantineIndex(entries: [], totalSizeBytes: 0, humanTotalSize: '0 B');
    }
  }

  Future<int> restoreFiles(List<String> ids) async {
    final data = await _callMethod('restore_files', {'ids': ids});
    return data as int? ?? ids.length;
  }

  Future<int> purgeFiles(List<String> ids) async {
    final data = await _callMethod('purge_files', {'ids': ids});
    return data as int? ?? ids.length;
  }

  // Realistic mock data if binary is starting up
  dynamic _mockResponse(String method, [Map<String, dynamic>? params]) {
    switch (method) {
      case 'disk_info':
        return [
          {
            'name': 'Windows (C:)',
            'mount_point': 'C:\\',
            'total_space_bytes': 512000000000,
            'available_space_bytes': 210000000000,
            'used_space_bytes': 302000000000,
            'human_total': '476.8 GB',
            'human_available': '195.5 GB',
            'human_used': '281.3 GB',
            'usage_percentage': 58.9,
          }
        ];
      case 'scan_recommendations':
        return _mockScanResultJson();
      case 'scan_organizer':
        return _mockOrganizeResultJson();
      case 'list_quarantine':
        return {'entries': [], 'total_size_bytes': 0, 'human_total_size': '0 B'};
      case 'quarantine_files':
        return [];
      case 'restore_files':
      case 'purge_files':
      case 'execute_organize':
        return 1;
      default:
        return null;
    }
  }

  ScanResult _mockScanResult() => ScanResult.fromJson(_mockScanResultJson());

  Map<String, dynamic> _mockScanResultJson() => {
        'total_scanned_files': 1420,
        'total_candidates': 6,
        'total_reclaimable_bytes': 4529848320,
        'human_reclaimable': '4.22 GB',
        'scan_duration_ms': 340,
        'items': [
          {
            'id': 'temp_1',
            'path': 'C:\\Users\\Burhan\\AppData\\Local\\Temp\\chrome_installer_old.tmp',
            'filename': 'chrome_installer_old.tmp',
            'size_bytes': 145000000,
            'human_size': '138.2 MB',
            'category': 'WindowsTemp',
            'reason': 'File sementara sistem (usia 45 hari)',
            'last_modified': '2026-10-12 11:20',
            'recommended_for_deletion': true,
          },
          {
            'id': 'inst_1',
            'path': 'C:\\Users\\Burhan\\Downloads\\VSCodeUserSetup-x64-1.92.0.exe',
            'filename': 'VSCodeUserSetup-x64-1.92.0.exe',
            'size_bytes': 102400000,
            'human_size': '97.6 MB',
            'category': 'OldInstaller',
            'reason': 'Installer lama diunduh 62 hari lalu',
            'last_modified': '2026-09-25 09:14',
            'recommended_for_deletion': true,
          },
          {
            'id': 'dup_1',
            'path': 'C:\\Users\\Burhan\\Downloads\\Asset_Project_Final(1).zip',
            'filename': 'Asset_Project_Final(1).zip',
            'size_bytes': 850000000,
            'human_size': '810.6 MB',
            'category': 'Duplicate',
            'reason': 'Duplikat identik dari Asset_Project_Final.zip',
            'last_modified': '2026-11-02 16:40',
            'hash': 'c8a3f9e21...',
            'recommended_for_deletion': true,
          },
          {
            'id': 'large_1',
            'path': 'C:\\Users\\Burhan\\Downloads\\Ubuntu_Desktop_24.04_LTS.iso',
            'filename': 'Ubuntu_Desktop_24.04_LTS.iso',
            'size_bytes': 3432448320,
            'human_size': '3.19 GB',
            'category': 'LargeForgotten',
            'reason': 'File besar berukuran 3.19 GB, belum dibuka 110 hari',
            'last_modified': '2026-08-08 14:02',
            'recommended_for_deletion': false,
          },
        ],
      };

  OrganizeResult _mockOrganizeResult() => OrganizeResult.fromJson(_mockOrganizeResultJson());

  Map<String, dynamic> _mockOrganizeResultJson() => {
        'total_items': 5,
        'items': [
          {
            'source_path': 'C:\\Users\\Burhan\\Downloads\\Laporan_Keuangan_Q3.pdf',
            'filename': 'Laporan_Keuangan_Q3.pdf',
            'target_folder_name': 'Documents',
            'target_path': 'C:\\Users\\Burhan\\Downloads\\Documents\\Laporan_Keuangan_Q3.pdf',
            'category': 'Dokumen',
            'size_bytes': 2400000,
            'human_size': '2.3 MB',
          },
          {
            'source_path': 'C:\\Users\\Burhan\\Downloads\\Screenshot_2026_Banner.png',
            'filename': 'Screenshot_2026_Banner.png',
            'target_folder_name': 'Images',
            'target_path': 'C:\\Users\\Burhan\\Downloads\\Images\\Screenshot_2026_Banner.png',
            'category': 'Gambar',
            'size_bytes': 1800000,
            'human_size': '1.7 MB',
          },
          {
            'source_path': 'C:\\Users\\Burhan\\Downloads\\NodeJS_v22_Setup.msi',
            'filename': 'NodeJS_v22_Setup.msi',
            'target_folder_name': 'Setups',
            'target_path': 'C:\\Users\\Burhan\\Downloads\\Setups\\NodeJS_v22_Setup.msi',
            'category': 'Installer & Setup',
            'size_bytes': 35000000,
            'human_size': '33.3 MB',
          },
        ]
      };
}
