use crate::models::{format_bytes, DirectDeleteResult, QuarantineEntry, QuarantineIndex};
use crate::scanner::Scanner;
use chrono::Utc;
use std::fs;
use std::path::{Path, PathBuf};

pub struct QuarantineManager;

impl QuarantineManager {
    pub fn get_vault_dir() -> PathBuf {
        if let Ok(local_app) = std::env::var("LOCALAPPDATA") {
            let p = PathBuf::from(local_app).join("RapihEuy").join("Quarantine");
            let _ = fs::create_dir_all(&p);
            return p;
        }

        // Fallback local directory
        let fallback = PathBuf::from(".rapih_quarantine");
        let _ = fs::create_dir_all(&fallback);
        fallback
    }

    fn get_index_path() -> PathBuf {
        Self::get_vault_dir().join("quarantine_index.json")
    }

    pub fn load_index() -> QuarantineIndex {
        let index_path = Self::get_index_path();
        if !index_path.exists() {
            return QuarantineIndex {
                entries: Vec::new(),
                total_size_bytes: 0,
                human_total_size: "0 B".to_string(),
            };
        }

        match fs::read_to_string(&index_path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_else(|_| QuarantineIndex {
                entries: Vec::new(),
                total_size_bytes: 0,
                human_total_size: "0 B".to_string(),
            }),
            Err(_) => QuarantineIndex {
                entries: Vec::new(),
                total_size_bytes: 0,
                human_total_size: "0 B".to_string(),
            },
        }
    }

    pub fn save_index(index: &QuarantineIndex) -> Result<(), std::io::Error> {
        let index_path = Self::get_index_path();
        let json = serde_json::to_string_pretty(index)?;
        fs::write(index_path, json)
    }

    pub fn quarantine_files(
        files_to_quarantine: &[String],
        reasons: Option<&[String]>,
    ) -> Result<Vec<QuarantineEntry>, std::io::Error> {
        let vault = Self::get_vault_dir();
        let mut index = Self::load_index();
        let mut quarantined = Vec::new();

        for (idx, file_path_str) in files_to_quarantine.iter().enumerate() {
            let src = Path::new(file_path_str);
            if !src.exists() {
                continue;
            }

            let filename = src
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();

            let metadata = match src.metadata() {
                Ok(m) => m,
                Err(_) => continue,
            };

            let size = metadata.len();
            let id = format!(
                "quar_{}_{}",
                Utc::now().timestamp_millis(),
                blake3::hash(file_path_str.as_bytes()).to_hex()
            );

            let vault_filename = format!("{}_{}", id, filename);
            let dest_path = vault.join(&vault_filename);

            // Compute hash before moving
            let hash = Scanner::compute_file_hash(src).ok();

            // Safe move (fallback to copy + remove for cross-drive operations)
            if fs::rename(src, &dest_path).is_err() {
                fs::copy(src, &dest_path)?;
                if src.is_file() {
                    let _ = fs::remove_file(src);
                } else if src.is_dir() {
                    let _ = fs::remove_dir_all(src);
                }
            }

            let reason_str = reasons
                .and_then(|r| r.get(idx))
                .cloned()
                .unwrap_or_else(|| "Dihapus oleh pengguna".to_string());

            let entry = QuarantineEntry {
                id,
                original_path: file_path_str.clone(),
                quarantine_path: dest_path.to_string_lossy().to_string(),
                filename,
                size_bytes: size,
                human_size: format_bytes(size),
                quarantined_at: Utc::now().to_rfc3339(),
                reason: reason_str,
                hash,
            };

            index.entries.push(entry.clone());
            quarantined.push(entry);
        }

        index.total_size_bytes = index.entries.iter().map(|e| e.size_bytes).sum();
        index.human_total_size = format_bytes(index.total_size_bytes);

        Self::save_index(&index)?;
        Ok(quarantined)
    }

    pub fn restore_files(entry_ids: &[String]) -> Result<usize, std::io::Error> {
        let mut index = Self::load_index();
        let mut restored_count = 0;

        let mut remaining_entries = Vec::new();

        for entry in index.entries {
            if entry_ids.contains(&entry.id) {
                let q_path = Path::new(&entry.quarantine_path);
                let orig_path = Path::new(&entry.original_path);

                if q_path.exists() {
                    if let Some(parent) = orig_path.parent() {
                        let _ = fs::create_dir_all(parent);
                    }

                    if fs::rename(q_path, orig_path).is_err() {
                        fs::copy(q_path, orig_path)?;
                        let _ = fs::remove_file(q_path);
                    }
                    restored_count += 1;
                }
            } else {
                remaining_entries.push(entry);
            }
        }

        index.entries = remaining_entries;
        index.total_size_bytes = index.entries.iter().map(|e| e.size_bytes).sum();
        index.human_total_size = format_bytes(index.total_size_bytes);

        Self::save_index(&index)?;
        Ok(restored_count)
    }

    pub fn purge_files(entry_ids: &[String]) -> Result<usize, std::io::Error> {
        let mut index = Self::load_index();
        let mut purged_count = 0;

        let mut remaining_entries = Vec::new();

        for entry in index.entries {
            if entry_ids.contains(&entry.id) {
                let q_path = Path::new(&entry.quarantine_path);
                if q_path.exists() {
                    let _ = fs::remove_file(q_path);
                    purged_count += 1;
                }
            } else {
                remaining_entries.push(entry);
            }
        }

        index.entries = remaining_entries;
        index.total_size_bytes = index.entries.iter().map(|e| e.size_bytes).sum();
        index.human_total_size = format_bytes(index.total_size_bytes);

        Self::save_index(&index)?;
        Ok(purged_count)
    }

    pub fn delete_files_directly(file_paths: &[String]) -> DirectDeleteResult {
        let mut deleted_count = 0;
        let mut skipped_count = 0;
        let mut freed_bytes = 0u64;
        let mut deleted_paths = Vec::new();

        for file_path_str in file_paths {
            let target = Path::new(file_path_str);
            if !target.exists() {
                skipped_count += 1;
                continue;
            }

            let size = target.metadata().map(|m| m.len()).unwrap_or(0);
            let remove_result = if target.is_dir() {
                fs::remove_dir_all(target)
            } else {
                fs::remove_file(target)
            };

            if remove_result.is_ok() {
                deleted_count += 1;
                freed_bytes += size;
                deleted_paths.push(file_path_str.clone());
            } else {
                skipped_count += 1;
            }
        }

        DirectDeleteResult {
            deleted_count,
            skipped_count,
            freed_bytes,
            human_freed: format_bytes(freed_bytes),
            deleted_paths,
        }
    }
}
