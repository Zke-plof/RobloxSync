// Simple test server to demonstrate Roblox Sync functionality
const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = 44755;
let connectedClients = [];
let consoleBuffer = [];

// Simple HTTP server
const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    console.log(`${req.method} ${pathname}`);
    
    // Handle API routes
    if (pathname === '/') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            version: '0.1.0-test',
            timestamp: Date.now() / 1000
        }));
        return;
    }
    
    if (pathname === '/api/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            version: '0.1.0-test',
            timestamp: Date.now() / 1000
        }));
        return;
    }
    
    if (pathname === '/api/connect' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const client = JSON.parse(body);
                connectedClients.push(client);
                console.log(`Client connected: ${client.id}`);
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    status: 'connected',
                    client_id: client.id
                }));
            } catch (error) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: error.message }));
            }
        });
        return;
    }
    
    if (pathname.match(/^\/api\/disconnect\//) && req.method === 'POST') {
        const clientId = pathname.split('/').pop();
        connectedClients = connectedClients.filter(c => c.id !== clientId);
        console.log(`Client disconnected: ${clientId}`);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'disconnected' }));
        return;
    }
    
    if (pathname === '/api/extract' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const request = JSON.parse(body);
                const projectPath = request.project_path;
                
                console.log(`Extracting game to: ${projectPath}`);
                
                // Create basic project structure
                if (!fs.existsSync(projectPath)) {
                    fs.mkdirSync(projectPath, { recursive: true });
                }
                
                const dirs = [
                    'src/Workspace',
                    'src/ServerScriptService', 
                    'src/StarterPlayer/StarterPlayerScripts',
                    'src/ReplicatedStorage'
                ];
                
                dirs.forEach(dir => {
                    const fullPath = path.join(projectPath, dir);
                    if (!fs.existsSync(fullPath)) {
                        fs.mkdirSync(fullPath, { recursive: true });
                    }
                });
                
                // Create example scripts
                const serverScript = `-- Server Script
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    print("Player joined:", player.Name)
end)

print("Server script loaded")`;
                
                fs.writeFileSync(path.join(projectPath, 'src/ServerScriptService/Main.server.luau'), serverScript);
                
                const clientScript = `-- Client Script
local player = game.Players.LocalPlayer

print("Client script loaded for", player.Name)`;
                
                fs.writeFileSync(path.join(projectPath, 'src/StarterPlayer/StarterPlayerScripts/Client.client.luau'), clientScript);
                
                // Create project config
                const projectConfig = {
                    name: "TestGame",
                    tree: { "$className": "DataModel" },
                    metadata: {}
                };
                
                fs.writeFileSync(path.join(projectPath, 'rbxsync.json'), JSON.stringify(projectConfig, null, 2));
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    status: 'extracted',
                    files_created: true
                }));
            } catch (error) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: error.message }));
            }
        });
        return;
    }
    
    if (pathname === '/api/sync' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const syncMsg = JSON.parse(body);
                console.log(`Sync received: ${syncMsg.type} -> ${syncMsg.path}`);
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    status: 'synced',
                    id: syncMsg.id
                }));
            } catch (error) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: error.message }));
            }
        });
        return;
    }
    
    if (pathname === '/api/console' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const msg = JSON.parse(body);
                console.log(`Console [${msg.type}]: ${msg.message}`);
                consoleBuffer.push(msg);
                
                // Keep buffer size manageable
                if (consoleBuffer.length > 1000) {
                    consoleBuffer = consoleBuffer.slice(-500);
                }
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ status: 'received' }));
            } catch (error) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: error.message }));
            }
        });
        return;
    }
    
    if (pathname === '/api/console/stream') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            messages: consoleBuffer
        }));
        return;
    }
    
    // 404 for unknown routes
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
    console.log(`🚀 Roblox Sync Test Server running on http://localhost:${PORT}`);
    console.log('');
    console.log('Available endpoints:');
    console.log('  GET  /                    - Health check');
    console.log('  POST /api/connect         - Connect client');
    console.log('  POST /api/extract         - Extract game');
    console.log('  POST /api/sync           - Sync changes');
    console.log('  POST /api/console         - Console message');
    console.log('  GET  /api/console/stream   - Console stream');
    console.log('');
    console.log('Test with:');
    console.log('  curl http://localhost:44755');
    console.log('  curl -X POST http://localhost:44755/api/extract -H "Content-Type: application/json" -d "{\"project_path\":\"./test-game\"}"');
});

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n👋 Shutting down server...');
    server.close(() => {
        console.log('✅ Server stopped');
        process.exit(0);
    });
});
