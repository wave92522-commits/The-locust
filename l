local FEManager = loadstring(game:HttpGet("https://gist.githubusercontent.com/MelonsStuff/a003ea305dd302eab1f8d372daed38b4/raw/9db59962b28555fd699a7c29891efb85d45677ab/gistfile1.txt"))()

local ScriptOptions = {
    Settings = {
        AnimationSpeed = 1.25;
        Fling = false;
        Music = true;
        FOVEffects = true;
        CameraEffects = true;
        InfiniteJump = false;
    };
    Customization = { 
        HitboxColor = Color3.fromRGB(255, 255, 255);
        Hitmarker = 103397225855135;
    };
    FlingOptions = {
        HatFling = false,
        Highlight = false,
        PredictionFling = false,
        Timeout = 0.5,
        ToolFling = false,
    };
    Reanimate_Settings = {
        Frequency = 6,
        Amplification = 6,
        FrontOffset = 2.5,
    }
}

local AnimatorCache = {
    Joints = {};
    AnimDefaults = {};
    Rigs = {};
}

local ScriptCache = {
    StoredMotors = {};
    TrashBin = {};
    HitHumanoids = {};
    ActiveConnections = {};
}

local Directories = {
    Main = "FEVerse/";
    RBXMs ="FEVerse/RBXMs/";
    Sounds = "FEVerse/Sounds/";
    Songs = "FEVerse/Songs/";
}

local States = {
    Movement = {
        Idle = false;
        Walking = false;
        Running = false;
        Crouching = false;
        Sitting = false;
    };
    Input = {
        Debounce = false;
        Shift = false;
        KillMode = false;
    };
    Waypoint = {
        SavedPosition = nil;
        TVLocation = nil;
    }
}

local Services = {
    RunService = game:GetService("RunService");
    UserInputService = game:GetService("UserInputService");
    TweenService = game:GetService("TweenService");
    Debris = game:GetService("Debris");
    Players = game:GetService("Players");
    InsertService = game:GetService("InsertService");
}

for i, v in pairs(Directories) do FEManager.EnsureFolder(v) end

local function WaitForFile(Path)
    local Attempts = 0
    while not isfile(Path) and Attempts < 60 do
        wait(1)
        Attempts += 1
    end
    return isfile(Path)
end

task.spawn(function()
    local StarterGui = cloneref(game:GetService("StarterGui"))
    StarterGui:SetCore("SendNotification",{
        Title = "Cherry's Club",
        Text = "Checking files...",
        Duration = 3,
    })
    
    if not isfile(Directories.RBXMs.."Locust.rbxm") then
        StarterGui:SetCore("SendNotification",{
            Title = "Cherry's Club",
            Text = "Downloading model...",
            Duration = 3,
        })
        FEManager.DownloadFile(Directories.RBXMs, "Locust.rbxm", "https://github.com/MelonsStuff/FEVerse/raw/refs/heads/main/RBXMs/Locust.rbxm")
    end
    
    if not isfile(Directories.Songs.."LocustTheme.mp3") then
        StarterGui:SetCore("SendNotification",{
            Title = "Cherry's Club",
            Text = "Downloading music...",
            Duration = 3,
        })
        FEManager.DownloadFile(Directories.Songs, "LocustTheme.mp3", "https://github.com/MelonsStuff/FEVerse/raw/refs/heads/main/Songs/LocustTheme.mp3")
    end
end)

local HasModel = WaitForFile(Directories.RBXMs.."Locust.rbxm")
local HasMusic = WaitForFile(Directories.Songs.."LocustTheme.mp3")

if not HasModel then
    warn("Model file not found! Running without model.")
end

local LoadedAssets = nil
local Animations = nil
local Objects = nil

if HasModel then
    local Success, Result = pcall(function()
        return Services.InsertService:LoadLocalAsset(getcustomasset(Directories.RBXMs.."Locust.rbxm"))
    end)
    
    if Success and Result then
        LoadedAssets = Result
        Animations = LoadedAssets:FindFirstChild("Animations")
        Objects = LoadedAssets:FindFirstChild("Objects")
    else
        warn("Failed to load model assets!")
    end
end

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = workspace.CurrentCamera
local Mouse = Player:GetMouse()

local LocustModel = nil
local ModelRoot = nil

local function ApplyLocustModel()
    if not Objects then return end
    
    if LocustModel then
        LocustModel:Destroy()
        LocustModel = nil
    end
    
    local StarterCharacter = Objects:FindFirstChild("StarterCharacter")
    if not StarterCharacter then 
        warn("StarterCharacter not found!")
        return 
    end
    
    LocustModel = StarterCharacter:Clone()
    LocustModel.Name = "LocustVisual"
    
    local ModelHumanoid = LocustModel:FindFirstChild("Humanoid")
    if ModelHumanoid then ModelHumanoid:Destroy() end
    
    for i, v in pairs(LocustModel:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Anchored = false
            v.CanCollide = false
            v.Massless = true
            
            if v:IsA("Part") and v.Shape == Enum.PartType.Block then
                v.Transparency = 1
            else
                v.Transparency = 0
            end
        elseif v:IsA("Bone") then
            AnimatorCache.Joints[v.Name] = v
            AnimatorCache.AnimDefaults[v.Name] = v.CFrame
        end
    end
    
    ModelRoot = LocustModel:FindFirstChild("HumanoidRootPart")
    LocustModel.Parent = workspace
    
    if ModelRoot and RootPart then
        ModelRoot.CFrame = RootPart.CFrame
    end
    
    for i, v in pairs(Character:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Transparency = 1
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("Accessory") or v:IsA("Accoutrement") or v:IsA("Hat") then
            v:Destroy()
        end
    end
    
    RootPart.Transparency = 1
end

if HasModel then
    ApplyLocustModel()
end

local Theme = nil
if HasMusic then
    Theme = Instance.new("Sound", RootPart)
    if Services.RunService:IsStudio() then
        Theme.SoundId = "rbxasset://Locust.mp3"
    else
        Theme.SoundId = getcustomasset(Directories.Songs.."LocustTheme.mp3")
    end
    Theme.Volume = 1
    Theme.Looped = true
    Theme:Play()
end

local Contains = function(Table, Check)
    for Index, Value in next, Table do 
        if rawequal(Check, Index) or rawequal(Check, Value) then 
            return true
        end
    end
    return false
end

local Edit = function(Joint, Change, Duration, Style, Direction)
    if typeof(Style) == "EnumItem" and Style.Name == "Constant" then
        Joint.CFrame = Change
        return
    end 
    Style = Enum.EasingStyle[Style.Name]
    Direction = Enum.EasingDirection[Direction.Name]
    local Anim = game:GetService("TweenService"):Create(Joint, TweenInfo.new(Duration, Style, Direction), {CFrame = Change})
    Anim:Play()
    return Anim
end

local LoadBoneAnimation = function(Rig, KeyframeSequence)
    local Sequence = KeyframeSequence
    assert(Sequence:IsA("KeyframeSequence"), "KeyframeSequence Missing!")
    local Class = {}
    Class.Speed = 1
    Class.KeepLast = 0
    local Keyframes = KeyframeSequence:GetKeyframes()
    table.sort(Keyframes, function(a, b) return a.Time < b.Time end)
    Class.Length = Keyframes[#(Keyframes)].Time
    local Yield = function(Seconds)
        local Elapsed = 0
        local Target = Seconds / (Class.Speed * ScriptOptions.Settings.AnimationSpeed)
        repeat
            Elapsed += Services.RunService.Heartbeat:Wait()
        until Elapsed >= Target
    end
    
    if Sequence:FindFirstChild("xSIXxNull", true) or Sequence:FindFirstChild("xSIXxCustomDir", true) or Sequence:FindFirstChild("xSIXxCustomStyle", true) then
        local Children = Sequence:GetChildren()
        for i = 1, #(Children) do
            if Children[i]:FindFirstChild("Torso") then
                local Limbs = Children[i].Torso:GetChildren()
                for l = 1, #(Limbs) do
                    Limbs[l].Parent = Children[i].HumanoidRootPart.Torso
                end
                Children[i].Torso:Destroy()
            end
        end
    end
    
    local Descendants = Sequence:GetDescendants()
    for i = 1, #(Descendants) do
        if Descendants[i]:IsA("IntValue") or Descendants[i]:IsA("StringValue") or Descendants[i]:IsA("Folder") then
            Descendants[i]:Destroy()
        end
        if Descendants[i].Parent ~= Sequence and Descendants[i]:IsA("Pose") and not Rig:FindFirstChild(Descendants[i].Name, true) then
            Descendants[i]:Destroy()
        end
    end
    
    Class.Stopped = true
    Class.IsPlaying = false
    Class.TimePosition = 0
    Class.Looped = Sequence.Loop
    local Completion = Instance.new("BindableEvent")
    local Reached = Instance.new("BindableEvent")
    Class.Completed = Completion.Event
    Class.KeyframeReached = Reached.Event
    
    Class["Play"] = function(self, FadeIn, Speed)
        if Speed and Speed < 0 then
            Speed += (Speed*2)
        end
        Class.Speed = Speed or Class.Speed
        Class.Stopped = false
        Class.IsPlaying = true
        task.spawn(function()
            wait(1/60)
            if FadeIn ~= nil then
                Class.TimePosition -= FadeIn
            end
            Class.Completed:Connect(function()
                if Class.Looped ~= false then
                    Class.TimePosition = 0
                end
            end)
            repeat game:GetService("RunService").Heartbeat:Wait()
                Class.TimePosition += (1 * Class.Speed) / (60 * Class.Speed) 
            until Class.IsPlaying == false or Class.Stopped ~= false
        end)
        task.spawn(function()
            if FadeIn ~= nil then
                task.wait(1/55)
                task.spawn(function()
                    local Frames = Keyframes[1]:GetDescendants()
                    for i = 1, #(Frames) do 
                        local Pose = Frames[i]
                        if Contains(AnimatorCache.Joints, Pose.Name) then 
                            task.spawn(function()
                                for i = 1, 2 do
                                    Edit(AnimatorCache.Joints[Pose.Name], AnimatorCache.AnimDefaults[Pose.Name] * Pose.CFrame, FadeIn, Pose.EasingStyle, Pose.EasingDirection)
                                    task.wait()
                                end
                            end)
                        end
                    end
                end)
                Yield(FadeIn)
            end
            repeat
                for K = 1, #(Keyframes) do 
                    local K0, K1, K2 = Keyframes[K-1], Keyframes[K], Keyframes[K+1]
                    if Class.Stopped ~= true then
                        if K0 ~= nil then 
                            Yield(K1.Time - K0.Time)
                        end
                        task.spawn(function()
                            for i = 1, #(K1:GetDescendants()) do 
                                local Pose = K1:GetDescendants()[i]
                                if Contains(AnimatorCache.Joints, Pose.Name) then 
                                    local Duration = K2 ~= nil and (K2.Time - K1.Time) / Class.Speed or 0.5
                                    Edit(AnimatorCache.Joints[Pose.Name], AnimatorCache.AnimDefaults[Pose.Name] * Pose.CFrame, Duration, Pose.EasingStyle, Pose.EasingDirection)
                                end
                            end
                        end)
                        if K == #(Keyframes) and Class.KeepLast > 0 then
                            Yield(Class.KeepLast)
                        end
                        Reached:Fire(K1.Name)
                    else
                        break
                    end
                end
                Completion:Fire()
            until Class.Looped ~= true or Class.Stopped ~= false
            Class.IsPlaying = false
        end)
    end
    
    Class["Stop"] = function()
        Class.Stopped = true
        Class.IsPlaying = false
    end
    
    Class["AdjustSpeed"] = function(self, Speed)
        if Speed < 0 then
            Speed += (Speed*2)
        end
        Class.Speed = Speed or Class.Speed
    end
    return Class
end

local PlayAnim = function(Rig, Animation, AnimSpeed)
    if not Rig or not AnimatorCache.Rigs[Rig] then
        AnimatorCache.Rigs[Rig] = {}
    end
    if not AnimatorCache.Rigs[Rig][Animation.Name] then
        AnimatorCache.Rigs[Rig][Animation.Name] = LoadBoneAnimation(Rig, Animation)
    end
    for Name, Track in pairs(AnimatorCache.Rigs[Rig]) do
        if Name ~= Animation.Name then
            Track:Stop()
        end
    end
    local AnimInstance = AnimatorCache.Rigs[Rig][Animation.Name]
    if not AnimInstance.IsPlaying then
        AnimInstance:Play(AnimSpeed or 1)
    end
    return AnimInstance
end

local StopAnim = function(Rig, Animation)
    if not AnimatorCache.Rigs[Rig] then
        AnimatorCache.Rigs[Rig] = {}
    end
    if not AnimatorCache.Rigs[Rig][Animation.Name] then
        AnimatorCache.Rigs[Rig][Animation.Name] = LoadBoneAnimation(Rig, Animation)
    end
    AnimatorCache.Rigs[Rig][Animation.Name]:Stop()
end

local PlayUISFX = function(Audio)
    local Sound = Instance.new("Sound", workspace)
    Sound.SoundId = "rbxassetid://" .. Audio
    Sound.Volume = 1
    Sound.PlayOnRemove = true
    Sound:Destroy()
    return Sound
end

local PlaySFX = function(Audio)
    local Sound = Instance.new("Sound", RootPart)
    Sound.SoundId = "rbxassetid://" .. Audio
    Sound.Volume = 1
    Sound.PlayOnRemove = true
    Sound:Destroy()
    return Sound
end

local FlashHitHighlight = function(Target)
    if not Target or not Target:IsA("Model") then return end
    if Target:FindFirstChild("HitHighlight") then return end 
    local Highlight = Instance.new("Highlight")
    Highlight.Name = "HitHighlight"
    Highlight.Adornee = Target
    Highlight.FillColor = Color3.fromRGB(0, 0, 0)
    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    Highlight.FillTransparency = 1
    Highlight.OutlineTransparency = 1
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Parent = Target
    local FlashIn = Services.TweenService:Create(Highlight, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FillTransparency = 0.3, OutlineTransparency = 0})
    local FadeOut = Services.TweenService:Create(Highlight,TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FillTransparency = 1,OutlineTransparency = 1})
    FlashIn:Play()
    FlashIn.Completed:Once(function() FadeOut:Play() end)
    FadeOut.Completed:Once(function() Highlight:Destroy() end)
end

local NewHitbox = function(Position, Size, HitSound)
    local Hitbox = Instance.new("Part")
    Hitbox.Size = Size or Vector3.new(4, 4, 4)
    Hitbox.Color = ScriptOptions.Customization.HitboxColor
    Hitbox.Material = Enum.Material.ForceField
    Hitbox.Transparency = 0.5
    Hitbox.Anchored = true
    Hitbox.CanCollide = false
    Hitbox.CanQuery = false
    Hitbox.CanTouch = true
    Hitbox.CFrame = Position or RootPart.CFrame
    Hitbox.Parent = workspace
    local HitboxFade = game:GetService("TweenService"):Create(Hitbox, TweenInfo.new(0.5), {Transparency = 1})
    HitboxFade:Play()
    game:GetService("Debris"):AddItem(Hitbox, 0.5)
    return Hitbox
end

local SetWalkSpeed = function(Speed)
    Humanoid.WalkSpeed = Speed
end

local SetRootAnchored = function(Anchored)
    RootPart.Anchored = Anchored
end

local ToggleCrouch = function()
    States.Movement.Crouching = not States.Movement.Crouching
    States.Movement.Idle = false
    States.Movement.Walking = false
    States.Movement.Running = false
    States.Movement.Sitting = false
end

local ToggleSit = function()
    States.Movement.Sitting = not States.Movement.Sitting
    States.Movement.Crouching = false
    States.Movement.Idle = false
    States.Movement.Walking = false
    States.Movement.Running = false
end

local Waypoint = function()
    if not States.Waypoint.SavedPosition then
        States.Waypoint.SavedPosition = RootPart.Position
        if States.Waypoint.TVLocation then States.Waypoint.TVLocation:Destroy() end
        if Objects then
            local Part = Objects:WaitForChild("TeleportPart"):Clone()
            Part.CFrame = CFrame.new(States.Waypoint.SavedPosition + Vector3.new(0, -2.975, 0))
            Part.Parent = workspace
            States.Waypoint.TVLocation = Part
        end
    else
        if States.Input.Debounce then return end
        if States.Waypoint.TVLocation then States.Waypoint.TVLocation:Destroy() States.Waypoint.TVLocation = nil end
        SetRootAnchored(true)
        States.Input.Debounce = true
        local TeleportAnim = nil
        if LocustModel and Animations then
            TeleportAnim = PlayAnim(LocustModel, Animations.Spawn, 0.1)
        end
        RootPart.CFrame = CFrame.new(States.Waypoint.SavedPosition)
        if TeleportAnim then TeleportAnim.Completed:Wait() end
        States.Waypoint.SavedPosition = nil
        States.Input.Debounce = false
        SetRootAnchored(false)
        RestoreMovement()
    end
end

local ToggleKillMode = function()
    States.Input.KillMode = not States.Input.KillMode
end

local Kill = function(Target)
    if States.Input.Debounce then return end
    if not States.Input.KillMode then return end
    if not Target then return end
    local Model = Target and Target:FindFirstAncestorOfClass("Model")
    if not Model or not Model:FindFirstChildOfClass("Humanoid") then return end
    States.Input.Debounce = true
    SetRootAnchored(true)
    local KillAnim = nil
    if LocustModel and Animations then
        KillAnim = PlayAnim(LocustModel, Animations.Kill, 0.1)
    end
    FlashHitHighlight(Model)
    PlaySFX(ScriptOptions.Customization.Hitmarker or 108515070727256)
    NewHitbox(RootPart.CFrame * CFrame.new(0, 0, -3), Vector3.new(4, 4, 4), 108515070727256)
    if KillAnim then KillAnim.Completed:Wait() end
    SetRootAnchored(false)
    States.Input.Debounce = false
    RestoreMovement()
end

local RestoreMovement = function()
    if not LocustModel or not Animations then return end
    if RootPart.Velocity.Magnitude < 1 and workspace:FindPartOnRay(Ray.new(RootPart.Position, (CFrame.new(RootPart.Position, RootPart.Position + Vector3.new(0, -1, 0))).LookVector * 4), Character) then
        States.Movement.Idle = true
        States.Movement.Walking = false
        States.Movement.Running = false
        PlayAnim(LocustModel, Animations.Idle, .1)
    elseif RootPart.Velocity.Magnitude > 1 and workspace:FindPartOnRay(Ray.new(RootPart.Position, (CFrame.new(RootPart.Position, RootPart.Position + Vector3.new(0, -1, 0))).LookVector * 4), Character) then
        States.Movement.Idle = false
        States.Movement.Walking = true
        States.Movement.Running = false
        PlayAnim(LocustModel, Animations.Walk, .1)
    end
end

local KeyDown = Services.UserInputService.InputBegan:Connect(function(Key, GPE)
    if GPE then return end
    if Key.UserInputType == Enum.UserInputType.MouseButton1 then
        Kill(Mouse.Target)
    end
    if Key.KeyCode == Enum.KeyCode.Q then
        ToggleCrouch()
    end
    if Key.KeyCode == Enum.KeyCode.C then
        ToggleSit()
    end
    if Key.KeyCode == Enum.KeyCode.X then
        ToggleKillMode()
    end
    if Key.KeyCode == Enum.KeyCode.E then
        Waypoint()
    end
    if Key.KeyCode == Enum.KeyCode.LeftShift then
        States.Input.Shift = true
    end
end)
table.insert(ScriptCache.ActiveConnections, KeyDown)

local KeyUp = Services.UserInputService.InputEnded:Connect(function(Key, GPE)
    if GPE then return end
    if Key.KeyCode == Enum.KeyCode.LeftShift then
        States.Input.Shift = false
    end
end)
table.insert(ScriptCache.ActiveConnections, KeyUp)

local InfiniteJump = Services.UserInputService.JumpRequest:Connect(function()
    if ScriptOptions.Settings.InfiniteJump and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
table.insert(ScriptCache.ActiveConnections, InfiniteJump)

if LoadedAssets then
    local GUI = LoadedAssets:WaitForChild("UIs").MobileUI
    GUI.Parent = game:GetService("CoreGui")
    table.insert(ScriptCache.TrashBin, GUI)

    local UpdateUI = function()
        local LastInput = Services.UserInputService:GetLastInputType()
        if LastInput == Enum.UserInputType.Touch
        then GUI.Enabled = true
        else GUI.Enabled = false
        end
    end

    UpdateUI()
    Services.UserInputService.LastInputTypeChanged:Connect(UpdateUI)

    GUI.AbilitiesUI["ToggleKill"].MouseButton1Down:connect(function() ToggleKillMode() end)
    GUI.AbilitiesUI["Waypoint"].MouseButton1Down:connect(function() Waypoint() end)
    GUI.AbilitiesUI["Sit"].MouseButton1Down:connect(function() ToggleSit() end)
    GUI.AbilitiesUI["Crouch"].MouseButton1Down:connect(function() ToggleCrouch() end)
    GUI.AbilitiesUI["Sprint"].MouseButton1Down:connect(function() States.Input.Shift = not States.Input.Shift end)

    local MainGUI = LoadedAssets.UIs:WaitForChild("MainGUI")
    MainGUI.Parent = game:GetService("CoreGui")
    table.insert(ScriptCache.TrashBin, MainGUI)

    local SettingsFrame = MainGUI:WaitForChild("SettingsFrame")
    local Vignette = MainGUI:WaitForChild("Vignette")
    local SettingsHolder = SettingsFrame:WaitForChild("SettingsHolder")
    local FloatingButton = MainGUI:WaitForChild("FloatingButton")
    local UIDragDetector = Instance.new("UIDragDetector", FloatingButton)

    UIDragDetector.DragStart:Connect(function()
        SettingsFrame.Visible = not SettingsFrame.Visible
        PlayUISFX(18755588842)
    end)

    FloatingButton.MouseEnter:Connect(function()
        PlayUISFX(122453173810540)
    end)

    local SetupToggle = function(Setting)
        local Object = SettingsHolder:FindFirstChild(Setting)
        if not Object then return end
        local Button = Object:FindFirstChildWhichIsA("TextButton")
        if not Button then return end
        Button.BackgroundColor3 = ScriptOptions.Settings[Setting] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
        Button.MouseButton1Click:Connect(function()
            PlayUISFX(18755588842)
            ScriptOptions.Settings[Setting] = not ScriptOptions.Settings[Setting]
            Button.BackgroundColor3 = ScriptOptions.Settings[Setting] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
        end)
    end

    for i, v in pairs(ScriptOptions.Settings) do
        local Object = SettingsHolder:FindFirstChild(i)
        if Object then
            if Object:FindFirstChild("Button") then
                SetupToggle(i)
            end
        end
    end

    SettingsHolder.TPToNearestSpawn.Button.MouseButton1Click:Connect(function()
        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        local GetClosestSpawn = function()
            local ClosestSpawn, ClosestDistance = nil, math.huge
            for i, v in pairs(workspace:GetDescendants()) do
                if v:IsA("SpawnLocation") then
                    local Distance = (RootPart.Position - v.Position).Magnitude
                    if Distance < ClosestDistance then
                        ClosestSpawn = v
                        ClosestDistance = Distance
                    end
                end
            end
            return ClosestSpawn
        end
        local Spawn = GetClosestSpawn()
        if Spawn then
            RootPart.CFrame = Spawn.CFrame + Vector3.new(0, 5, 0)
        else
            warn("No spawn found.")
        end
    end)
end

local RunServiceConnection = Services.RunService.Heartbeat:Connect(function(dt)
    if LocustModel and ModelRoot and RootPart then
        ModelRoot.CFrame = RootPart.CFrame
        ModelRoot.Velocity = Vector3.zero
        ModelRoot.RotVelocity = Vector3.zero
    end
    
    if States.Input.Debounce and LocustModel and Animations then
        StopAnim(LocustModel, Animations.Idle)
        StopAnim(LocustModel, Animations.Walk)
        StopAnim(LocustModel, Animations.Sprint)
    end
    
    if ScriptOptions.Settings.CameraEffects then
        local TargetOffset = States.Movement.Crouching and Vector3.new(0, 5, 0) or Vector3.new(0, 10, 0)
        Humanoid.CameraOffset = Humanoid.CameraOffset:Lerp(TargetOffset, 0.1)
    else
        Humanoid.CameraOffset = Humanoid.CameraOffset:Lerp(Vector3.zero, 0.1)
    end
    
    if not States.Input.Debounce then
        if States.Movement.Crouching then
            SetWalkSpeed(3)
        elseif States.Input.Shift then
            SetWalkSpeed(24)
        else
            SetWalkSpeed(6)
        end
    end
    
    if ScriptOptions.Settings.FOVEffects and Theme then
        Camera.FieldOfView = 80 + Theme.PlaybackLoudness / 100
        if Vignette then
            Vignette.ImageTransparency = 1 - Theme.PlaybackLoudness / 900
        end
    else
        Camera.FieldOfView = 70
        if Vignette then
            Vignette.ImageTransparency = 1
        end
    end
    
    if ScriptOptions.Settings.Music and Theme then
        Theme.Playing = true
    elseif Theme then
        Theme.Playing = false
    end
    
    local RootPartOrigin = RootPart.Position
    local Direction = Vector3.new(0, -1, 0) * 4
    local Params = RaycastParams.new()
    Params.FilterDescendantsInstances = {Character, LocustModel}
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.IgnoreWater = true
    local Result = workspace:Raycast(RootPartOrigin, Direction, Params)
    local HitFloor = Result and Result.Instance
    local TorsoVelocity = RootPart.Velocity.Magnitude
    
    if LocustModel and Animations then
        if TorsoVelocity < 0.001 and HitFloor ~= nil and not States.Input.Debounce then
            if States.Movement.Crouching then
                PlayAnim(LocustModel, Animations.IdleCrouch, 0.1)
            elseif States.Movement.Sitting then
                PlayAnim(LocustModel, Animations.Sit, 0.1) 
            elseif States.Movement.Idle == false then
                States.Movement.Idle = true
                PlayAnim(LocustModel, Animations.Idle, 0.1)
            end
            States.Movement.Walking = false
            States.Movement.Running = false
            StopAnim(LocustModel, Animations.Walk)
            StopAnim(LocustModel, Animations.Sprint)
        elseif TorsoVelocity > 6 and HitFloor ~= nil and not States.Input.Debounce and States.Input.Shift and not States.Movement.Crouching then
            if States.Movement.Running == false then
                States.Movement.Running = true
                PlayAnim(LocustModel, Animations.Sprint, 0.1)
            end
            States.Movement.Idle = false
            States.Movement.Walking = false
            StopAnim(LocustModel, Animations.Idle)
            StopAnim(LocustModel, Animations.Walk)
        elseif TorsoVelocity > 6 and HitFloor ~= nil and not States.Input.Debounce then
            if States.Movement.Crouching then
                States.Movement.Walking = true
                PlayAnim(LocustModel, Animations.WalkCrouch, 0.1)
            elseif States.Movement.Walking == false then
                States.Movement.Walking = true
                PlayAnim(LocustModel, Animations.Walk, 0.1)
            end
            States.Movement.Idle = false
            States.Movement.Running = false
            StopAnim(LocustModel, Animations.Idle)
            StopAnim(LocustModel, Animations.Sprint)
        end
    end
end)
table.insert(ScriptCache.ActiveConnections, RunServiceConnection)

Player.CharacterAdded:Connect(function(NewCharacter)
    Character = NewCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    
    wait(0.5)
    if HasModel then
        ApplyLocustModel()
    end
    
    if HasMusic then
        if Theme then Theme:Destroy() end
        Theme = Instance.new("Sound", RootPart)
        if Services.RunService:IsStudio() then
            Theme.SoundId = "rbxasset://Locust.mp3"
        else
            Theme.SoundId = getcustomasset(Directories.Songs.."LocustTheme.mp3")
        end
        Theme.Volume = 1
        Theme.Looped = true
        Theme:Play()
    end
    
    AnimatorCache.Rigs = {}
    RestoreMovement()
end)
