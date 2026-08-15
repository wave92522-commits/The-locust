local FEManager = loadstring(game:HttpGet("https://gist.githubusercontent.com/MelonsStuff/a003ea305dd302eab1f8d372daed38b4/raw/9db59962b28555fd699a7c29891efb85d45677ab/gistfile1.txt"
))()

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
        DeathExtraSounds = {5801257793, 4988580332}; -- Доп. звуки смерти (можно заменить своими ID)
    };

    FlingOptions = {
        HatFling = false;
        Highlight = false;
        PredictionFling = false;
        Timeout = 0.5;
        ToolFling = false;
    };

    Reanimate_Settings = {
        Frequency = 6;
        Amplification = 6;
        FrontOffset = 2.5;
    };

    Blood = {
        CorpseLifetime = 7;      -- Тело валяется 7 секунд, потом исчезает
        EmissionDuration = 6;    -- Кровь всегда идёт 6 секунд
        BigCubeLifetime = 5;
        BigCubeCount = 28;       -- Больше кусков
        InitialSmallCount = 90;  -- Мощный начальный взрыв крови
        WaveStartCount = 22;
    };
}

local AnimatorCache = {
    Joints = {};
    AnimDefaults = {};
    Rigs = {};
    ActiveTweens = {};
}

local ScriptCache = {
    StoredMotors = {};
    TrashBin = {};
    HitHumanoids = {};
    ActiveConnections = {};
}

local Directories = {
    Main = "FEVerse/";
    RBXMs = "FEVerse/RBXMs/";
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
        MobileSprint = false; -- Тоггл бега для мобилки
        KillMode = true;
    };

    Waypoint = {
        SavedPosition = nil;
        TVLocation = nil;
    };
}

local Services = {
    RunService = game:GetService("RunService");
    UserInputService = game:GetService("UserInputService");
    TweenService = game:GetService("TweenService");
    Debris = game:GetService("Debris");
    Players = game:GetService("Players");
    InsertService = game:GetService("InsertService");
    StarterGui = game:GetService("StarterGui");
    CoreGui = game:GetService("CoreGui");
    Lighting = game:GetService("Lighting");
}

local RandomGenerator = Random.new()

for _, Directory in pairs(Directories) do
    FEManager.EnsureFolder(Directory)
end

local function SendNotification(Text)
    task.spawn(function()
        local StarterGui = Services.StarterGui

        if typeof(cloneref) == "function" then
            StarterGui = cloneref(StarterGui)
        end

        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Cherry's Club";
                Text = Text;
                Duration = 3;
            })
        end)
    end)
end

local function WaitForFile(Path)
    local Attempts = 0

    while not isfile(Path) and Attempts < 60 do
        task.wait(1)
        Attempts += 1
    end

    return isfile(Path)
end

task.spawn(function()
    SendNotification("Checking files...")

    if not isfile(Directories.RBXMs .. "Locust.rbxm") then
        SendNotification("Downloading model...")

        FEManager.DownloadFile(
            Directories.RBXMs,
            "Locust.rbxm",
            "https://github.com/MelonsStuff/FEVerse/raw/refs/heads/main/RBXMs/Locust.rbxm"
        )
    end

    if not isfile(Directories.Songs .. "LocustTheme.mp3") then
        SendNotification("Downloading music...")

        FEManager.DownloadFile(
            Directories.Songs,
            "LocustTheme.mp3",
            "https://github.com/MelonsStuff/FEVerse/raw/refs/heads/main/Songs/LocustTheme.mp3"
        )
    end
end)

local HasModel = WaitForFile(Directories.RBXMs .. "Locust.rbxm")
local HasMusic = WaitForFile(Directories.Songs .. "LocustTheme.mp3")

if not HasModel then
    warn("Model file not found! Running without model.")
end

if not HasMusic then
    warn("Music file not found! Running without music.")
end

local LoadedAssets = nil
local Animations = nil
local Objects = nil

if HasModel then
    local Success, Result = pcall(function()
        local AssetPath = Directories.RBXMs .. "Locust.rbxm"

        if typeof(getcustomasset) == "function" then
            AssetPath = getcustomasset(AssetPath)
        end

        return Services.InsertService:LoadLocalAsset(AssetPath)
    end)

    if Success and Result then
        LoadedAssets = Result
        Animations = LoadedAssets:FindFirstChild("Animations")
        Objects = LoadedAssets:FindFirstChild("Objects")
    else
        warn("Failed to load model assets:", Result)
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
local Theme = nil
local Vignette = nil
local CurrentMovementAnimation = nil
local CharacterHideConnection = nil

--// ANIMATION SYSTEM

local function GetEffectiveAnimationSpeed(Track)
    local TrackSpeed = 1

    if Track and type(Track.Speed) == "number" then
        TrackSpeed = math.abs(Track.Speed)
    end

    local GlobalSpeed = tonumber(ScriptOptions.Settings.AnimationSpeed) or 1

    return math.max(0.01, TrackSpeed * math.max(0.01, GlobalSpeed))
end

local function CancelJointTween(Joint)
    local Tween = AnimatorCache.ActiveTweens[Joint]

    if Tween then
        AnimatorCache.ActiveTweens[Joint] = nil

        pcall(function()
            Tween:Cancel()
        end)
    end
end

local function SetJointInstant(Track, Joint, TargetCFrame)
    if not Joint or not Joint.Parent then
        return
    end

    CancelJointTween(Joint)

    if Track and Track._tweens then
        Track._tweens[Joint] = nil
    end

    pcall(function()
        Joint.CFrame = TargetCFrame
    end)
end

local function ResolveTweenStyle(PoseStyle)
    if typeof(PoseStyle) ~= "EnumItem" then
        return Enum.EasingStyle.Linear
    end

    return Enum.EasingStyle[PoseStyle.Name] or Enum.EasingStyle.Linear
end

local function ResolveTweenDirection(PoseDirection)
    if typeof(PoseDirection) ~= "EnumItem" then
        return Enum.EasingDirection.Out
    end

    return Enum.EasingDirection[PoseDirection.Name] or Enum.EasingDirection.Out
end

local function TweenJoint(Track, Joint, TargetCFrame, Duration, PoseStyle, PoseDirection)
    if not Joint or not Joint.Parent then
        return
    end

    Duration = math.max(0, tonumber(Duration) or 0)

    if Duration <= 0 then
        SetJointInstant(Track, Joint, TargetCFrame)
        return
    end

    CancelJointTween(Joint)

    local TweenStyle = ResolveTweenStyle(PoseStyle)
    local TweenDirection = ResolveTweenDirection(PoseDirection)

    local Success, Tween = pcall(function()
        return Services.TweenService:Create(
            Joint,
            TweenInfo.new(Duration, TweenStyle, TweenDirection),
            {CFrame = TargetCFrame}
        )
    end)

    if not Success or not Tween then
        SetJointInstant(Track, Joint, TargetCFrame)
        return
    end

    AnimatorCache.ActiveTweens[Joint] = Tween
    Track._tweens[Joint] = Tween

    local CompletionConnection
    CompletionConnection = Tween.Completed:Connect(function()
        if CompletionConnection then
            CompletionConnection:Disconnect()
            CompletionConnection = nil
        end

        if AnimatorCache.ActiveTweens[Joint] == Tween then
            AnimatorCache.ActiveTweens[Joint] = nil
        end

        if Track._tweens[Joint] == Tween then
            Track._tweens[Joint] = nil
        end
    end)

    Tween:Play()
end

local function PrepareSequence(SourceSequence)
    local Sequence = SourceSequence:Clone()

    local HasLegacyData =
        Sequence:FindFirstChild("xSIXxNull", true)
        or Sequence:FindFirstChild("xSIXxCustomDir", true)
        or Sequence:FindFirstChild("xSIXxCustomStyle", true)

    if HasLegacyData then
        for _, Keyframe in ipairs(Sequence:GetChildren()) do
            local OldTorso = Keyframe:FindFirstChild("Torso")
            local RootPose = Keyframe:FindFirstChild("HumanoidRootPart")
            local NewTorso = RootPose and RootPose:FindFirstChild("Torso")

            if OldTorso and NewTorso then
                for _, Limb in ipairs(OldTorso:GetChildren()) do
                    Limb.Parent = NewTorso
                end

                OldTorso:Destroy()
            end
        end
    end

    return Sequence
end

local function LoadBoneAnimation(Rig, SourceSequence)
    assert(SourceSequence and SourceSequence:IsA("KeyframeSequence"), "KeyframeSequence missing!")

    local Sequence = PrepareSequence(SourceSequence)
    local Keyframes = Sequence:GetKeyframes()

    table.sort(Keyframes, function(A, B)
        return A.Time < B.Time
    end)

    assert(#Keyframes > 0, "Animation has no keyframes!")

    local CompletionBindable = Instance.new("BindableEvent")
    local KeyframeBindable = Instance.new("BindableEvent")

    local Track = {
        Speed = 1;
        KeepLast = 0;
        Length = Keyframes[#Keyframes].Time;
        TimePosition = 0;
        Looped = Sequence.Loop;
        IsPlaying = false;
        Stopped = true;
        Completed = CompletionBindable.Event;
        KeyframeReached = KeyframeBindable.Event;
        _completionBindable = CompletionBindable;
        _keyframeBindable = KeyframeBindable;
        _sequence = Sequence;
        _generation = 0;
        _tweens = {};
    }

    function Track:_CancelTweens()
        for Joint, Tween in pairs(self._tweens) do
            if AnimatorCache.ActiveTweens[Joint] == Tween then
                AnimatorCache.ActiveTweens[Joint] = nil
            end

            pcall(function()
                Tween:Cancel()
            end)

            self._tweens[Joint] = nil
        end
    end

    local function WaitRealSeconds(Self, Duration, Generation)
        local Elapsed = 0

        while Elapsed < Duration do
            if Self.Stopped or Self._generation ~= Generation then
                return false
            end

            Elapsed += Services.RunService.Heartbeat:Wait()
        end

        return true
    end

    local function WaitAnimationSeconds(Self, Duration, Generation)
        local Progress = 0

        while Progress < Duration do
            if Self.Stopped or Self._generation ~= Generation then
                return false
            end

            local DeltaTime = Services.RunService.Heartbeat:Wait()
            local AnimationDelta = DeltaTime * GetEffectiveAnimationSpeed(Self)

            Progress += AnimationDelta
            Self.TimePosition = math.min(Self.Length, Self.TimePosition + AnimationDelta)
        end

        return true
    end

    local function ApplyFrame(Self, Keyframe, TweenDuration, Generation, DeferConstant)
        local Deferred = {}

        for _, Pose in ipairs(Keyframe:GetDescendants()) do
            if Pose:IsA("Pose") then
                local Joint = AnimatorCache.Joints[Pose.Name]
                local DefaultCFrame = AnimatorCache.AnimDefaults[Pose.Name]

                if Joint and DefaultCFrame and Joint.Parent then
                    local TargetCFrame = DefaultCFrame * Pose.CFrame
                    local IsConstant =
                        typeof(Pose.EasingStyle) == "EnumItem"
                        and Pose.EasingStyle.Name == "Constant"

                    if IsConstant and DeferConstant and TweenDuration > 0 then
                        table.insert(Deferred, {
                            Joint = Joint;
                            CFrame = TargetCFrame;
                        })
                    elseif IsConstant then
                        SetJointInstant(Self, Joint, TargetCFrame)
                    else
                        TweenJoint(
                            Self,
                            Joint,
                            TargetCFrame,
                            TweenDuration,
                            Pose.EasingStyle,
                            Pose.EasingDirection
                        )
                    end
                end
            end
        end

        return Deferred
    end

    local function ApplyDeferred(Self, Deferred)
        for _, Data in ipairs(Deferred) do
            SetJointInstant(Self, Data.Joint, Data.CFrame)
        end
    end

    function Track:Play(FadeIn, Speed)
        if self.IsPlaying then
            return
        end

        if type(Speed) == "number" then
            self.Speed = math.max(0.01, math.abs(Speed))
        end

        FadeIn = math.max(0, tonumber(FadeIn) or 0)

        self._generation += 1
        local Generation = self._generation

        self.Stopped = false
        self.IsPlaying = true
        self.TimePosition = 0

        task.spawn(function()
            Services.RunService.Heartbeat:Wait()

            local FirstLoop = true

            while self._generation == Generation and not self.Stopped do
                self.TimePosition = 0

                local FirstFrame = Keyframes[1]
                local CurrentFade = FirstLoop and FadeIn or 0

                ApplyFrame(self, FirstFrame, CurrentFade, Generation, false)

                if CurrentFade > 0 then
                    if not WaitRealSeconds(self, CurrentFade, Generation) then
                        return
                    end
                end

                if self.Stopped or self._generation ~= Generation then
                    return
                end

                self.TimePosition = FirstFrame.Time
                KeyframeBindable:Fire(FirstFrame.Name)

                for Index = 2, #Keyframes do
                    if self.Stopped or self._generation ~= Generation then
                        return
                    end

                    local PreviousFrame = Keyframes[Index - 1]
                    local CurrentFrame = Keyframes[Index]
                    local AnimationDuration = math.max(0, CurrentFrame.Time - PreviousFrame.Time)
                    local TweenDuration = AnimationDuration / GetEffectiveAnimationSpeed(self)

                    local Deferred = ApplyFrame(
                        self,
                        CurrentFrame,
                        TweenDuration,
                        Generation,
                        true
                    )

                    if AnimationDuration > 0 then
                        if not WaitAnimationSeconds(self, AnimationDuration, Generation) then
                            return
                        end
                    end

                    ApplyDeferred(self, Deferred)
                    self.TimePosition = CurrentFrame.Time
                    KeyframeBindable:Fire(CurrentFrame.Name)
                end

                if self.KeepLast > 0 then
                    if not WaitAnimationSeconds(self, self.KeepLast, Generation) then
                        return
                    end
                end

                CompletionBindable:Fire()
                FirstLoop = false

                if not self.Looped then
                    break
                end
            end

            if self._generation == Generation then
                self.IsPlaying = false
                self.Stopped = true
                self:_CancelTweens()
            end
        end)
    end

    function Track:Stop()
        self._generation += 1
        self.Stopped = true
        self.IsPlaying = false
        self:_CancelTweens()
    end

    function Track:AdjustSpeed(Speed)
        if type(Speed) == "number" then
            self.Speed = math.max(0.01, math.abs(Speed))
        end
    end

    function Track:Destroy()
        self:Stop()

        if self._completionBindable then
            self._completionBindable:Destroy()
        end

        if self._keyframeBindable then
            self._keyframeBindable:Destroy()
        end

        if self._sequence then
            self._sequence:Destroy()
        end
    end

    return Track
end

local function StopAllAnimations()
    for _, RigTracks in pairs(AnimatorCache.Rigs) do
        for _, Track in pairs(RigTracks) do
            pcall(function()
                Track:Stop()
            end)
        end
    end

    for Joint, Tween in pairs(AnimatorCache.ActiveTweens) do
        pcall(function()
            Tween:Cancel()
        end)

        AnimatorCache.ActiveTweens[Joint] = nil
    end
end

local function PlayAnim(Rig, Animation, FadeIn, Speed, ForceLoop, Restart)
    if not Rig or not Animation or not Animation:IsA("KeyframeSequence") then
        return nil
    end

    AnimatorCache.Rigs[Rig] = AnimatorCache.Rigs[Rig] or {}

    local RigTracks = AnimatorCache.Rigs[Rig]
    local Track = RigTracks[Animation.Name]

    if not Track then
        local Success, Result = pcall(function()
            return LoadBoneAnimation(Rig, Animation)
        end)

        if not Success then
            warn("Failed to load animation " .. Animation.Name .. ":", Result)
            return nil
        end

        Track = Result
        RigTracks[Animation.Name] = Track
    end

    for Name, OtherTrack in pairs(RigTracks) do
        if Name ~= Animation.Name and OtherTrack.IsPlaying then
            OtherTrack:Stop()
        end
    end

    if ForceLoop ~= nil then
        Track.Looped = ForceLoop
    end

    if Restart and Track.IsPlaying then
        Track:Stop()
    end

    if not Track.IsPlaying then
        Track:Play(FadeIn or 0.1, Speed or 1)
    end

    return Track
end

local function StopAnim(Rig, Animation)
    if not Rig or not Animation then
        return
    end

    local RigTracks = AnimatorCache.Rigs[Rig]
    local Track = RigTracks and RigTracks[Animation.Name]

    if Track then
        Track:Stop()
    end
end

local function GetAnimation(Name)
    if not Animations then
        return nil
    end

    local Animation = Animations:FindFirstChild(Name)

    if Animation and Animation:IsA("KeyframeSequence") then
        return Animation
    end

    return nil
end

local function PlayNamedAnimation(Name, FadeIn, Speed, ForceLoop, Restart)
    local Animation = GetAnimation(Name)

    if not Animation or not LocustModel then
        return nil
    end

    return PlayAnim(
        LocustModel,
        Animation,
        FadeIn,
        Speed,
        ForceLoop,
        Restart
    )
end

local function WaitForTrackToFinish(Track, Timeout)
    if not Track then
        return
    end

    local Elapsed = 0
    Timeout = Timeout or 15

    while Track.IsPlaying and Elapsed < Timeout do
        Elapsed += Services.RunService.Heartbeat:Wait()
    end

    if Track.IsPlaying then
        Track:Stop()
    end
end

--// VISUAL MODEL

local function HideOriginalCharacter()
    if not Character then
        return
    end

    for _, Object in ipairs(Character:GetDescendants()) do
        if Object:IsA("BasePart") then
            Object.LocalTransparencyModifier = 1
        elseif Object:IsA("Decal") or Object:IsA("Texture") then
            Object.Transparency = 1
        end
    end
end

-- Игра может сбрасывать прозрачность (например, при смене вида камеры или
-- добавлении новых частей), поэтому следим за этим постоянно.
local function BindCharacterHide()
    if CharacterHideConnection then
        CharacterHideConnection:Disconnect()
        CharacterHideConnection = nil
    end

    if not Character then
        return
    end

    CharacterHideConnection = Character.DescendantAdded:Connect(function(Object)
        task.defer(function()
            if Object:IsA("BasePart") then
                Object.LocalTransparencyModifier = 1
            elseif Object:IsA("Decal") or Object:IsA("Texture") then
                Object.Transparency = 1
            end
        end)
    end)
end

local function ApplyLocustModel()
    if not Objects or not Character or not RootPart then
        return
    end

    StopAllAnimations()

    AnimatorCache.Joints = {}
    AnimatorCache.AnimDefaults = {}
    AnimatorCache.Rigs = {}
    AnimatorCache.ActiveTweens = {}

    CurrentMovementAnimation = nil

    if LocustModel then
        LocustModel:Destroy()
        LocustModel = nil
        ModelRoot = nil
    end

    local StarterCharacter = Objects:FindFirstChild("StarterCharacter")

    if not StarterCharacter then
        warn("StarterCharacter not found!")
        return
    end

    LocustModel = StarterCharacter:Clone()
    LocustModel.Name = "LocustVisual"

    local ModelHumanoid = LocustModel:FindFirstChildOfClass("Humanoid")

    if ModelHumanoid then
        ModelHumanoid:Destroy()
    end

    for _, Object in ipairs(LocustModel:GetDescendants()) do
        if Object:IsA("BasePart") then
            Object.Anchored = true
            Object.CanCollide = false
            Object.CanTouch = false
            Object.CanQuery = false
            Object.Massless = true

            if Object:IsA("Part") and Object.Shape == Enum.PartType.Block then
                Object.Transparency = 1
            else
                Object.Transparency = 0
            end
        elseif Object:IsA("Bone") then
            AnimatorCache.Joints[Object.Name] = Object
            AnimatorCache.AnimDefaults[Object.Name] = Object.CFrame
        elseif Object:IsA("Script")
            or Object:IsA("LocalScript")
            or Object:IsA("ModuleScript") then
            Object:Destroy()
        end
    end

    ModelRoot = LocustModel:FindFirstChild("HumanoidRootPart", true)

    if not ModelRoot then
        ModelRoot = LocustModel:FindFirstChildWhichIsA("BasePart", true)
    end

    LocustModel.Parent = workspace

    if ModelRoot and ModelRoot:IsA("BasePart") then
        pcall(function()
            LocustModel.PrimaryPart = ModelRoot
        end)
    end

    pcall(function()
        LocustModel:PivotTo(RootPart.CFrame)
    end)

    HideOriginalCharacter()
    BindCharacterHide()
end

if HasModel then
    ApplyLocustModel()
end

--// MUSIC

local function CreateTheme()
    if Theme then
        Theme:Destroy()
        Theme = nil
    end

    if not HasMusic or not RootPart then
        return
    end

    Theme = Instance.new("Sound")
    Theme.Name = "LocustTheme"
    Theme.Volume = 1
    Theme.Looped = true
    Theme.Parent = RootPart

    if Services.RunService:IsStudio() then
        Theme.SoundId = "rbxasset://Locust.mp3"
    elseif typeof(getcustomasset) == "function" then
        Theme.SoundId = getcustomasset(Directories.Songs .. "LocustTheme.mp3")
    else
        Theme.SoundId = Directories.Songs .. "LocustTheme.mp3"
    end

    if ScriptOptions.Settings.Music then
        Theme:Play()
    end
end

CreateTheme()

local function PlayUISFX(Audio)
    local Sound = Instance.new("Sound")
    Sound.SoundId = "rbxassetid://" .. tostring(Audio)
    Sound.Volume = 1
    Sound.PlayOnRemove = true
    Sound.Parent = workspace
    Sound:Destroy()
end

local function PlaySFX(Audio)
    local Sound = Instance.new("Sound")
    Sound.SoundId = "rbxassetid://" .. tostring(Audio)
    Sound.Volume = 1
    Sound.PlayOnRemove = true
    Sound.Parent = RootPart or workspace
    Sound:Destroy()
end

--// OPTIONAL HIT EFFECTS

local function FlashHitHighlight(Target)
    if not Target or not Target:IsA("Model") then
        return
    end

    if Target:FindFirstChild("HitHighlight") then
        return
    end

    local Highlight = Instance.new("Highlight")
    Highlight.Name = "HitHighlight"
    Highlight.Adornee = Target
    Highlight.FillColor = Color3.fromRGB(255, 0, 0)
    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    Highlight.FillTransparency = 1
    Highlight.OutlineTransparency = 1
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Parent = Target

    local FlashIn = Services.TweenService:Create(
        Highlight,
        TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            FillTransparency = 0.15;
            OutlineTransparency = 0;
        }
    )

    local FadeOut = Services.TweenService:Create(
        Highlight,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {
            FillTransparency = 1;
            OutlineTransparency = 1;
        }
    )

    FlashIn:Play()

    FlashIn.Completed:Once(function()
        FadeOut:Play()
    end)

    FadeOut.Completed:Once(function()
        Highlight:Destroy()
    end)
end

local function NewHitbox(Position, Size)
    local Hitbox = Instance.new("Part")
    Hitbox.Name = "LocustHitbox"
    Hitbox.Size = Size or Vector3.new(4, 4, 4)
    Hitbox.Color = ScriptOptions.Customization.HitboxColor
    Hitbox.Material = Enum.Material.ForceField
    Hitbox.Transparency = 0.5
    Hitbox.Anchored = true
    Hitbox.CanCollide = false
    Hitbox.CanQuery = false
    Hitbox.CanTouch = false
    Hitbox.CFrame = Position or RootPart.CFrame
    Hitbox.Parent = workspace

    Services.TweenService:Create(
        Hitbox,
        TweenInfo.new(0.5),
        {Transparency = 1}
    ):Play()

    Services.Debris:AddItem(Hitbox, 0.5)

    return Hitbox
end

--// EPIC DEATH EFFECTS

local function CameraShake(Duration, Intensity)
    task.spawn(function()
        local Elapsed = 0

        while Elapsed < Duration do
            local DeltaTime = Services.RunService.RenderStepped:Wait()
            Elapsed += DeltaTime

            local Fade = 1 - (Elapsed / Duration)
            local Cam = workspace.CurrentCamera

            if Cam then
                Cam.CFrame = Cam.CFrame * CFrame.Angles(
                    RandomGenerator:NextNumber(-1, 1) * Intensity * Fade * 0.012,
                    RandomGenerator:NextNumber(-1, 1) * Intensity * Fade * 0.012,
                    RandomGenerator:NextNumber(-1, 1) * Intensity * Fade * 0.008
                )
            end
        end
    end)
end

local function ScreenFlash()
    pcall(function()
        local CC = Instance.new("ColorCorrectionEffect")
        CC.Name = "LocustDeathFlash"
        CC.TintColor = Color3.fromRGB(255, 70, 70)
        CC.Brightness = 0.25
        CC.Contrast = 0.35
        CC.Saturation = -0.3
        CC.Parent = Services.Lighting

        Services.TweenService:Create(
            CC,
            TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                TintColor = Color3.fromRGB(255, 255, 255);
                Brightness = 0;
                Contrast = 0;
                Saturation = 0;
            }
        ):Play()

        Services.Debris:AddItem(CC, 0.8)
    end)
end

local function CreateShockwave(Position, Parent)
    -- Расширяющиеся сферы
    for Index = 1, 3 do
        local Sphere = Instance.new("Part")
        Sphere.Name = "DeathShockwave"
        Sphere.Shape = Enum.PartType.Ball
        Sphere.Material = Enum.Material.Neon
        Sphere.Color = Index == 1
            and Color3.fromRGB(255, 255, 255)
            or Color3.fromRGB(150 - Index * 25, 0, 0)
        Sphere.Transparency = 0.2 + Index * 0.15
        Sphere.Size = Vector3.new(1, 1, 1)
        Sphere.Anchored = true
        Sphere.CanCollide = false
        Sphere.CanQuery = false
        Sphere.CanTouch = false
        Sphere.CFrame = CFrame.new(Position)
        Sphere.Parent = Parent

        local TargetSize = 14 + Index * 8
        local Duration = 0.4 + Index * 0.2

        Services.TweenService:Create(
            Sphere,
            TweenInfo.new(Duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {
                Size = Vector3.new(TargetSize, TargetSize, TargetSize);
                Transparency = 1;
            }
        ):Play()

        Services.Debris:AddItem(Sphere, Duration + 0.1)
    end

    -- Расширяющееся кольцо по земле
    local Ring = Instance.new("Part")
    Ring.Name = "DeathRing"
    Ring.Shape = Enum.PartType.Cylinder
    Ring.Material = Enum.Material.Neon
    Ring.Color = Color3.fromRGB(255, 30, 30)
    Ring.Transparency = 0.3
    Ring.Size = Vector3.new(0.3, 1, 1)
    Ring.Anchored = true
    Ring.CanCollide = false
    Ring.CanQuery = false
    Ring.CanTouch = false
    Ring.CFrame = CFrame.new(Position) * CFrame.Angles(0, 0, math.rad(90))
    Ring.Parent = Parent

    Services.TweenService:Create(
        Ring,
        TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {
            Size = Vector3.new(0.3, 32, 32);
            Transparency = 1;
        }
    ):Play()

    Services.Debris:AddItem(Ring, 0.8)
end

local function CreateDeathLight(Position, Parent)
    local Holder = Instance.new("Part")
    Holder.Name = "DeathLight"
    Holder.Transparency = 1
    Holder.Size = Vector3.new(0.1, 0.1, 0.1)
    Holder.Anchored = true
    Holder.CanCollide = false
    Holder.CanQuery = false
    Holder.CanTouch = false
    Holder.CFrame = CFrame.new(Position)
    Holder.Parent = Parent

    local Light = Instance.new("PointLight")
    Light.Color = Color3.fromRGB(255, 20, 20)
    Light.Brightness = 15
    Light.Range = 35
    Light.Parent = Holder

    Services.TweenService:Create(
        Light,
        TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Brightness = 0; Range = 5}
    ):Play()

    Services.Debris:AddItem(Holder, 1.1)
end

local function CreateBloodPool(Position, Parent, IgnoreModels)
    local Params = RaycastParams.new()
    local Filter = {Parent}

    for _, Ignored in ipairs(IgnoreModels or {}) do
        if Ignored then
            table.insert(Filter, Ignored)
        end
    end

    Params.FilterDescendantsInstances = Filter
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.IgnoreWater = true

    local Result = workspace:Raycast(Position, Vector3.new(0, -25, 0), Params)

    if not Result then
        return
    end

    local Pool = Instance.new("Part")
    Pool.Name = "BloodPool"
    Pool.Shape = Enum.PartType.Cylinder
    Pool.Material = Enum.Material.SmoothPlastic
    Pool.Color = Color3.fromRGB(90, 0, 0)
    Pool.Transparency = 0.1
    Pool.Size = Vector3.new(0.15, 1, 1)
    Pool.Anchored = true
    Pool.CanCollide = false
    Pool.CanQuery = false
    Pool.CanTouch = false
    Pool.CFrame =
        CFrame.new(Result.Position + Vector3.new(0, 0.07, 0))
        * CFrame.Angles(0, 0, math.rad(90))
    Pool.Parent = Parent

    Services.TweenService:Create(
        Pool,
        TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(0.15, 11, 11)}
    ):Play()

    task.delay(ScriptOptions.Blood.CorpseLifetime - 1.2, function()
        if Pool.Parent then
            Services.TweenService:Create(
                Pool,
                TweenInfo.new(1),
                {Transparency = 1}
            ):Play()
        end
    end)

    Services.Debris:AddItem(Pool, ScriptOptions.Blood.CorpseLifetime)
end

local function CreateBloodBurstParticles(Position, Parent)
    local Holder = Instance.new("Part")
    Holder.Name = "BloodBurst"
    Holder.Transparency = 1
    Holder.Size = Vector3.new(0.1, 0.1, 0.1)
    Holder.Anchored = true
    Holder.CanCollide = false
    Holder.CanQuery = false
    Holder.CanTouch = false
    Holder.CFrame = CFrame.new(Position)
    Holder.Parent = Parent

    local Attachment = Instance.new("Attachment")
    Attachment.Parent = Holder

    local Emitter = Instance.new("ParticleEmitter")
    Emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    Emitter.Color = ColorSequence.new(
        Color3.fromRGB(160, 0, 0),
        Color3.fromRGB(60, 0, 0)
    )
    Emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6);
        NumberSequenceKeypoint.new(0.4, 2.4);
        NumberSequenceKeypoint.new(1, 0);
    })
    Emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2);
        NumberSequenceKeypoint.new(1, 1);
    })
    Emitter.Lifetime = NumberRange.new(0.4, 1.1)
    Emitter.Speed = NumberRange.new(20, 55)
    Emitter.SpreadAngle = Vector2.new(180, 180)
    Emitter.RotSpeed = NumberRange.new(-200, 200)
    Emitter.Drag = 3
    Emitter.Enabled = false
    Emitter.Parent = Attachment

    Emitter:Emit(90)

    Services.Debris:AddItem(Holder, 2.5)
end

local function PlayDeathSounds(Position)
    local Holder = Instance.new("Part")
    Holder.Name = "DeathSoundHolder"
    Holder.Transparency = 1
    Holder.Size = Vector3.new(0.1, 0.1, 0.1)
    Holder.Anchored = true
    Holder.CanCollide = false
    Holder.CanQuery = false
    Holder.CanTouch = false
    Holder.CFrame = CFrame.new(Position)
    Holder.Parent = workspace

    for _, Id in ipairs(ScriptOptions.Customization.DeathExtraSounds) do
        pcall(function()
            local Sound = Instance.new("Sound")
            Sound.SoundId = "rbxassetid://" .. tostring(Id)
            Sound.Volume = 3
            Sound.PlaybackSpeed = RandomGenerator:NextNumber(0.85, 1.1)
            Sound.Parent = Holder
            Sound:Play()
        end)
    end

    Services.Debris:AddItem(Holder, 6)
end

local function CreateEpicDeathEffects(Position, EffectFolder, IgnoreModels)
    CameraShake(0.8, 3)
    ScreenFlash()
    CreateShockwave(Position, EffectFolder)
    CreateDeathLight(Position, EffectFolder)
    CreateBloodBurstParticles(Position, EffectFolder)
    CreateBloodPool(Position, EffectFolder, IgnoreModels)
    PlayDeathSounds(Position)
end

--// BLOOD SYSTEM

local function IsIgnoredBloodHit(Hit, EffectFolder, IgnoreModels)
    if not Hit then
        return true
    end

    if EffectFolder and Hit:IsDescendantOf(EffectFolder) then
        return true
    end

    for _, Ignored in ipairs(IgnoreModels or {}) do
        if Ignored and Hit:IsDescendantOf(Ignored) then
            return true
        end
    end

    return false
end

local function CreateBloodCube(
    Position,
    Size,
    Color,
    Velocity,
    AngularVelocity,
    EffectFolder,
    Lifetime,
    DestroyOnGround,
    IgnoreModels,
    IsBig
)
    if not EffectFolder or not EffectFolder.Parent then
        return nil
    end

    local Part = Instance.new("Part")
    Part.Name = IsBig and "OrganCube" or "BloodCube"
    Part.Size = Size
    Part.Shape = Enum.PartType.Block
    Part.Color = Color
    Part.Material = Enum.Material.SmoothPlastic
    Part.TopSurface = Enum.SurfaceType.Smooth
    Part.BottomSurface = Enum.SurfaceType.Smooth
    Part.Anchored = false
    Part.CanCollide = IsBig == true
    Part.CanQuery = false
    Part.CanTouch = true
    Part.CastShadow = true
    Part.CFrame =
        CFrame.new(Position)
        * CFrame.Angles(
            RandomGenerator:NextNumber(-math.pi, math.pi),
            RandomGenerator:NextNumber(-math.pi, math.pi),
            RandomGenerator:NextNumber(-math.pi, math.pi)
        )
    Part.Parent = EffectFolder

    Part.AssemblyLinearVelocity = Velocity
    Part.AssemblyAngularVelocity = AngularVelocity

    -- Трейлы на больших кусках для эпичности
    if IsBig then
        pcall(function()
            local A0 = Instance.new("Attachment")
            A0.Position = Vector3.new(0, Size.Y / 2, 0)
            A0.Parent = Part

            local A1 = Instance.new("Attachment")
            A1.Position = Vector3.new(0, -Size.Y / 2, 0)
            A1.Parent = Part

            local Trail = Instance.new("Trail")
            Trail.Attachment0 = A0
            Trail.Attachment1 = A1
            Trail.Color = ColorSequence.new(Color3.fromRGB(120, 0, 0))
            Trail.Transparency = NumberSequence.new(0.3, 1)
            Trail.Lifetime = 0.35
            Trail.WidthScale = NumberSequence.new(1, 0)
            Trail.Parent = Part
        end)
    end

    if DestroyOnGround then
        local TouchConnection

        TouchConnection = Part.Touched:Connect(function(Hit)
            if not Part.Parent then
                if TouchConnection then
                    TouchConnection:Disconnect()
                end

                return
            end

            if not Hit:IsA("BasePart") then
                return
            end

            if IsIgnoredBloodHit(Hit, EffectFolder, IgnoreModels) then
                return
            end

            if not Hit.CanCollide then
                return
            end

            -- Кровь исчезает только когда уже падает.
            if Part.AssemblyLinearVelocity.Y > 2 then
                return
            end

            if TouchConnection then
                TouchConnection:Disconnect()
                TouchConnection = nil
            end

            Part:Destroy()
        end)
    end

    if Lifetime and Lifetime > 0 then
        Services.Debris:AddItem(Part, Lifetime)
    end

    return Part
end

local function CreateSmallBloodCube(Position, EffectFolder, IgnoreModels)
    local SizeValue = RandomGenerator:NextNumber(0.16, 0.38)

    local Size = Vector3.new(
        SizeValue * RandomGenerator:NextNumber(0.75, 1.25),
        SizeValue * RandomGenerator:NextNumber(0.75, 1.25),
        SizeValue * RandomGenerator:NextNumber(0.75, 1.25)
    )

    local Color = Color3.fromRGB(
        RandomGenerator:NextInteger(115, 185),
        RandomGenerator:NextInteger(0, 8),
        RandomGenerator:NextInteger(0, 8)
    )

    local Velocity = Vector3.new(
        RandomGenerator:NextNumber(-42, 42),
        RandomGenerator:NextNumber(25, 62),
        RandomGenerator:NextNumber(-42, 42)
    )

    local AngularVelocity = Vector3.new(
        RandomGenerator:NextNumber(-22, 22),
        RandomGenerator:NextNumber(-22, 22),
        RandomGenerator:NextNumber(-22, 22)
    )

    return CreateBloodCube(
        Position + Vector3.new(
            RandomGenerator:NextNumber(-1.1, 1.1),
            RandomGenerator:NextNumber(-0.2, 2),
            RandomGenerator:NextNumber(-1.1, 1.1)
        ),
        Size,
        Color,
        Velocity,
        AngularVelocity,
        EffectFolder,
        ScriptOptions.Blood.CorpseLifetime + 0.5,
        true,
        IgnoreModels,
        false
    )
end

local function CreateBigBloodCube(Position, EffectFolder, IgnoreModels)
    local Size = Vector3.new(
        RandomGenerator:NextNumber(0.65, 1.2),
        RandomGenerator:NextNumber(0.65, 1.2),
        RandomGenerator:NextNumber(0.65, 1.2)
    )

    local Color = Color3.fromRGB(
        RandomGenerator:NextInteger(55, 105),
        RandomGenerator:NextInteger(0, 5),
        RandomGenerator:NextInteger(0, 5)
    )

    local Velocity = Vector3.new(
        RandomGenerator:NextNumber(-38, 38),
        RandomGenerator:NextNumber(35, 65),
        RandomGenerator:NextNumber(-38, 38)
    )

    local AngularVelocity = Vector3.new(
        RandomGenerator:NextNumber(-32, 32),
        RandomGenerator:NextNumber(-32, 32),
        RandomGenerator:NextNumber(-32, 32)
    )

    return CreateBloodCube(
        Position + Vector3.new(
            RandomGenerator:NextNumber(-0.7, 0.7),
            RandomGenerator:NextNumber(0, 1.8),
            RandomGenerator:NextNumber(-0.7, 0.7)
        ),
        Size,
        Color,
        Velocity,
        AngularVelocity,
        EffectFolder,
        ScriptOptions.Blood.BigCubeLifetime,
        false,
        IgnoreModels,
        true
    )
end

local function GetBloodSourcePosition(SourceModel, FallbackPosition)
    if SourceModel and SourceModel.Parent then
        local SourcePart =
            SourceModel:FindFirstChild("UpperTorso")
            or SourceModel:FindFirstChild("Torso")
            or SourceModel:FindFirstChild("HumanoidRootPart")
            or SourceModel:FindFirstChild("Head")

        if SourcePart and SourcePart:IsA("BasePart") then
            return SourcePart.Position
        end
    end

    return FallbackPosition
end

local function StartDeathBlood(
    DeathContainer,
    SourceModel,
    OriginalTarget,
    FallbackPosition
)
    if not DeathContainer or not DeathContainer.Parent then
        return nil
    end

    local EffectFolder = Instance.new("Folder")
    EffectFolder.Name = "LocustBloodEffects"
    EffectFolder.Parent = DeathContainer

    local IgnoreModels = {
        Character;
        LocustModel;
        SourceModel;
        OriginalTarget;
    }

    local InitialPosition = GetBloodSourcePosition(
        SourceModel,
        FallbackPosition
    )

    -- ЭПИЧНЫЕ ЭФФЕКТЫ СМЕРТИ
    CreateEpicDeathEffects(InitialPosition, EffectFolder, IgnoreModels)

    -- Крупные куски
    for _ = 1, ScriptOptions.Blood.BigCubeCount do
        CreateBigBloodCube(
            InitialPosition,
            EffectFolder,
            IgnoreModels
        )
    end

    -- Мощный начальный выброс маленькой крови
    for _ = 1, ScriptOptions.Blood.InitialSmallCount do
        CreateSmallBloodCube(
            InitialPosition,
            EffectFolder,
            IgnoreModels
        )
    end

    -- Кровь ВСЕГДА идёт полные EmissionDuration (6) секунд.
    task.spawn(function()
        local Elapsed = 0
        local Duration = ScriptOptions.Blood.EmissionDuration

        while Elapsed < Duration and EffectFolder.Parent do
            local Alpha = math.clamp(Elapsed / Duration, 0, 1)

            -- Минимум 3 кубика за волну даже в самом конце,
            -- чтобы кровь шла все 6 секунд без остановки.
            local CurrentCount = math.max(
                3,
                math.floor(
                    ScriptOptions.Blood.WaveStartCount
                    * ((1 - Alpha) ^ 1.2)
                )
            )

            local CurrentPosition = GetBloodSourcePosition(
                SourceModel,
                FallbackPosition
            )

            for _ = 1, CurrentCount do
                CreateSmallBloodCube(
                    CurrentPosition,
                    EffectFolder,
                    IgnoreModels
                )
            end

            local Interval = 0.08 + (Alpha * 0.1)
            Elapsed += task.wait(Interval)
        end
    end)

    return EffectFolder
end

--// CORPSE SYSTEM (РЭГДОЛЛ)

local function RagdollCorpse(Corpse)
    for _, Object in ipairs(Corpse:GetDescendants()) do
        if Object:IsA("Motor6D") then
            local Part0 = Object.Part0
            local Part1 = Object.Part1

            if Part0 and Part1 then
                local A0 = Instance.new("Attachment")
                A0.CFrame = Object.C0
                A0.Parent = Part0

                local A1 = Instance.new("Attachment")
                A1.CFrame = Object.C1
                A1.Parent = Part1

                local Socket = Instance.new("BallSocketConstraint")
                Socket.Attachment0 = A0
                Socket.Attachment1 = A1
                Socket.LimitsEnabled = true
                Socket.TwistLimitsEnabled = true
                Socket.MaxFrictionTorque = 10
                Socket.Parent = Part0
            end

            Object:Destroy()
        end
    end
end

local function CreateCorpseVisual(TargetModel)
    local DeathContainer = Instance.new("Folder")
    DeathContainer.Name = "LocustDeathContainer"
    DeathContainer.Parent = workspace

    local Corpse = nil
    local OldArchivable = TargetModel.Archivable

    TargetModel.Archivable = true

    local Success, Result = pcall(function()
        return TargetModel:Clone()
    end)

    TargetModel.Archivable = OldArchivable

    if Success and Result then
        Corpse = Result
        Corpse.Name = TargetModel.Name .. "_LocustCorpse"

        for _, Object in ipairs(Corpse:GetDescendants()) do
            if Object:IsA("Script")
                or Object:IsA("LocalScript")
                or Object:IsA("ModuleScript")
                or Object:IsA("Animator")
                or Object:IsA("BodyMover")
                or Object:IsA("ForceField") then

                Object:Destroy()

            elseif Object:IsA("BasePart") then
                -- Тело НЕ заморожено — падает и валяется как рэгдолл
                Object.Anchored = false
                Object.CanCollide = Object.Name ~= "HumanoidRootPart"
                Object.CanTouch = false
                Object.CanQuery = false
                Object.Massless = false
                Object.LocalTransparencyModifier = 0
                Object.AssemblyLinearVelocity = Vector3.zero
                Object.AssemblyAngularVelocity = Vector3.zero

                if Object.Name == "HumanoidRootPart" then
                    Object.Transparency = 1
                end

            elseif Object:IsA("Humanoid") then
                Object.AutoRotate = false
                Object.PlatformStand = true
                Object.RequiresNeck = false
                Object.BreakJointsOnDeath = false
                Object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                Object.EvaluateStateMachine = false

                pcall(function()
                    Object:ChangeState(Enum.HumanoidStateType.Physics)
                end)
            end
        end

        -- Превращаем труп в рэгдолл
        RagdollCorpse(Corpse)

        Corpse.Parent = DeathContainer

        pcall(function()
            Corpse:PivotTo(TargetModel:GetPivot())
        end)
    end

    return DeathContainer, Corpse
end

local function FadeOutContainer(Container, Duration)
    if not Container or not Container.Parent then
        return
    end

    for _, Object in ipairs(Container:GetDescendants()) do
        if Object:IsA("BasePart") and Object.Transparency < 1 then
            pcall(function()
                Services.TweenService:Create(
                    Object,
                    TweenInfo.new(Duration),
                    {Transparency = 1}
                ):Play()
            end)
        elseif Object:IsA("Decal") or Object:IsA("Texture") then
            pcall(function()
                Services.TweenService:Create(
                    Object,
                    TweenInfo.new(Duration),
                    {Transparency = 1}
                ):Play()
            end)
        end
    end
end

local function HideOriginalTarget(TargetModel)
    for _, Object in ipairs(TargetModel:GetDescendants()) do
        if Object:IsA("BasePart") then
            Object.LocalTransparencyModifier = 1
        elseif Object:IsA("Decal") or Object:IsA("Texture") then
            Object.Transparency = 1
        end
    end
end

--// MOVEMENT

local MovementAnimationNames = {
    "Idle";
    "Walk";
    "Sprint";
    "IdleCrouch";
    "WalkCrouch";
    "Sit";
}

local function SetWalkSpeed(Speed)
    if Humanoid and Humanoid.Parent then
        Humanoid.WalkSpeed = Speed
    end
end

local function SetRootAnchored(Anchored)
    if RootPart and RootPart.Parent then
        RootPart.Anchored = Anchored
    end
end

local function IsGrounded()
    if not RootPart or not Character then
        return false
    end

    if Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air then
        return true
    end

    local Params = RaycastParams.new()
    local Filter = {Character}

    if LocustModel then
        table.insert(Filter, LocustModel)
    end

    Params.FilterDescendantsInstances = Filter
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.IgnoreWater = true

    local Result = workspace:Raycast(
        RootPart.Position,
        Vector3.new(0, -4.5, 0),
        Params
    )

    return Result ~= nil
end

local function StopMovementAnimations()
    if not LocustModel then
        CurrentMovementAnimation = nil
        return
    end

    for _, Name in ipairs(MovementAnimationNames) do
        local Animation = GetAnimation(Name)

        if Animation then
            StopAnim(LocustModel, Animation)
        end
    end

    CurrentMovementAnimation = nil
end

local function ResolveMovementAnimation(Name)
    if GetAnimation(Name) then
        return Name
    end

    local Fallbacks = {
        IdleCrouch = "Idle";
        WalkCrouch = "Walk";
        Sprint = "Walk";
        Sit = "Idle";
    }

    local Fallback = Fallbacks[Name]

    if Fallback and GetAnimation(Fallback) then
        return Fallback
    end

    return Name
end

local function SetMovementAnimation(Name, Force)
    if not LocustModel or not Animations then
        return
    end

    if not Name then
        StopMovementAnimations()
        return
    end

    Name = ResolveMovementAnimation(Name)

    if CurrentMovementAnimation == Name and not Force then
        local RigTracks = AnimatorCache.Rigs[LocustModel]
        local Track = RigTracks and RigTracks[Name]

        if Track and Track.IsPlaying then
            return
        end
    end

    local Track = PlayNamedAnimation(
        Name,
        0.1,
        1,
        true,
        false
    )

    if Track then
        CurrentMovementAnimation = Name
    end
end

local function UpdateMovementAnimation(Force)
    if States.Input.Debounce then
        return
    end

    if not LocustModel or not Animations or not Humanoid or not RootPart then
        return
    end

    if States.Movement.Sitting then
        States.Movement.Idle = false
        States.Movement.Walking = false
        States.Movement.Running = false

        SetMovementAnimation("Sit", Force)
        return
    end

    if not IsGrounded() then
        return
    end

    local Velocity = RootPart.AssemblyLinearVelocity
    local HorizontalVelocity = Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude

    local Moving =
        Humanoid.MoveDirection.Magnitude > 0.05
        or HorizontalVelocity > 0.75

    if not Moving then
        States.Movement.Idle = true
        States.Movement.Walking = false
        States.Movement.Running = false

        if States.Movement.Crouching then
            SetMovementAnimation("IdleCrouch", Force)
        else
            SetMovementAnimation("Idle", Force)
        end

        return
    end

    States.Movement.Idle = false

    if States.Movement.Crouching then
        States.Movement.Walking = true
        States.Movement.Running = false
        SetMovementAnimation("WalkCrouch", Force)

    elseif States.Input.Shift then
        States.Movement.Walking = false
        States.Movement.Running = true
        SetMovementAnimation("Sprint", Force)

    else
        States.Movement.Walking = true
        States.Movement.Running = false
        SetMovementAnimation("Walk", Force)
    end
end

local function RestoreMovement()
    if not Humanoid or not RootPart then
        return
    end

    if States.Movement.Sitting then
        SetWalkSpeed(0)
    elseif States.Movement.Crouching then
        SetWalkSpeed(3)
    elseif States.Input.Shift then
        SetWalkSpeed(24)
    else
        SetWalkSpeed(6)
    end

    UpdateMovementAnimation(true)
end

local function ToggleCrouch()
    if States.Input.Debounce then
        return
    end

    States.Movement.Crouching = not States.Movement.Crouching
    States.Movement.Sitting = false
    States.Movement.Idle = false
    States.Movement.Walking = false
    States.Movement.Running = false

    RestoreMovement()
end

local function ToggleSit()
    if States.Input.Debounce then
        return
    end

    States.Movement.Sitting = not States.Movement.Sitting
    States.Movement.Crouching = false
    States.Movement.Idle = false
    States.Movement.Walking = false
    States.Movement.Running = false

    RestoreMovement()
end

--// WAYPOINT

local function SetWaypointObjectPosition(Object, Position)
    local TargetCFrame = CFrame.new(Position + Vector3.new(0, -2.975, 0))

    if Object:IsA("BasePart") then
        Object.CFrame = TargetCFrame
    elseif Object:IsA("Model") then
        Object:PivotTo(TargetCFrame)
    end
end

local function Waypoint()
    if not RootPart then
        return
    end

    if not States.Waypoint.SavedPosition then
        States.Waypoint.SavedPosition = RootPart.Position

        if States.Waypoint.TVLocation then
            States.Waypoint.TVLocation:Destroy()
            States.Waypoint.TVLocation = nil
        end

        if Objects then
            local TeleportTemplate = Objects:FindFirstChild("TeleportPart")

            if TeleportTemplate then
                local Part = TeleportTemplate:Clone()
                SetWaypointObjectPosition(Part, States.Waypoint.SavedPosition)
                Part.Parent = workspace
                States.Waypoint.TVLocation = Part
            end
        end

        return
    end

    if States.Input.Debounce then
        return
    end

    States.Input.Debounce = true
    SetRootAnchored(true)
    StopMovementAnimations()

    if States.Waypoint.TVLocation then
        States.Waypoint.TVLocation:Destroy()
        States.Waypoint.TVLocation = nil
    end

    local SpawnTrack = PlayNamedAnimation(
        "Spawn",
        0.1,
        1,
        false,
        true
    )

    RootPart.CFrame = CFrame.new(States.Waypoint.SavedPosition)
    States.Waypoint.SavedPosition = nil

    if SpawnTrack then
        local Timeout =
            (SpawnTrack.Length / GetEffectiveAnimationSpeed(SpawnTrack))
            + 2

        WaitForTrackToFinish(SpawnTrack, Timeout)
    end

    SetRootAnchored(false)
    States.Input.Debounce = false
    RestoreMovement()
end

--// KILL

local function GetTargetModel(Target)
    if not Target then
        return nil
    end

    local TargetModel = Target:FindFirstAncestorOfClass("Model")

    if not TargetModel then
        return nil
    end

    if TargetModel == Character or TargetModel == LocustModel then
        return nil
    end

    local TargetHumanoid = TargetModel:FindFirstChildOfClass("Humanoid")

    if not TargetHumanoid or TargetHumanoid.Health <= 0 then
        return nil
    end

    return TargetModel, TargetHumanoid
end

local function Kill(Target)
    if States.Input.Debounce or not States.Input.KillMode then
        return
    end

    local TargetModel, TargetHumanoid = GetTargetModel(Target)

    if not TargetModel or not TargetHumanoid then
        return
    end

    local TargetRoot =
        TargetModel:FindFirstChild("HumanoidRootPart")
        or TargetModel:FindFirstChild("UpperTorso")
        or TargetModel:FindFirstChild("Torso")

    if not TargetRoot or not TargetRoot:IsA("BasePart") then
        return
    end

    States.Input.Debounce = true
    SetRootAnchored(true)
    StopMovementAnimations()

    local OldWalkSpeed = TargetHumanoid.WalkSpeed
    local OldAutoRotate = TargetHumanoid.AutoRotate
    local DeathOccurred = false
    local DeathContainer = nil
    local KillTrack = nil

    local Success, ErrorMessage = xpcall(function()
        TargetHumanoid.WalkSpeed = 0
        TargetHumanoid.AutoRotate = false
        TargetRoot.Anchored = true

        local PullCFrame = RootPart.CFrame * CFrame.new(0, 0, -3)
        local Distance = (TargetRoot.Position - RootPart.Position).Magnitude

        if Distance > 5 then
            local PullTween = Services.TweenService:Create(
                TargetRoot,
                TweenInfo.new(
                    0.3,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                ),
                {CFrame = PullCFrame}
            )

            PullTween:Play()
            PullTween.Completed:Wait()
        else
            TargetRoot.CFrame = PullCFrame
        end

        local FlatLookPosition = Vector3.new(
            TargetRoot.Position.X,
            RootPart.Position.Y,
            TargetRoot.Position.Z
        )

        if (FlatLookPosition - RootPart.Position).Magnitude > 0.01 then
            RootPart.CFrame = CFrame.lookAt(
                RootPart.Position,
                FlatLookPosition
            )
        end

        KillTrack = PlayNamedAnimation(
            "Kill",
            0.1,
            1,
            false,
            true
        )

        -- Момент смертельного удара.
        local ImpactDelay = 0.35

        if KillTrack and KillTrack.Length > 0 then
            local AnimationDuration =
                KillTrack.Length / GetEffectiveAnimationSpeed(KillTrack)

            ImpactDelay = math.min(
                4,
                math.max(0.35, AnimationDuration * 0.9)
            )
        end

        task.wait(ImpactDelay)

        if not TargetModel.Parent or not TargetHumanoid.Parent then
            return
        end

        local DeathPosition = TargetRoot.Position
        local Corpse

        DeathContainer, Corpse = CreateCorpseVisual(TargetModel)

        if Corpse then
            HideOriginalTarget(TargetModel)

            -- Отбрасываем рэгдолл-труп от удара
            local CorpseRoot =
                Corpse:FindFirstChild("UpperTorso")
                or Corpse:FindFirstChild("Torso")
                or Corpse:FindFirstChild("HumanoidRootPart")
                or Corpse:FindFirstChildWhichIsA("BasePart")

            if CorpseRoot then
                local FlingDirection =
                    (RootPart.CFrame.LookVector + Vector3.new(0, 0.9, 0)).Unit

                CorpseRoot.AssemblyLinearVelocity =
                    FlingDirection * RandomGenerator:NextNumber(40, 55)

                CorpseRoot.AssemblyAngularVelocity = Vector3.new(
                    RandomGenerator:NextNumber(-18, 18),
                    RandomGenerator:NextNumber(-18, 18),
                    RandomGenerator:NextNumber(-18, 18)
                )
            end
        end

        TargetRoot.Anchored = false
        TargetHumanoid.WalkSpeed = 0
        TargetHumanoid.AutoRotate = false
        TargetHumanoid.BreakJointsOnDeath = false

        pcall(function()
            TargetHumanoid.Health = 0
        end)

        pcall(function()
            TargetModel:BreakJoints()
        end)

        FlashHitHighlight(Corpse or TargetModel)
        PlaySFX(ScriptOptions.Customization.Hitmarker)

        DeathOccurred = true

        StartDeathBlood(
            DeathContainer,
            Corpse or TargetModel,
            TargetModel,
            DeathPosition
        )

        -- Тело валяется, плавно растворяется и исчезает через 7 секунд.
        task.delay(ScriptOptions.Blood.CorpseLifetime - 1, function()
            FadeOutContainer(DeathContainer, 1)
        end)

        task.delay(ScriptOptions.Blood.CorpseLifetime, function()
            if TargetModel and TargetModel.Parent then
                pcall(function()
                    TargetModel:Destroy()
                end)
            end

            if DeathContainer and DeathContainer.Parent then
                DeathContainer:Destroy()
            end
        end)

        if KillTrack then
            local Timeout =
                (KillTrack.Length / GetEffectiveAnimationSpeed(KillTrack))
                + 2

            WaitForTrackToFinish(KillTrack, Timeout)
        end
    end, function(Message)
        return debug.traceback(tostring(Message))
    end)

    if not Success then
        warn("Kill ability error:", ErrorMessage)
    end

    if not DeathOccurred then
        if TargetHumanoid and TargetHumanoid.Parent then
            TargetHumanoid.WalkSpeed = OldWalkSpeed
            TargetHumanoid.AutoRotate = OldAutoRotate
        end

        if TargetRoot and TargetRoot.Parent then
            TargetRoot.Anchored = false
        end

        if DeathContainer and DeathContainer.Parent then
            DeathContainer:Destroy()
        end
    end

    SetRootAnchored(false)
    States.Input.Debounce = false
    RestoreMovement()
end

--// INPUT

local KeyDown = Services.UserInputService.InputBegan:Connect(function(Input, GPE)
    if GPE then
        return
    end

    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        task.spawn(Kill, Mouse.Target)

    elseif Input.KeyCode == Enum.KeyCode.Q then
        ToggleCrouch()

    elseif Input.KeyCode == Enum.KeyCode.C then
        ToggleSit()

    elseif Input.KeyCode == Enum.KeyCode.E then
        Waypoint()
    end
end)

table.insert(ScriptCache.ActiveConnections, KeyDown)

local InfiniteJumpConnection =
    Services.UserInputService.JumpRequest:Connect(function()
        if ScriptOptions.Settings.InfiniteJump
            and Humanoid
            and Humanoid.Parent then

            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

table.insert(ScriptCache.ActiveConnections, InfiniteJumpConnection)

--// UI

local function StoreConnection(Connection)
    if Connection then
        table.insert(ScriptCache.ActiveConnections, Connection)
    end

    return Connection
end

if LoadedAssets then
    local UIs = LoadedAssets:FindFirstChild("UIs")

    if UIs then
        local MobileUI = UIs:FindFirstChild("MobileUI")

        if MobileUI then
            MobileUI.Parent = Services.CoreGui
            table.insert(ScriptCache.TrashBin, MobileUI)

            local function UpdateMobileUI()
                MobileUI.Enabled =
                    Services.UserInputService:GetLastInputType()
                    == Enum.UserInputType.Touch
            end

            UpdateMobileUI()

            StoreConnection(
                Services.UserInputService.LastInputTypeChanged:Connect(
                    UpdateMobileUI
                )
            )

            local AbilitiesUI = MobileUI:FindFirstChild("AbilitiesUI")

            if AbilitiesUI then
                local WaypointButton = AbilitiesUI:FindFirstChild("Waypoint")
                local SitButton = AbilitiesUI:FindFirstChild("Sit")
                local CrouchButton = AbilitiesUI:FindFirstChild("Crouch")
                local SprintButton = AbilitiesUI:FindFirstChild("Sprint")

                if WaypointButton and WaypointButton:IsA("GuiButton") then
                    StoreConnection(WaypointButton.Activated:Connect(Waypoint))
                end

                if SitButton and SitButton:IsA("GuiButton") then
                    StoreConnection(SitButton.Activated:Connect(ToggleSit))
                end

                if CrouchButton and CrouchButton:IsA("GuiButton") then
                    StoreConnection(CrouchButton.Activated:Connect(ToggleCrouch))
                end

                if SprintButton and SprintButton:IsA("GuiButton") then
                    StoreConnection(SprintButton.Activated:Connect(function()
                        States.Input.MobileSprint = not States.Input.MobileSprint
                    end))
                end
            end
        end

        local MainGUI = UIs:FindFirstChild("MainGUI")

        if MainGUI then
            MainGUI.Parent = Services.CoreGui
            table.insert(ScriptCache.TrashBin, MainGUI)

            local SettingsFrame = MainGUI:FindFirstChild("SettingsFrame")
            Vignette = MainGUI:FindFirstChild("Vignette")
            local FloatingButton = MainGUI:FindFirstChild("FloatingButton")

            local SettingsHolder =
                SettingsFrame
                and SettingsFrame:FindFirstChild("SettingsHolder")

            if FloatingButton then
                pcall(function()
                    local DragDetector = Instance.new("UIDragDetector")
                    DragDetector.Parent = FloatingButton
                end)

                if FloatingButton:IsA("GuiButton") and SettingsFrame then
                    StoreConnection(FloatingButton.Activated:Connect(function()
                        SettingsFrame.Visible = not SettingsFrame.Visible
                        PlayUISFX(18755588842)
                    end))
                end

                StoreConnection(FloatingButton.MouseEnter:Connect(function()
                    PlayUISFX(122453173810540)
                end))
            end

            if SettingsHolder then
                local function SetupToggle(Setting)
                    if type(ScriptOptions.Settings[Setting]) ~= "boolean" then
                        return
                    end

                    local Object = SettingsHolder:FindFirstChild(Setting)

                    if not Object then
                        return
                    end

                    local Button =
                        Object:FindFirstChild("Button")
                        or Object:FindFirstChildWhichIsA("TextButton")
                        or Object:FindFirstChildWhichIsA("ImageButton")

                    if not Button or not Button:IsA("GuiButton") then
                        return
                    end

                    local function UpdateColor()
                        Button.BackgroundColor3 =
                            ScriptOptions.Settings[Setting]
                            and Color3.fromRGB(0, 255, 0)
                            or Color3.fromRGB(255, 0, 0)
                    end

                    UpdateColor()

                    StoreConnection(Button.Activated:Connect(function()
                        PlayUISFX(18755588842)

                        ScriptOptions.Settings[Setting] =
                            not ScriptOptions.Settings[Setting]

                        UpdateColor()
                    end))
                end

                for Setting, Value in pairs(ScriptOptions.Settings) do
                    if type(Value) == "boolean" then
                        SetupToggle(Setting)
                    end
                end

                local TPSetting =
                    SettingsHolder:FindFirstChild("TPToNearestSpawn")

                local TPButton =
                    TPSetting
                    and (
                        TPSetting:FindFirstChild("Button")
                        or TPSetting:FindFirstChildWhichIsA("GuiButton")
                    )

                if TPButton and TPButton:IsA("GuiButton") then
                    StoreConnection(TPButton.Activated:Connect(function()
                        if not RootPart then
                            return
                        end

                        local ClosestSpawn = nil
                        local ClosestDistance = math.huge

                        for _, Object in ipairs(workspace:GetDescendants()) do
                            if Object:IsA("SpawnLocation") then
                                local Distance =
                                    (RootPart.Position - Object.Position).Magnitude

                                if Distance < ClosestDistance then
                                    ClosestSpawn = Object
                                    ClosestDistance = Distance
                                end
                            end
                        end

                        if ClosestSpawn then
                            RootPart.CFrame =
                                ClosestSpawn.CFrame
                                + Vector3.new(0, 5, 0)
                        else
                            warn("No spawn found.")
                        end
                    end))
                end
            end
        end
    end
end

--// MAIN LOOP

local HideAccumulator = 0

local RunServiceConnection =
    Services.RunService.Heartbeat:Connect(function(DeltaTime)
        if not Character
            or not Character.Parent
            or not Humanoid
            or not RootPart
            or not RootPart.Parent then

            return
        end

        Camera = workspace.CurrentCamera or Camera

        -- ФИКС ШИФТА: опрашиваем клавишу напрямую каждый кадр,
        -- события InputBegan/InputEnded игра могла "съедать".
        local KeyboardShift =
            Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or Services.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

        States.Input.Shift = KeyboardShift or States.Input.MobileSprint

        -- ФИКС НЕВИДИМОСТИ: игра сбрасывает LocalTransparencyModifier,
        -- поэтому прячем оригинального персонажа каждые 0.2 сек.
        HideAccumulator += DeltaTime

        if HideAccumulator >= 0.2 then
            HideAccumulator = 0
            HideOriginalCharacter()
        end

        if LocustModel
            and LocustModel.Parent
            and ModelRoot
            and RootPart then

            pcall(function()
                LocustModel:PivotTo(RootPart.CFrame)
            end)
        end

        if ScriptOptions.Settings.CameraEffects then
            local TargetOffset =
                States.Movement.Crouching
                and Vector3.new(0, 5, 0)
                or Vector3.new(0, 10, 0)

            Humanoid.CameraOffset =
                Humanoid.CameraOffset:Lerp(TargetOffset, 0.1)
        else
            Humanoid.CameraOffset =
                Humanoid.CameraOffset:Lerp(Vector3.zero, 0.1)
        end

        if not States.Input.Debounce then
            if States.Movement.Sitting then
                SetWalkSpeed(0)
            elseif States.Movement.Crouching then
                SetWalkSpeed(3)
            elseif States.Input.Shift then
                SetWalkSpeed(24)
            else
                SetWalkSpeed(6)
            end

            UpdateMovementAnimation(false)
        end

        if Camera then
            if ScriptOptions.Settings.FOVEffects and Theme then
                Camera.FieldOfView =
                    80 + math.clamp(Theme.PlaybackLoudness / 100, 0, 20)

                if Vignette then
                    Vignette.ImageTransparency =
                        math.clamp(
                            1 - Theme.PlaybackLoudness / 900,
                            0,
                            1
                        )
                end
            else
                Camera.FieldOfView = 70

                if Vignette then
                    Vignette.ImageTransparency = 1
                end
            end
        end

        if Theme then
            if ScriptOptions.Settings.Music then
                if not Theme.IsPlaying then
                    Theme:Resume()
                end
            elseif Theme.IsPlaying then
                Theme:Pause()
            end
        end
    end)

table.insert(ScriptCache.ActiveConnections, RunServiceConnection)

--// RESPAWN

local CharacterAddedConnection = Player.CharacterAdded:Connect(function(NewCharacter)
    StopAllAnimations()

    if LocustModel then
        LocustModel:Destroy()
        LocustModel = nil
        ModelRoot = nil
    end

    if Theme then
        Theme:Destroy()
        Theme = nil
    end

    Character = NewCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Camera = workspace.CurrentCamera

    States.Input.Debounce = false
    States.Input.Shift = false
    States.Input.MobileSprint = false

    States.Movement.Idle = false
    States.Movement.Walking = false
    States.Movement.Running = false
    States.Movement.Crouching = false
    States.Movement.Sitting = false

    CurrentMovementAnimation = nil

    task.wait(0.5)

    if HasModel then
        ApplyLocustModel()
    else
        BindCharacterHide()
    end

    CreateTheme()
    RestoreMovement()
end)

table.insert(ScriptCache.ActiveConnections, CharacterAddedConnection)

RestoreMovement()
SendNotification("Loaded! LMB: Kill | Q: Crouch | C: Sit | E: Waypoint | Shift: Sprint")
