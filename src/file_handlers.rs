use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RbxJsonInstance {
    #[serde(rename = "className")]
    pub class_name: String,
    pub name: String,
    pub properties: HashMap<String, RbxJsonProperty>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "value")]
pub enum RbxJsonProperty {
    #[serde(rename = "string")]
    String(String),
    #[serde(rename = "bool")]
    Bool(bool),
    #[serde(rename = "int")]
    Int(i64),
    #[serde(rename = "float")]
    Float(f64),
    #[serde(rename = "Vector2")]
    Vector2 { x: f64, y: f64 },
    #[serde(rename = "Vector3")]
    Vector3 { x: f64, y: f64, z: f64 },
    #[serde(rename = "CFrame")]
    CFrame { 
        position: [f64; 3], 
        rotation: [f64; 9] 
    },
    #[serde(rename = "Color3")]
    Color3 { r: f64, g: f64, b: f64 },
    #[serde(rename = "Color3uint8")]
    Color3uint8 { r: u8, g: u8, b: u8 },
    #[serde(rename = "BrickColor")]
    BrickColor(u32),
    #[serde(rename = "UDim")]
    UDim { scale: f64, offset: i32 },
    #[serde(rename = "UDim2")]
    UDim2 { 
        x: Box<RbxJsonProperty>, 
        y: Box<RbxJsonProperty> 
    },
    #[serde(rename = "Rect")]
    Rect { 
        min: Box<RbxJsonProperty>, 
        max: Box<RbxJsonProperty> 
    },
    #[serde(rename = "NumberRange")]
    NumberRange { min: f64, max: f64 },
    #[serde(rename = "Enum")]
    Enum { 
        #[serde(rename = "enumType")]
        enum_type: String, 
        value: String 
    },
    #[serde(rename = "Content")]
    Content(String),
    #[serde(rename = "Font")]
    Font { 
        family: String, 
        weight: u16, 
        style: String 
    },
}

pub struct RbxJsonHandler;

impl RbxJsonHandler {
    pub fn parse_instance(json_str: &str) -> anyhow::Result<RbxJsonInstance> {
        let instance: RbxJsonInstance = serde_json::from_str(json_str)?;
        Ok(instance)
    }

    pub fn serialize_instance(instance: &RbxJsonInstance) -> anyhow::Result<String> {
        let json_str = serde_json::to_string_pretty(instance)?;
        Ok(json_str)
    }

    pub fn create_part(name: &str, size: (f64, f64, f64), position: (f64, f64, f64)) -> RbxJsonInstance {
        let mut properties = HashMap::new();
        
        properties.insert("Anchored".to_string(), RbxJsonProperty::Bool(true));
        properties.insert("Size".to_string(), RbxJsonProperty::Vector3 { 
            x: size.0, 
            y: size.1, 
            z: size.2 
        });
        properties.insert("Position".to_string(), RbxJsonProperty::Vector3 { 
            x: position.0, 
            y: position.1, 
            z: position.2 
        });
        properties.insert("Material".to_string(), RbxJsonProperty::Enum { 
            enum_type: "Material".to_string(), 
            value: "Plastic".to_string() 
        });

        RbxJsonInstance {
            class_name: "Part".to_string(),
            name: name.to_string(),
            properties,
        }
    }

    pub fn create_script(name: &str, script_type: ScriptType, source: &str) -> RbxJsonInstance {
        let mut properties = HashMap::new();
        
        properties.insert("Source".to_string(), RbxJsonProperty::String(source.to_string()));
        properties.insert("Enabled".to_string(), RbxJsonProperty::Bool(true));

        RbxJsonInstance {
            class_name: script_type.to_string(),
            name: name.to_string(),
            properties,
        }
    }
}

#[derive(Debug, Clone)]
pub enum ScriptType {
    Script,
    LocalScript,
    ModuleScript,
}

impl ScriptType {
    pub fn to_string(&self) -> String {
        match self {
            ScriptType::Script => "Script".to_string(),
            ScriptType::LocalScript => "LocalScript".to_string(),
            ScriptType::ModuleScript => "ModuleScript".to_string(),
        }
    }
}

pub struct LuauHandler;

impl LuauHandler {
    pub fn detect_script_type(filename: &str) -> ScriptType {
        if filename.ends_with(".server.luau") {
            ScriptType::Script
        } else if filename.ends_with(".client.luau") {
            ScriptType::LocalScript
        } else if filename.ends_with(".luau") {
            ScriptType::ModuleScript
        } else {
            ScriptType::ModuleScript // Default
        }
    }

    pub fn generate_server_script() -> String {
        r#"-- Server Script
local Players = game:GetService("Players")

local function onPlayerAdded(player)
    print("Player joined:", player.Name)
    
    -- Give player starting tools
    local starterPack = game:GetService("StarterPack")
    -- Add tools here
end

local function onPlayerRemoving(player)
    print("Player left:", player.Name)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("Server script loaded")
"#.to_string()
    }

    pub fn generate_client_script() -> String {
        r#"-- Local Script
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Example: Handle player input
local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.Keyboard then
        print("Key pressed:", input.KeyCode.Name)
    end
end

UserInputService.InputBegan:Connect(onInputBegan)

-- Example: Handle character spawn
local function onCharacterAdded(character)
    print("Character spawned for", player.Name)
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

print("Client script loaded")
"#.to_string()
    }

    pub fn generate_module_script() -> String {
        r#"-- Module Script
local MyModule = {}

-- Example utility functions
function MyModule.formatNumber(num)
    return tostring(num)
end

function MyModule.calculateDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

function MyModule.createNotification(message, duration)
    duration = duration or 3
    
    local starterGui = game:GetService("StarterGui")
    starterGui:SetCore("ChatMakeSystemMessage", {
        Text = "[System] " .. message;
        Color = Color3.new(1, 1, 1);
        Font = Enum.Font.SourceSans;
    })
end

return MyModule
"#.to_string()
    }

    pub fn validate_syntax(code: &str) -> Result<(), String> {
        // Basic syntax validation - in a real implementation, 
        // you'd use a proper Luau parser
        if code.is_empty() {
            return Err("Empty code".to_string());
        }

        // Check for balanced parentheses, brackets, etc.
        let mut paren_count = 0;
        let mut brace_count = 0;
        let mut bracket_count = 0;

        for char in code.chars() {
            match char {
                '(' => paren_count += 1,
                ')' => paren_count -= 1,
                '{' => brace_count += 1,
                '}' => brace_count -= 1,
                '[' => bracket_count += 1,
                ']' => bracket_count -= 1,
                _ => {}
            }

            if paren_count < 0 || brace_count < 0 || bracket_count < 0 {
                return Err("Unmatched closing bracket".to_string());
            }
        }

        if paren_count != 0 {
            return Err("Unmatched parentheses".to_string());
        }
        if brace_count != 0 {
            return Err("Unmatched braces".to_string());
        }
        if bracket_count != 0 {
            return Err("Unmatched brackets".to_string());
        }

        Ok(())
    }
}
