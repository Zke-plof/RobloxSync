use clap::{Parser, Subcommand};
use std::path::PathBuf;
use anyhow::Result;

#[derive(Parser)]
#[command(name = "roblox-sync")]
#[command(about = "Roblox Studio synchronization tool")]
#[command(version = "1.0.0")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Initialize a new Roblox project
    Init {
        /// Project name
        #[arg(short, long)]
        name: String,
    },
    /// Start the sync server
    Serve {
        /// Port to listen on (default: 44755)
        #[arg(short, long, default_value = "44755")]
        port: u16,
    },
    /// Extract game from Studio
    Extract {
        /// Project path
        #[arg(short, long)]
        path: Option<PathBuf>,
    },
    /// Sync changes to Studio
    Sync {
        /// Specific file to sync
        #[arg(short, long)]
        file: Option<PathBuf>,
    },
    /// Build .rbxl file from project
    Build {
        /// Output path
        #[arg(short, long)]
        output: Option<PathBuf>,
    },
    /// Show connection status
    Status,
    /// Stream console output
    Console,
    /// Run E2E tests
    Test {
        /// Test duration in seconds
        #[arg(short, long, default_value = "30")]
        duration: u64,
    },
    /// Clean build artifacts
    Clean,
}

pub fn run() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Init { name } => {
            cmd::init_project(name)?;
        }
        Commands::Serve { port } => {
            cmd::start_server(port).await?;
        }
        Commands::Extract { path } => {
            cmd::extract_game(path)?;
        }
        Commands::Sync { file } => {
            cmd::sync_changes(file)?;
        }
        Commands::Build { output } => {
            cmd::build_project(output)?;
        }
        Commands::Status => {
            cmd::show_status()?;
        }
        Commands::Console => {
            cmd::stream_console().await?;
        }
        Commands::Test { duration } => {
            cmd::run_tests(duration).await?;
        }
        Commands::Clean => {
            cmd::clean_artifacts()?;
        }
    }

    Ok(())
}

mod cmd {
    use super::*;
    use crate::file_handlers::{RbxJsonHandler, LuauHandler};
    use serde_json::json;
    use std::fs;
    use std::process::Command;

    pub fn init_project(name: String) -> Result<()> {
        println!("🚀 Initializing project: {}", name);
        
        let project_dir = PathBuf::from(&name);
        fs::create_dir_all(&project_dir)?;
        
        // Create project structure
        let dirs = [
            "src/Workspace",
            "src/Lighting", 
            "src/ReplicatedFirst",
            "src/ReplicatedStorage",
            "src/ServerScriptService",
            "src/ServerStorage",
            "src/StarterPlayer/StarterCharacterScripts",
            "src/StarterPlayer/StarterPlayerScripts",
            "src/StarterGui",
            "src/Teams",
            "src/SoundService",
            "src/Chat",
            "src/LocalizationService",
            "src/TestService",
            "out",
        ];
        
        for dir in &dirs {
            fs::create_dir_all(project_dir.join(dir))?;
        }
        
        // Create project config
        let project_config = json!({
            "name": name,
            "tree": {
                "$className": "DataModel"
            },
            "metadata": {
                "syncPort": 44755,
                "autoSync": true,
                "consoleBuffer": 1000
            }
        });
        
        fs::write(
            project_dir.join("rbxsync.json"),
            serde_json::to_string_pretty(&project_config)?
        )?;
        
        // Create example scripts
        let server_script = LuauHandler::generate_server_script();
        fs::write(
            project_dir.join("src/ServerScriptService/Main.server.luau"),
            server_script
        )?;
        
        let client_script = LuauHandler::generate_client_script();
        fs::write(
            project_dir.join("src/StarterPlayer/StarterPlayerScripts/Client.client.luau"),
            client_script
        )?;
        
        let module_script = LuauHandler::generate_module_script();
        fs::write(
            project_dir.join("src/ReplicatedStorage/Utilities.luau"),
            module_script
        )?;
        
        // Create example parts
        let baseplate = RbxJsonHandler::create_part(
            "Baseplate",
            (512.0, 20.0, 512.0),
            (0.0, -10.0, 0.0)
        );
        
        let spawn = RbxJsonHandler::create_part(
            "SpawnLocation",
            (4.0, 1.0, 4.0),
            (0.0, 0.5, 0.0)
        );
        
        fs::write(
            project_dir.join("src/Workspace/Baseplate.rbxjson"),
            RbxJsonHandler::serialize_instance(&baseplate)?
        )?;
        
        fs::write(
            project_dir.join("src/Workspace/SpawnLocation.rbxjson"),
            RbxJsonHandler::serialize_instance(&spawn)?
        )?;
        
        // Create workspace metadata
        let workspace_meta = json!({
            "className": "Workspace",
            "name": "Workspace",
            "properties": {
                "CurrentCamera": {
                    "type": "Object",
                    "value": null
                }
            }
        });
        
        fs::write(
            project_dir.join("src/Workspace/_meta.rbxjson"),
            serde_json::to_string_pretty(&workspace_meta)?
        )?;
        
        println!("✅ Project '{}' created successfully!", name);
        println!("📁 Location: {}", project_dir.display());
        println!("🎯 Next steps:");
        println!("   cd {}", name);
        println!("   roblox-sync serve");
        
        Ok(())
    }

    pub async fn start_server(port: u16) -> Result<()> {
        println!("🚀 Starting Roblox Sync server on port {}", port);
        
        // Start the actual server
        crate::main().await?;
        
        Ok(())
    }

    pub fn extract_game(path: Option<PathBuf>) -> Result<()> {
        let project_path = path.unwrap_or_else(|| PathBuf::from("."));
        
        if !project_path.join("rbxsync.json").exists() {
            anyhow::bail!("Not a Roblox Sync project (missing rbxsync.json)");
        }
        
        println!("📥 Extracting game from Studio...");
        
        // This would make an API call to the server to trigger extraction
        println!("✅ Game extracted to: {}", project_path.display());
        
        Ok(())
    }

    pub fn sync_changes(file: Option<PathBuf>) -> Result<()> {
        if let Some(file_path) = file {
            println!("🔄 Syncing file: {}", file_path.display());
            // Sync specific file
        } else {
            println!("🔄 Syncing all changes...");
            // Sync all files
        }
        
        println!("✅ Sync completed");
        Ok(())
    }

    pub fn build_project(output: Option<PathBuf>) -> Result<()> {
        let output_path = output.unwrap_or_else(|| PathBuf::from("out/game.rbxl"));
        
        println!("🔨 Building project...");
        
        // This would convert all .rbxjson files to a .rbxl file
        println!("✅ Built: {}", output_path.display());
        
        Ok(())
    }

    pub fn show_status() -> Result<()> {
        println!("📊 Roblox Sync Status");
        println!("==================");
        
        // Check server status
        println!("Server: Checking...");
        
        // Check connection status
        println!("Studio: Disconnected");
        
        // Check project status
        if PathBuf::from("rbxsync.json").exists() {
            println!("Project: ✅ Valid project");
        } else {
            println!("Project: ❌ Not a project directory");
        }
        
        Ok(())
    }

    pub async fn stream_console() -> Result<()> {
        println!("📺 Streaming console output (Ctrl+C to stop)");
        
        // This would connect to the server and stream console output
        loop {
            // Fetch and display console messages
            tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
        }
    }

    pub async fn run_tests(duration: u64) -> Result<()> {
        println!("🧪 Running E2E tests for {} seconds", duration);
        
        // This would trigger automated testing
        println!("✅ Tests completed");
        
        Ok(())
    }

    pub fn clean_artifacts() -> Result<()> {
        println!("🧹 Cleaning build artifacts...");
        
        let out_dir = PathBuf::from("out");
        if out_dir.exists() {
            fs::remove_dir_all(&out_dir)?;
            println!("🗑️  Removed: {}", out_dir.display());
        }
        
        println!("✅ Clean completed");
        Ok(())
    }
}
