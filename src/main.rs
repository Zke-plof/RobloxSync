use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    net::SocketAddr,
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};
use tokio::net::TcpListener;
use tower_http::cors::{Any, CorsLayer};
use tracing::{error, info, warn};
use tracing_subscriber;

mod file_handlers;
mod cli;

use file_handlers::{RbxJsonHandler, LuauHandler};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SyncMessage {
    id: String,
    #[serde(rename = "type")]
    message_type: String,
    path: String,
    content: Option<serde_json::Value>,
    timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ProjectInfo {
    name: String,
    path: String,
    #[serde(rename = "rbxsync_version")]
    rbxsync_version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ConsoleMessage {
    #[serde(rename = "type")]
    message_type: String, // "print", "warn", "error"
    message: String,
    timestamp: u64,
    source: String,
}

type AppState = Arc<Mutex<AppStateInner>>;

struct AppStateInner {
    project_info: Option<ProjectInfo>,
    connected_clients: Vec<String>,
    console_buffer: Vec<ConsoleMessage>,
    pending_syncs: HashMap<String, SyncMessage>,
}

impl AppStateInner {
    fn new() -> Self {
        Self {
            project_info: None,
            connected_clients: Vec::new(),
            console_buffer: Vec::new(),
            pending_syncs: HashMap::new(),
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Check if we're running CLI commands or starting server
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() > 1 {
        // Run CLI commands
        cli::run().await?;
        return Ok(());
    }
    
    // Start server by default
    start_server().await
}

async fn start_server() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let state = AppState::new(Mutex::new(AppStateInner::new()));

    let app = Router::new()
        .route("/", get(health_check))
        .route("/api/health", get(health_check))
        .route("/api/connect", post(connect_client))
        .route("/api/disconnect/:client_id", post(disconnect_client))
        .route("/api/extract", post(extract_game))
        .route("/api/sync", post(sync_changes))
        .route("/api/console", post(console_message))
        .route("/api/console/stream", get(console_stream))
        .route("/api/project", get(get_project))
        .route("/api/project", post(set_project))
        .route("/api/clients", get(list_clients))
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 44755));
    info!("Roblox Sync server starting on {}", addr);

    let listener = TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "ok",
        "version": "1.0.0",
        "timestamp": SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
    }))
}

async fn connect_client(
    State(state): State<AppState>,
    Json(client_info): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let client_id = client_info.get("id")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown")
        .to_string();

    let mut app_state = state.lock().unwrap();
    app_state.connected_clients.push(client_id.clone());

    info!("Client connected: {}", client_id);

    Ok(Json(serde_json::json!({
        "status": "connected",
        "client_id": client_id
    })))
}

async fn disconnect_client(
    State(state): State<AppState>,
    Path(client_id): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut app_state = state.lock().unwrap();
    app_state.connected_clients.retain(|id| id != &client_id);

    info!("Client disconnected: {}", client_id);

    Ok(Json(serde_json::json!({
        "status": "disconnected"
    })))
}

async fn list_clients(State(state): State<AppState>) -> Json<serde_json::Value> {
    let app_state = state.lock().unwrap();
    Json(serde_json::json!({
        "clients": app_state.connected_clients,
        "count": app_state.connected_clients.len()
    }))
}

async fn extract_game(
    State(state): State<AppState>,
    Json(request): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let project_path = request.get("project_path")
        .and_then(|v| v.as_str())
        .ok_or(StatusCode::BAD_REQUEST)?;

    info!("Extracting game from: {}", project_path);

    // This would normally extract from Roblox Studio
    // For now, we'll create a basic project structure
    let path = PathBuf::from(project_path);
    
    if let Err(e) = create_project_structure(&path) {
        error!("Failed to create project structure: {}", e);
        return Err(StatusCode::INTERNAL_SERVER_ERROR);
    }

    Ok(Json(serde_json::json!({
        "status": "extracted",
        "files_created": true
    })))
}

async fn sync_changes(
    State(state): State<AppState>,
    Json(sync_msg): Json<SyncMessage>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut app_state = state.lock().unwrap();
    app_state.pending_syncs.insert(sync_msg.id.clone(), sync_msg.clone());

    info!("Sync received: {} -> {}", sync_msg.message_type, sync_msg.path);

    // Process the sync based on type
    match sync_msg.message_type.as_str() {
        "file_change" | "file_create" => {
            if let Some(content) = sync_msg.content {
                if let Err(e) = process_file_change(&sync_msg.path, content) {
                    error!("Failed to process file change: {}", e);
                    return Err(StatusCode::INTERNAL_SERVER_ERROR);
                }
            }
        }
        "file_delete" => {
            if let Err(e) = process_file_delete(&sync_msg.path) {
                error!("Failed to delete file: {}", e);
                return Err(StatusCode::INTERNAL_SERVER_ERROR);
            }
        }
        _ => warn!("Unknown sync type: {}", sync_msg.message_type),
    }

    Ok(Json(serde_json::json!({
        "status": "synced",
        "id": sync_msg.id
    })))
}

async fn console_message(
    State(state): State<AppState>,
    Json(msg): Json<ConsoleMessage>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut app_state = state.lock().unwrap();
    app_state.console_buffer.push(msg.clone());

    // Keep console buffer size manageable
    if app_state.console_buffer.len() > 1000 {
        app_state.console_buffer.drain(0..500);
    }

    info!("Console [{}]: {}", msg.message_type, msg.message);

    Ok(Json(serde_json::json!({
        "status": "received"
    })))
}

async fn console_stream(State(state): State<AppState>) -> Json<serde_json::Value> {
    let app_state = state.lock().unwrap();
    Json(serde_json::json!({
        "messages": app_state.console_buffer
    }))
}

async fn get_project(State(state): State<AppState>) -> Json<serde_json::Value> {
    let app_state = state.lock().unwrap();
    Json(serde_json::json!({
        "project": app_state.project_info
    }))
}

async fn set_project(
    State(state): State<AppState>,
    Json(project): Json<ProjectInfo>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut app_state = state.lock().unwrap();
    app_state.project_info = Some(project.clone());

    info!("Project set: {}", project.name);

    Ok(Json(serde_json::json!({
        "status": "set",
        "project": project
    })))
}

fn create_project_structure(path: &PathBuf) -> anyhow::Result<()> {
    std::fs::create_dir_all(path.join("src"))?;
    std::fs::create_dir_all(path.join("src/Workspace"))?;
    std::fs::create_dir_all(path.join("src/Lighting"))?;
    std::fs::create_dir_all(path.join("src/ReplicatedFirst"))?;
    std::fs::create_dir_all(path.join("src/ReplicatedStorage"))?;
    std::fs::create_dir_all(path.join("src/ServerScriptService"))?;
    std::fs::create_dir_all(path.join("src/ServerStorage"))?;
    std::fs::create_dir_all(path.join("src/StarterPlayer"))?;
    std::fs::create_dir_all(path.join("src/StarterPlayer/StarterCharacterScripts"))?;
    std::fs::create_dir_all(path.join("src/StarterPlayer/StarterPlayerScripts"))?;
    std::fs::create_dir_all(path.join("src/StarterGui"))?;
    std::fs::create_dir_all(path.join("src/Teams"))?;
    std::fs::create_dir_all(path.join("src/SoundService"))?;
    std::fs::create_dir_all(path.join("src/Chat"))?;
    std::fs::create_dir_all(path.join("src/LocalizationService"))?;
    std::fs::create_dir_all(path.join("src/TestService"))?;

    // Create project config
    let project_config = serde_json::json!({
        "name": "MyGame",
        "tree": {
            "$className": "DataModel"
        },
        "metadata": {}
    });

    std::fs::write(
        path.join("rbxsync.json"),
        serde_json::to_string_pretty(&project_config)?
    )?;

    Ok(())
}

fn process_file_change(file_path: &str, content: serde_json::Value) -> anyhow::Result<()> {
    let path_buf = PathBuf::from(file_path);
    
    if path_buf.extension().map_or(false, |ext| ext == "luau") {
        // Handle Luau file
        let code = content.get("code")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing code in Luau file"))?;
        
        std::fs::write(file_path, code)?;
    } else if path_buf.extension().map_or(false, |ext| ext == "rbxjson") {
        // Handle RbxJson file
        let json_str = serde_json::to_string_pretty(&content)?;
        std::fs::write(file_path, json_str)?;
    }

    Ok(())
}

fn process_file_delete(path: &str) -> anyhow::Result<()> {
    std::fs::remove_file(path)?;
    Ok(())
}
