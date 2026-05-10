#!/usr/bin/env python3
"""
Simple Python test server for Roblox Sync
No installation required - uses built-in Python 3
"""

import http.server
import socketserver
import json
import os
import threading
import time
from urllib.parse import urlparse, parse_qs

PORT = 44755
connected_clients = []
console_buffer = []

class RobloxSyncHandler(http.server.SimpleHTTPRequestHandler):
    
    def do_OPTIONS(self):
        # Handle CORS preflight
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()
    
    def do_GET(self):
        self.send_cors_headers()
        
        if self.path == '/' or self.path == '/api/health':
            self.send_json_response({
                'status': 'ok',
                'version': '0.1.0-test',
                'timestamp': int(time.time())
            })
        elif self.path == '/api/console/stream':
            self.send_json_response({
                'messages': console_buffer
            })
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        self.send_cors_headers()
        
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
        except:
            self.send_response(400)
            self.end_headers()
            return
        
        if self.path == '/api/connect':
            client_id = data.get('id', 'unknown')
            connected_clients.append(data)
            print(f"✅ Client connected: {client_id}")
            self.send_json_response({
                'status': 'connected',
                'client_id': client_id
            })
            
        elif self.path.startswith('/api/disconnect/'):
            client_id = self.path.split('/')[-1]
            connected_clients[:] = [c for c in connected_clients if c.get('id') != client_id]
            print(f"❌ Client disconnected: {client_id}")
            self.send_json_response({'status': 'disconnected'})
            
        elif self.path == '/api/extract':
            project_path = data.get('project_path', './test-game')
            print(f"📥 Extracting game to: {project_path}")
            
            # Create project structure
            os.makedirs(project_path, exist_ok=True)
            
            dirs = [
                'src/Workspace',
                'src/ServerScriptService', 
                'src/StarterPlayer/StarterPlayerScripts',
                'src/ReplicatedStorage'
            ]
            
            for dir_path in dirs:
                full_path = os.path.join(project_path, dir_path)
                os.makedirs(full_path, exist_ok=True)
            
            # Create example server script
            server_script = '''-- Server Script
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    print("Player joined:", player.Name)
end)

print("Server script loaded")'''
            
            with open(os.path.join(project_path, 'src/ServerScriptService/Main.server.luau'), 'w') as f:
                f.write(server_script)
            
            # Create example client script
            client_script = '''-- Client Script
local player = game.Players.LocalPlayer

print("Client script loaded for", player.Name)'''
            
            with open(os.path.join(project_path, 'src/StarterPlayer/StarterPlayerScripts/Client.client.luau'), 'w') as f:
                f.write(client_script)
            
            # Create project config
            project_config = {
                "name": "TestGame",
                "tree": {"$className": "DataModel"},
                "metadata": {}
            }
            
            with open(os.path.join(project_path, 'rbxsync.json'), 'w') as f:
                json.dump(project_config, f, indent=2)
            
            print(f"✅ Project created at: {project_path}")
            self.send_json_response({
                'status': 'extracted',
                'files_created': True
            })
            
        elif self.path == '/api/sync':
            sync_type = data.get('type', 'unknown')
            sync_path = data.get('path', 'unknown')
            print(f"🔄 Sync received: {sync_type} -> {sync_path}")
            self.send_json_response({
                'status': 'synced',
                'id': data.get('id', 'unknown')
            })
            
        elif self.path == '/api/console':
            msg_type = data.get('type', 'print')
            message = data.get('message', '')
            print(f"📺 Console [{msg_type}]: {message}")
            
            console_buffer.append({
                'type': msg_type,
                'message': message,
                'timestamp': int(time.time()),
                'source': 'Studio'
            })
            
            # Keep buffer size manageable
            if len(console_buffer) > 1000:
                console_buffer[:] = console_buffer[-500:]
            
            self.send_json_response({'status': 'received'})
            
        else:
            self.send_response(404)
            self.end_headers()
    
    def send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
    
    def send_json_response(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

def start_server():
    with socketserver.TCPServer(("", PORT), RobloxSyncHandler) as httpd:
        print(f"🚀 Roblox Sync Test Server running on http://localhost:{PORT}")
        print("")
        print("Available endpoints:")
        print("  GET  /                    - Health check")
        print("  POST /api/connect         - Connect client")
        print("  POST /api/extract         - Extract game")
        print("  POST /api/sync           - Sync changes")
        print("  POST /api/console         - Console message")
        print("  GET  /api/console/stream   - Console stream")
        print("")
        print("Test with:")
        print(f"  curl http://localhost:{PORT}")
        print(f'  curl -X POST http://localhost:{PORT}/api/extract -H "Content-Type: application/json" -d \'{{"project_path":"./test-game"}}\'')
        print("")
        print("Press Ctrl+C to stop the server")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Shutting down server...")
            httpd.shutdown()
            print("✅ Server stopped")

if __name__ == "__main__":
    start_server()
