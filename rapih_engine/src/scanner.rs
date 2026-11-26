use crate::models::{format_bytes, FileCategory, ScanResult, ScannedFile};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant, SystemTime};
use walkdir::WalkDir;

pub struct Scanner;

impl Scanner {
    pub fn scan_recommendations(custom_targets: Option<Vec<PathBuf>>) -> ScanResult {
        let start_time = Instant::now();
        let mut items = Vec::new();
        let mut total_scanned = 0;

        let mut scan_paths = Vec::new();

        if let Some(targets) = custom_targets {
            for t in targets {
                if t.exists() {
                    scan_paths.push(t);
                }
            }
        } else {
            // Default Windows scanning targets
            if let Ok(temp) = std::env::var("TEMP") {
                let temp_path = PathBuf::from(temp);
                if temp_path.exists() {
                    scan_paths.push(temp_path);
                }
            }

            if let Some(user_dirs) = dirs_sys::download_dir() {
                if user_dirs.exists() {
                    scan_paths.push(user_dirs);
                }
            }
        }

        // 1. Scan for Temp, Installers, Large Forgotten Files, & Empty Folders
        for target in &scan_paths {
            Self::scan_directory_candidates(target, &mut items, &mut total_scanned);
        }

        // Track already-queued candidate paths to avoid double counting
        let seen_paths: HashSet<String> = items.iter().map(|i| i.path.clone()).collect();

        // 2. Scan for Duplicates in non-Temp folders
        for target in &scan_paths {
            let is_temp = target.to_string_lossy().to_lowercase().contains("temp");
            if !is_temp {
                Self::scan_duplicates_in_path(target, &mut items, &seen_paths);
            }
        }

        // Sort largest reclaimable candidates first
        items.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));

        let total_candidates = items.len();
        let total_reclaimable_bytes: u64 = items.iter().map(|f| f.size_bytes).sum();
        let human_reclaimable = format_bytes(total_reclaimable_bytes);

        // Keep top 500 items in UI payload so rendering stays snappy even with thousands of temp files
        const MAX_UI_ITEMS: usize = 500;
        if items.len() > MAX_UI_ITEMS {
            items.truncate(MAX_UI_ITEMS);
        }

        let scan_duration_ms = start_time.elapsed().as_millis();

        ScanResult {
            total_scanned_files: total_scanned,
            total_candidates,
            total_reclaimable_bytes,
            human_reclaimable,
            items,
            scan_duration_ms,
        }
    }

    fn scan_directory_candidates(
        dir: &Path,
        items: &mut Vec<ScannedFile>,
        total_scanned: &mut usize,
    ) {
        let is_temp_dir = dir
            .to_string_lossy()
            .to_lowercase()
            .contains("temp");

        for entry in WalkDir::new(dir)
            .max_depth(4)
            .into_iter()
            .filter_map(Result::ok)
        {
            let path = entry.path();
            *total_scanned += 1;

            if entry.file_type().is_dir() {
                if let Ok(mut read_dir) = fs::read_dir(path) {
                    if read_dir.next().is_none() && path != dir {
                        items.push(ScannedFile {
                            id: format!("empty_{}", blake3::hash(path.to_string_lossy().as_bytes()).to_hex()),
                            path: path.to_string_lossy().to_string(),
                            filename: path.file_name().unwrap_or_default().to_string_lossy().to_string(),
                            size_bytes: 0,
                            human_size: "0 B".to_string(),
                            category: FileCategory::EmptyFolder,
                            reason: "Folder kosong tanpa isi".to_string(),
                            last_modified: None,
                            hash: None,
                            recommended_for_deletion: true,
                        });
                    }
                }
                continue;
            }

            if !entry.file_type().is_file() {
                continue;
            }

            let metadata = match entry.metadata() {
                Ok(m) => m,
                Err(_) => continue,
            };

            let size = metadata.len();
            let filename = entry.file_name().to_string_lossy().to_string();
            let ext = path
                .extension()
                .map(|e| e.to_string_lossy().to_lowercase())
                .unwrap_or_default();

            let last_mod_system = metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH);
            let age_duration = SystemTime::now()
                .duration_since(last_mod_system)
                .unwrap_or(Duration::ZERO);
            let age_days = age_duration.as_secs() / 86400;

            let last_modified_str = chrono::DateTime::<chrono::Utc>::from(last_mod_system)
                .format("%Y-%m-%d %H:%M")
                .to_string();

            // Candidate A: Windows Temp files
            if is_temp_dir {
                if age_days >= 1 || ext == "tmp" || ext == "log" || ext == "bak" {
                    items.push(ScannedFile {
                        id: format!("temp_{}", blake3::hash(path.to_string_lossy().as_bytes()).to_hex()),
                        path: path.to_string_lossy().to_string(),
                        filename: filename.clone(),
                        size_bytes: size,
                        human_size: format_bytes(size),
                        category: FileCategory::WindowsTemp,
                        reason: format!("File sementara sistem (usia {} hari)", age_days),
                        last_modified: Some(last_modified_str.clone()),
                        hash: None,
                        recommended_for_deletion: true,
                    });
                    continue;
                }
            }

            // Candidate B: Old leftover installers in Downloads
            let is_installer = matches!(ext.as_str(), "exe" | "msi" | "iso" | "crdownload");
            if is_installer && age_days >= 14 {
                items.push(ScannedFile {
                    id: format!("installer_{}", blake3::hash(path.to_string_lossy().as_bytes()).to_hex()),
                    path: path.to_string_lossy().to_string(),
                    filename: filename.clone(),
                    size_bytes: size,
                    human_size: format_bytes(size),
                    category: FileCategory::OldInstaller,
                    reason: format!("Installer lama diunduh {} hari lalu", age_days),
                    last_modified: Some(last_modified_str.clone()),
                    hash: None,
                    recommended_for_deletion: true,
                });
                continue;
            }

            // Candidate C: Large forgotten files (> 100 MB and untouched for > 90 days)
            const LARGE_FILE_THRESHOLD: u64 = 100 * 1024 * 1024;
            if size >= LARGE_FILE_THRESHOLD && age_days >= 90 {
                items.push(ScannedFile {
                    id: format!("large_{}", blake3::hash(path.to_string_lossy().as_bytes()).to_hex()),
                    path: path.to_string_lossy().to_string(),
                    filename: filename.clone(),
                    size_bytes: size,
                    human_size: format_bytes(size),
                    category: FileCategory::LargeForgotten,
                    reason: format!("File besar berukuran {}, belum dibuka {} hari", format_bytes(size), age_days),
                    last_modified: Some(last_modified_str.clone()),
                    hash: None,
                    recommended_for_deletion: false,
                });
            }
        }
    }

    fn scan_duplicates_in_path(
        dir: &Path,
        items: &mut Vec<ScannedFile>,
        seen_paths: &HashSet<String>,
    ) {
        let mut size_map: HashMap<u64, Vec<PathBuf>> = HashMap::new();

        // Pass 1: Group files by exact byte size
        for entry in WalkDir::new(dir)
            .max_depth(3)
            .into_iter()
            .filter_map(Result::ok)
        {
            if entry.file_type().is_file() {
                if let Ok(meta) = entry.metadata() {
                    let len = meta.len();
                    if len > 4096 {
                        size_map.entry(len).or_default().push(entry.into_path());
                    }
                }
            }
        }

        // Pass 2: Quick partial hash (head + tail), then full BLAKE3 hash only on matches
        for (size, paths) in size_map {
            if paths.len() < 2 {
                continue;
            }

            let mut quick_map: HashMap<String, Vec<PathBuf>> = HashMap::new();
            for path in paths {
                if let Ok(qhash) = Self::compute_quick_hash(&path, size) {
                    quick_map.entry(qhash).or_default().push(path);
                }
            }

            for (_qhash, quick_matches) in quick_map {
                if quick_matches.len() < 2 {
                    continue;
                }

                let mut hash_map: HashMap<String, Vec<PathBuf>> = HashMap::new();
                for path in quick_matches {
                    if let Ok(hash) = Self::compute_file_hash(&path) {
                        hash_map.entry(hash).or_default().push(path);
                    }
                }

                for (hash, dupes) in hash_map {
                    if dupes.len() >= 2 {
                        for (index, dupe_path) in dupes.iter().enumerate().skip(1) {
                            let path_str = dupe_path.to_string_lossy().to_string();
                            if seen_paths.contains(&path_str) {
                                continue;
                            }

                            let filename = dupe_path
                                .file_name()
                                .unwrap_or_default()
                                .to_string_lossy()
                                .to_string();

                            items.push(ScannedFile {
                                id: format!("dup_{}", blake3::hash(path_str.as_bytes()).to_hex()),
                                path: path_str,
                                filename,
                                size_bytes: size,
                                human_size: format_bytes(size),
                                category: FileCategory::Duplicate,
                                reason: format!("Duplikat identik dari {}", dupes[0].display()),
                                last_modified: None,
                                hash: Some(hash.clone()),
                                recommended_for_deletion: index > 0,
                            });
                        }
                    }
                }
            }
        }
    }

    fn compute_quick_hash(path: &Path, size: u64) -> Result<String, std::io::Error> {
        const CHUNK: usize = 65536;
        let mut file = fs::File::open(path)?;
        let mut hasher = blake3::Hasher::new();
        let mut buffer = vec![0u8; CHUNK];

        let head_read = file.read(&mut buffer)?;
        hasher.update(&buffer[..head_read]);

        if size > (CHUNK as u64) * 2 {
            file.seek(SeekFrom::End(-(CHUNK as i64)))?;
            let tail_read = file.read(&mut buffer)?;
            hasher.update(&buffer[..tail_read]);
        }

        Ok(hasher.finalize().to_hex().to_string())
    }

    pub fn compute_file_hash(path: &Path) -> Result<String, std::io::Error> {
        let mut file = fs::File::open(path)?;
        let mut hasher = blake3::Hasher::new();
        let mut buffer = [0u8; 65536];

        loop {
            let bytes_read = file.read(&mut buffer)?;
            if bytes_read == 0 {
                break;
            }
            hasher.update(&buffer[..bytes_read]);
        }

        Ok(hasher.finalize().to_hex().to_string())
    }
}

mod dirs_sys {
    use std::path::PathBuf;

    pub fn download_dir() -> Option<PathBuf> {
        if let Ok(user_profile) = std::env::var("USERPROFILE") {
            let p = PathBuf::from(user_profile).join("Downloads");
            if p.exists() {
                return Some(p);
            }
        }
        None
    }
}
