-- af_hub GUI ENGINE - ULTIMATE V5.0
-- Rayfield互換 / 完全日本語 / 一人称視点対応
-- V4.6 BUGFIX CHANGELOG (最終版):
--   [FIX] Dropdown/MultiDropdown/ColorPicker 合体バグ完全修正:
--         旧: OC/CPanel を F の子に置いていた → TC.ClipsDescendants=true で他要素に合体して見えた
--         新: OC/CPanel を CA 直下に配置、開くときに F.AbsolutePosition で座標を計算して配置
--             ZIndex=200 で全要素より前面に表示
--   [FIX] TCスクロール中にポップアップを自動クローズ (CanvasPosition変化を監視)
--   [FIX] F 破棄時に OC/CPanel を明示的に Destroy (CA の子なので自動削除されないため)
--   [FIX] MkHsvSlider の RenderStepped / InputEnded 接続を F 破棄時に切断 (メモリリーク)
--   [FIX] CreateDropdown / CreateMultiDropdown: DBボタンがSize 1,0で展開時にOCを覆いクリックをブロックするバグ修正 (→固定44px)
--   [FIX] MakeDraggable: UserInputService.InputChangedが切断されないメモリリーク修正
--   [FIX] CreateWindow: トグルキーInputBegan接続がSG破棄後も残るメモリリーク修正
--   [FIX] CreatePlayerList: PlayerAdded/PlayerRemoving接続がF破棄後も残るメモリリーク修正
-- V4.1 BUGFIX CHANGELOG:
--   [FIX] CreateDropdown / CreateMultiDropdown: OCがF外側に配置されUIバグを起こす問題を修正 (UDim2 1,3 → 0,44 + ClipsDescendants)
--   [FIX] CreateColorPicker: CPanelがF外側に配置されUIバグを起こす問題を修正 (同上)
--   [FIX] CreateColorPicker: Elem:Set() で内部curValが同期されないバグを修正 (SetH/S/V追加)
--   [FIX] CreateSlider: UserInputService接続がF破棄後も残るメモリリークを修正 (Destroying切断)
--   [FIX] CreateTab: アクティブタブのアクセントバーが常に非表示になるバグを修正 (Transparency 1→0)

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local Stats            = game:GetService("Stats")
local TextService      = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

-- ================================================================
--  ユーティリティ
-- ================================================================
local function CC(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function CS(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(45, 45, 50)
    s.Thickness = th or 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function TW(obj, props, dur, style, dir)
    local t = TweenService:Create(obj,
        TweenInfo.new(dur or 0.3, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props)
    t:Play()
    return t
end

local function GetTime()
    local t = tick()
    return string.format("%02d:%02d:%02d",
        math.floor(t / 3600) % 24, math.floor(t / 60) % 60, math.floor(t) % 60)
end

local function MkLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.SourceSans
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextSize = 16
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k, v in pairs(props) do pcall(function() l[k] = v end) end
    l.Parent = parent
    return l
end

local function TypeWrite(label, text, speed)
    speed = speed or 0.028
    label.Text = ""
    for i = 1, #text do
        if not label.Parent then break end
        label.Text = text:sub(1, i)
        task.wait(speed)
    end
end

-- ================================================================
--  折りたたみヘルパー（PlayerList / LogViewer / GameInfo 共通）
-- ================================================================
local function MakeCollapsible(F, fullH, headerH)
    headerH = headerH or 48
    local collapsed = false

    local Btn = Instance.new("TextButton")
    Btn.Size           = UDim2.new(0, 28, 0, 28)
    Btn.Position       = UDim2.new(1, -36, 0, (headerH - 28) / 2)
    Btn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    Btn.BorderSizePixel  = 0
    Btn.Text           = "▲"
    Btn.TextColor3     = Color3.fromRGB(95, 115, 155)
    Btn.TextSize       = 14
    Btn.Font           = Enum.Font.GothamBold
    Btn.AutoButtonColor = false
    Btn.ZIndex         = 20
    Btn.Parent         = F
    CC(Btn, 6)
    CS(Btn, Color3.fromRGB(42, 42, 58), 1)

    Btn.MouseEnter:Connect(function()
        TW(Btn, {BackgroundColor3 = Color3.fromRGB(32, 32, 48)}, 0.1)
    end)
    Btn.MouseLeave:Connect(function()
        TW(Btn, {BackgroundColor3 = Color3.fromRGB(22, 22, 32)}, 0.1)
    end)

    F.ClipsDescendants = true

    Btn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        if collapsed then
            TW(F, {Size = UDim2.new(1, 0, 0, headerH)},
               0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Btn.Text = "▼"
        else
            TW(F, {Size = UDim2.new(1, 0, 0, fullH)},
               0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            Btn.Text = "▲"
        end
    end)

    return Btn
end

-- ================================================================
--  マウス管理
-- ================================================================
local MouseManager = {}
function MouseManager.ShowCursor()  UserInputService.MouseIconEnabled = true  end
function MouseManager.HideCursor()  UserInputService.MouseIconEnabled = false end
function MouseManager.StartOverride() end
function MouseManager.StopOverride()  end
function MouseManager.BindFrame(_)    end

-- ================================================================
--  エンジン本体
-- ================================================================
local MyEngine = {
    Flags = {}, KillList = {}, Blacklist = {}, Logs = {},
    ToggleKey = Enum.KeyCode.K,
    _ScreenGuis = {},
}

local LogListeners = {}
local function AddLog(msg, t)
    table.insert(MyEngine.Logs, {Message = msg, Type = t or "Info", Time = GetTime()})
    if #MyEngine.Logs > 100 then table.remove(MyEngine.Logs, 1) end
    for _, cb in pairs(LogListeners) do pcall(cb) end
end

-- ================================================================
--  粒子システム V1 — フローティングドット＋接続ライン
-- ================================================================
local function StartParticles(parentSG)
    local PARTICLE_COUNT = 30
    local CONNECT_DIST   = 155   -- px以内のドットを線で繋ぐ
    local BASE_SPEED     = 38    -- px/秒 (基準速度)
    local DOT_COLOR      = Color3.fromRGB(55, 165, 255)
    local LINE_COLOR     = Color3.fromRGB(35, 115, 220)
    local MAX_LINES      = 200

    local PBG = Instance.new("Frame")
    PBG.Name = "ParticleBG"
    PBG.Size = UDim2.new(1, 0, 1, 0)
    PBG.BackgroundTransparency = 1
    PBG.BorderSizePixel = 0
    PBG.ZIndex = 1
    PBG.ClipsDescendants = true
    PBG.Parent = parentSG

    -- ライン用フレームプール
    local linePool = {}
    for i = 1, MAX_LINES do
        local ln = Instance.new("Frame")
        ln.BackgroundColor3 = LINE_COLOR
        ln.BackgroundTransparency = 1
        ln.BorderSizePixel = 0
        ln.AnchorPoint = Vector2.new(0, 0.5)
        ln.ZIndex = 1
        ln.Visible = false
        ln.Parent = PBG
        linePool[i] = ln
    end

    -- ドット生成
    local particles = {}
    for i = 1, PARTICLE_COUNT do
        local sz = math.random(2, 5)
        local dot = Instance.new("Frame")
        dot.Size = UDim2.fromOffset(sz, sz)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.BackgroundColor3 = DOT_COLOR
        dot.BackgroundTransparency = 0.15 + math.random() * 0.45
        dot.BorderSizePixel = 0
        dot.ZIndex = 2
        dot.Parent = PBG
        CC(dot, 100)

        local ang = math.random() * math.pi * 2
        local spd = BASE_SPEED * (0.4 + math.random() * 1.2)
        particles[i] = {
            frame = dot,
            x = math.random(20, 800),
            y = math.random(20, 500),
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd,
        }
    end

    local pConn = RunService.RenderStepped:Connect(function(dt)
        if not PBG.Parent then return end
        local W = PBG.AbsoluteSize.X
        local H = PBG.AbsoluteSize.Y
        if W < 10 or H < 10 then return end

        -- ドット位置を更新（跳ね返り）
        for _, p in ipairs(particles) do
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            if p.x < 0 then
                p.x = 0; p.vx = math.abs(p.vx) + math.random() * 3
            elseif p.x > W then
                p.x = W; p.vx = -(math.abs(p.vx) + math.random() * 3)
            end
            if p.y < 0 then
                p.y = 0; p.vy = math.abs(p.vy) + math.random() * 3
            elseif p.y > H then
                p.y = H; p.vy = -(math.abs(p.vy) + math.random() * 3)
            end
            p.frame.Position = UDim2.fromOffset(p.x, p.y)
        end

        -- 接続ライン描画
        local lineIdx = 0
        for i = 1, #particles - 1 do
            for j = i + 1, #particles do
                if lineIdx >= MAX_LINES then break end
                local p1 = particles[i]; local p2 = particles[j]
                local dx = p2.x - p1.x; local dy = p2.y - p1.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < CONNECT_DIST then
                    lineIdx = lineIdx + 1
                    local ln = linePool[lineIdx]
                    local alpha = (1 - dist / CONNECT_DIST) * 0.55
                    ln.Position = UDim2.fromOffset(p1.x, p1.y)
                    ln.Size     = UDim2.fromOffset(dist, 1)
                    ln.Rotation = math.deg(math.atan2(dy, dx))
                    ln.BackgroundTransparency = 1 - alpha
                    ln.Visible = true
                end
            end
            if lineIdx >= MAX_LINES then break end
        end
        -- 未使用ラインを非表示
        for i = lineIdx + 1, MAX_LINES do
            if linePool[i].Visible then linePool[i].Visible = false end
        end
    end)

    PBG.Destroying:Connect(function() pConn:Disconnect() end)
    return PBG
end

-- ================================================================
--  起動アニメーション V5 — 線からウィンドウへ展開
-- ================================================================
local function PlayBoot(sg, onDone)
    -- 薄い暗幕（完全に黒くしない）
    local Boot = Instance.new("Frame")
    Boot.Size = UDim2.new(1, 0, 1, 0)
    Boot.BackgroundColor3 = Color3.fromRGB(4, 4, 8)
    Boot.BackgroundTransparency = 0.05
    Boot.BorderSizePixel = 0
    Boot.ZIndex = 200
    Boot.Parent = sg

    -- 粒子を起動画面でも流す
    local bootParticles = StartParticles(Boot)
    bootParticles.ZIndex = 201

    -- 中央の「線」フレーム（これがウィンドウに化ける）
    local Line = Instance.new("Frame")
    Line.Size = UDim2.fromOffset(0, 2)
    Line.AnchorPoint = Vector2.new(0.5, 0.5)
    Line.Position = UDim2.new(0.5, 0, 0.5, 0)
    Line.BackgroundColor3 = Color3.fromRGB(50, 155, 255)
    Line.BorderSizePixel = 0
    Line.ZIndex = 220
    Line.Parent = Boot
    CC(Line, 100)

    -- ロゴ（線の上に出現）
    local Logo = MkLabel(Boot, {
        Size = UDim2.fromOffset(340, 54),
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0.5, -14),
        Text = "af_hub",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 42,
        Font = Enum.Font.GothamBold,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 222,
    })
    local Sub = MkLabel(Boot, {
        Size = UDim2.fromOffset(340, 20),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 14),
        Text = "ULTIMATE V4.6  //  " .. LocalPlayer.Name,
        TextColor3 = Color3.fromRGB(50, 155, 255),
        TextSize = 12,
        Font = Enum.Font.GothamSemibold,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 222,
    })

    task.spawn(function()
        -- 1) 線が横に伸びる
        task.wait(0.12)
        TW(Line, {Size = UDim2.fromOffset(320, 2)}, 0.38, Enum.EasingStyle.Quint)
        task.wait(0.22)

        -- 2) ロゴ・サブが浮き上がりながらフェードイン
        TW(Logo, {TextTransparency = 0,
            Position = UDim2.new(0.5, 0, 0.5, -18)}, 0.4, Enum.EasingStyle.Quint)
        TW(Sub,  {TextTransparency = 0}, 0.4, Enum.EasingStyle.Quint)
        task.wait(0.72)

        -- 3) 線が820pxの横幅（ウィンドウ幅）まで広がり色が変わる
        TW(Line, {
            Size = UDim2.fromOffset(820, 2),
            BackgroundColor3 = Color3.fromRGB(20, 20, 26),
        }, 0.42, Enum.EasingStyle.Quint)
        -- ロゴも同時にフェードアウト
        TW(Logo, {TextTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, -30)}, 0.35, Enum.EasingStyle.Quint)
        TW(Sub, {TextTransparency = 1}, 0.3, Enum.EasingStyle.Quint)
        task.wait(0.44)

        -- 4) 縦に展開してウィンドウの形に
        TW(Line, {
            Size = UDim2.fromOffset(820, 520),
            BackgroundColor3 = Color3.fromRGB(14, 14, 16),
        }, 0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        task.wait(0.28)

        -- 5) フラッシュして消える
        local Flash = Instance.new("Frame")
        Flash.Size = UDim2.new(1, 0, 1, 0)
        Flash.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
        Flash.BackgroundTransparency = 1
        Flash.BorderSizePixel = 0; Flash.ZIndex = 350; Flash.Parent = Boot
        TW(Flash, {BackgroundTransparency = 0.65}, 0.07); task.wait(0.07)
        TW(Flash, {BackgroundTransparency = 1}, 0.22); task.wait(0.12)

        TW(Boot, {BackgroundTransparency = 1}, 0.28, Enum.EasingStyle.Quint)
        task.wait(0.30)
        Boot:Destroy()
        if onDone then onDone() end
    end)
end

-- ================================================================
--  スクロール転送ヘルパー
--  TextButton はマウスホイールイベントを横取りして親ScrollingFrameに届かない。
--  オーバーレイボタン全てにこれを適用して親へ転送する。
-- ================================================================
local SCROLL_SPEED = 40
local function ForwardScroll(btn, scrollTarget)
    if not btn or not scrollTarget then return end
    btn.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseWheel then
            local maxY = math.max(0, scrollTarget.AbsoluteCanvasSize.Y - scrollTarget.AbsoluteSize.Y)
            scrollTarget.CanvasPosition = Vector2.new(
                scrollTarget.CanvasPosition.X,
                math.clamp(scrollTarget.CanvasPosition.Y - inp.Position.Z * SCROLL_SPEED, 0, maxY)
            )
        end
    end)
end

-- ================================================================
--  ドラッグ
-- ================================================================
local function MakeDraggable(handle, target)
    local drag, di, ds, sp = false, nil, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = inp.Position; sp = target.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then di = inp end
    end)
    -- [FIX] グローバル接続を保持し、handle破棄時に切断してメモリリークを防止
    local _dragConn = UserInputService.InputChanged:Connect(function(inp)
        if inp == di and drag then
            local d = inp.Position - ds
            target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    handle.Destroying:Connect(function() _dragConn:Disconnect() end)
end

-- ================================================================
--  CreateWindow
-- ================================================================
function MyEngine:CreateWindow(Config)
    local WinName = Config.Name or "af_hub"
    if Config.ToggleKey then MyEngine.ToggleKey = Config.ToggleKey end

    local SG = Instance.new("ScreenGui")
    SG.Name = "afHub_" .. HttpService:GenerateGUID()
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.DisplayOrder = 100
    SG.ResetOnSpawn = false
    pcall(function() SG.IgnoreGuiInset = true end)
    SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
    table.insert(MyEngine._ScreenGuis, SG)

    PlayBoot(SG, function()
        AddLog("GUI起動完了", "Success")
        MouseManager.ShowCursor()
    end)

    local Main = Instance.new("Frame")
    Main.Name = "Main"; Main.Size = UDim2.new(0, 820, 0, 520)
    Main.AnchorPoint = Vector2.new(0.5, 0.5); Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.BackgroundColor3 = Color3.fromRGB(14, 14, 16); Main.BorderSizePixel = 0
    Main.BackgroundTransparency = 1; Main.ZIndex = 3; Main.ClipsDescendants = true; Main.Parent = SG
    CC(Main, 12); CS(Main, Color3.fromRGB(38, 38, 48), 2)
    local Grad = Instance.new("UIGradient")
    Grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 16)),
    }
    Grad.Rotation = 140; Grad.Parent = Main

    -- ウィンドウ内にも粒子レイヤーを追加
    local _mainParticles = StartParticles(Main)
    _mainParticles.ZIndex = 0

    -- Boot終了後、線からウィンドウへ展開するアニメーション
    task.delay(2.55, function()
        Main.Size = UDim2.fromOffset(820, 2)
        Main.BackgroundTransparency = 0
        TW(Main, {Size = UDim2.fromOffset(820, 520)},
            0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
    MouseManager.BindFrame(Main)

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 210, 1, 0); Sidebar.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    Sidebar.BorderSizePixel = 0; Sidebar.Parent = Main; CC(Sidebar, 12)
    local SideDiv = Instance.new("Frame")
    SideDiv.Size = UDim2.new(0, 1, 1, 0); SideDiv.Position = UDim2.new(1, 0, 0, 0)
    SideDiv.BackgroundColor3 = Color3.fromRGB(30, 30, 38); SideDiv.BorderSizePixel = 0; SideDiv.Parent = Sidebar

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 54); TitleBar.BackgroundTransparency = 1; TitleBar.Parent = Main
    MakeDraggable(TitleBar, Main)
    MkLabel(TitleBar, {
        Size = UDim2.new(1, -115, 1, 0), Position = UDim2.new(0, 15, 0, 0),
        Text = WinName, TextSize = 20, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 2,
    })

    local function CtrlBtn(txt, bg, xoff)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 30, 0, 30); b.Position = UDim2.new(1, xoff, 0.5, -15)
        b.BackgroundColor3 = bg; b.BorderSizePixel = 0
        b.Text = txt; b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 15; b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false; b.Parent = TitleBar; CC(b, 6); return b
    end
    local CloseBtn = CtrlBtn("✕", Color3.fromRGB(170, 48, 48), -10)
    local MinBtn   = CtrlBtn("—", Color3.fromRGB(26, 26, 32), -46)
    CloseBtn.MouseEnter:Connect(function() TW(CloseBtn, {BackgroundColor3 = Color3.fromRGB(205, 58, 58)}, 0.1) end)
    CloseBtn.MouseLeave:Connect(function() TW(CloseBtn, {BackgroundColor3 = Color3.fromRGB(170, 48, 48)}, 0.1) end)
    MinBtn.MouseEnter:Connect(function()   TW(MinBtn, {BackgroundColor3 = Color3.fromRGB(42, 42, 52)}, 0.1) end)
    MinBtn.MouseLeave:Connect(function()   TW(MinBtn, {BackgroundColor3 = Color3.fromRGB(26, 26, 32)}, 0.1) end)

    local Mini = Instance.new("TextButton")
    Mini.Size = UDim2.new(0, 50, 0, 50); Mini.AnchorPoint = Vector2.new(0, 1)
    Mini.Position = UDim2.new(0, 20, 1, -20); Mini.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
    Mini.BorderSizePixel = 0; Mini.Text = "◈"; Mini.TextColor3 = Color3.fromRGB(50, 150, 255)
    Mini.TextSize = 22; Mini.Font = Enum.Font.GothamBold
    Mini.AutoButtonColor = false; Mini.Visible = false; Mini.ZIndex = 50; Mini.Parent = SG
    CC(Mini, 10); CS(Mini, Color3.fromRGB(50, 150, 255), 2)
    MakeDraggable(Mini, Mini); MouseManager.BindFrame(Mini)

    local TabScroll = Instance.new("ScrollingFrame")
    TabScroll.Size = UDim2.new(1, -10, 1, -190); TabScroll.Position = UDim2.new(0, 5, 0, 58)
    TabScroll.BackgroundTransparency = 1; TabScroll.BorderSizePixel = 0
    TabScroll.ScrollBarThickness = 2; TabScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
    TabScroll.Parent = Sidebar
    local TL = Instance.new("UIListLayout")
    TL.Padding = UDim.new(0, 5); TL.SortOrder = Enum.SortOrder.LayoutOrder; TL.Parent = TabScroll
    TL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabScroll.CanvasSize = UDim2.new(0, 0, 0, TL.AbsoluteContentSize.Y + 8)
    end)

    local AccSec = Instance.new("Frame")
    AccSec.Size = UDim2.new(1, -10, 0, 80); AccSec.Position = UDim2.new(0, 5, 1, -85)
    AccSec.BackgroundColor3 = Color3.fromRGB(15, 15, 18); AccSec.BorderSizePixel = 0; AccSec.Parent = Sidebar
    CC(AccSec, 8); CS(AccSec, Color3.fromRGB(36, 36, 44), 1)
    local AccIco = Instance.new("ImageLabel")
    AccIco.Size = UDim2.new(0, 50, 0, 50); AccIco.Position = UDim2.new(0, 10, 0.5, -25)
    AccIco.BackgroundTransparency = 1
    AccIco.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
    AccIco.Parent = AccSec; CC(AccIco, 100)
    MkLabel(AccSec, {
        Size = UDim2.new(1, -72, 0, 26), Position = UDim2.new(0, 66, 0.15, 0),
        Text = LocalPlayer.DisplayName, TextSize = 16, Font = Enum.Font.SourceSansBold,
    })
    MkLabel(AccSec, {
        Size = UDim2.new(1, -72, 0, 18), Position = UDim2.new(0, 66, 0.60, 0),
        Text = "@" .. LocalPlayer.Name, TextSize = 14, Font = Enum.Font.SourceSans,
        TextColor3 = Color3.fromRGB(65, 125, 195),
    })
    local ODot = Instance.new("Frame")
    ODot.Size = UDim2.new(0, 8, 0, 8); ODot.Position = UDim2.new(0, 56, 1, -16)
    ODot.BackgroundColor3 = Color3.fromRGB(50, 225, 100); ODot.BorderSizePixel = 0; ODot.Parent = AccSec; CC(ODot, 100)

    local CA = Instance.new("Frame")
    CA.Size = UDim2.new(1, -220, 1, -64); CA.Position = UDim2.new(0, 215, 0, 54)
    CA.BackgroundTransparency = 1; CA.Parent = Main

    local isOpen = true; local isMin = false; local busy = false

    local function Open(v)
        if busy then return end; isOpen = v
        if v then
            busy = true; Main.Visible = true
            MouseManager.ShowCursor()
            -- 線から広がる開くアニメーション
            Main.Size = UDim2.fromOffset(820, 2)
            Main.BackgroundTransparency = 0
            TW(Main, {Size = UDim2.fromOffset(820, 520)},
                0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            task.delay(0.42, function() busy = false end)
        else
            busy = true
            -- 閉じるときは線に縮まってから即非表示
            local t = TW(Main, {Size = UDim2.fromOffset(820, 2)},
                0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            t.Completed:Connect(function()
                Main.Visible = false
                Main.Size = UDim2.fromOffset(820, 520)
                MouseManager.StopOverride(); MouseManager.HideCursor(); busy = false
            end)
        end
    end

    local function Minimize(v)
        if busy then return end; isMin = v; busy = true
        if v then
            -- 線に縮まってからミニアイコンへ
            local t = TW(Main, {Size = UDim2.fromOffset(820, 2)},
                0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            t.Completed:Connect(function()
                Main.Visible = false; Main.Size = UDim2.fromOffset(820, 520)
                Mini.Visible = true; Mini.BackgroundTransparency = 1; Mini.Size = UDim2.fromOffset(38, 38)
                TW(Mini, {BackgroundTransparency = 0, Size = UDim2.fromOffset(50, 50)},
                    0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                MouseManager.HideCursor()
                busy = false
            end)
        else
            local t = TW(Mini, {BackgroundTransparency = 1, Size = UDim2.fromOffset(38, 38)},
                0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            t.Completed:Connect(function()
                Mini.Visible = false; Mini.Size = UDim2.fromOffset(50, 50)
                Main.Visible = true
                -- 線から広がって復元
                Main.Size = UDim2.fromOffset(820, 2)
                Main.BackgroundTransparency = 0
                MouseManager.ShowCursor()
                TW(Main, {Size = UDim2.fromOffset(820, 520)},
                    0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                task.delay(0.42, function() busy = false end)
            end)
        end
    end

    -- [FIX] トグルキー接続を保持し、ウィンドウ破棄時に切断
    local _toggleConn = UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode == MyEngine.ToggleKey then
            if busy then return end
            if isMin then Minimize(false) else Open(not isOpen) end
        end
    end)
    SG.Destroying:Connect(function() _toggleConn:Disconnect() end)

    MinBtn.MouseButton1Click:Connect(function() Minimize(true) end)
    CloseBtn.MouseButton1Click:Connect(function() Open(false) end)
    Mini.MouseButton1Click:Connect(function() Minimize(false) end)

    -- ================================================================
    --  Window オブジェクト
    -- ================================================================
    local Window = {_Main = Main, _Sidebar = Sidebar, _TabScroll = TabScroll, _CA = CA, _Tabs = {}, _SG = SG}

    local TAB_ACTIVE_BG   = Color3.fromRGB(255, 255, 255)
    local TAB_ACTIVE_TEXT = Color3.fromRGB(16, 16, 20)
    local TAB_IDLE_BG     = Color3.fromRGB(17, 17, 20)
    local TAB_IDLE_TEXT   = Color3.fromRGB(155, 155, 170)

    -- ================================================================
    --  Window:Destroy
    -- ================================================================
    function Window:Destroy()
        pcall(function() SG:Destroy() end)
    end

    -- ================================================================
    --  Window:Dialog - モーダルダイアログ
    -- ================================================================
    function Window:Dialog(Data)
        -- Data: {Title, Content, Buttons={{Title, Color, Callback}, ...}}
        local Overlay = Instance.new("Frame")
        Overlay.Size = UDim2.new(1, 0, 1, 0)
        Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Overlay.BackgroundTransparency = 0.42
        Overlay.BorderSizePixel = 0
        Overlay.ZIndex = 500
        Overlay.Parent = Main

        local buttons = Data.Buttons or {{Title = "OK"}}
        local contentLines = 0
        if Data.Content then
            -- Estimate wrapped height
            local w = 332 -- inner width approx
            pcall(function()
                contentLines = math.ceil(TextService:GetTextSize(
                    Data.Content, 15, Enum.Font.SourceSans, Vector2.new(w, 9999)).Y)
            end)
        end
        local dlgH = 52 + 14 + math.max(contentLines, 18) + 14 + 46

        local DF = Instance.new("Frame")
        DF.Size = UDim2.new(0, 400, 0, dlgH)
        DF.AnchorPoint = Vector2.new(0.5, 0.5)
        DF.Position = UDim2.new(0.5, 0, 0.5, 0)
        DF.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        DF.BorderSizePixel = 0
        DF.ZIndex = 501
        DF.Parent = Overlay
        CC(DF, 10)
        CS(DF, Color3.fromRGB(58, 68, 110), 1.5)

        -- Top accent bar
        local TopBar = Instance.new("Frame")
        TopBar.Size = UDim2.new(1, 0, 0, 3)
        TopBar.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
        TopBar.BorderSizePixel = 0; TopBar.ZIndex = 502; TopBar.Parent = DF
        CC(TopBar, 10)

        -- Title
        MkLabel(DF, {
            Size = UDim2.new(1, -24, 0, 38),
            Position = UDim2.new(0, 14, 0, 8),
            Text = Data.Title or "確認",
            TextSize = 19,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(240, 243, 255),
            ZIndex = 502,
        })

        -- Separator
        local Sep2 = Instance.new("Frame")
        Sep2.Size = UDim2.new(1, -24, 0, 1)
        Sep2.Position = UDim2.new(0, 12, 0, 48)
        Sep2.BackgroundColor3 = Color3.fromRGB(38, 38, 58)
        Sep2.BorderSizePixel = 0; Sep2.ZIndex = 502; Sep2.Parent = DF

        -- Content
        if Data.Content then
            local CL = MkLabel(DF, {
                Size = UDim2.new(1, -28, 0, math.max(contentLines, 18)),
                Position = UDim2.new(0, 14, 0, 58),
                Text = Data.Content,
                TextSize = 15,
                Font = Enum.Font.SourceSans,
                TextColor3 = Color3.fromRGB(175, 182, 205),
                TextWrapped = true,
                ZIndex = 502,
            })
            CL.TextXAlignment = Enum.TextXAlignment.Left
        end

        -- Buttons
        local btnCount = #buttons
        local btnAreaW = 400 - 28
        local btnW = math.floor((btnAreaW - (btnCount - 1) * 10) / btnCount)

        local function CloseDialog()
            TW(DF, {BackgroundTransparency = 1}, 0.18, Enum.EasingStyle.Quint)
            TW(Overlay, {BackgroundTransparency = 1}, 0.18, Enum.EasingStyle.Quint)
            task.delay(0.22, function() pcall(function() Overlay:Destroy() end) end)
        end

        for i, btn in ipairs(buttons) do
            local isPrimary = (i == 1)
            local btnBG = btn.Color or (isPrimary and Color3.fromRGB(42, 105, 225) or Color3.fromRGB(26, 26, 38))
            local BF = Instance.new("TextButton")
            BF.Size = UDim2.new(0, btnW, 0, 36)
            BF.Position = UDim2.new(0, 14 + (i - 1) * (btnW + 10), 1, -48)
            BF.BackgroundColor3 = btnBG
            BF.BorderSizePixel = 0
            BF.Text = btn.Title or "OK"
            BF.TextColor3 = Color3.fromRGB(230, 235, 255)
            BF.TextSize = 15; BF.Font = Enum.Font.GothamSemibold
            BF.AutoButtonColor = false; BF.ZIndex = 502; BF.Parent = DF
            CC(BF, 7)
            if not isPrimary then CS(BF, Color3.fromRGB(44, 44, 64), 1) end
            BF.MouseEnter:Connect(function()
                TW(BF, {BackgroundColor3 = isPrimary
                    and Color3.fromRGB(58, 125, 255)
                    or  Color3.fromRGB(36, 36, 52)}, 0.1)
            end)
            BF.MouseLeave:Connect(function()
                TW(BF, {BackgroundColor3 = btnBG}, 0.1)
            end)
            BF.MouseButton1Click:Connect(function()
                TW(BF, {BackgroundColor3 = isPrimary
                    and Color3.fromRGB(35, 85, 185)
                    or  Color3.fromRGB(22, 22, 32)}, 0.08)
                CloseDialog()
                if btn.Callback then task.defer(btn.Callback) end
            end)
        end

        -- Animate in
        DF.BackgroundTransparency = 1
        DF.Size = UDim2.new(0, 370, 0, dlgH - 20)
        TW(DF, {Size = UDim2.new(0, 400, 0, dlgH), BackgroundTransparency = 0},
            0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end

    -- ================================================================
    --  CreateTab
    -- ================================================================
    function Window:CreateTab(TabName, TabIcon)
        local TBtn = Instance.new("TextButton")
        TBtn.Size = UDim2.new(1, -8, 0, 44)
        TBtn.BackgroundColor3 = TAB_IDLE_BG
        TBtn.BorderSizePixel = 0
        TBtn.Text = (TabIcon and (TabIcon .. "  ") or "  ") .. TabName
        TBtn.TextColor3 = TAB_IDLE_TEXT
        TBtn.TextSize = 17
        TBtn.Font = Enum.Font.GothamSemibold
        TBtn.TextXAlignment = Enum.TextXAlignment.Left
        TBtn.AutoButtonColor = false; TBtn.Parent = TabScroll
        CC(TBtn, 7)

        local Acc = Instance.new("Frame")
        Acc.Size = UDim2.new(0, 3, 0.55, 0); Acc.Position = UDim2.new(0, 0, 0.225, 0)
        Acc.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        Acc.BorderSizePixel = 0; Acc.BackgroundTransparency = 1; Acc.Parent = TBtn; CC(Acc, 100)

        local TC = Instance.new("ScrollingFrame")
        TC.Name = TabName .. "_C"; TC.Size = UDim2.new(1, 0, 1, 0)
        TC.BackgroundTransparency = 1; TC.BorderSizePixel = 0
        TC.ScrollBarThickness = 3; TC.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
        -- [FIX] Y軸のみスクロール（デフォルトXYが干渉するため）
        TC.ScrollingDirection = Enum.ScrollingDirection.Y
        TC.Visible = false; TC.Parent = CA
        local CL = Instance.new("UIListLayout")
        CL.Padding = UDim.new(0, 8); CL.SortOrder = Enum.SortOrder.LayoutOrder; CL.Parent = TC
        local CP = Instance.new("UIPadding")
        -- [FIX] PaddingLeft と PaddingBottom が欠落していたため要素が切れていた
        CP.PaddingTop = UDim.new(0, 8); CP.PaddingBottom = UDim.new(0, 12)
        CP.PaddingLeft = UDim.new(0, 8); CP.PaddingRight = UDim.new(0, 10); CP.Parent = TC
        CL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TC.CanvasSize = UDim2.new(0, 0, 0, CL.AbsoluteContentSize.Y + 18)
        end)

        local Tab = {B = TBtn, A = Acc, C = TC, Elements = {}}

        local function ActivateTab()
            for _, t in pairs(Window._Tabs) do
                TW(t.B, {BackgroundColor3 = TAB_IDLE_BG, TextColor3 = TAB_IDLE_TEXT}, 0.14)
                t.A.BackgroundTransparency = 1; t.C.Visible = false
            end
            TW(TBtn, {BackgroundColor3 = TAB_ACTIVE_BG, TextColor3 = TAB_ACTIVE_TEXT}, 0.14)
            Acc.BackgroundTransparency = 0 -- [FIX] アクティブタブのアクセントバーを表示
            TC.Visible = true
        end

        TBtn.MouseButton1Click:Connect(ActivateTab)

        if #Window._Tabs == 0 then
            TBtn.BackgroundColor3 = TAB_ACTIVE_BG
            TBtn.TextColor3 = TAB_ACTIVE_TEXT
            Acc.BackgroundTransparency = 0; TC.Visible = true -- [FIX] 最初のタブのアクセントバーを表示
        end

        table.insert(Window._Tabs, Tab)

        -- プログラムからタブを選択する
        function Tab:Select()
            ActivateTab()
        end

        -- ================================================================
        --  要素ビルダー（コンテナを引数に取り、全要素を生成して返す）
        -- ================================================================
        local function buildCreators(container, scrollTarget)
            -- scrollTarget: マウスホイールを転送する親ScrollingFrame
            -- containerがScrollingFrameならそれ自体、Frameならその上位のTCを使う
            scrollTarget = scrollTarget or (container:IsA("ScrollingFrame") and container or TC)
            local Creators = {}

            -- ── セクション ────────────────────────────────────────
            -- [FIX] 戻り値を返すように修正、:Set() でテキスト更新可能
            function Creators:CreateSection(n)
                local f = Instance.new("Frame")
                f.Size = UDim2.new(1, 0, 0, 26); f.BackgroundTransparency = 1; f.Parent = container
                local lbl = MkLabel(f, {
                    Size = UDim2.new(0.65, 0, 1, 0), Position = UDim2.new(0, 6, 0, 0),
                    Text = n, TextColor3 = Color3.fromRGB(85, 125, 175), TextSize = 14,
                    Font = Enum.Font.GothamSemibold,
                })
                local ln = Instance.new("Frame")
                ln.Size = UDim2.new(1, -8, 0, 1); ln.Position = UDim2.new(0, 4, 1, -1)
                ln.BackgroundColor3 = Color3.fromRGB(28, 28, 36); ln.BorderSizePixel = 0; ln.Parent = f
                local Elem = {}
                function Elem:Set(text) lbl.Text = text or "" end
                function Elem:Get() return lbl.Text end
                return Elem
            end

            -- ── ラベル ────────────────────────────────────────────
            -- [FIX] :Set()/:Get() が機能しないバグを修正、テキスト折り返しで高さ自動調整
            function Creators:CreateLabel(text, color)
                local f = Instance.new("Frame")
                f.Size = UDim2.new(1, 0, 0, 28); f.BackgroundTransparency = 1; f.Parent = container
                local lbl = MkLabel(f, {
                    Size = UDim2.new(1, -18, 1, 0),
                    Position = UDim2.new(0, 12, 0, 0),
                    Text = text or "",
                    TextSize = 14,
                    Font = Enum.Font.SourceSans,
                    TextColor3 = color or Color3.fromRGB(145, 150, 168),
                    TextWrapped = true,
                })

                local function AutoResize()
                    local w = math.max(lbl.AbsoluteSize.X > 0 and lbl.AbsoluteSize.X or 400, 80)
                    local h
                    pcall(function()
                        h = TextService:GetTextSize(lbl.Text, 14, Enum.Font.SourceSans, Vector2.new(w, 9999)).Y
                    end)
                    h = h or 18
                    f.Size = UDim2.new(1, 0, 0, math.max(28, h + 8))
                    lbl.Size = UDim2.new(1, -18, 0, math.max(20, h + 4))
                end
                lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(AutoResize)
                task.defer(AutoResize)

                local Elem = {}
                function Elem:Set(t, col)
                    lbl.Text = t or ""
                    if col then lbl.TextColor3 = col end
                    task.defer(AutoResize)
                end
                function Elem:Get()
                    return lbl.Text
                end
                return Elem
            end

            -- ── 区切り線 (NEW) ────────────────────────────────────
            function Creators:CreateDivider(opts)
                opts = opts or {}
                local thickness = opts.Thickness or 1
                local color = opts.Color or Color3.fromRGB(28, 28, 36)
                local f = Instance.new("Frame")
                f.Size = UDim2.new(1, 0, 0, thickness + 8)
                f.BackgroundTransparency = 1
                f.Parent = container
                local ln = Instance.new("Frame")
                ln.Size = UDim2.new(1, -16, 0, thickness)
                ln.Position = UDim2.new(0, 8, 0.5, 0)
                ln.BackgroundColor3 = color
                ln.BorderSizePixel = 0
                ln.Parent = f
                CC(ln, 100)
            end

            -- ── パラグラフ ────────────────────────────────────────
            -- [FIX] 戻り値を返すように修正、:Set() でコンテンツ更新可能
            function Creators:CreateParagraph(Data)
                local f = Instance.new("Frame")
                f.Size = UDim2.new(1, 0, 0, 60); f.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                f.BorderSizePixel = 0; f.Parent = container; CC(f, 7); CS(f, Color3.fromRGB(34, 34, 42), 1)
                local titleLbl = MkLabel(f, {
                    Size = UDim2.new(1, -18, 0, 22), Position = UDim2.new(0, 12, 0, 6),
                    Text = Data.Title or "", TextSize = 15, Font = Enum.Font.GothamSemibold,
                    TextColor3 = Color3.fromRGB(200, 210, 230),
                })
                local body = MkLabel(f, {
                    Size = UDim2.new(1, -18, 0, 30), Position = UDim2.new(0, 12, 0, 30),
                    Text = Data.Content or "", TextSize = 14, Font = Enum.Font.SourceSans,
                    TextColor3 = Color3.fromRGB(140, 148, 168), TextWrapped = true,
                })
                local function resize()
                    local h
                    pcall(function()
                        h = TextService:GetTextSize(body.Text, 14, Enum.Font.SourceSans,
                            Vector2.new(math.max(body.AbsoluteSize.X, 80), 9999)).Y
                    end)
                    h = h or 30
                    body.Size = UDim2.new(1, -18, 0, h + 4)
                    f.Size = UDim2.new(1, 0, 0, h + 44)
                end
                body:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
                task.defer(resize)

                local Elem = {}
                function Elem:Set(title, content)
                    if title  ~= nil then titleLbl.Text = title  end
                    if content ~= nil then body.Text = content; task.defer(resize) end
                end
                function Elem:Get()
                    return {Title = titleLbl.Text, Content = body.Text}
                end
                return Elem
            end

            -- ── ボタン ────────────────────────────────────────────
            -- [FIX] 戻り値を返すように修正
            function Creators:CreateButton(Data)
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 44); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)
                local B = Instance.new("TextButton")
                B.Size = UDim2.new(1, 0, 1, 0); B.BackgroundTransparency = 1
                B.Text = Data.Name or "ボタン"; B.TextColor3 = Color3.fromRGB(235, 235, 245)
                B.TextSize = 17; B.Font = Enum.Font.SourceSansSemibold; B.Parent = F
                B.MouseButton1Click:Connect(function()
                    TW(F, {BackgroundColor3 = Color3.fromRGB(30, 30, 38)}, 0.08)
                    task.delay(0.08, function() TW(F, {BackgroundColor3 = Color3.fromRGB(20, 20, 24)}, 0.12) end)
                    if Data.Callback then pcall(Data.Callback) end
                    AddLog("実行: " .. (Data.Name or "?"), "Action")
                end)
                B.MouseEnter:Connect(function() TW(F, {BackgroundColor3 = Color3.fromRGB(26, 26, 32)}, 0.08) end)
                B.MouseLeave:Connect(function() TW(F, {BackgroundColor3 = Color3.fromRGB(20, 20, 24)}, 0.08) end)
                -- [FIX] ホイールイベントを親ScrollingFrameへ転送
                ForwardScroll(B, scrollTarget)
                local Elem = {}
                function Elem:SetName(name)
                    B.Text = name or ""
                    Data.Name = name
                end
                function Elem:SetCallback(cb)
                    Data.Callback = cb
                end
                return Elem
            end

            -- ── トグル ────────────────────────────────────────────
            function Creators:CreateToggle(Data)
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 44); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)
                MkLabel(F, {
                    Size = UDim2.new(1, -72, 1, 0), Position = UDim2.new(0, 14, 0, 0),
                    Text = Data.Name or "トグル", TextSize = 17, Font = Enum.Font.SourceSans,
                })
                local Trk = Instance.new("Frame")
                Trk.Size = UDim2.new(0, 48, 0, 24); Trk.Position = UDim2.new(1, -58, 0.5, -12)
                Trk.BackgroundColor3 = Color3.fromRGB(36, 36, 44); Trk.BorderSizePixel = 0
                Trk.Parent = F; CC(Trk, 100)
                local Cir = Instance.new("Frame")
                Cir.Size = UDim2.new(0, 20, 0, 20); Cir.Position = UDim2.new(0, 2, 0.5, -10)
                Cir.BackgroundColor3 = Color3.fromRGB(185, 185, 200); Cir.BorderSizePixel = 0
                Cir.Parent = Trk; CC(Cir, 100)
                local HitBtn = Instance.new("TextButton")
                HitBtn.Size = UDim2.new(1, 0, 1, 0); HitBtn.Position = UDim2.new(0, 0, 0, 0)
                HitBtn.BackgroundTransparency = 1; HitBtn.Text = ""
                HitBtn.AutoButtonColor = false; HitBtn.ZIndex = 5; HitBtn.Parent = F
                local val = Data.CurrentValue or false
                local function ApplyVisual(v, animate)
                    if v then
                        if animate then
                            TW(Trk, {BackgroundColor3 = Color3.fromRGB(42, 138, 242)}, 0.18)
                            TW(Cir, {Position = UDim2.new(1, -22, 0.5, -10)}, 0.18)
                        else
                            Trk.BackgroundColor3 = Color3.fromRGB(42, 138, 242)
                            Cir.Position = UDim2.new(1, -22, 0.5, -10)
                        end
                    else
                        if animate then
                            TW(Trk, {BackgroundColor3 = Color3.fromRGB(36, 36, 44)}, 0.18)
                            TW(Cir, {Position = UDim2.new(0, 2, 0.5, -10)}, 0.18)
                        else
                            Trk.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
                            Cir.Position = UDim2.new(0, 2, 0.5, -10)
                        end
                    end
                end
                ApplyVisual(val, false)
                HitBtn.MouseEnter:Connect(function() TW(F, {BackgroundColor3 = Color3.fromRGB(26, 26, 32)}, 0.08) end)
                HitBtn.MouseLeave:Connect(function() TW(F, {BackgroundColor3 = Color3.fromRGB(20, 20, 24)}, 0.08) end)
                -- [FIX] ホイールイベントを親ScrollingFrameへ転送
                ForwardScroll(HitBtn, scrollTarget)
                HitBtn.MouseButton1Click:Connect(function()
                    val = not val; ApplyVisual(val, true)
                    if Data.Callback then pcall(Data.Callback, val) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = val
                    AddLog("トグル: " .. (Data.Name or "?") .. " = " .. tostring(val), "Action")
                end)
                local Elem = {}
                function Elem:Set(v)
                    val = v; ApplyVisual(val, true)
                    if Data.Callback then pcall(Data.Callback, val) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = val
                end
                function Elem:Get() return val end
                return Elem
            end

            -- ── スライダー ────────────────────────────────────────
            function Creators:CreateSlider(Data)
                local Min = Data.Range[1]; local Max = Data.Range[2]
                local Inc = Data.Increment or 1
                local cur = math.clamp(Data.CurrentValue or Min, Min, Max)
                local dr = false
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 54); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)
                MkLabel(F, {
                    Size = UDim2.new(1, -90, 0, 30), Position = UDim2.new(0, 14, 0, 0),
                    Text = Data.Name or "スライダー", TextSize = 17, Font = Enum.Font.SourceSans,
                    TextColor3 = Color3.fromRGB(220, 225, 240),
                })
                local VL = MkLabel(F, {
                    Size = UDim2.new(0, 72, 0, 30), Position = UDim2.new(1, -80, 0, 0),
                    Text = "", TextColor3 = Color3.fromRGB(50, 138, 220), TextSize = 15,
                    Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Right,
                })
                local TrkBG = Instance.new("Frame")
                TrkBG.Size = UDim2.new(1, -28, 0, 8); TrkBG.Position = UDim2.new(0, 14, 1, -18)
                TrkBG.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                TrkBG.BorderSizePixel = 0; TrkBG.ZIndex = 2; TrkBG.Parent = F; CC(TrkBG, 100)
                CS(TrkBG, Color3.fromRGB(40, 40, 52), 1)
                local Fil = Instance.new("Frame")
                Fil.Size = UDim2.new(0, 0, 1, 0); Fil.BackgroundColor3 = Color3.fromRGB(50, 138, 220)
                Fil.BorderSizePixel = 0; Fil.ZIndex = 3; Fil.Parent = TrkBG; CC(Fil, 100)
                local FilStroke = Instance.new("UIStroke")
                FilStroke.Color = Color3.fromRGB(58, 163, 255); FilStroke.Thickness = 1.2
                FilStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; FilStroke.Parent = Fil
                local Hit = Instance.new("TextButton")
                Hit.Size = UDim2.new(1, 0, 1, 0); Hit.BackgroundTransparency = 1
                Hit.Text = ""; Hit.AutoButtonColor = false; Hit.ZIndex = 10; Hit.Parent = F
                local function MouseRatio()
                    local ax = TrkBG.AbsolutePosition.X; local aw = TrkBG.AbsoluteSize.X
                    if aw <= 0 then return 0 end
                    return math.clamp((UserInputService:GetMouseLocation().X - ax) / aw, 0, 1)
                end
                local function Upd(v)
                    v = math.clamp(math.floor(v / Inc + 0.5) * Inc, Min, Max); cur = v
                    local ratio = (Max == Min) and 0 or (v - Min) / (Max - Min)
                    Fil.Size = UDim2.new(ratio, 0, 1, 0)
                    VL.Text = tostring(v) .. (Data.Suffix or "")
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = v
                end
                Upd(cur)
                Hit.InputBegan:Connect(function(i)
                    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    dr = true; Upd(Min + (Max - Min) * MouseRatio())
                    TW(Fil, {BackgroundColor3 = Color3.fromRGB(65, 155, 255)}, 0.1)
                    TW(FilStroke, {Color = Color3.fromRGB(90, 185, 255)}, 0.1)
                end)
                -- [FIX] コネクションを保持し、F破棄時に切断してメモリリークを防止
                local _changedConn = UserInputService.InputChanged:Connect(function(i)
                    if dr and i.UserInputType == Enum.UserInputType.MouseMovement then
                        Upd(Min + (Max - Min) * MouseRatio())
                    end
                end)
                local _endedConn = UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 and dr then
                        dr = false
                        TW(Fil, {BackgroundColor3 = Color3.fromRGB(50, 138, 220)}, 0.15)
                        TW(FilStroke, {Color = Color3.fromRGB(58, 163, 255)}, 0.15)
                        if Data.Callback then pcall(Data.Callback, cur) end
                        AddLog((Data.Name or "スライダー") .. " = " .. tostring(cur), "Action")
                    end
                end)
                F.Destroying:Connect(function()
                    _changedConn:Disconnect(); _endedConn:Disconnect()
                end)
                Hit.MouseEnter:Connect(function() TW(F, {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}, 0.1) end)
                Hit.MouseLeave:Connect(function()
                    if not dr then TW(F, {BackgroundColor3 = Color3.fromRGB(20, 20, 24)}, 0.1) end
                end)
                -- [FIX] ホイールイベントを親ScrollingFrameへ転送
                ForwardScroll(Hit, scrollTarget)
                local Elem = {}
                function Elem:Set(v) Upd(v); if Data.Callback then pcall(Data.Callback, cur) end end
                function Elem:Get() return cur end
                return Elem
            end

            -- ── プログレスバー (NEW) ─────────────────────────────
            function Creators:CreateProgressBar(Data)
                local Min = Data.MinValue or 0
                local Max = Data.MaxValue or 100
                local cur = math.clamp(Data.CurrentValue or Min, Min, Max)
                local barColor = Data.Color or Color3.fromRGB(50, 138, 220)

                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 54); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)
                MkLabel(F, {
                    Size = UDim2.new(1, -90, 0, 30), Position = UDim2.new(0, 14, 0, 0),
                    Text = Data.Name or "進行状況", TextSize = 17, Font = Enum.Font.SourceSans,
                    TextColor3 = Color3.fromRGB(220, 225, 240),
                })
                local VL = MkLabel(F, {
                    Size = UDim2.new(0, 72, 0, 30), Position = UDim2.new(1, -80, 0, 0),
                    Text = "", TextColor3 = barColor, TextSize = 15,
                    Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Right,
                })
                local TrkBG = Instance.new("Frame")
                TrkBG.Size = UDim2.new(1, -28, 0, 8); TrkBG.Position = UDim2.new(0, 14, 1, -18)
                TrkBG.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                TrkBG.BorderSizePixel = 0; TrkBG.ZIndex = 2; TrkBG.Parent = F; CC(TrkBG, 100)
                CS(TrkBG, Color3.fromRGB(40, 40, 52), 1)
                local Fil = Instance.new("Frame")
                Fil.Size = UDim2.new(0, 0, 1, 0); Fil.BackgroundColor3 = barColor
                Fil.BorderSizePixel = 0; Fil.ZIndex = 3; Fil.Parent = TrkBG; CC(Fil, 100)

                local function Upd(v, animate)
                    v = math.clamp(v, Min, Max); cur = v
                    local ratio = (Max == Min) and 0 or (v - Min) / (Max - Min)
                    if animate then
                        TW(Fil, {Size = UDim2.new(ratio, 0, 1, 0)}, 0.35, Enum.EasingStyle.Quint)
                    else
                        Fil.Size = UDim2.new(ratio, 0, 1, 0)
                    end
                    VL.Text = tostring(math.floor(v * 10) / 10) .. (Data.Suffix or "")
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = v
                end
                Upd(cur, false)

                local Elem = {}
                function Elem:Set(v, noAnimate)
                    Upd(v, not noAnimate)
                end
                function Elem:Get() return cur end
                function Elem:SetColor(col)
                    barColor = col
                    Fil.BackgroundColor3 = col
                    VL.TextColor3 = col
                end
                return Elem
            end

            -- ── ドロップダウン ────────────────────────────────────
            function Creators:CreateDropdown(Data)
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 44); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)

                local DB = Instance.new("TextButton")
                DB.Size = UDim2.new(1, 0, 1, 0); DB.BackgroundTransparency = 1
                DB.Text = "  " .. (Data.Name or "選択") .. ":  " .. (Data.CurrentOption or "未選択")
                DB.TextColor3 = Color3.fromRGB(235, 235, 245); DB.TextSize = 17
                DB.Font = Enum.Font.SourceSans; DB.TextXAlignment = Enum.TextXAlignment.Left; DB.Parent = F
                DB.TextTruncate = Enum.TextTruncate.AtEnd
                ForwardScroll(DB, scrollTarget)

                local Arr = MkLabel(F, {
                    Size = UDim2.new(0, 24, 1, 0), Position = UDim2.new(1, -28, 0, 0),
                    Text = "▾", TextColor3 = Color3.fromRGB(95, 115, 145), TextSize = 16,
                    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
                })

                -- ★ Rayfield方式: OC を CA 直下に配置し TC の ClipsDescendants を完全に回避
                -- ★ 開くときに F の AbsolutePosition から相対座標を計算して配置
                local OC = Instance.new("ScrollingFrame")
                OC.Size = UDim2.new(0, 0, 0, 0)
                OC.BackgroundColor3 = Color3.fromRGB(16, 16, 20); OC.BorderSizePixel = 0
                OC.ScrollBarThickness = 3; OC.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
                OC.ScrollingDirection = Enum.ScrollingDirection.Y
                OC.CanvasSize = UDim2.new(0, 0, 0, 0)
                OC.Visible = false; OC.ZIndex = 200; OC.Parent = CA; CC(OC, 7); CS(OC, Color3.fromRGB(34, 34, 42), 1)
                local OCL = Instance.new("UIListLayout"); OCL.SortOrder = Enum.SortOrder.LayoutOrder; OCL.Parent = OC

                local op = false
                local optionCount = 0

                local function CloseDD()
                    op = false; OC.Visible = false; Arr.Text = "▾"
                end

                -- TCスクロール中は自動クローズ
                TC:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                    if op then CloseDD() end
                end)

                -- F 破棄時に OC も削除（CAの子なので自動削除されないため）
                F.Destroying:Connect(function() pcall(function() OC:Destroy() end) end)

                DB.MouseButton1Click:Connect(function()
                    if op then
                        CloseDD()
                    else
                        op = true
                        local h = math.min(optionCount * 34, 185)
                        local absF = F.AbsolutePosition
                        local absCA = CA.AbsolutePosition
                        OC.CanvasSize = UDim2.new(0, 0, 0, optionCount * 34)
                        OC.CanvasPosition = Vector2.zero
                        OC.Size = UDim2.fromOffset(F.AbsoluteSize.X, h)
                        OC.Position = UDim2.fromOffset(absF.X - absCA.X, absF.Y - absCA.Y + 44)
                        OC.Visible = true; Arr.Text = "▴"
                    end
                end)

                local function AddOption(opt)
                    optionCount = optionCount + 1
                    local OB = Instance.new("TextButton")
                    OB.Size = UDim2.new(1, 0, 0, 34); OB.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
                    OB.BorderSizePixel = 0; OB.Text = "  " .. opt
                    OB.TextColor3 = Color3.fromRGB(195, 200, 215); OB.TextSize = 16
                    OB.Font = Enum.Font.SourceSans; OB.TextXAlignment = Enum.TextXAlignment.Left
                    OB.AutoButtonColor = false; OB.ZIndex = 201; OB.Parent = OC
                    OB.MouseEnter:Connect(function() TW(OB, {BackgroundColor3 = Color3.fromRGB(28, 28, 36)}, 0.08) end)
                    OB.MouseLeave:Connect(function() TW(OB, {BackgroundColor3 = Color3.fromRGB(20, 20, 26)}, 0.08) end)
                    ForwardScroll(OB, OC)
                    OB.MouseButton1Click:Connect(function()
                        DB.Text = "  " .. (Data.Name or "選択") .. ":  " .. opt
                        CloseDD()
                        if Data.Callback then pcall(Data.Callback, opt) end
                        MyEngine.Flags[Data.Flag or Data.Name or ""] = opt
                    end)
                end
                for _, opt in pairs(Data.Options or {}) do AddOption(opt) end

                local Elem = {}
                function Elem:Set(opt)
                    DB.Text = "  " .. (Data.Name or "選択") .. ":  " .. opt
                    CloseDD()
                    if Data.Callback then pcall(Data.Callback, opt) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = opt
                end
                function Elem:Refresh(newOptions)
                    for _, c in pairs(OC:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    optionCount = 0; Data.Options = newOptions
                    for _, opt in pairs(newOptions or {}) do AddOption(opt) end
                end
                function Elem:Get()
                    local t = DB.Text:match(":  (.+)$"); return t
                end
                return Elem
            end

            -- ── マルチドロップダウン (NEW) ────────────────────────
            function Creators:CreateMultiDropdown(Data)
                local selected = {}
                for _, v in pairs(Data.CurrentOptions or {}) do selected[v] = true end
                local maxSel = Data.MaxSelection or math.huge

                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 44); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)

                local function getSelectedText()
                    local keys = {}
                    for k in pairs(selected) do table.insert(keys, k) end
                    if #keys == 0 then return "  " .. (Data.Name or "選択") .. ":  未選択" end
                    return "  " .. (Data.Name or "選択") .. ":  " .. table.concat(keys, ", ")
                end

                local DB = Instance.new("TextButton")
                DB.Size = UDim2.new(1, 0, 1, 0); DB.BackgroundTransparency = 1
                DB.Text = getSelectedText()
                DB.TextColor3 = Color3.fromRGB(235, 235, 245); DB.TextSize = 15
                DB.Font = Enum.Font.SourceSans; DB.TextXAlignment = Enum.TextXAlignment.Left
                DB.TextTruncate = Enum.TextTruncate.AtEnd; DB.Parent = F
                ForwardScroll(DB, scrollTarget)

                local Arr = MkLabel(F, {
                    Size = UDim2.new(0, 24, 1, 0), Position = UDim2.new(1, -28, 0, 0),
                    Text = "▾", TextColor3 = Color3.fromRGB(95, 115, 145), TextSize = 16,
                    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
                })

                -- ★ OC を CA 直下に配置 (TC の ClipsDescendants を完全回避)
                local OC = Instance.new("ScrollingFrame")
                OC.Size = UDim2.new(0, 0, 0, 0)
                OC.BackgroundColor3 = Color3.fromRGB(16, 16, 20); OC.BorderSizePixel = 0
                OC.ScrollBarThickness = 3; OC.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
                OC.ScrollingDirection = Enum.ScrollingDirection.Y
                OC.CanvasSize = UDim2.new(0, 0, 0, 0)
                OC.Visible = false; OC.ZIndex = 200; OC.Parent = CA; CC(OC, 7); CS(OC, Color3.fromRGB(34, 34, 42), 1)
                local OCL = Instance.new("UIListLayout"); OCL.SortOrder = Enum.SortOrder.LayoutOrder; OCL.Parent = OC

                local op = false
                local optionBtns = {}
                local optionCount = 0

                local function CloseDD()
                    op = false; OC.Visible = false; Arr.Text = "▾"
                end

                TC:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                    if op then CloseDD() end
                end)
                F.Destroying:Connect(function() pcall(function() OC:Destroy() end) end)

                local function UpdateDisplay()
                    DB.Text = getSelectedText()
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = selected
                    if Data.Callback then pcall(Data.Callback, selected) end
                end

                local function MakeOption(opt)
                    optionCount = optionCount + 1
                    local ORow = Instance.new("Frame")
                    ORow.Size = UDim2.new(1, 0, 0, 34); ORow.BorderSizePixel = 0; ORow.ZIndex = 201
                    ORow.BackgroundColor3 = selected[opt] and Color3.fromRGB(26, 42, 70) or Color3.fromRGB(20, 20, 26)
                    ORow.Parent = OC

                    local CB = Instance.new("Frame")
                    CB.Size = UDim2.new(0, 16, 0, 16); CB.Position = UDim2.new(0, 10, 0.5, -8)
                    CB.BackgroundColor3 = selected[opt] and Color3.fromRGB(42, 138, 242) or Color3.fromRGB(32, 32, 44)
                    CB.BorderSizePixel = 0; CB.ZIndex = 202; CB.Parent = ORow; CC(CB, 4)

                    local Check = MkLabel(CB, {
                        Size = UDim2.new(1, 0, 1, 0), Text = selected[opt] and "✓" or "",
                        TextSize = 11, Font = Enum.Font.GothamBold,
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 203,
                    })

                    local OBBtn = Instance.new("TextButton")
                    OBBtn.Size = UDim2.new(1, -36, 1, 0); OBBtn.Position = UDim2.new(0, 34, 0, 0)
                    OBBtn.BackgroundTransparency = 1; OBBtn.Text = opt
                    OBBtn.TextColor3 = Color3.fromRGB(195, 200, 215); OBBtn.TextSize = 15
                    OBBtn.Font = Enum.Font.SourceSans; OBBtn.TextXAlignment = Enum.TextXAlignment.Left
                    OBBtn.AutoButtonColor = false; OBBtn.ZIndex = 202; OBBtn.Parent = ORow
                    OBBtn.MouseEnter:Connect(function()
                        if not selected[opt] then TW(ORow, {BackgroundColor3 = Color3.fromRGB(26, 26, 34)}, 0.08) end
                    end)
                    OBBtn.MouseLeave:Connect(function()
                        if not selected[opt] then TW(ORow, {BackgroundColor3 = Color3.fromRGB(20, 20, 26)}, 0.08) end
                    end)
                    ForwardScroll(OBBtn, OC)
                    OBBtn.MouseButton1Click:Connect(function()
                        if selected[opt] then
                            selected[opt] = nil
                            TW(ORow, {BackgroundColor3 = Color3.fromRGB(20, 20, 26)}, 0.12)
                            TW(CB, {BackgroundColor3 = Color3.fromRGB(32, 32, 44)}, 0.12)
                            Check.Text = ""
                        else
                            local count = 0; for _ in pairs(selected) do count = count + 1 end
                            if count >= maxSel then
                                TW(ORow, {BackgroundColor3 = Color3.fromRGB(60, 25, 25)}, 0.08)
                                task.delay(0.2, function() TW(ORow, {BackgroundColor3 = Color3.fromRGB(20, 20, 26)}, 0.15) end)
                                return
                            end
                            selected[opt] = true
                            TW(ORow, {BackgroundColor3 = Color3.fromRGB(26, 42, 70)}, 0.12)
                            TW(CB, {BackgroundColor3 = Color3.fromRGB(42, 138, 242)}, 0.12)
                            Check.Text = "✓"
                        end
                        UpdateDisplay()
                    end)
                    optionBtns[opt] = {Frame = ORow, Check = Check, CB = CB}
                end

                for _, opt in pairs(Data.Options or {}) do MakeOption(opt) end

                DB.MouseButton1Click:Connect(function()
                    if op then
                        CloseDD()
                    else
                        op = true
                        local h = math.min(optionCount * 34, 185)
                        local absF = F.AbsolutePosition
                        local absCA = CA.AbsolutePosition
                        OC.CanvasSize = UDim2.new(0, 0, 0, optionCount * 34)
                        OC.CanvasPosition = Vector2.zero
                        OC.Size = UDim2.fromOffset(F.AbsoluteSize.X, h)
                        OC.Position = UDim2.fromOffset(absF.X - absCA.X, absF.Y - absCA.Y + 44)
                        OC.Visible = true; Arr.Text = "▴"
                    end
                end)

                local Elem = {}
                function Elem:Set(optTable)
                    selected = {}
                    for _, v in pairs(optTable or {}) do selected[v] = true end
                    for opt, btns in pairs(optionBtns) do
                        if selected[opt] then
                            btns.Frame.BackgroundColor3 = Color3.fromRGB(26, 42, 70)
                            btns.CB.BackgroundColor3 = Color3.fromRGB(42, 138, 242)
                            btns.Check.Text = "✓"
                        else
                            btns.Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
                            btns.CB.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
                            btns.Check.Text = ""
                        end
                    end
                    UpdateDisplay()
                end
                function Elem:Get()
                    local t = {}; for k in pairs(selected) do table.insert(t, k) end; return t
                end
                function Elem:Refresh(newOptions)
                    for _, c in pairs(OC:GetChildren()) do
                        if c:IsA("Frame") then c:Destroy() end
                    end
                    optionBtns = {}; optionCount = 0; selected = {}; Data.Options = newOptions
                    for _, opt in pairs(newOptions or {}) do MakeOption(opt) end
                    UpdateDisplay()
                end
                return Elem
            end

            -- ── キーバインド設定 ──────────────────────────────────
            function Creators:CreateKeybind(Data)
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 44); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)
                MkLabel(F, {
                    Size = UDim2.new(1, -118, 1, 0), Position = UDim2.new(0, 14, 0, 0),
                    Text = Data.Name or "キーバインド", TextSize = 17, Font = Enum.Font.SourceSans,
                })
                local KB = Instance.new("TextButton")
                KB.Size = UDim2.new(0, 102, 0, 28); KB.Position = UDim2.new(1, -110, 0.5, -14)
                KB.BackgroundColor3 = Color3.fromRGB(26, 26, 36); KB.BorderSizePixel = 0
                KB.Font = Enum.Font.GothamSemibold; KB.TextSize = 15
                KB.TextColor3 = Color3.fromRGB(155, 200, 255); KB.AutoButtonColor = false; KB.Parent = F
                CC(KB, 6); CS(KB, Color3.fromRGB(48, 78, 130), 1)
                local function KeyName(kc)
                    local s = tostring(kc); return s:match("Enum%.KeyCode%.(.+)") or s
                end
                local isMain = (Data.IsToggleKey == true)
                local curKey = Data.CurrentKey or MyEngine.ToggleKey
                KB.Text = "[ " .. KeyName(curKey) .. " ]"
                local listening = false; local listenConn = nil; local blinking = false
                KB.MouseButton1Click:Connect(function()
                    if listening then return end
                    listening = true; blinking = true
                    TW(KB, {BackgroundColor3 = Color3.fromRGB(16, 16, 26)}, 0.1)
                    TW(KB, {TextColor3 = Color3.fromRGB(255, 220, 55)}, 0.1)
                    KB.Text = "[ ??? ]"
                    task.spawn(function()
                        while blinking and KB.Parent do
                            KB.BackgroundTransparency = 0; task.wait(0.32)
                            if blinking then KB.BackgroundTransparency = 0.45; task.wait(0.32) end
                        end
                        KB.BackgroundTransparency = 0
                    end)
                    listenConn = UserInputService.InputBegan:Connect(function(inp)
                        if not listening then return end
                        if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
                        local kc = inp.KeyCode; listening = false; blinking = false
                        if kc == Enum.KeyCode.Escape then
                            KB.Text = "[ " .. KeyName(curKey) .. " ]"
                        else
                            curKey = kc; KB.Text = "[ " .. KeyName(curKey) .. " ]"
                            if isMain then
                                MyEngine.ToggleKey = curKey
                                AddLog("トグルキー変更 → " .. KeyName(curKey), "Action")
                            end
                            if Data.Callback then pcall(Data.Callback, curKey) end
                            MyEngine.Flags[Data.Flag or Data.Name or ""] = curKey
                        end
                        TW(KB, {BackgroundColor3 = Color3.fromRGB(26, 26, 36), TextColor3 = Color3.fromRGB(155, 200, 255)}, 0.15)
                        if listenConn then listenConn:Disconnect(); listenConn = nil end
                    end)
                end)
                KB.MouseEnter:Connect(function()
                    if not listening then TW(KB, {BackgroundColor3 = Color3.fromRGB(34, 34, 48)}, 0.1) end
                end)
                KB.MouseLeave:Connect(function()
                    if not listening then TW(KB, {BackgroundColor3 = Color3.fromRGB(26, 26, 36)}, 0.1) end
                end)
                -- [FIX] ホイールイベントを親ScrollingFrameへ転送
                ForwardScroll(KB, scrollTarget)
                local Elem = {}
                function Elem:Set(kc)
                    curKey = kc
                    KB.Text = "[ " .. KeyName(kc) .. " ]"
                    if isMain then MyEngine.ToggleKey = kc end
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = kc
                end
                function Elem:Get() return curKey end
                return Elem
            end

            -- ── テキスト入力 ──────────────────────────────────────
            function Creators:CreateTextInput(Data)
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 70); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)
                MkLabel(F, {
                    Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 14, 0, 6),
                    Text = Data.Name or "テキスト入力", TextSize = 14, Font = Enum.Font.GothamSemibold,
                    TextColor3 = Color3.fromRGB(95, 115, 155),
                })
                local TB = Instance.new("TextBox")
                TB.Size = UDim2.new(1, -18, 0, 32); TB.Position = UDim2.new(0, 9, 1, -39)
                TB.BackgroundColor3 = Color3.fromRGB(13, 13, 18); TB.BorderSizePixel = 0
                TB.PlaceholderText = Data.PlaceholderText or "入力..."
                TB.PlaceholderColor3 = Color3.fromRGB(70, 75, 95)
                TB.Text = Data.DefaultValue or ""
                TB.TextColor3 = Color3.fromRGB(220, 225, 240); TB.TextSize = 16
                TB.Font = Enum.Font.SourceSans; TB.ClearTextOnFocus = false; TB.Parent = F; CC(TB, 6)
                CS(TB, Color3.fromRGB(34, 34, 52), 1)
                TB.Focused:Connect(function() TW(TB, {BackgroundColor3 = Color3.fromRGB(16, 16, 26)}, 0.1) end)
                TB.FocusLost:Connect(function(enter)
                    TW(TB, {BackgroundColor3 = Color3.fromRGB(13, 13, 18)}, 0.1)
                    if Data.Callback then pcall(Data.Callback, TB.Text, enter) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = TB.Text
                    if enter then AddLog("入力確定: " .. (Data.Name or "?") .. " = " .. TB.Text, "Action") end
                end)
                local Elem = {}
                function Elem:Set(text)
                    TB.Text = text or ""
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = TB.Text
                end
                function Elem:Get() return TB.Text end
                return Elem
            end

            -- Rayfieldとの互換エイリアス
            Creators.CreateInput = Creators.CreateTextInput

            -- ── カラーピッカー ────────────────────────────────────
            function Creators:CreateColorPicker(Data)
                local initCol = Data.Color or Color3.fromRGB(255, 85, 85)
                local H, S, V = initCol:ToHSV()
                local opened = false
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, 44); F.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 7); CS(F, Color3.fromRGB(34, 34, 42), 1)
                MkLabel(F, {
                    Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 14, 0, 0),
                    Text = Data.Name or "カラー", TextSize = 17, Font = Enum.Font.SourceSans,
                })
                local Preview = Instance.new("Frame")
                Preview.Size = UDim2.new(0, 28, 0, 28); Preview.Position = UDim2.new(1, -68, 0.5, -14)
                Preview.BackgroundColor3 = initCol; Preview.BorderSizePixel = 0; Preview.Parent = F; CC(Preview, 6)
                CS(Preview, Color3.fromRGB(55, 55, 70), 1)
                local HexLbl = MkLabel(F, {
                    Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -118, 0.5, -10),
                    Text = "", TextSize = 11, Font = Enum.Font.Code,
                    TextColor3 = Color3.fromRGB(95, 115, 155), TextXAlignment = Enum.TextXAlignment.Right,
                })
                local TogBtn = Instance.new("TextButton")
                TogBtn.Size = UDim2.new(0, 22, 0, 22); TogBtn.Position = UDim2.new(1, -36, 0.5, -11)
                TogBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38); TogBtn.BorderSizePixel = 0
                TogBtn.Text = "▾"; TogBtn.TextColor3 = Color3.fromRGB(155, 160, 185)
                TogBtn.TextSize = 14; TogBtn.Font = Enum.Font.GothamBold
                TogBtn.AutoButtonColor = false; TogBtn.Parent = F; CC(TogBtn, 6)

                -- ★ CPanel を CA 直下に配置 (TC の ClipsDescendants を完全回避)
                local PANEL_H = 148
                local CPanel = Instance.new("Frame")
                CPanel.Size = UDim2.new(0, 0, 0, PANEL_H)
                CPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 19); CPanel.BorderSizePixel = 0
                CPanel.Visible = false; CPanel.ZIndex = 200; CPanel.Parent = CA; CC(CPanel, 7)
                CS(CPanel, Color3.fromRGB(34, 34, 48), 1)

                local BigPrev = Instance.new("Frame")
                BigPrev.Size = UDim2.new(1, -20, 0, 46); BigPrev.Position = UDim2.new(0, 10, 0, 10)
                BigPrev.BackgroundColor3 = initCol; BigPrev.BorderSizePixel = 0; BigPrev.ZIndex = 201; BigPrev.Parent = CPanel
                CC(BigPrev, 8); CS(BigPrev, Color3.fromRGB(50, 50, 70), 1.5)

                -- スライダー接続を追跡 (F破棄時に切断)
                local _rsConns = {}
                local _ieConns = {}

                -- スライダー生成関数
                local function MkHsvSlider(label, yPos, initVal, col1, col2)
                    MkLabel(CPanel, {
                        Size = UDim2.new(0, 14, 0, 16), Position = UDim2.new(0, 10, 0, yPos),
                        Text = label, TextSize = 12, Font = Enum.Font.GothamSemibold,
                        TextColor3 = Color3.fromRGB(95, 115, 155), ZIndex = 201,
                    })
                    local ValLbl = MkLabel(CPanel, {
                        Size = UDim2.new(0, 28, 0, 16), Position = UDim2.new(1, -34, 0, yPos),
                        Text = "", TextSize = 11, Font = Enum.Font.Code,
                        TextColor3 = Color3.fromRGB(95, 115, 155), ZIndex = 201,
                        TextXAlignment = Enum.TextXAlignment.Right,
                    })
                    local TrkBG2 = Instance.new("Frame")
                    TrkBG2.Size = UDim2.new(1, -54, 0, 8); TrkBG2.Position = UDim2.new(0, 26, 0, yPos + 4)
                    TrkBG2.BorderSizePixel = 0; TrkBG2.ZIndex = 201; TrkBG2.Parent = CPanel; CC(TrkBG2, 100)
                    local Grad2 = Instance.new("UIGradient")
                    Grad2.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, col1),
                        ColorSequenceKeypoint.new(1, col2)
                    }
                    Grad2.Parent = TrkBG2
                    local Knob = Instance.new("Frame")
                    Knob.Size = UDim2.new(0, 14, 0, 14); Knob.AnchorPoint = Vector2.new(0.5, 0.5)
                    Knob.Position = UDim2.new(initVal, 0, 0.5, 0); Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    Knob.BorderSizePixel = 0; Knob.ZIndex = 203; Knob.Parent = TrkBG2; CC(Knob, 100)
                    CS(Knob, Color3.fromRGB(120, 120, 140), 1)
                    local dr2 = false
                    TrkBG2.InputBegan:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 then dr2 = true end
                    end)
                    -- [FIX] InputEnded を追跡して F 破棄時に切断
                    local ieConn = UserInputService.InputEnded:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 then dr2 = false end
                    end)
                    table.insert(_ieConns, ieConn)
                    local curVal = initVal
                    -- [FIX] RenderStepped を追跡して F 破棄時に切断
                    local rsConn = RunService.RenderStepped:Connect(function()
                        if dr2 and CPanel.Visible then
                            local mx = UserInputService:GetMouseLocation().X
                            curVal = math.clamp((mx - TrkBG2.AbsolutePosition.X) / TrkBG2.AbsoluteSize.X, 0, 1)
                            Knob.Position = UDim2.new(curVal, 0, 0.5, 0)
                            ValLbl.Text = tostring(math.floor(curVal * 100)) .. "%"
                        end
                    end)
                    table.insert(_rsConns, rsConn)
                    ValLbl.Text = tostring(math.floor(initVal * 100)) .. "%"
                    local function GetVal() return curVal end
                    local function SetVal(v)
                        curVal = math.clamp(v, 0, 1)
                        Knob.Position = UDim2.new(curVal, 0, 0.5, 0)
                        ValLbl.Text = tostring(math.floor(curVal * 100)) .. "%"
                    end
                    return GetVal, SetVal, ValLbl, Knob, TrkBG2, Grad2
                end

                local GetH, SetH, HValLbl, HKnob, HTrkBG, HGrad = MkHsvSlider("H", 66, H,
                    Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 0, 0))
                local GetS, SetS, SValLbl, SKnob, STrkBG, SGrad = MkHsvSlider("S", 92, S,
                    Color3.fromRGB(180, 180, 180), Color3.fromRGB(255, 85, 85))
                local GetV, SetV, VValLbl, VKnob, VTrkBG, VGrad = MkHsvSlider("V", 118, V,
                    Color3.fromRGB(0, 0, 0), Color3.fromRGB(255, 255, 255))

                -- [FIX] H スライダーをレインボーグラデーションに
                HGrad.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 0)),
                }

                local function ToHex(c)
                    return string.format("#%02X%02X%02X",
                        math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
                end
                local curColor = initCol
                HexLbl.Text = ToHex(initCol)

                task.spawn(function()
                    while F.Parent do
                        if CPanel.Visible then
                            local newH = GetH(); local newS = GetS(); local newV = GetV()
                            local nc = Color3.fromHSV(newH, newS, newV)
                            if nc ~= curColor then
                                curColor = nc
                                Preview.BackgroundColor3 = curColor
                                BigPrev.BackgroundColor3 = curColor
                                HexLbl.Text = ToHex(curColor)
                                SGrad.Color = ColorSequence.new{
                                    ColorSequenceKeypoint.new(0, Color3.fromHSV(newH, 0, newV)),
                                    ColorSequenceKeypoint.new(1, Color3.fromHSV(newH, 1, newV)),
                                }
                                VGrad.Color = ColorSequence.new{
                                    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                                    ColorSequenceKeypoint.new(1, Color3.fromHSV(newH, newS, 1)),
                                }
                                if Data.Callback then pcall(Data.Callback, curColor) end
                                MyEngine.Flags[Data.Flag or Data.Name or ""] = curColor
                            end
                        end
                        task.wait(0.05)
                    end
                end)

                -- TCスクロール中は自動クローズ
                TC:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                    if opened then
                        opened = false; CPanel.Visible = false; TogBtn.Text = "▾"
                    end
                end)

                -- [FIX] F 破棄時に CPanel・全接続を切断
                F.Destroying:Connect(function()
                    pcall(function() CPanel:Destroy() end)
                    for _, c in ipairs(_rsConns) do pcall(function() c:Disconnect() end) end
                    for _, c in ipairs(_ieConns) do pcall(function() c:Disconnect() end) end
                end)

                ForwardScroll(TogBtn, scrollTarget)
                TogBtn.MouseButton1Click:Connect(function()
                    opened = not opened; TogBtn.Text = opened and "▴" or "▾"
                    if opened then
                        local absF = F.AbsolutePosition
                        local absCA = CA.AbsolutePosition
                        CPanel.Size = UDim2.fromOffset(F.AbsoluteSize.X, PANEL_H)
                        CPanel.Position = UDim2.fromOffset(absF.X - absCA.X, absF.Y - absCA.Y + 44)
                        CPanel.Visible = true
                    else
                        CPanel.Visible = false
                    end
                end)

                local Elem = {}
                function Elem:Set(color3)
                    curColor = color3; H, S, V = color3:ToHSV()
                    SetH(H); SetS(S); SetV(V)
                    Preview.BackgroundColor3 = curColor; BigPrev.BackgroundColor3 = curColor
                    HexLbl.Text = ToHex(curColor)
                    if Data.Callback then pcall(Data.Callback, curColor) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""] = curColor
                end
                function Elem:Get() return curColor end
                return Elem
            end

            -- ================================================================
            --  【V3.3 継承】折りたたみセクション
            -- ================================================================
            function Creators:CreateCollapsibleSection(sectionName)
                local HEADER_H = 40

                local Outer = Instance.new("Frame")
                Outer.Size = UDim2.new(1, 0, 0, HEADER_H)
                Outer.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
                Outer.BorderSizePixel = 0
                Outer.ClipsDescendants = true
                Outer.Parent = container
                CC(Outer, 8); CS(Outer, Color3.fromRGB(38, 50, 75), 1.5)

                local HdrGrad = Instance.new("UIGradient")
                HdrGrad.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 22, 32)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 13, 17)),
                }
                HdrGrad.Rotation = 90; HdrGrad.Parent = Outer

                local AccLine = Instance.new("Frame")
                AccLine.Size = UDim2.new(0, 3, 0, 24)
                AccLine.Position = UDim2.new(0, 0, 0, (HEADER_H - 24) / 2)
                AccLine.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
                AccLine.BorderSizePixel = 0; AccLine.Parent = Outer; CC(AccLine, 2)

                local HeaderBtn = Instance.new("TextButton")
                HeaderBtn.Size = UDim2.new(1, 0, 0, HEADER_H)
                HeaderBtn.BackgroundTransparency = 1
                HeaderBtn.Text = "  " .. (sectionName or "セクション")
                HeaderBtn.TextColor3 = Color3.fromRGB(110, 160, 235)
                HeaderBtn.TextSize = 15; HeaderBtn.Font = Enum.Font.GothamSemibold
                HeaderBtn.TextXAlignment = Enum.TextXAlignment.Left
                HeaderBtn.AutoButtonColor = false; HeaderBtn.ZIndex = 5; HeaderBtn.Parent = Outer

                local Arrow = MkLabel(Outer, {
                    Size = UDim2.new(0, 28, 0, HEADER_H), Position = UDim2.new(1, -32, 0, 0),
                    Text = "▶", TextColor3 = Color3.fromRGB(70, 110, 180), TextSize = 13,
                    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6,
                })

                local Sep = Instance.new("Frame")
                Sep.Size = UDim2.new(1, -12, 0, 1); Sep.Position = UDim2.new(0, 6, 0, HEADER_H - 1)
                Sep.BackgroundColor3 = Color3.fromRGB(32, 42, 65); Sep.BorderSizePixel = 0; Sep.Parent = Outer

                local Inner = Instance.new("Frame")
                Inner.Name = "_SecInner"; Inner.Size = UDim2.new(1, 0, 0, 0)
                Inner.Position = UDim2.new(0, 0, 0, HEADER_H + 1)
                Inner.BackgroundTransparency = 1; Inner.BorderSizePixel = 0; Inner.Parent = Outer

                local IL = Instance.new("UIListLayout")
                IL.Padding = UDim.new(0, 6); IL.SortOrder = Enum.SortOrder.LayoutOrder; IL.Parent = Inner

                local IP = Instance.new("UIPadding")
                IP.PaddingTop = UDim.new(0, 6); IP.PaddingBottom = UDim.new(0, 10)
                IP.PaddingLeft = UDim.new(0, 4); IP.PaddingRight = UDim.new(0, 4); IP.Parent = Inner

                local expanded = false

                local function getContentH()
                    return IL.AbsoluteContentSize.Y + 16
                end
                local function getFullH()
                    return HEADER_H + 1 + getContentH()
                end

                IL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    Inner.Size = UDim2.new(1, 0, 0, getContentH())
                    if expanded then
                        Outer.Size = UDim2.new(1, 0, 0, getFullH())
                    end
                end)

                HeaderBtn.MouseEnter:Connect(function()
                    TW(HeaderBtn, {TextColor3 = Color3.fromRGB(145, 195, 255)}, 0.1)
                    TW(AccLine, {BackgroundColor3 = Color3.fromRGB(75, 165, 255)}, 0.1)
                end)
                HeaderBtn.MouseLeave:Connect(function()
                    TW(HeaderBtn, {TextColor3 = Color3.fromRGB(110, 160, 235)}, 0.1)
                    TW(AccLine, {BackgroundColor3 = Color3.fromRGB(50, 130, 255)}, 0.1)
                end)
                -- [FIX] ホイールイベントを親ScrollingFrameへ転送
                ForwardScroll(HeaderBtn, scrollTarget)
                HeaderBtn.MouseButton1Click:Connect(function()
                    expanded = not expanded
                    if expanded then
                        Arrow.Text = "▼"
                        TW(AccLine, {BackgroundColor3 = Color3.fromRGB(95, 195, 255)}, 0.15)
                        TW(Outer, {Size = UDim2.new(1, 0, 0, getFullH())},
                            0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                        CS(Outer, Color3.fromRGB(55, 130, 225), 1.5)
                    else
                        Arrow.Text = "▶"
                        TW(AccLine, {BackgroundColor3 = Color3.fromRGB(50, 130, 255)}, 0.15)
                        TW(Outer, {Size = UDim2.new(1, 0, 0, HEADER_H)},
                            0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        CS(Outer, Color3.fromRGB(38, 50, 75), 1.5)
                    end
                end)

                -- [FIX] scrollTarget を内側の buildCreators へ伝播させる
                return buildCreators(Inner, scrollTarget)
            end

            -- ================================================================
            --  ログビューアー ── 折りたたみ対応
            -- ================================================================
            function Creators:CreateLogViewer()
                local FULL_H   = 360
                local HEADER_H = 48

                local LOG_COLORS = {
                    Info    = Color3.fromRGB(160, 170, 190),
                    Action  = Color3.fromRGB(70, 150, 255),
                    Success = Color3.fromRGB(65, 210, 100),
                    Warning = Color3.fromRGB(240, 175, 45),
                    Error   = Color3.fromRGB(215, 70, 70),
                }
                local LOG_BADGES = {Info = "INFO", Action = "ACT", Success = "OK", Warning = "WARN", Error = "ERR"}

                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, FULL_H); F.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 8); CS(F, Color3.fromRGB(34, 34, 42), 1)

                MkLabel(F, {
                    Size = UDim2.new(1, -130, 0, 32), Position = UDim2.new(0, 14, 0, 8),
                    Text = "ログ", TextSize = 18, Font = Enum.Font.SourceSansBold,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                })

                local ClearBtn = Instance.new("TextButton")
                ClearBtn.Size = UDim2.new(0, 64, 0, 26); ClearBtn.Position = UDim2.new(1, -114, 0, 11)
                ClearBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 30); ClearBtn.BorderSizePixel = 0
                ClearBtn.Text = "クリア"; ClearBtn.TextColor3 = Color3.fromRGB(180, 80, 80)
                ClearBtn.TextSize = 14; ClearBtn.Font = Enum.Font.GothamSemibold
                ClearBtn.AutoButtonColor = false; ClearBtn.ZIndex = 10; ClearBtn.Parent = F; CC(ClearBtn, 6)
                CS(ClearBtn, Color3.fromRGB(80, 30, 30), 1)
                ClearBtn.MouseEnter:Connect(function() TW(ClearBtn, {BackgroundColor3 = Color3.fromRGB(32, 18, 18)}, 0.1) end)
                ClearBtn.MouseLeave:Connect(function() TW(ClearBtn, {BackgroundColor3 = Color3.fromRGB(22, 22, 30)}, 0.1) end)

                MakeCollapsible(F, FULL_H, HEADER_H)

                local Sep = Instance.new("Frame")
                Sep.Size = UDim2.new(1, -24, 0, 1); Sep.Position = UDim2.new(0, 12, 0, 42)
                Sep.BackgroundColor3 = Color3.fromRGB(28, 28, 38); Sep.BorderSizePixel = 0; Sep.Parent = F

                local SF = Instance.new("ScrollingFrame")
                SF.Size = UDim2.new(1, -12, 0, 302); SF.Position = UDim2.new(0, 6, 0, 48)
                SF.BackgroundTransparency = 1; SF.BorderSizePixel = 0
                SF.ScrollBarThickness = 3; SF.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
                SF.ScrollingDirection = Enum.ScrollingDirection.Y; SF.Parent = F
                local LL = Instance.new("UIListLayout")
                LL.Padding = UDim.new(0, 2); LL.SortOrder = Enum.SortOrder.LayoutOrder; LL.Parent = SF
                local LP2 = Instance.new("UIPadding")
                LP2.PaddingTop = UDim.new(0, 4); LP2.PaddingBottom = UDim.new(0, 4)
                LP2.PaddingLeft = UDim.new(0, 4); LP2.PaddingRight = UDim.new(0, 4); LP2.Parent = SF

                local function Rebuild()
                    for _, c in pairs(SF:GetChildren()) do
                        if c:IsA("Frame") then c:Destroy() end
                    end
                    local logs = MyEngine.Logs
                    for i = #logs, math.max(1, #logs - 79), -1 do
                        local log = logs[i]
                        local col = LOG_COLORS[log.Type] or LOG_COLORS.Info
                        local badge = LOG_BADGES[log.Type] or "INFO"
                        local Row = Instance.new("Frame")
                        Row.Size = UDim2.new(1, 0, 0, 26); Row.BackgroundTransparency = 1; Row.Parent = SF
                        local BadgeF = Instance.new("Frame")
                        BadgeF.Size = UDim2.new(0, 38, 0, 18); BadgeF.Position = UDim2.new(0, 0, 0.5, -9)
                        BadgeF.BackgroundColor3 = col; BadgeF.BackgroundTransparency = 0.72
                        BadgeF.BorderSizePixel = 0; BadgeF.Parent = Row; CC(BadgeF, 4)
                        MkLabel(BadgeF, {Size = UDim2.new(1, 0, 1, 0), Text = badge, TextSize = 10,
                            Font = Enum.Font.GothamBold, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Center})
                        MkLabel(Row, {Size = UDim2.new(0, 62, 1, 0), Position = UDim2.new(0, 42, 0, 0),
                            Text = log.Time, TextSize = 11, Font = Enum.Font.Code, TextColor3 = Color3.fromRGB(55, 65, 90)})
                        MkLabel(Row, {Size = UDim2.new(1, -108, 1, 0), Position = UDim2.new(0, 108, 0, 0),
                            Text = log.Message, TextSize = 13, Font = Enum.Font.SourceSans,
                            TextColor3 = col, TextTruncate = Enum.TextTruncate.AtEnd})
                    end
                    SF.CanvasSize = UDim2.new(0, 0, 0, LL.AbsoluteContentSize.Y + 8)
                end
                Rebuild()

                ClearBtn.MouseButton1Click:Connect(function()
                    MyEngine.Logs = {}
                    TW(ClearBtn, {BackgroundColor3 = Color3.fromRGB(40, 20, 20)}, 0.06)
                    task.delay(0.08, function() TW(ClearBtn, {BackgroundColor3 = Color3.fromRGB(22, 22, 30)}, 0.12) end)
                    Rebuild(); AddLog("ログをクリアしました", "Info")
                end)

                local listenId = tostring(tick())
                LogListeners[listenId] = Rebuild
                F.AncestryChanged:Connect(function()
                    if not F.Parent then LogListeners[listenId] = nil end
                end)
            end

            -- ================================================================
            --  プレイヤーリスト ── テーブル式マルチ選択 ── 折りたたみ対応
            -- ================================================================
            function Creators:CreatePlayerList(Data)
                local FULL_H   = 420
                local HEADER_H = 48
                local selectedTable = {}

                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, FULL_H); F.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 8); CS(F, Color3.fromRGB(34, 34, 42), 1)

                MkLabel(F, {
                    Size = UDim2.new(0.55, 0, 0, 30), Position = UDim2.new(0, 14, 0, 9),
                    Text = Data.Title or "プレイヤーリスト", TextSize = 18, Font = Enum.Font.SourceSansBold,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                })

                local CountLbl = MkLabel(F, {
                    Size = UDim2.new(0, 120, 0, 26), Position = UDim2.new(0.55, -10, 0, 11),
                    Text = "選択: 0", TextSize = 13, Font = Enum.Font.GothamSemibold,
                    TextColor3 = Color3.fromRGB(70, 150, 255), TextXAlignment = Enum.TextXAlignment.Right,
                })

                MakeCollapsible(F, FULL_H, HEADER_H)

                local Sep = Instance.new("Frame")
                Sep.Size = UDim2.new(1, -24, 0, 1); Sep.Position = UDim2.new(0, 12, 0, 42)
                Sep.BackgroundColor3 = Color3.fromRGB(28, 28, 38); Sep.BorderSizePixel = 0; Sep.Parent = F

                local PS = Instance.new("ScrollingFrame")
                PS.Size = UDim2.new(1, -12, 0, 286); PS.Position = UDim2.new(0, 6, 0, 50)
                PS.BackgroundTransparency = 1; PS.BorderSizePixel = 0
                PS.ScrollBarThickness = 3; PS.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
                PS.ScrollingDirection = Enum.ScrollingDirection.Y; PS.Parent = F
                local PL = Instance.new("UIListLayout")
                PL.Padding = UDim.new(0, 4); PL.SortOrder = Enum.SortOrder.LayoutOrder; PL.Parent = PS
                local PP = Instance.new("UIPadding")
                PP.PaddingTop = UDim.new(0, 4); PP.PaddingBottom = UDim.new(0, 4)
                PP.PaddingLeft = UDim.new(0, 4); PP.PaddingRight = UDim.new(0, 4); PP.Parent = PS
                PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    PS.CanvasSize = UDim2.new(0, 0, 0, PL.AbsoluteContentSize.Y + 8)
                end)

                -- 全選択 / 全解除ボタンエリア
                local CtrlRow = Instance.new("Frame")
                CtrlRow.Size = UDim2.new(1, -12, 0, 32)
                CtrlRow.Position = UDim2.new(0, 6, 0, 342)
                CtrlRow.BackgroundTransparency = 1; CtrlRow.BorderSizePixel = 0; CtrlRow.Parent = F

                local function MkCtrlBtn(txt, bg, xScale)
                    local b = Instance.new("TextButton")
                    b.Size = UDim2.new(0.49, 0, 1, 0); b.Position = UDim2.new(xScale, 0, 0, 0)
                    b.BackgroundColor3 = bg; b.BorderSizePixel = 0
                    b.Text = txt; b.TextColor3 = Color3.fromRGB(210, 215, 230)
                    b.TextSize = 14; b.Font = Enum.Font.GothamSemibold
                    b.AutoButtonColor = false; b.Parent = CtrlRow; CC(b, 6)
                    b.MouseEnter:Connect(function() TW(b, {BackgroundTransparency = 0.3}, 0.1) end)
                    b.MouseLeave:Connect(function() TW(b, {BackgroundTransparency = 0}, 0.1) end)
                    return b
                end
                local SelAllBtn  = MkCtrlBtn("全選択", Color3.fromRGB(28, 52, 95), 0)
                local DeselAllBtn = MkCtrlBtn("全解除", Color3.fromRGB(38, 24, 24), 0.51)

                local function UpdateCountLbl()
                    local count = 0
                    for _ in pairs(selectedTable) do count = count + 1 end
                    CountLbl.Text = "選択: " .. count
                end

                local function ApplyCardVisual(card, stroke, active)
                    if active then
                        TW(card, {BackgroundColor3 = Color3.fromRGB(22, 42, 76)}, 0.15)
                        stroke.Color = Color3.fromRGB(50, 130, 255); stroke.Thickness = 1.8
                    else
                        TW(card, {BackgroundColor3 = Color3.fromRGB(20, 20, 26)}, 0.15)
                        stroke.Color = Color3.fromRGB(36, 36, 46); stroke.Thickness = 1.5
                    end
                end

                local function BuildCard(plr)
                    local c = Instance.new("Frame")
                    c.Name = "p_" .. plr.UserId
                    c.Size = UDim2.new(1, 0, 0, 48)
                    c.BackgroundColor3 = selectedTable[plr.Name] and Color3.fromRGB(22, 42, 76) or Color3.fromRGB(20, 20, 26)
                    c.BorderSizePixel = 0; c.Parent = PS
                    CC(c, 7)
                    local s = CS(c,
                        selectedTable[plr.Name] and Color3.fromRGB(50, 130, 255) or Color3.fromRGB(36, 36, 46),
                        selectedTable[plr.Name] and 1.8 or 1.5)

                    local Ico = Instance.new("ImageLabel")
                    Ico.Size = UDim2.new(0, 36, 0, 36); Ico.Position = UDim2.new(0, 8, 0.5, -18)
                    Ico.BackgroundColor3 = Color3.fromRGB(26, 26, 36); Ico.BorderSizePixel = 0
                    Ico.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=150&h=150"
                    Ico.Parent = c; CC(Ico, 100)

                    MkLabel(c, {
                        Size = UDim2.new(1, -100, 0, 22), Position = UDim2.new(0, 52, 0, 5),
                        Text = plr.DisplayName, TextSize = 15, Font = Enum.Font.SourceSansBold,
                        TextColor3 = Color3.fromRGB(225, 230, 245),
                    })
                    MkLabel(c, {
                        Size = UDim2.new(1, -100, 0, 18), Position = UDim2.new(0, 52, 0, 26),
                        Text = "@" .. plr.Name, TextSize = 13, Font = Enum.Font.SourceSans,
                        TextColor3 = Color3.fromRGB(75, 120, 185),
                    })

                    -- ✓マーク
                    local ChkF = Instance.new("Frame")
                    ChkF.Size = UDim2.new(0, 22, 0, 22); ChkF.Position = UDim2.new(1, -32, 0.5, -11)
                    ChkF.BackgroundColor3 = Color3.fromRGB(42, 138, 242); ChkF.BorderSizePixel = 0
                    ChkF.BackgroundTransparency = selectedTable[plr.Name] and 0 or 1
                    ChkF.Parent = c; CC(ChkF, 6)
                    local ChkLbl = MkLabel(ChkF, {
                        Size = UDim2.new(1, 0, 1, 0), Text = "✓", TextSize = 13,
                        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextTransparency = selectedTable[plr.Name] and 0 or 1,
                    })

                    local hitBtn = Instance.new("TextButton")
                    hitBtn.Size = UDim2.new(1, 0, 1, 0); hitBtn.BackgroundTransparency = 1
                    hitBtn.Text = ""; hitBtn.AutoButtonColor = false; hitBtn.ZIndex = 5; hitBtn.Parent = c

                    hitBtn.MouseButton1Click:Connect(function()
                        if selectedTable[plr.Name] then
                            selectedTable[plr.Name] = nil
                            MyEngine.KillList[plr.UserId] = nil
                            MyEngine.Blacklist[plr.UserId] = nil
                            ApplyCardVisual(c, s, false)
                            TW(ChkF, {BackgroundTransparency = 1}, 0.15)
                            TW(ChkLbl, {TextTransparency = 1}, 0.15)
                        else
                            selectedTable[plr.Name] = true
                            MyEngine.KillList[plr.UserId] = true
                            MyEngine.Blacklist[plr.UserId] = plr.Name
                            ApplyCardVisual(c, s, true)
                            TW(ChkF, {BackgroundTransparency = 0}, 0.15)
                            TW(ChkLbl, {TextTransparency = 0}, 0.15)
                        end
                        UpdateCountLbl()
                        if Data.Callback then pcall(Data.Callback, plr, selectedTable[plr.Name] ~= nil, selectedTable) end
                    end)

                    hitBtn.MouseEnter:Connect(function()
                        if not selectedTable[plr.Name] then TW(c, {BackgroundColor3 = Color3.fromRGB(24, 24, 32)}, 0.1) end
                    end)
                    hitBtn.MouseLeave:Connect(function()
                        if not selectedTable[plr.Name] then TW(c, {BackgroundColor3 = Color3.fromRGB(20, 20, 26)}, 0.1) end
                    end)
                    -- [FIX] ホイールイベントを親ScrollingFrameへ転送
                    ForwardScroll(hitBtn, scrollTarget)
                end

                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer or Data.ShowSelf then BuildCard(p) end
                end

                -- [FIX] 接続を保持し、F破棄時に切断してメモリリークを防止
                local _addedConn = Players.PlayerAdded:Connect(function(p)
                    if p ~= LocalPlayer or Data.ShowSelf then BuildCard(p) end
                end)
                local _removingConn = Players.PlayerRemoving:Connect(function(p)
                    selectedTable[p.Name] = nil
                    MyEngine.KillList[p.UserId] = nil
                    MyEngine.Blacklist[p.UserId] = nil
                    local c = PS:FindFirstChild("p_" .. p.UserId)
                    if c then
                        TW(c, {BackgroundTransparency = 1}, 0.15)
                        task.delay(0.18, function() pcall(function() c:Destroy() end) end)
                    end
                    UpdateCountLbl()
                end)
                F.Destroying:Connect(function()
                    _addedConn:Disconnect(); _removingConn:Disconnect()
                end)

                local Elem = {}
                function Elem:GetSelected() return selectedTable end
                function Elem:IsSelected(player)
                    return selectedTable[player.Name] == true
                end
                function Elem:ClearAll()
                    for _, c in pairs(PS:GetChildren()) do
                        if c:IsA("Frame") then
                            local s = c:FindFirstChildOfClass("UIStroke")
                            if s then
                                s.Color = Color3.fromRGB(36, 36, 46); s.Thickness = 1.5
                            end
                            TW(c, {BackgroundColor3 = Color3.fromRGB(20, 20, 26)}, 0.15)
                            for _, lbl in pairs(c:GetDescendants()) do
                                if lbl:IsA("TextLabel") and lbl.Text == "✓" then
                                    TW(lbl, {TextTransparency = 1}, 0.15)
                                end
                            end
                        end
                    end
                    selectedTable = {}
                    UpdateCountLbl()
                    AddLog("全選択を解除しました", "Action")
                end
                function Elem:SelectPlayer(player)
                    if not player or selectedTable[player.Name] then return end
                    selectedTable[player.Name] = true
                    MyEngine.KillList[player.UserId] = true
                    MyEngine.Blacklist[player.UserId] = player.Name
                    local c = PS:FindFirstChild("p_" .. player.UserId)
                    if c then
                        local s = c:FindFirstChildOfClass("UIStroke")
                        if s then ApplyCardVisual(c, s, true) end
                        for _, lbl in pairs(c:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Text == "✓" then
                                TW(lbl, {TextTransparency = 0}, 0.15)
                            end
                        end
                    end
                    UpdateCountLbl()
                    if Data.Callback then pcall(Data.Callback, player, true, selectedTable) end
                end
                function Elem:DeselectPlayer(player)
                    if not player or not selectedTable[player.Name] then return end
                    selectedTable[player.Name] = nil
                    MyEngine.KillList[player.UserId] = nil
                    MyEngine.Blacklist[player.UserId] = nil
                    local c = PS:FindFirstChild("p_" .. player.UserId)
                    if c then
                        local s = c:FindFirstChildOfClass("UIStroke")
                        if s then ApplyCardVisual(c, s, false) end
                        for _, lbl in pairs(c:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Text == "✓" then
                                TW(lbl, {TextTransparency = 1}, 0.15)
                            end
                        end
                    end
                    UpdateCountLbl()
                    if Data.Callback then pcall(Data.Callback, player, false, selectedTable) end
                end

                -- 全選択ボタン
                SelAllBtn.MouseButton1Click:Connect(function()
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer or Data.ShowSelf then
                            if not selectedTable[p.Name] then
                                Elem:SelectPlayer(p)
                            end
                        end
                    end
                    AddLog("全プレイヤーを選択しました", "Action")
                end)
                DeselAllBtn.MouseButton1Click:Connect(function()
                    Elem:ClearAll()
                end)

                return Elem
            end

            -- ================================================================
            --  ゲーム情報 ── 折りたたみ対応
            -- ================================================================
            function Creators:CreateGameInfo()
                local FULL_H   = 300
                local HEADER_H = 48

                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, 0, 0, FULL_H); F.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
                F.BorderSizePixel = 0; F.Parent = container; CC(F, 8); CS(F, Color3.fromRGB(34, 34, 42), 1)

                MkLabel(F, {
                    Size = UDim2.new(1, -55, 0, 30), Position = UDim2.new(0, 14, 0, 9),
                    Text = "サーバー情報", TextSize = 18, Font = Enum.Font.SourceSansBold,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                })

                MakeCollapsible(F, FULL_H, HEADER_H)

                local Sep = Instance.new("Frame")
                Sep.Size = UDim2.new(1, -24, 0, 1); Sep.Position = UDim2.new(0, 12, 0, 40)
                Sep.BackgroundColor3 = Color3.fromRGB(28, 28, 38); Sep.BorderSizePixel = 0; Sep.Parent = F

                local function Row(lbl, y)
                    MkLabel(F, {Size = UDim2.new(0.42, -4, 0, 26), Position = UDim2.new(0, 16, 0, y),
                        Text = lbl, TextSize = 15, Font = Enum.Font.GothamSemibold,
                        TextColor3 = Color3.fromRGB(95, 115, 155)})
                    local v = MkLabel(F, {Size = UDim2.new(0.58, -4, 0, 26), Position = UDim2.new(0.42, 0, 0, y),
                        Text = "…", TextSize = 15, Font = Enum.Font.SourceSans,
                        TextColor3 = Color3.fromRGB(200, 210, 230)})
                    return v
                end
                local vSrv  = Row("サーバーID",     46)
                local vPly  = Row("プレイヤー数",    74)
                local vPing = Row("Ping",           102)
                local vFPS  = Row("FPS",            130)
                local vUp   = Row("稼働時間",       158)
                local vGame = Row("ゲーム名",       186)
                local vPID  = Row("PlaceID",        214)
                local vMe   = Row("自分のUserId",    242)

                pcall(function()
                    local jid = tostring(game.JobId)
                    vSrv.Text = jid ~= "" and (jid:sub(1, 18) .. "...") or "ローカル"
                    vGame.Text = tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
                end)
                pcall(function() vPID.Text = tostring(game.PlaceId) end)
                pcall(function() vMe.Text = tostring(LocalPlayer.UserId) end)

                local startT = tick(); local lastPing = 0
                local function UpdLive()
                    pcall(function()
                        lastPing = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                    end)
                    local pc = Color3.fromRGB(65, 210, 100)
                    if lastPing > 300 then pc = Color3.fromRGB(215, 70, 70)
                    elseif lastPing > 150 then pc = Color3.fromRGB(240, 175, 45) end
                    vPing.Text = lastPing .. " ms"; vPing.TextColor3 = pc
                    local fps = 0
                    pcall(function()
                        local s = tick(); RunService.RenderStepped:Wait()
                        fps = math.floor(1 / (tick() - s))
                    end)
                    vFPS.Text = fps .. " fps"
                    local e = tick() - startT
                    vUp.Text = string.format("%02d:%02d:%02d",
                        math.floor(e / 3600), math.floor(e / 60) % 60, math.floor(e) % 60)
                    vPly.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
                end
                task.spawn(function() while F.Parent do pcall(UpdLive); task.wait(1) end end)
            end

            return Creators
        end -- buildCreators 終了

        -- Tab 本体に全ビルダーをコピー
        local Creators = buildCreators(TC)
        for k, v in pairs(Creators) do
            Tab[k] = v
        end

        return Tab
    end -- CreateTab 終了

    return Window
end

-- ================================================================
--  通知
--  Data: {Title, Content, Duration, Type}
--  Type: "Info" | "Success" | "Warning" | "Error"  (デフォルト "Info")
-- ================================================================
local NOTIFY_TYPE_CONFIG = {
    Info    = {Color = Color3.fromRGB(45, 145, 255),  Icon = "ℹ"},
    Success = {Color = Color3.fromRGB(55, 210, 115),  Icon = "✓"},
    Warning = {Color = Color3.fromRGB(240, 175, 45),  Icon = "⚠"},
    Error   = {Color = Color3.fromRGB(215, 70, 70),   Icon = "✕"},
}

-- 通知スタック管理（重複しないよう Y オフセット）
local _notifyStack = {}
local _notifyBase  = -20
local _notifyGap   = 96

local function GetNotifyYOffset()
    local idx = #_notifyStack + 1
    return _notifyBase - (idx - 1) * _notifyGap
end

function MyEngine:Notify(Data)
    local cfg = NOTIFY_TYPE_CONFIG[Data.Type or "Info"] or NOTIFY_TYPE_CONFIG.Info
    local accentColor = cfg.Color
    local icon        = cfg.Icon

    local yOff = GetNotifyYOffset()
    local entry = {}; table.insert(_notifyStack, entry)

    local NG = Instance.new("ScreenGui")
    NG.Name = "afNotify"; NG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    NG.DisplayOrder = 101
    pcall(function() NG.IgnoreGuiInset = true end)
    NG.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local NF = Instance.new("Frame")
    NF.Size = UDim2.new(0, 318, 0, 84)
    NF.Position = UDim2.new(1, 10, 1, yOff)
    NF.AnchorPoint = Vector2.new(1, 1)
    NF.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    NF.BorderSizePixel = 0; NF.Parent = NG
    CC(NF, 10); CS(NF, accentColor, 1.5)

    -- 左カラーバー
    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(0, 3, 1, -16); Bar.Position = UDim2.new(0, 8, 0, 8)
    Bar.BackgroundColor3 = accentColor; Bar.BorderSizePixel = 0; Bar.Parent = NF; CC(Bar, 100)

    -- アイコン
    local IcoLbl = MkLabel(NF, {
        Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0, 18, 0, 10),
        Text = icon, TextSize = 18, Font = Enum.Font.GothamBold,
        TextColor3 = accentColor, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
    })

    MkLabel(NF, {
        Size = UDim2.new(1, -52, 0, 25), Position = UDim2.new(0, 46, 0, 8),
        Text = Data.Title or "通知", TextSize = 16, Font = Enum.Font.SourceSansBold,
        ZIndex = 2,
    })
    MkLabel(NF, {
        Size = UDim2.new(1, -52, 0, 36), Position = UDim2.new(0, 46, 0, 33),
        Text = Data.Content or "", TextSize = 15, Font = Enum.Font.SourceSans,
        TextColor3 = Color3.fromRGB(175, 180, 200), TextWrapped = true, ZIndex = 2,
    })

    -- 底辺プログレスバー
    local ProgBG = Instance.new("Frame")
    ProgBG.Size = UDim2.new(1, -16, 0, 2); ProgBG.Position = UDim2.new(0, 8, 1, -5)
    ProgBG.BackgroundColor3 = Color3.fromRGB(28, 28, 38); ProgBG.BorderSizePixel = 0; ProgBG.Parent = NF; CC(ProgBG, 100)
    local ProgFil = Instance.new("Frame")
    ProgFil.Size = UDim2.new(1, 0, 1, 0); ProgFil.BackgroundColor3 = accentColor
    ProgFil.BorderSizePixel = 0; ProgFil.Parent = ProgBG; CC(ProgFil, 100)

    task.spawn(function()
        TW(NF, {Position = UDim2.new(1, -10, 1, yOff)}, 0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local dur = Data.Duration or 3
        TW(ProgFil, {Size = UDim2.new(0, 0, 1, 0)}, dur, Enum.EasingStyle.Linear)
        task.wait(dur)
        TW(NF, {Position = UDim2.new(1, 10, 1, yOff)}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.32)
        pcall(function()
            local idx = table.find(_notifyStack, entry)
            if idx then table.remove(_notifyStack, idx) end
            NG:Destroy()
        end)
    end)

    return entry
end

-- ================================================================
--  設定の保存・読み込み (新機能)
--  writefile / readfile が利用できる環境向け
-- ================================================================
function MyEngine:SaveConfig(name)
    local filename = "afHub_" .. (name or "config") .. ".json"
    local data = {}
    for k, v in pairs(self.Flags) do
        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then
            data[k] = v
        end
    end
    local ok, json = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if ok and json then
        local ok2, err = pcall(function()
            writefile(filename, json)
        end)
        if ok2 then
            AddLog("設定を保存しました: " .. filename, "Success")
        else
            AddLog("設定の保存に失敗: " .. tostring(err), "Error")
        end
    else
        AddLog("JSON変換に失敗しました", "Error")
    end
end

function MyEngine:LoadConfig(name)
    local filename = "afHub_" .. (name or "config") .. ".json"
    local ok, json = pcall(function()
        return readfile(filename)
    end)
    if ok and json then
        local ok2, data = pcall(function()
            return HttpService:JSONDecode(json)
        end)
        if ok2 and type(data) == "table" then
            for k, v in pairs(data) do
                self.Flags[k] = v
            end
            AddLog("設定を読み込みました: " .. filename, "Success")
            return data
        else
            AddLog("設定ファイルのJSONが不正です", "Error")
        end
    else
        AddLog("設定ファイルが見つかりません: " .. filename, "Warning")
    end
    return {}
end

-- ================================================================
--  全GUI破棄 (新機能)
-- ================================================================
function MyEngine:Destroy()
    -- 登録済みScreenGuiを全て破棄
    for _, sg in pairs(self._ScreenGuis) do
        pcall(function() sg:Destroy() end)
    end
    self._ScreenGuis = {}
    -- 通知も破棄
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, c in pairs(pg:GetChildren()) do
            if c.Name == "afNotify" then
                pcall(function() c:Destroy() end)
            end
        end
    end
    _notifyStack = {}
    AddLog = function() end -- ログ追加を無効化
    print("[af_hub] GUI を破棄しました")
end

-- ================================================================
--  AddLog 公開
-- ================================================================
function MyEngine:Log(msg, t)
    AddLog(msg, t)
end

-- ================================================================
getgenv().Rayfield = MyEngine
print("[af_hub] v4.6 起動完了 | トグルキー: " .. tostring(MyEngine.ToggleKey))
print("[af_hub] ─── V4.0 新機能 ───────────────────────────────────────")
print("[af_hub] [FIX] CreateLabel :Set()/:Get() が機能しないバグ修正済み")
print("[af_hub] [FIX] CreateColorPicker S/Vグラデーション更新バグ修正済み")
print("[af_hub] [FIX] CreateSection/Paragraph/Button 戻り値バグ修正済み")
print("[af_hub] [NEW] Tab:CreateMultiDropdown({Name,Options,CurrentOptions,MaxSelection,Callback})")
print("[af_hub] [NEW] Tab:CreateProgressBar({Name,MinValue,MaxValue,CurrentValue,Suffix,Color})")
print("[af_hub] [NEW] Tab:CreateDivider({Thickness,Color})")
print("[af_hub] [NEW] Tab:CreateInput() — CreateTextInputのエイリアス")
print("[af_hub] [NEW] Tab:Select()      — プログラムからタブを切り替える")
print("[af_hub] [NEW] Window:Dialog({Title,Content,Buttons={{Title,Color,Callback}...}})")
print("[af_hub] [NEW] Window:Destroy()  — ウィンドウを破棄する")
print("[af_hub] [NEW] Rayfield:Notify({Title,Content,Duration,Type}) — Type対応")
print("[af_hub] [NEW] Rayfield:SaveConfig('name') — Flagsを保存 (writefile必要)")
print("[af_hub] [NEW] Rayfield:LoadConfig('name') — Flagsを読込 (readfile必要)")
print("[af_hub] [NEW] Rayfield:Log('msg','Type')  — 任意ログ追加")
print("[af_hub] [NEW] Rayfield:Destroy()          — 全GUI破棄")
print("[af_hub] ─────────────────────────────────────────────────────────")
return MyEngine
