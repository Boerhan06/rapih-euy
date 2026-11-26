mod models;
mod organizer;
mod quarantine;
mod scanner;

use models::{format_bytes, ApiResponse, DiskStats, OrganizePlanItem};
use organizer::Organizer;
use quarantine::QuarantineManager;
use scanner::Scanner;
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};
use std::path::PathBuf;
use sysinfo::Disks;

#[derive(Debug, Deserialize)]
struct JsonRpcRequest {
    pub id: Option<String>,
    pub method: String,
    pub params: Option<serde_json::Value>,
}

#[derive(Debug, Serialize)]
struct JsonRpcResponse<T> {
    pub id: Option<String>,
    pub result: Option<T>,
    pub error: Option<String>,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    // Mode 1: CLI invocation (e.g. rapih_engine.exe --cmd disk_info)
    if args.len() > 1 && args[1] == "--cmd" {
        let cmd = args.get(2).map(|s| s.as_str()).unwrap_or("help");
        let payload = args.get(3).map(|s| s.as_str());
        handle_cli_command(cmd, payload);
        return;
    }

    // Mode 2: Interactive JSON-RPC stdio daemon loop for Flutter desktop frontend
    run_interactive_stdio();
}

fn handle_cli_command(cmd: &str, payload: Option<&str>) {
    match cmd {
        "disk_info" => {
            let res = get_disk_stats();
            println!("{}", serde_json::to_string(&ApiResponse::ok(res, "Disk info loaded")).unwrap());
        }
        "scan_recommendations" => {
            let targets: Option<Vec<PathBuf>> = payload
                .and_then(|p| serde_json::from_str::<Vec<String>>(p).ok())
                .map(|v| v.into_iter().map(PathBuf::from).collect());

            let res = Scanner::scan_recommendations(targets);
            println!("{}", serde_json::to_string(&ApiResponse::ok(res, "Scan completed")).unwrap());
        }
        "scan_organizer" => {
            let target_str = payload.unwrap_or(".");
            let res = Organizer::plan_organization(&PathBuf::from(target_str));
            println!("{}", serde_json::to_string(&ApiResponse::ok(res, "Organize plan generated")).unwrap());
        }
        "execute_organize" => {
            if let Some(p) = payload {
                if let Ok(items) = serde_json::from_str::<Vec<OrganizePlanItem>>(p) {
                    match Organizer::execute_plan(&items) {
                        Ok(count) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::ok(count, "Files organized successfully")).unwrap()
                        ),
                        Err(e) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::<()>::err(&e.to_string())).unwrap()
                        ),
                    }
                    return;
                }
            }
            println!("{}", serde_json::to_string(&ApiResponse::<()>::err("Invalid payload for execute_organize")).unwrap());
        }
        "quarantine_files" => {
            if let Some(p) = payload {
                if let Ok(files) = serde_json::from_str::<Vec<String>>(p) {
                    match QuarantineManager::quarantine_files(&files, None) {
                        Ok(entries) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::ok(entries, "Files moved to quarantine")).unwrap()
                        ),
                        Err(e) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::<()>::err(&e.to_string())).unwrap()
                        ),
                    }
                    return;
                }
            }
            println!("{}", serde_json::to_string(&ApiResponse::<()>::err("Invalid payload for quarantine_files")).unwrap());
        }
        "list_quarantine" => {
            let index = QuarantineManager::load_index();
            println!("{}", serde_json::to_string(&ApiResponse::ok(index, "Quarantine list loaded")).unwrap());
        }
        "restore_files" => {
            if let Some(p) = payload {
                if let Ok(ids) = serde_json::from_str::<Vec<String>>(p) {
                    match QuarantineManager::restore_files(&ids) {
                        Ok(count) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::ok(count, "Files restored successfully")).unwrap()
                        ),
                        Err(e) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::<()>::err(&e.to_string())).unwrap()
                        ),
                    }
                    return;
                }
            }
            println!("{}", serde_json::to_string(&ApiResponse::<()>::err("Invalid payload for restore_files")).unwrap());
        }
        "purge_files" => {
            if let Some(p) = payload {
                if let Ok(ids) = serde_json::from_str::<Vec<String>>(p) {
                    match QuarantineManager::purge_files(&ids) {
                        Ok(count) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::ok(count, "Files permanently purged")).unwrap()
                        ),
                        Err(e) => println!(
                            "{}",
                            serde_json::to_string(&ApiResponse::<()>::err(&e.to_string())).unwrap()
                        ),
                    }
                    return;
                }
            }
            println!("{}", serde_json::to_string(&ApiResponse::<()>::err("Invalid payload for purge_files")).unwrap());
        }
        _ => {
            println!("{}", serde_json::to_string(&ApiResponse::<()>::err("Unknown command")).unwrap());
        }
    }
}

fn run_interactive_stdio() {
    let stdin = io::stdin();
    let mut stdout = io::stdout();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        let req: JsonRpcRequest = match serde_json::from_str(trimmed) {
            Ok(r) => r,
            Err(e) => {
                let err_resp = JsonRpcResponse::<()> {
                    id: None,
                    result: None,
                    error: Some(format!("Parse error: {}", e)),
                };
                let _ = writeln!(stdout, "{}", serde_json::to_string(&err_resp).unwrap());
                let _ = stdout.flush();
                continue;
            }
        };

        let req_id = req.id.clone();
        match req.method.as_str() {
            "ping" => {
                send_response(&mut stdout, req_id, Ok("pong"));
            }
            "disk_info" => {
                let stats = get_disk_stats();
                send_response(&mut stdout, req_id, Ok(stats));
            }
            "scan_recommendations" => {
                let targets: Option<Vec<PathBuf>> = req.params
                    .and_then(|p| p.get("targets").cloned())
                    .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                    .map(|v| v.into_iter().map(PathBuf::from).collect());

                let result = Scanner::scan_recommendations(targets);
                send_response(&mut stdout, req_id, Ok(result));
            }
            "scan_organizer" => {
                let target_dir = req.params
                    .as_ref()
                    .and_then(|p| p.get("path"))
                    .and_then(|v| v.as_str())
                    .map(PathBuf::from)
                    .unwrap_or_else(|| {
                        dirs_sys::download_dir().unwrap_or_else(|| PathBuf::from("."))
                    });

                let result = Organizer::plan_organization(&target_dir);
                send_response(&mut stdout, req_id, Ok(result));
            }
            "execute_organize" => {
                if let Some(items) = req.params
                    .and_then(|p| p.get("items").cloned())
                    .and_then(|v| serde_json::from_value::<Vec<OrganizePlanItem>>(v).ok())
                {
                    match Organizer::execute_plan(&items) {
                        Ok(count) => send_response(&mut stdout, req_id, Ok(count)),
                        Err(e) => send_response::<()>(&mut stdout, req_id, Err(e.to_string())),
                    }
                } else {
                    send_response::<()>(&mut stdout, req_id, Err("Missing 'items' parameter".to_string()));
                }
            }
            "quarantine_files" => {
                if let Some(files) = req.params
                    .and_then(|p| p.get("files").cloned())
                    .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                {
                    match QuarantineManager::quarantine_files(&files, None) {
                        Ok(entries) => send_response(&mut stdout, req_id, Ok(entries)),
                        Err(e) => send_response::<()>(&mut stdout, req_id, Err(e.to_string())),
                    }
                } else {
                    send_response::<()>(&mut stdout, req_id, Err("Missing 'files' parameter".to_string()));
                }
            }
            "list_quarantine" => {
                let index = QuarantineManager::load_index();
                send_response(&mut stdout, req_id, Ok(index));
            }
            "restore_files" => {
                if let Some(ids) = req.params
                    .and_then(|p| p.get("ids").cloned())
                    .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                {
                    match QuarantineManager::restore_files(&ids) {
                        Ok(count) => send_response(&mut stdout, req_id, Ok(count)),
                        Err(e) => send_response::<()>(&mut stdout, req_id, Err(e.to_string())),
                    }
                } else {
                    send_response::<()>(&mut stdout, req_id, Err("Missing 'ids' parameter".to_string()));
                }
            }
            "purge_files" => {
                if let Some(ids) = req.params
                    .and_then(|p| p.get("ids").cloned())
                    .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                {
                    match QuarantineManager::purge_files(&ids) {
                        Ok(count) => send_response(&mut stdout, req_id, Ok(count)),
                        Err(e) => send_response::<()>(&mut stdout, req_id, Err(e.to_string())),
                    }
                } else {
                    send_response::<()>(&mut stdout, req_id, Err("Missing 'ids' parameter".to_string()));
                }
            }
            unknown => {
                send_response::<()>(&mut stdout, req_id, Err(format!("Unknown method: {}", unknown)));
            }
        }
    }
}

fn send_response<T: Serialize>(
    stdout: &mut io::Stdout,
    id: Option<String>,
    res: Result<T, String>,
) {
    let resp = match res {
        Ok(data) => JsonRpcResponse {
            id,
            result: Some(data),
            error: None,
        },
        Err(err) => JsonRpcResponse {
            id,
            result: None,
            error: Some(err),
        },
    };
    let _ = writeln!(stdout, "{}", serde_json::to_string(&resp).unwrap());
    let _ = stdout.flush();
}

fn get_disk_stats() -> Vec<DiskStats> {
    let disks = Disks::new_with_refreshed_list();
    let mut stats = Vec::new();

    for disk in disks.iter() {
        let total = disk.total_space();
        let available = disk.available_space();
        let used = total.saturating_sub(available);
        let usage_pct = if total > 0 {
            (used as f32 / total as f32) * 100.0
        } else {
            0.0
        };

        stats.push(DiskStats {
            name: disk.name().to_string_lossy().to_string(),
            mount_point: disk.mount_point().to_string_lossy().to_string(),
            total_space_bytes: total,
            available_space_bytes: available,
            used_space_bytes: used,
            human_total: format_bytes(total),
            human_available: format_bytes(available),
            human_used: format_bytes(used),
            usage_percentage: usage_pct,
        });
    }

    stats
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
