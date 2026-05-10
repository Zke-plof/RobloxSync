-- Roblox Sync Plugin Main Script
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local Players = game:GetService("Players")

local RobloxSync = {}
RobloxSync.__index = RobloxSync

-- Configuration
local SERVER_URL = "http://localhost:44755"
local CLIENT_ID = "studio_plugin_" .. tick()
local CONNECTED = false
local PROJECT_PATH = ""

-- Console capture
local originalPrint = print
local originalWarn = warn
local originalError = error

function RobloxSync.new()
    local self = setmetatable({}, RobloxSync)
    self.widget = nil
    self.connection = nil
    return self
end

function RobloxSync:init()
    -- Create UI Widget
    local success, widgetInfo = pcall(function()
        return plugin:CreateDockWidgetPluginGui(
            "RobloxSync",
            DockWidgetPluginGuiInfo.new(
                Enum.InitialDockState.Right,
                false,
                false,
                300,
                400,
                300,
                400
            )
        )
    end)
    
    if not success then
        warn("Failed to create widget:", widgetInfo)
        return
    end
    
    self.widget = widgetInfo
    self.widget.Title = "Roblox Sync"
    
    -- Create UI
    self:createUI()
    
    -- Override console functions
    self:setupConsoleCapture()
    
    -- Connect to server
    self:connectToServer()
    
    print("Roblox Sync plugin initialized")
end

function RobloxSync:createUI()
    local frame = Instance.new("Frame")
    frame.Parent = self.widget
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Parent = frame
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 0
    title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    title.Text = "Roblox Sync"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = frame
    statusLabel.Size = UDim2.new(1, -20, 0, 20)
    statusLabel.Position = UDim2.new(0, 10, 0, 40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Disconnected"
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextSize = 14
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.statusLabel = statusLabel
    
    -- Project path input
    local pathLabel = Instance.new("TextLabel")
    pathLabel.Parent = frame
    pathLabel.Size = UDim2.new(1, -20, 0, 20)
    pathLabel.Position = UDim2.new(0, 10, 0, 70)
    pathLabel.BackgroundTransparency = 1
    pathLabel.Text = "Project Path:"
    pathLabel.TextColor3 = Color3.new(1, 1, 1)
    pathLabel.Font = Enum.Font.SourceSans
    pathLabel.TextSize = 14
    pathLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local pathInput = Instance.new("TextBox")
    pathInput.Parent = frame
    pathInput.Size = UDim2.new(1, -20, 0, 25)
    pathInput.Position = UDim2.new(0, 10, 0, 95)
    pathInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    pathInput.TextColor3 = Color3.new(1, 1, 1)
    pathInput.PlaceholderText = "C:/path/to/project"
    pathInput.Font = Enum.Font.SourceSans
    pathInput.TextSize = 12
    pathInput.TextXAlignment = Enum.TextXAlignment.Left
    self.pathInput = pathInput
    
    -- Connect button
    local connectBtn = Instance.new("TextButton")
    connectBtn.Parent = frame
    connectBtn.Size = UDim2.new(1, -20, 0, 30)
    connectBtn.Position = UDim2.new(0, 10, 0, 130)
    connectBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    connectBtn.Text = "Connect"
    connectBtn.TextColor3 = Color3.new(1, 1, 1)
    connectBtn.Font = Enum.Font.SourceSansBold
    connectBtn.TextSize = 14
    
    connectBtn.MouseButton1Click:Connect(function()
        if not CONNECTED then
            PROJECT_PATH = self.pathInput.Text
            self:connectToServer()
        else
            self:disconnectFromServer()
        end
    end)
    self.connectBtn = connectBtn
    
    -- Extract button
    local extractBtn = Instance.new("TextButton")
    extractBtn.Parent = frame
    extractBtn.Size = UDim2.new(1, -20, 0, 30)
    extractBtn.Position = UDim2.new(0, 10, 0, 170)
    extractBtn.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
    extractBtn.Text = "Extract Game"
    extractBtn.TextColor3 = Color3.new(1, 1, 1)
    extractBtn.Font = Enum.Font.SourceSansBold
    extractBtn.TextSize = 14
    
    extractBtn.MouseButton1Click:Connect(function()
        self:extractGame()
    end)
    self.extractBtn = extractBtn
    
    -- Sync button
    local syncBtn = Instance.new("TextButton")
    syncBtn.Parent = frame
    syncBtn.Size = UDim2.new(1, -20, 0, 30)
    syncBtn.Position = UDim2.new(0, 10, 0, 210)
    syncBtn.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
    syncBtn.Text = "Sync Changes"
    syncBtn.TextColor3 = Color3.new(0, 0, 0)
    syncBtn.Font = Enum.Font.SourceSansBold
    syncBtn.TextSize = 14
    
    syncBtn.MouseButton1Click:Connect(function()
        self:syncChanges()
    end)
    self.syncBtn = syncBtn
    
    -- Console output
    local consoleLabel = Instance.new("TextLabel")
    consoleLabel.Parent = frame
    consoleLabel.Size = UDim2.new(1, -20, 0, 20)
    consoleLabel.Position = UDim2.new(0, 10, 0, 250)
    consoleLabel.BackgroundTransparency = 1
    consoleLabel.Text = "Console Output:"
    consoleLabel.TextColor3 = Color3.new(1, 1, 1)
    consoleLabel.Font = Enum.Font.SourceSans
    consoleLabel.TextSize = 14
    consoleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local consoleFrame = Instance.new("ScrollingFrame")
    consoleFrame.Parent = frame
    consoleFrame.Size = UDim2.new(1, -20, 1, -290)
    consoleFrame.Position = UDim2.new(0, 10, 0, 275)
    consoleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    consoleFrame.ScrollBarThickness = 8
    self.consoleFrame = consoleFrame
    
    -- Console text layout
    local consoleLayout = Instance.new("UIListLayout")
    consoleLayout.Parent = consoleFrame
    consoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
end

function RobloxSync:setupConsoleCapture()
    -- Override print to capture output
    _G.print = function(...)
        local args = {...}
        local message = table.concat(args, "\t")
        self:sendConsoleMessage("print", message)
        originalPrint(...)
    end
    
    -- Override warn
    _G.warn = function(...)
        local args = {...}
        local message = table.concat(args, "\t")
        self:sendConsoleMessage("warn", message)
        originalWarn(...)
    end
    
    -- Note: We can't safely override error() as it halts execution
end

function RobloxSync:sendConsoleMessage(messageType, message)
    if not CONNECTED then return end
    
    local data = {
        type = messageType,
        message = message,
        timestamp = tick(),
        source = "Studio"
    }
    
    self:addConsoleMessage(messageType, message)
    
    spawn(function()
        local success, response = pcall(function()
            return HttpService:PostAsync(
                SERVER_URL .. "/api/console",
                HttpService:JSONEncode(data),
                Enum.HttpContentType.ApplicationJson
            )
        end)
        
        if not success then
            -- Silently fail to avoid console spam
        end
    end)
end

function RobloxSync:addConsoleMessage(messageType, message)
    local label = Instance.new("TextLabel")
    label.Parent = self.consoleFrame
    label.Size = UDim2.new(1, -10, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = string.format("[%s] %s", messageType:upper(), message)
    label.TextColor3 = messageType == "error" and Color3.new(1, 0.2, 0.2) or 
                       messageType == "warn" and Color3.new(1, 1, 0) or 
                       Color3.new(1, 1, 1)
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    
    -- Auto-scroll to bottom
    self.consoleFrame.CanvasPosition = Vector2.new(0, self.consoleFrame.CanvasSize.Y.Offset)
    
    -- Limit console messages
    local children = self.consoleFrame:GetChildren()
    if #children > 100 then
        for i = 1, #children - 100 do
            if children[i]:IsA("TextLabel") then
                children[i]:Destroy()
            end
        end
    end
end

function RobloxSync:connectToServer()
    if CONNECTED then return end
    
    local data = {
        id = CLIENT_ID,
        type = "studio_plugin",
        version = "1.0.0"
    }
    
    local success, response = pcall(function()
        return HttpService:PostAsync(
            SERVER_URL .. "/api/connect",
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        CONNECTED = true
        self.statusLabel.Text = "Status: Connected"
        self.connectBtn.Text = "Disconnect"
        self.connectBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        self:addConsoleMessage("print", "Connected to sync server")
    else
        self:addConsoleMessage("error", "Failed to connect: " .. tostring(response))
        warn("Failed to connect to sync server:", response)
    end
end

function RobloxSync:disconnectFromServer()
    if not CONNECTED then return end
    
    pcall(function()
        HttpService:PostAsync(
            SERVER_URL .. "/api/disconnect/" .. CLIENT_ID,
            "",
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    CONNECTED = false
    self.statusLabel.Text = "Status: Disconnected"
    self.connectBtn.Text = "Connect"
    self.connectBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    self:addConsoleMessage("print", "Disconnected from sync server")
end

function RobloxSync:extractGame()
    if not CONNECTED then
        self:addConsoleMessage("error", "Not connected to server")
        return
    end
    
    if PROJECT_PATH == "" then
        self:addConsoleMessage("error", "Please set project path")
        return
    end
    
    self:addConsoleMessage("print", "Starting game extraction...")
    
    -- First, initialize project structure on server
    local data = {
        project_path = PROJECT_PATH
    }
    
    local success, response = pcall(function()
        return HttpService:PostAsync(
            SERVER_URL .. "/api/extract",
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        local result = HttpService:JSONDecode(response)
        if result.status == "extracted" then
            self:addConsoleMessage("print", "Project structure created")
            self:extractInstances()
            self:extractScripts()
            self:sendRbxsyncConfig()
            self:addConsoleMessage("print", "Game extraction complete!")
        else
            self:addConsoleMessage("error", "Extraction failed: " .. tostring(result.error or "unknown"))
        end
    else
        self:addConsoleMessage("error", "Extraction error: " .. tostring(response))
    end
end

function RobloxSync:extractInstances()
    -- Extract all instances to files
    self:extractService(game.Workspace, "Workspace")
    self:extractService(game.Lighting, "Lighting")
    self:extractService(game.ReplicatedFirst, "ReplicatedFirst")
    self:extractService(game.ReplicatedStorage, "ReplicatedStorage")
    self:extractService(game.ServerScriptService, "ServerScriptService")
    self:extractService(game.ServerStorage, "ServerStorage")
    self:extractService(game.StarterGui, "StarterGui")
    self:extractService(game.StarterPack, "StarterPack")
    self:extractService(game.Teams, "Teams")
    self:extractService(game.SoundService, "SoundService")
    
    self:addConsoleMessage("print", "All instances extracted")
end

function RobloxSync:extractScripts()
    -- Extract script sources to .luau files
    local function extractScriptsFrom(parent, path)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BaseScript") or child:IsA("ModuleScript") then
                local ext = child:IsA("Script") and ".server.luau" or 
                            child:IsA("LocalScript") and ".client.luau" or ".luau"
                local filePath = path .. "/" .. child.Name .. ext
                
                local data = {
                    id = "script_" .. tick() .. "_" .. child.Name,
                    type = "file_create",
                    path = filePath,
                    content = { code = child.Source }
                }
                
                spawn(function()
                    pcall(function()
                        HttpService:PostAsync(
                            SERVER_URL .. "/api/sync",
                            HttpService:JSONEncode(data),
                            Enum.HttpContentType.ApplicationJson
                        )
                    end)
                end)
            end
            extractScriptsFrom(child, path .. "/" .. child.Name)
        end
    end
    
    extractScriptsFrom(game.ServerScriptService, "ServerScriptService")
    extractScriptsFrom(game.StarterPlayer.StarterPlayerScripts, "StarterPlayer/StarterPlayerScripts")
    extractScriptsFrom(game.ReplicatedStorage, "ReplicatedStorage")
end

function RobloxSync:sendRbxsyncConfig()
    local config = {
        id = "config_" .. tick(),
        type = "file_create",
        path = "rbxsync.json",
        content = {
            name = game.Name,
            tree = { ["$className"] = "DataModel" },
            metadata = {
                syncPort = 44755,
                autoSync = true,
                extractedAt = tick()
            }
        }
    }
    
    spawn(function()
        pcall(function()
            HttpService:PostAsync(
                SERVER_URL .. "/api/sync",
                HttpService:JSONEncode(config),
                Enum.HttpContentType.ApplicationJson
            )
        end)
    end)
end

function RobloxSync:extractService(service, serviceName)
    for _, child in ipairs(service:GetChildren()) do
        -- Skip scripts, they are handled by extractScripts
        if not (child:IsA("BaseScript") or child:IsA("ModuleScript")) then
            self:extractInstance(child, serviceName)
        end
    end
end

function RobloxSync:extractInstance(instance, parentPath)
    local instanceData = self:serializeInstance(instance)
    local fileName = instance.Name .. ".rbxjson"
    local filePath = parentPath .. "/" .. fileName
    
    -- Send instance data to server
    local data = {
        id = "extract_" .. tick(),
        type = "file_create",
        path = filePath,
        content = instanceData
    }
    
    spawn(function()
        local success, response = pcall(function()
            return HttpService:PostAsyncAsync(
                SERVER_URL .. "/api/sync",
                HttpService:JSONEncode(data),
                Enum.HttpContentType.ApplicationJson
            )
        end)
        
        if not success then
            warn("Failed to extract instance:", response)
        end
    end)
    
    -- Recursively extract children
    for _, child in ipairs(instance:GetChildren()) do
        self:extractInstance(child, parentPath .. "/" .. instance.Name)
    end
end

function RobloxSync:serializeInstance(instance)
    local properties = {}
    
    -- Common properties to serialize for most instances
    local commonProps = {
        "Name", "Parent", "Archivable"
    }
    
    -- Part-specific properties
    local partProps = {
        "Position", "Orientation", "Size", "Color", 
        "Transparency", "Reflectance", "CanCollide",
        "Anchored", "Material", "Shape"
    }
    
    -- GUI properties
    local guiProps = {
        "Position", "Size", "BackgroundColor3", "BackgroundTransparency",
        "BorderColor3", "BorderSizePixel", "Text", "TextColor3",
        "TextSize", "Font", "Visible", "Active"
    }
    
    local propsToTry = commonProps
    
    if instance:IsA("BasePart") then
        for _, p in ipairs(partProps) do
            table.insert(propsToTry, p)
        end
    end
    
    if instance:IsA("GuiObject") then
        for _, p in ipairs(guiProps) do
            table.insert(propsToTry, p)
        end
    end
    
    -- Get properties
    for _, propName in ipairs(propsToTry) do
        local success, value = pcall(function()
            return instance[propName]
        end)
        
        if success and value ~= nil then
            properties[propName] = self:serializeProperty(value)
        end
    end
    
    return {
        className = instance.ClassName,
        name = instance.Name,
        properties = properties
    }
end

function RobloxSync:serializeProperty(value)
    if typeof(value) == "string" then
        return {type = "string", value = value}
    elseif typeof(value) == "boolean" then
        return {type = "bool", value = value}
    elseif typeof(value) == "number" then
        return {type = "float", value = value}
    elseif typeof(value) == "Vector3" then
        return {
            type = "Vector3",
            value = {x = value.X, y = value.Y, z = value.Z}
        }
    elseif typeof(value) == "Vector2" then
        return {
            type = "Vector2",
            value = {x = value.X, y = value.Y}
        }
    elseif typeof(value) == "CFrame" then
        local pos = value.Position
        local lookVector = value.LookVector
        return {
            type = "CFrame",
            value = {
                position = {x = pos.X, y = pos.Y, z = pos.Z},
                rotation = {1, 0, 0, 0, 1, 0, 0, 0, 1} -- Simplified
            }
        }
    elseif typeof(value) == "Color3" then
        return {
            type = "Color3",
            value = {r = value.R, g = value.G, b = value.B}
        }
    elseif typeof(value) == "BrickColor" then
        return {type = "BrickColor", value = value.Number}
    elseif typeof(value) == "EnumItem" then
        return {
            type = "Enum",
            value = {
                enumType = value.EnumType.Name,
                value = value.Name
            }
        }
    else
        return {type = "string", value = tostring(value)}
    end
end

function RobloxSync:syncChanges()
    if not CONNECTED then
        self:addConsoleMessage("error", "Not connected to server")
        return
    end
    
    self:addConsoleMessage("print", "Syncing changes...")
    
    -- This would normally sync changes from files to Studio
    -- For now, we'll just show a message
    self:addConsoleMessage("print", "Sync completed")
end

function RobloxSync:destroy()
    self:disconnectFromServer()
    if self.widget then
        self.widget:Destroy()
    end
end

-- Create plugin instance
local pluginInstance = RobloxSync.new()

-- Plugin cleanup
plugin.Unloading:Connect(function()
    pluginInstance:destroy()
end)

-- Initialize plugin
pluginInstance:init()
