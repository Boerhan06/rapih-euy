use crate::models::{format_bytes, OrganizePlanItem, OrganizeResult};
use std::fs;
use std::path::{Path, PathBuf};

pub struct Organizer;

impl Organizer {
    pub fn plan_organization(dir: &Path) -> OrganizeResult {
        let mut items = Vec::new();

        if !dir.exists() || !dir.is_dir() {
            return OrganizeResult {
                total_items: 0,
                items,
            };
        }

        let entries = match fs::read_dir(dir) {
            Ok(e) => e,
            Err(_) => {
                return OrganizeResult {
                    total_items: 0,
                    items,
                }
            }
        };

        for entry in entries.filter_map(Result::ok) {
            let path = entry.path();
            if path.is_dir() {
                // Skip subdirectories to avoid reorganizing existing folders
                continue;
            }

            let filename = entry.file_name().to_string_lossy().to_string();
            let ext = path
                .extension()
                .map(|e| e.to_string_lossy().to_lowercase())
                .unwrap_or_default();

            let (target_folder, category_name) = Self::categorize_extension(&ext);
            let target_dir = dir.join(&target_folder);
            let target_path = target_dir.join(&filename);

            let size = entry.metadata().map(|m| m.len()).unwrap_or(0);

            items.push(OrganizePlanItem {
                source_path: path.to_string_lossy().to_string(),
                filename,
                target_folder_name: target_folder,
                target_path: target_path.to_string_lossy().to_string(),
                category: category_name,
                size_bytes: size,
                human_size: format_bytes(size),
            });
        }

        let total_items = items.len();
        OrganizeResult { total_items, items }
    }

    pub fn execute_plan(items: &[OrganizePlanItem]) -> Result<usize, std::io::Error> {
        let mut moved_count = 0;

        for item in items {
            let src = Path::new(&item.source_path);
            if !src.exists() {
                continue;
            }

            let parent_dir = Path::new(&item.target_path)
                .parent()
                .unwrap_or_else(|| Path::new("."));
            fs::create_dir_all(parent_dir)?;

            let target = Self::resolve_collision(&PathBuf::from(&item.target_path));
            if fs::rename(src, &target).is_err() {
                // Fallback for cross-filesystem moves
                fs::copy(src, &target)?;
                let _ = fs::remove_file(src);
            }
            moved_count += 1;
        }

        Ok(moved_count)
    }

    fn resolve_collision(target: &Path) -> PathBuf {
        if !target.exists() {
            return target.to_path_buf();
        }

        let stem = target
            .file_stem()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();
        let ext = target
            .extension()
            .map(|e| format!(".{}", e.to_string_lossy()))
            .unwrap_or_default();
        let parent = target.parent().unwrap_or_else(|| Path::new("."));

        let mut counter = 1;
        loop {
            let candidate = parent.join(format!("{}_{}{}", stem, counter, ext));
            if !candidate.exists() {
                return candidate;
            }
            counter += 1;
        }
    }

    fn categorize_extension(ext: &str) -> (String, String) {
        match ext {
            // Documents
            "pdf" | "doc" | "docx" | "xls" | "xlsx" | "ppt" | "pptx" | "txt" | "md" | "rtf"
            | "odt" | "csv" | "epub" => ("Documents".to_string(), "Dokumen".to_string()),

            // Images
            "jpg" | "jpeg" | "png" | "gif" | "svg" | "webp" | "bmp" | "ico" | "psd" | "ai"
            | "raw" | "tiff" => ("Images".to_string(), "Gambar".to_string()),

            // Videos
            "mp4" | "mkv" | "avi" | "mov" | "wmv" | "flv" | "webm" | "m4v" => {
                ("Videos".to_string(), "Video".to_string())
            }

            // Audio
            "mp3" | "wav" | "flac" | "aac" | "ogg" | "m4a" | "wma" => {
                ("Audio".to_string(), "Audio / Musik".to_string())
            }

            // Archives
            "zip" | "rar" | "7z" | "tar" | "gz" | "bz2" | "xz" | "tgz" => {
                ("Archives".to_string(), "Arsip & Zip".to_string())
            }

            // Installers / Executables
            "exe" | "msi" | "apk" | "iso" | "dmg" | "deb" | "rpm" => {
                ("Setups".to_string(), "Installer & Setup".to_string())
            }

            // Developer / Code
            "rs" | "dart" | "py" | "js" | "ts" | "jsx" | "tsx" | "html" | "css" | "json"
            | "yaml" | "yml" | "sql" | "cpp" | "c" | "h" | "java" | "go" | "sh" | "bat"
            | "ps1" => ("DevProjects".to_string(), "Kode & Data".to_string()),

            // Others
            _ => ("Others".to_string(), "Lainnya".to_string()),
        }
    }
}
