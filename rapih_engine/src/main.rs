mod models;
mod organizer;
mod quarantine;
mod scanner;

use models::{format_bytes, ApiResponse, DiskStats, OrganizePlanItem};
use organizer::Organizer;
use quarantine::QuarantineManager;
use scanner::Scanner;
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::thread;
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

    // Mode 1: Local HTTP JSON-RPC Server (for Web / Hybrid / Multi-client UI)
    if args.len() > 1 && args[1] == "--serve" {
        let port: u16 = args
            .get(2)
            .and_then(|s| s.parse().ok())
            .unwrap_or(8787);
        run_http_server(port);
        return;
    }

    // Mode 2: CLI invocation (e.g. rapih_engine.exe --cmd disk_info)
    if args.len() > 1 && args[1] == "--cmd" {
        let cmd = args.get(2).map(|s| s.as_str()).unwrap_or("help");
        let payload = args.get(3).map(|s| s.as_str());
        handle_cli_command(cmd, payload);
        return;
    }

    // Mode 3: Interactive JSON-RPC stdio daemon loop for Flutter desktop frontend
    run_interactive_stdio();
}

/// Shared RPC dispatcher used across CLI, stdio JSON-RPC, and local HTTP server.
fn dispatch_rpc(method: &str, params: Option<serde_json::Value>) -> Result<serde_json::Value, String> {
    match method {
        "ping" => Ok(serde_json::Value::String("pong".to_string())),
        "disk_info" => {
            let stats = get_disk_stats();
            serde_json::to_value(stats).map_err(|e| e.to_string())
        }
        "scan_recommendations" => {
            let targets: Option<Vec<PathBuf>> = params
                .and_then(|p| p.get("targets").cloned())
                .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                .map(|v| v.into_iter().map(PathBuf::from).collect());

            let result = Scanner::scan_recommendations(targets);
            serde_json::to_value(result).map_err(|e| e.to_string())
        }
        "scan_organizer" => {
            let requested = params
                .as_ref()
                .and_then(|p| p.get("path"))
                .and_then(|v| v.as_str());

            let target_dir = resolve_organizer_dir(requested);
            let result = Organizer::plan_organization(&target_dir);
            serde_json::to_value(result).map_err(|e| e.to_string())
        }
        "execute_organize" => {
            let items = params
                .and_then(|p| p.get("items").cloned())
                .and_then(|v| serde_json::from_value::<Vec<OrganizePlanItem>>(v).ok())
                .ok_or_else(|| "Missing 'items' parameter".to_string())?;

            let count = Organizer::execute_plan(&items).map_err(|e| e.to_string())?;
            serde_json::to_value(count).map_err(|e| e.to_string())
        }
        "quarantine_files" => {
            let files = params
                .and_then(|p| p.get("files").cloned())
                .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                .ok_or_else(|| "Missing 'files' parameter".to_string())?;

            let entries = QuarantineManager::quarantine_files(&files, None).map_err(|e| e.to_string())?;
            serde_json::to_value(entries).map_err(|e| e.to_string())
        }
        "list_quarantine" => {
            let index = QuarantineManager::load_index();
            serde_json::to_value(index).map_err(|e| e.to_string())
        }
        "restore_files" => {
            let ids = params
                .and_then(|p| p.get("ids").cloned())
                .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                .ok_or_else(|| "Missing 'ids' parameter".to_string())?;

            let count = QuarantineManager::restore_files(&ids).map_err(|e| e.to_string())?;
            serde_json::to_value(count).map_err(|e| e.to_string())
        }
        "purge_files" => {
            let ids = params
                .and_then(|p| p.get("ids").cloned())
                .and_then(|v| serde_json::from_value::<Vec<String>>(v).ok())
                .ok_or_else(|| "Missing 'ids' parameter".to_string())?;

            let count = QuarantineManager::purge_files(&ids).map_err(|e| e.to_string())?;
            serde_json::to_value(count).map_err(|e| e.to_string())
        }
        unknown => Err(format!("Unknown method: {}", unknown)),
    }
}

fn resolve_organizer_dir(requested: Option<&str>) -> PathBuf {
    match requested.map(|s| s.trim()).filter(|s| !s.is_empty()) {
        Some("downloads") | None => dirs_sys::download_dir().unwrap_or_else(|| PathBuf::from(".")),
        Some("desktop") => dirs_sys::user_subdir("Desktop").unwrap_or_else(|| PathBuf::from(".")),
        Some("documents") => dirs_sys::user_subdir("Documents").unwrap_or_else(|| PathBuf::from(".")),
        Some(custom) => PathBuf::from(custom),
    }
}

fn handle_cli_command(cmd: &str, payload: Option<&str>) {
    let params = match (cmd, payload) {
        ("scan_recommendations", Some(p)) => Some(
            serde_json::from_str::<serde_json::Value>(p)
                .map(|v| if v.is_array() { serde_json::json!({ "targets": v }) } else { v })
                .unwrap_or_else(|_| serde_json::json!({ "targets": [p] })),
        ),
        ("scan_organizer", Some(p)) => Some(
            serde_json::from_str::<serde_json::Value>(p)
                .unwrap_or_else(|_| serde_json::json!({ "path": p })),
        ),
        ("execute_organize", Some(p)) => serde_json::from_str::<serde_json::Value>(p)
            .ok()
            .map(|v| if v.is_array() { serde_json::json!({ "items": v }) } else { v }),
        ("quarantine_files", Some(p)) => serde_json::from_str::<serde_json::Value>(p)
            .ok()
            .map(|v| if v.is_array() { serde_json::json!({ "files": v }) } else { v }),
        ("restore_files" | "purge_files", Some(p)) => serde_json::from_str::<serde_json::Value>(p)
            .ok()
            .map(|v| if v.is_array() { serde_json::json!({ "ids": v }) } else { v }),
        (_, Some(p)) => serde_json::from_str::<serde_json::Value>(p).ok(),
        (_, None) => None,
    };

    match dispatch_rpc(cmd, params) {
        Ok(data) => println!(
            "{}",
            serde_json::to_string(&ApiResponse::ok(data, "OK")).unwrap()
        ),
        Err(msg) => println!(
            "{}",
            serde_json::to_string(&ApiResponse::<()>::err(&msg)).unwrap()
        ),
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
                send_response::<()>(&mut stdout, None, Err(format!("Parse error: {}", e)));
                continue;
            }
        };

        let req_id = req.id.clone();
        let res = dispatch_rpc(&req.method, req.params);
        send_response(&mut stdout, req_id, res);
    }
}

fn run_http_server(port: u16) {
    let addr = format!("127.0.0.1:{}", port);
    let listener = match TcpListener::bind(&addr) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind {}: {}", addr, e);
            std::process::exit(1);
        }
    };

    println!("rapih_engine HTTP server listening on http://{}", addr);

    for stream in listener.incoming() {
        if let Ok(stream) = stream {
            thread::spawn(|| handle_http_connection(stream));
        }
    }
}

fn handle_http_connection(mut stream: TcpStream) {
    let mut reader = BufReader::new(match stream.try_clone() {
        Ok(s) => s,
        Err(_) => return,
    });

    let mut request_line = String::new();
    if reader.read_line(&mut request_line).unwrap_or(0) == 0 {
        return;
    }

    let parts: Vec<&str> = request_line.split_whitespace().collect();
    if parts.len() < 2 {
        return;
    }
    let http_method = parts[0];
    let http_path = parts[1];

    let mut content_length: usize = 0;
    loop {
        let mut header_line = String::new();
        if reader.read_line(&mut header_line).unwrap_or(0) == 0 {
            break;
        }
        let trimmed = header_line.trim();
        if trimmed.is_empty() {
            break;
        }
        if let Some((name, value)) = trimmed.split_once(':') {
            if name.eq_ignore_ascii_case("content-length") {
                content_length = value.trim().parse().unwrap_or(0);
            }
        }
    }

    if http_method == "OPTIONS" {
        write_http_response(&mut stream, "204 No Content", "");
        return;
    }

    if http_method == "GET" && http_path == "/health" {
        write_http_response(&mut stream, "200 OK", r#"{"status":"ok","engine":"rapih_engine"}"#);
        return;
    }

    if http_method == "POST" && http_path == "/rpc" {
        let mut body = vec![0u8; content_length];
        if content_length > 0 && reader.read_exact(&mut body).is_err() {
            write_http_response(&mut stream, "400 Bad Request", r#"{"error":"Failed to read body"}"#);
            return;
        }

        let req: JsonRpcRequest = match serde_json::from_slice(&body) {
            Ok(r) => r,
            Err(e) => {
                let err_json = serde_json::to_string(&JsonRpcResponse::<()> {
                    id: None,
                    result: None,
                    error: Some(format!("Parse error: {}", e)),
                })
                .unwrap();
                write_http_response(&mut stream, "400 Bad Request", &err_json);
                return;
            }
        };

        let req_id = req.id.clone();
        let resp = match dispatch_rpc(&req.method, req.params) {
            Ok(data) => JsonRpcResponse {
                id: req_id,
                result: Some(data),
                error: None,
            },
            Err(err) => JsonRpcResponse {
                id: req_id,
                result: None,
                error: Some(err),
            },
        };

        let json = serde_json::to_string(&resp).unwrap();
        write_http_response(&mut stream, "200 OK", &json);
        return;
    }

    write_http_response(&mut stream, "404 Not Found", r#"{"error":"Not found"}"#);
}

fn write_http_response(stream: &mut TcpStream, status: &str, body: &str) {
    let response = format!(
        "HTTP/1.1 {}\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: POST, GET, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        status,
        body.len(),
        body
    );
    let _ = stream.write_all(response.as_bytes());
    let _ = stream.flush();
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
        user_subdir("Downloads")
    }

    pub fn user_subdir(folder: &str) -> Option<PathBuf> {
        if let Ok(user_profile) = std::env::var("USERPROFILE") {
            let p = PathBuf::from(user_profile).join(folder);
            if p.exists() {
                return Some(p);
            }
        }
        None
    }
}
