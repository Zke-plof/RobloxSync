"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const axios_1 = __importStar(require("axios"));
const SERVER_URL = 'http://localhost:44755';
const CLIENT_ID = 'vscode_extension_' + Date.now();
let serverTerminal;
let statusBarItem;
let isConnected = false;
let consoleOutputChannel;
let reconnectTimer;
let consolePollTimer;
let clientPollTimer;
let lastSyncTime = new Map();
const SYNC_COOLDOWN_MS = 500;
function activate(context) {
    console.log('Roblox Sync extension is now active!');
    // Create status bar item
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.text = '$(plug) Roblox Sync: Disconnected';
    statusBarItem.tooltip = 'Roblox Sync Status';
    statusBarItem.command = 'robloxSync.connect';
    statusBarItem.show();
    // Create output channel for console
    consoleOutputChannel = vscode.window.createOutputChannel('Roblox Sync Console');
    // Register commands
    const initProjectCommand = vscode.commands.registerCommand('robloxSync.initProject', () => {
        initProject();
    });
    const connectCommand = vscode.commands.registerCommand('robloxSync.connect', () => {
        connectToServer();
    });
    const extractCommand = vscode.commands.registerCommand('robloxSync.extract', () => {
        extractGame();
    });
    const syncCommand = vscode.commands.registerCommand('robloxSync.sync', () => {
        syncChanges();
    });
    const consoleCommand = vscode.commands.registerCommand('robloxSync.console', () => {
        openConsole();
    });
    const restartServerCommand = vscode.commands.registerCommand('robloxSync.restartServer', () => {
        restartServer();
    });
    const newScriptCommand = vscode.commands.registerCommand('robloxSync.newScript', () => {
        newScript();
    });
    // Register sidebar provider
    const sidebarProvider = new RobloxSyncProvider();
    vscode.window.registerTreeDataProvider('robloxSyncSidebar', sidebarProvider);
    context.subscriptions.push(initProjectCommand, connectCommand, extractCommand, syncCommand, consoleCommand, restartServerCommand, newScriptCommand, statusBarItem, consoleOutputChannel, sidebarProvider);
    // Auto-start server if configured
    const config = vscode.workspace.getConfiguration('robloxSync');
    if (config.get('autoStart')) {
        startServer();
    }
    // Watch for file changes with cooldown
    const fileWatcher = vscode.workspace.createFileSystemWatcher('**/*.{luau,rbxjson}');
    fileWatcher.onDidChange((uri) => {
        if (!isConnected) {
            return;
        }
        const filePath = uri.fsPath;
        const now = Date.now();
        const last = lastSyncTime.get(filePath) || 0;
        if (now - last < SYNC_COOLDOWN_MS) {
            return;
        }
        lastSyncTime.set(filePath, now);
        syncFile(filePath);
    });
    context.subscriptions.push(fileWatcher);
}
class RobloxSyncProvider {
    constructor() {
        this._onDidChangeTreeData = new vscode.EventEmitter();
        this.onDidChangeTreeData = this._onDidChangeTreeData.event;
    }
    dispose() {
        this._onDidChangeTreeData.dispose();
    }
    getTreeItem(element) {
        return element;
    }
    getChildren(element) {
        if (!element) {
            // Root level items
            return Promise.resolve([
                new RobloxSyncItem('Connect to Studio', vscode.TreeItemCollapsibleState.None, 'connect'),
                new RobloxSyncItem('Extract Game', vscode.TreeItemCollapsibleState.None, 'extract'),
                new RobloxSyncItem('Sync Changes', vscode.TreeItemCollapsibleState.None, 'sync'),
                new RobloxSyncItem('Open Console', vscode.TreeItemCollapsibleState.None, 'console'),
                new RobloxSyncItem('Restart Server', vscode.TreeItemCollapsibleState.None, 'restart'),
                new RobloxSyncItem('New Script', vscode.TreeItemCollapsibleState.None, 'newScript'),
            ]);
        }
        return Promise.resolve([]);
    }
}
class RobloxSyncItem extends vscode.TreeItem {
    constructor(label, collapsibleState, commandType) {
        super(label, collapsibleState);
        this.commandType = commandType;
        this.tooltip = label;
        this.description = label;
        switch (commandType) {
            case 'connect':
                this.command = {
                    command: 'robloxSync.connect',
                    title: 'Connect to Studio'
                };
                this.contextValue = 'connect';
                break;
            case 'extract':
                this.command = {
                    command: 'robloxSync.extract',
                    title: 'Extract Game'
                };
                this.contextValue = 'extract';
                break;
            case 'sync':
                this.command = {
                    command: 'robloxSync.sync',
                    title: 'Sync Changes'
                };
                this.contextValue = 'sync';
                break;
            case 'console':
                this.command = {
                    command: 'robloxSync.console',
                    title: 'Open Console'
                };
                this.contextValue = 'console';
                break;
            case 'restart':
                this.command = {
                    command: 'robloxSync.restartServer',
                    title: 'Restart Server'
                };
                this.contextValue = 'restart';
                break;
            case 'newScript':
                this.command = {
                    command: 'robloxSync.newScript',
                    title: 'New Script'
                };
                this.contextValue = 'newScript';
                break;
        }
    }
}
async function startServer() {
    if (serverTerminal) {
        serverTerminal.dispose();
    }
    serverTerminal = vscode.window.createTerminal({
        name: 'Roblox Sync Server',
        hideFromUser: false
    });
    serverTerminal.sendText('roblox-sync serve');
    serverTerminal.show();
    // Give server time to start
    setTimeout(() => {
        connectToServer();
    }, 2000);
}
async function connectToServer() {
    try {
        const response = await axios_1.default.post(`${SERVER_URL}/api/connect`, {
            id: CLIENT_ID,
            type: 'vscode_extension',
            version: '1.0.0'
        });
        if (response.data.status === 'connected') {
            isConnected = true;
            updateStatusBar();
            vscode.window.showInformationMessage('Connected to Roblox Studio!');
            startClientPolling();
        }
        else {
            throw new Error(response.data.error || 'Unknown error');
        }
    }
    catch (error) {
        const message = error instanceof axios_1.AxiosError ? error.message : String(error);
        vscode.window.showErrorMessage(`Failed to connect: ${message}`);
        statusBarItem.text = '$(plug-disconnect) Roblox Sync: Error';
        isConnected = false;
        // Auto-retry after 5 seconds
        if (reconnectTimer) {
            clearTimeout(reconnectTimer);
        }
        reconnectTimer = setTimeout(() => {
            reconnectTimer = undefined;
            connectToServer();
        }, 5000);
    }
}
async function extractGame() {
    if (!isConnected) {
        vscode.window.showErrorMessage('Not connected to Studio. Please connect first.');
        return;
    }
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
    }
    try {
        const response = await axios_1.default.post(`${SERVER_URL}/api/extract`, {
            project_path: workspaceFolder.uri.fsPath
        });
        if (response.data.status === 'extracted') {
            vscode.window.showInformationMessage('Game extracted successfully!');
            refreshExplorer();
        }
        else {
            throw new Error(response.data.error || 'Extraction failed');
        }
    }
    catch (error) {
        const message = error instanceof axios_1.AxiosError ? error.message : String(error);
        vscode.window.showErrorMessage(`Extract failed: ${message}`);
    }
}
async function syncChanges() {
    if (!isConnected) {
        vscode.window.showErrorMessage('Not connected to Studio. Please connect first.');
        return;
    }
    try {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            vscode.window.showErrorMessage('No workspace folder open.');
            return;
        }
        // Get all .luau and .rbxjson files
        const files = await vscode.workspace.findFiles('**/*.{luau,rbxjson}');
        let syncedCount = 0;
        for (const file of files) {
            const success = await syncFile(file.fsPath);
            if (success)
                syncedCount++;
        }
        vscode.window.showInformationMessage(`Synced ${syncedCount}/${files.length} files to Studio!`);
    }
    catch (error) {
        vscode.window.showErrorMessage(`Sync failed: ${error.message || error}`);
    }
}
async function syncFile(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        let syncData;
        if (filePath.endsWith('.luau')) {
            syncData = {
                id: 'sync_' + Date.now() + '_' + path.basename(filePath),
                type: 'file_change',
                path: filePath,
                content: { code: content }
            };
        }
        else if (filePath.endsWith('.rbxjson')) {
            syncData = {
                id: 'sync_' + Date.now() + '_' + path.basename(filePath),
                type: 'file_change',
                path: filePath,
                content: JSON.parse(content)
            };
        }
        if (syncData) {
            const response = await axios_1.default.post(`${SERVER_URL}/api/sync`, syncData);
            if (response.data.status === 'synced') {
                return true;
            }
        }
        return false;
    }
    catch (error) {
        const message = error instanceof axios_1.AxiosError ? error.message : String(error);
        console.error(`Failed to sync file ${filePath}:`, message);
        return false;
    }
}
function openConsole() {
    consoleOutputChannel.show();
    startConsoleStreaming();
    // Start polling console every 2 seconds
    if (consolePollTimer) {
        clearTimeout(consolePollTimer);
    }
    const poll = () => {
        startConsoleStreaming();
        consolePollTimer = setTimeout(poll, 2000);
    };
    consolePollTimer = setTimeout(poll, 2000);
}
async function startConsoleStreaming() {
    try {
        const response = await axios_1.default.get(`${SERVER_URL}/api/console/stream`);
        const messages = response.data.messages || [];
        consoleOutputChannel.clear();
        messages.forEach((msg) => {
            const timestamp = msg.timestamp ? new Date(msg.timestamp * 1000).toLocaleTimeString() : 'N/A';
            const msgType = msg.type ? msg.type.toUpperCase() : 'INFO';
            consoleOutputChannel.appendLine(`[${timestamp}] [${msgType}] ${msg.message || ''}`);
        });
    }
    catch (error) {
        const message = error instanceof axios_1.AxiosError ? error.message : String(error);
        consoleOutputChannel.appendLine(`Failed to fetch console: ${message}`);
    }
}
async function initProject() {
    const projectName = await vscode.window.showInputBox({
        prompt: 'Enter project name',
        placeHolder: 'MyAwesomeGame'
    });
    if (!projectName) {
        return;
    }
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('Please open a workspace folder first.');
        return;
    }
    try {
        const response = await axios_1.default.post(`${SERVER_URL}/api/extract`, {
            project_path: path.join(workspaceFolder.uri.fsPath, projectName)
        });
        if (response.data.status === 'extracted') {
            vscode.window.showInformationMessage(`Project '${projectName}' initialized successfully!`);
            refreshExplorer();
        }
    }
    catch (error) {
        const message = error instanceof axios_1.AxiosError ? error.message : String(error);
        vscode.window.showErrorMessage(`Failed to initialize project: ${message}`);
    }
}
function restartServer() {
    if (serverTerminal) {
        serverTerminal.dispose();
        serverTerminal = undefined;
    }
    startServer();
    vscode.window.showInformationMessage('Sync server restarting...');
}
async function newScript() {
    const scriptType = await vscode.window.showQuickPick([
        { label: 'Server Script', description: 'Runs on server (.server.luau)', value: 'server' },
        { label: 'Client Script', description: 'Runs on client (.client.luau)', value: 'client' },
        { label: 'Module Script', description: 'Shared module (.luau)', value: 'module' }
    ], { placeHolder: 'Select script type' });
    if (!scriptType) {
        return;
    }
    const scriptName = await vscode.window.showInputBox({
        prompt: 'Enter script name (without extension)',
        placeHolder: 'MyScript'
    });
    if (!scriptName) {
        return;
    }
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return;
    }
    let folderPath;
    let ext;
    let boilerplate;
    switch (scriptType.value) {
        case 'server':
            folderPath = path.join(workspaceFolder.uri.fsPath, 'src', 'ServerScriptService');
            ext = '.server.luau';
            boilerplate = `--!strict
-- Server script: ${scriptName}

local Players = game:GetService("Players")

print("[Server] ${scriptName} loaded")
`;
            break;
        case 'client':
            folderPath = path.join(workspaceFolder.uri.fsPath, 'src', 'StarterPlayer', 'StarterPlayerScripts');
            ext = '.client.luau';
            boilerplate = `--!strict
-- Client script: ${scriptName}

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

print("[Client] ${scriptName} loaded")
`;
            break;
        default:
            folderPath = path.join(workspaceFolder.uri.fsPath, 'src', 'ReplicatedStorage');
            ext = '.luau';
            boilerplate = `--!strict
-- Module: ${scriptName}

local ${scriptName} = {}

function ${scriptName}.Init()
    print("[Module] ${scriptName} initialized")
end

return ${scriptName}
`;
    }
    if (!fs.existsSync(folderPath)) {
        fs.mkdirSync(folderPath, { recursive: true });
    }
    const filePath = path.join(folderPath, scriptName + ext);
    if (fs.existsSync(filePath)) {
        vscode.window.showWarningMessage(`File already exists: ${scriptName}${ext}`);
        return;
    }
    fs.writeFileSync(filePath, boilerplate);
    vscode.window.showInformationMessage(`Created ${scriptName}${ext}`);
    refreshExplorer();
}
function updateStatusBar(clientCount = 0) {
    if (!isConnected) {
        statusBarItem.text = '$(plug) Roblox Sync: Disconnected';
        statusBarItem.tooltip = 'Click to connect';
        return;
    }
    const clientLabel = clientCount > 0 ? `(${clientCount} clients)` : '(waiting...)';
    statusBarItem.text = `$(plug) Roblox Sync: Connected ${clientLabel}`;
    statusBarItem.tooltip = `Connected - ${clientCount} client(s) active`;
}
function startClientPolling() {
    if (clientPollTimer) {
        clearTimeout(clientPollTimer);
    }
    const poll = async () => {
        if (!isConnected) {
            return;
        }
        try {
            const response = await axios_1.default.get(`${SERVER_URL}/api/clients`);
            updateStatusBar(response.data.count || 0);
        }
        catch {
            // Silently fail, connection might be temporarily down
        }
        clientPollTimer = setTimeout(poll, 5000);
    };
    clientPollTimer = setTimeout(poll, 1000);
}
function refreshExplorer() {
    vscode.commands.executeCommand('workbench.files.action.refreshFilesExplorer');
}
function deactivate() {
    if (reconnectTimer) {
        clearTimeout(reconnectTimer);
    }
    if (consolePollTimer) {
        clearTimeout(consolePollTimer);
    }
    if (clientPollTimer) {
        clearTimeout(clientPollTimer);
    }
    if (serverTerminal) {
        serverTerminal.dispose();
    }
    if (statusBarItem) {
        statusBarItem.dispose();
    }
    if (consoleOutputChannel) {
        consoleOutputChannel.dispose();
    }
}
//# sourceMappingURL=extension.js.map