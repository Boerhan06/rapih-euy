use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum FileCategory {
    WindowsTemp,
    Duplicate,
    LargeForgotten,
    OldInstaller,
    EmptyFolder,
    Documents,
    Media,
    Archives,
    Installers,
    Developer,
    Miscellaneous,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScannedFile {
    pub id: String,
    pub path: String,
    pub filename: String,
    pub size_bytes: u64,
    pub human_size: String,
    pub category: FileCategory,
    pub reason: String,
    pub last_modified: Option<String>,
    pub hash: Option<String>,
    pub recommended_for_deletion: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanResult {
    pub total_scanned_files: usize,
    pub total_candidates: usize,
    pub total_reclaimable_bytes: u64,
    pub human_reclaimable: String,
    pub items: Vec<ScannedFile>,
    pub scan_duration_ms: u128,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrganizePlanItem {
    pub source_path: String,
    pub filename: String,
    pub target_folder_name: String,
    pub target_path: String,
    pub category: String,
    pub size_bytes: u64,
    pub human_size: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrganizeResult {
    pub total_items: usize,
    pub items: Vec<OrganizePlanItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuarantineEntry {
    pub id: String,
    pub original_path: String,
    pub quarantine_path: String,
    pub filename: String,
    pub size_bytes: u64,
    pub human_size: String,
    pub quarantined_at: String,
    pub reason: String,
    pub hash: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuarantineIndex {
    pub entries: Vec<QuarantineEntry>,
    pub total_size_bytes: u64,
    pub human_total_size: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskStats {
    pub name: String,
    pub mount_point: String,
    pub total_space_bytes: u64,
    pub available_space_bytes: u64,
    pub used_space_bytes: u64,
    pub human_total: String,
    pub human_available: String,
    pub human_used: String,
    pub usage_percentage: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DirectDeleteResult {
    pub deleted_count: usize,
    pub skipped_count: usize,
    pub freed_bytes: u64,
    pub human_freed: String,
    pub deleted_paths: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub message: String,
    pub data: Option<T>,
}

impl<T> ApiResponse<T> {
    pub fn ok(data: T, message: &str) -> Self {
        Self {
            success: true,
            message: message.to_string(),
            data: Some(data),
        }
    }

    pub fn err(message: &str) -> Self {
        Self {
            success: false,
            message: message.to_string(),
            data: None,
        }
    }
}

pub fn format_bytes(bytes: u64) -> String {
    const KB: f64 = 1024.0;
    const MB: f64 = KB * 1024.0;
    const GB: f64 = MB * 1024.0;
    const TB: f64 = GB * 1024.0;

    let b = bytes as f64;
    if b >= TB {
        format!("{:.2} TB", b / TB)
    } else if b >= GB {
        format!("{:.2} GB", b / GB)
    } else if b >= MB {
        format!("{:.2} MB", b / MB)
    } else if b >= KB {
        format!("{:.1} KB", b / KB)
    } else {
        format!("{} B", bytes)
    }
}
