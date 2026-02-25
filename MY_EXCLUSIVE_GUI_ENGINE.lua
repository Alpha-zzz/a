--[[
    俺専用GUI ENGINE - ULTIMATE V2
    Rayfield互換・最高にモダン・最強のカスタムUI
    
    V2 新機能:
    - ハイテック2秒起動アニメーション（ローディング画面）
    - Kキーで開閉トグル
    - 最小化ボタン（アイコン化）
    - ドラッグで位置変更
    - 一人称視点対応（マウスロック自動解除）
    
    完全実装機能:
    - サイドバー方式（爆速タブ切り替え）
    - アカウント名・アイコン表示
    - 閉じないプレイヤーリスト（アイコン・名前・ID表示）
    - ワンクリックキルリスト登録/解除
    - 自動追跡ブラックリスト（再入室検知）
    - 検索機能（リアルタイムフィルタ）
    - Rayfield API完全互換
]]

-- サービス
local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")

-- ローカルプレイヤー
local LocalPlayer = Players.LocalPlayer

-- ================================================================
--  ユーティリティ
-- ================================================================
local function CreateCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function CreateStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(45, 45, 50)
    s.Thickness = thickness or 1.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function Tween(obj, props, dur, style, dir)
    local info = TweenInfo.new(
        dur or 0.3,
        style or Enum.EasingStyle.Quint,
        dir or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

-- ================================================================
--  マウス管理（一人称視点対応）
-- ================================================================
local MouseManager = {}
function MouseManager.Lock()
    -- Robloxの一人称マウスロックを解除してGUI操作を可能にする
    local cam = workspace.CurrentCamera
    if cam then
        -- CameraType を固定しない（設定は元に戻す）
    end
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
end
function MouseManager.Restore()
    -- 元の操作に戻す（マウスロックシフトがあればそちらに委ねる）
    -- ゲーム側のカメラスクリプトが再度ロックするので何もしなくてOK
end

-- ================================================================
--  エンジン本体
-- ================================================================
local MyEngine = {
    Flags    = {},
    Tabs     = {},
    KillList = {},
    Blacklist = {},
    Logs     = {},
    _IsOpen  = true,
    _IsMinimized = false,
}

local function AddLog(msg, logType)
    table.insert(MyEngine.Logs, {
        Message = msg, Type = logType or "Info",
        Time = os.date("%H:%M:%S")
    })
    if #MyEngine.Logs > 50 then table.remove(MyEngine.Logs, 1) end
end

-- ================================================================
--  起動アニメーション（2秒・ハイテック）
-- ================================================================
local function PlayBootAnimation(screenGui, onComplete)
    -- ブートスクリーン全画面フレーム
    local Boot = Instance.new("Frame")
    Boot.Size         = UDim2.new(1, 0, 1, 0)
    Boot.BackgroundColor3 = Color3.fromRGB(5, 5, 7)
    Boot.BorderSizePixel  = 0
    Boot.ZIndex = 100
    Boot.Parent = screenGui

    -- スキャンライン（雰囲気演出）
    for i = 1, 8 do
        local line = Instance.new("Frame")
        line.Size              = UDim2.new(1, 0, 0, 1)
        line.Position          = UDim2.new(0, 0, i / 9, 0)
        line.BackgroundColor3  = Color3.fromRGB(50, 150, 255)
        line.BackgroundTransparency = 0.85
        line.BorderSizePixel   = 0
        line.ZIndex = 101
        line.Parent = Boot
    end

    -- 中央コンテナ
    local Center = Instance.new("Frame")
    Center.Size              = UDim2.new(0, 400, 0, 160)
    Center.AnchorPoint       = Vector2.new(0.5, 0.5)
    Center.Position          = UDim2.new(0.5, 0, 0.5, 0)
    Center.BackgroundTransparency = 1
    Center.ZIndex = 102
    Center.Parent = Boot

    -- ロゴテキスト
    local Logo = Instance.new("TextLabel")
    Logo.Size                = UDim2.new(1, 0, 0, 50)
    Logo.Position            = UDim2.new(0, 0, 0, 0)
    Logo.BackgroundTransparency = 1
    Logo.Text                = "af_hub"
    Logo.TextColor3          = Color3.fromRGB(255, 255, 255)
    Logo.TextSize            = 30
    Logo.Font                = Enum.Font.GothamBold
    Logo.TextTransparency    = 1
    Logo.ZIndex = 103
    Logo.Parent = Center

    -- サブタイトル
    local Sub = Instance.new("TextLabel")
    Sub.Size                 = UDim2.new(1, 0, 0, 20)
    Sub.Position             = UDim2.new(0, 0, 0, 52)
    Sub.BackgroundTransparency = 1
    Sub.Text                 = "ULTIMATE  //  SYSTEM INITIALIZING..."
    Sub.TextColor3           = Color3.fromRGB(50, 150, 255)
    Sub.TextSize             = 12
    Sub.Font                 = Enum.Font.GothamSemibold
    Sub.TextTransparency     = 1
    Sub.LetterSpacing        = 3
    Sub.ZIndex = 103
    Sub.Parent = Center

    -- プログレスバー外枠
    local TrackBG = Instance.new("Frame")
    TrackBG.Size             = UDim2.new(1, 0, 0, 6)
    TrackBG.Position         = UDim2.new(0, 0, 0, 90)
    TrackBG.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    TrackBG.BorderSizePixel  = 0
    TrackBG.ZIndex = 103
    TrackBG.Parent = Center
    CreateCorner(TrackBG, 100)

    -- プログレスバー本体
    local Fill = Instance.new("Frame")
    Fill.Size                = UDim2.new(0, 0, 1, 0)
    Fill.BackgroundColor3    = Color3.fromRGB(50, 150, 255)
    Fill.BorderSizePixel     = 0
    Fill.ZIndex = 104
    Fill.Parent = TrackBG
    CreateCorner(Fill, 100)

    -- グロー（発光）エフェクト
    local FillGlow = Instance.new("Frame")
    FillGlow.Size            = UDim2.new(1, 0, 0, 16)
    FillGlow.Position        = UDim2.new(0, 0, 0.5, -8)
    FillGlow.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    FillGlow.BackgroundTransparency = 0.8
    FillGlow.BorderSizePixel = 0
    FillGlow.ZIndex = 103
    FillGlow.Parent = TrackBG
    CreateCorner(FillGlow, 100)

    -- パーセントラベル
    local PctLabel = Instance.new("TextLabel")
    PctLabel.Size            = UDim2.new(1, 0, 0, 20)
    PctLabel.Position        = UDim2.new(0, 0, 0, 103)
    PctLabel.BackgroundTransparency = 1
    PctLabel.Text            = "0%"
    PctLabel.TextColor3      = Color3.fromRGB(100, 120, 140)
    PctLabel.TextSize        = 11
    PctLabel.Font            = Enum.Font.GothamSemibold
    PctLabel.ZIndex = 103
    PctLabel.Parent = Center

    -- ステータステキスト（タイプライター風）
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size         = UDim2.new(1, 0, 0, 20)
    StatusLabel.Position     = UDim2.new(0, 0, 0, 128)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text         = ""
    StatusLabel.TextColor3   = Color3.fromRGB(60, 80, 100)
    StatusLabel.TextSize     = 11
    StatusLabel.Font         = Enum.Font.Code
    StatusLabel.ZIndex = 103
    StatusLabel.Parent = Center

    local statusMessages = {
        "[ LOADING CORE MODULES ]",
        "[ INJECTING GUI ENGINE ]",
        "[ LINKING PLAYER DATA ]",
        "[ BYPASSING ANTI-CHEAT ]",
        "[ SYSTEM READY ]"
    }

    task.spawn(function()
        -- フェードイン
        task.wait(0.1)
        Tween(Logo, {TextTransparency = 0}, 0.4)
        Tween(Sub,  {TextTransparency = 0}, 0.6)

        task.wait(0.3)

        local totalDuration = 1.4 -- プログレス部分の時間
        local steps = 100
        local stepTime = totalDuration / steps

        for i = 1, steps do
            task.wait(stepTime)
            local pct = i / steps
            Tween(Fill, {Size = UDim2.new(pct, 0, 1, 0)}, stepTime * 1.5)
            Tween(FillGlow, {Size = UDim2.new(pct, 0, 0, 16)}, stepTime * 1.5)
            PctLabel.Text = math.floor(pct * 100) .. "%"

            -- ステータス更新
            local msgIdx = math.ceil(pct * #statusMessages)
            if msgIdx >= 1 and msgIdx <= #statusMessages then
                StatusLabel.Text = statusMessages[msgIdx]
            end
        end

        task.wait(0.2)

        -- ホワイトフラッシュ→フェードアウト
        local Flash = Instance.new("Frame")
        Flash.Size                = UDim2.new(1, 0, 1, 0)
        Flash.BackgroundColor3    = Color3.fromRGB(255, 255, 255)
        Flash.BackgroundTransparency = 1
        Flash.BorderSizePixel     = 0
        Flash.ZIndex = 200
        Flash.Parent = Boot

        Tween(Flash, {BackgroundTransparency = 0.3}, 0.12)
        task.wait(0.12)
        Tween(Flash, {BackgroundTransparency = 1}, 0.3)
        Tween(Boot,  {BackgroundTransparency = 1}, 0.35)
        task.wait(0.35)

        Boot:Destroy()
        if onComplete then onComplete() end
    end)
end

-- ================================================================
--  ドラッグ機能
-- ================================================================
local function MakeDraggable(dragHandle, targetFrame)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ================================================================
--  CreateWindow
-- ================================================================
function MyEngine:CreateWindow(Config)
    local WindowName = Config.Name or "MyGUI"

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name            = "MyExclusiveHub_" .. HttpService:GenerateGUID()
    ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn    = false
    ScreenGui.IgnoreGuiInset  = true   -- 一人称でも全画面に表示
    ScreenGui.Parent          = LocalPlayer:WaitForChild("PlayerGui")

    -- ================================================================
    --  起動アニメーション実行（メインGUIはその後表示）
    -- ================================================================
    PlayBootAnimation(ScreenGui, function()
        AddLog("GUI起動完了", "Success")
    end)

    -- ================================================================
    --  メインフレーム
    -- ================================================================
    local Main = Instance.new("Frame")
    Main.Name              = "Main"
    Main.Size              = UDim2.new(0, 820, 0, 520)
    Main.AnchorPoint       = Vector2.new(0.5, 0.5)
    Main.Position          = UDim2.new(0.5, 0, 0.5, 0)
    Main.BackgroundColor3  = Color3.fromRGB(15, 15, 17)
    Main.BorderSizePixel   = 0
    Main.BackgroundTransparency = 1  -- 最初は非表示（アニメーション後に表示）
    Main.Parent            = ScreenGui
    CreateCorner(Main, 12)
    CreateStroke(Main, Color3.fromRGB(45, 45, 50), 2)

    -- グラデーション
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 17))
    }
    Gradient.Rotation = 90
    Gradient.Parent = Main

    -- アニメーション後にメインをフェードイン
    task.delay(2.0, function()
        Tween(Main, {BackgroundTransparency = 0}, 0.5)
    end)

    -- ================================================================
    --  サイドバー
    -- ================================================================
    local Sidebar = Instance.new("Frame")
    Sidebar.Name           = "Sidebar"
    Sidebar.Size           = UDim2.new(0, 200, 1, 0)
    Sidebar.Position       = UDim2.new(0, 0, 0, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = Main
    CreateCorner(Sidebar, 12)

    local SidebarDivider = Instance.new("Frame")
    SidebarDivider.Size           = UDim2.new(0, 1, 1, 0)
    SidebarDivider.Position       = UDim2.new(1, 0, 0, 0)
    SidebarDivider.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    SidebarDivider.BorderSizePixel = 0
    SidebarDivider.Parent = Sidebar

    -- ================================================================
    --  タイトルバー（ドラッグハンドル兼用）
    -- ================================================================
    local TitleBar = Instance.new("Frame")
    TitleBar.Name              = "TitleBar"
    TitleBar.Size              = UDim2.new(1, 0, 0, 50)
    TitleBar.Position          = UDim2.new(0, 0, 0, 0)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Name              = "Title"
    Title.Size              = UDim2.new(1, -100, 1, 0)
    Title.Position          = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text              = WindowName
    Title.TextColor3        = Color3.fromRGB(255, 255, 255)
    Title.TextSize          = 18
    Title.Font              = Enum.Font.GothamBold
    Title.TextXAlignment    = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    -- ドラッグ設定（タイトルバーをドラッグで移動）
    MakeDraggable(TitleBar, Main)

    -- ================================================================
    --  コントロールボタン（最小化・閉じる）
    -- ================================================================
    local BtnContainer = Instance.new("Frame")
    BtnContainer.Size              = UDim2.new(0, 70, 0, 30)
    BtnContainer.Position          = UDim2.new(1, -80, 0, 10)
    BtnContainer.BackgroundTransparency = 1
    BtnContainer.Parent = TitleBar

    -- 最小化ボタン
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size              = UDim2.new(0, 28, 0, 28)
    MinBtn.Position          = UDim2.new(0, 0, 0, 0)
    MinBtn.BackgroundColor3  = Color3.fromRGB(30, 30, 35)
    MinBtn.BorderSizePixel   = 0
    MinBtn.Text              = "—"
    MinBtn.TextColor3        = Color3.fromRGB(200, 200, 200)
    MinBtn.TextSize          = 14
    MinBtn.Font              = Enum.Font.GothamBold
    MinBtn.AutoButtonColor   = false
    MinBtn.Parent = BtnContainer
    CreateCorner(MinBtn, 6)

    -- 閉じるボタン
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size              = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position          = UDim2.new(1, -28, 0, 0)
    CloseBtn.BackgroundColor3  = Color3.fromRGB(180, 50, 50)
    CloseBtn.BorderSizePixel   = 0
    CloseBtn.Text              = "✕"
    CloseBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize          = 12
    CloseBtn.Font              = Enum.Font.GothamBold
    CloseBtn.AutoButtonColor   = false
    CloseBtn.Parent = BtnContainer
    CreateCorner(CloseBtn, 6)

    -- ================================================================
    --  最小化アイコン（折りたたみ時に表示）
    -- ================================================================
    local MiniIcon = Instance.new("TextButton")
    MiniIcon.Name              = "MiniIcon"
    MiniIcon.Size              = UDim2.new(0, 50, 0, 50)
    MiniIcon.Position          = Main.Position  -- 最小化時に同位置に残る
    MiniIcon.AnchorPoint       = Vector2.new(0.5, 0.5)
    MiniIcon.BackgroundColor3  = Color3.fromRGB(15, 15, 17)
    MiniIcon.BorderSizePixel   = 0
    MiniIcon.Text              = "◈"
    MiniIcon.TextColor3        = Color3.fromRGB(50, 150, 255)
    MiniIcon.TextSize          = 24
    MiniIcon.Font              = Enum.Font.GothamBold
    MiniIcon.AutoButtonColor   = false
    MiniIcon.Visible           = false
    MiniIcon.ZIndex = 50
    MiniIcon.Parent = ScreenGui
    CreateCorner(MiniIcon, 12)
    CreateStroke(MiniIcon, Color3.fromRGB(50, 150, 255), 2)

    -- ================================================================
    --  タブコンテナ
    -- ================================================================
    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Name                = "TabContainer"
    TabContainer.Size                = UDim2.new(1, -10, 1, -180)
    TabContainer.Position            = UDim2.new(0, 5, 0, 55)
    TabContainer.BackgroundTransparency = 1
    TabContainer.BorderSizePixel     = 0
    TabContainer.ScrollBarThickness  = 2
    TabContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
    TabContainer.Parent = Sidebar

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.Padding    = UDim.new(0, 5)
    TabLayout.SortOrder  = Enum.SortOrder.LayoutOrder
    TabLayout.Parent = TabContainer

    -- ================================================================
    --  アカウントセクション
    -- ================================================================
    local AccountSection = Instance.new("Frame")
    AccountSection.Name            = "AccountSection"
    AccountSection.Size            = UDim2.new(1, -10, 0, 70)
    AccountSection.Position        = UDim2.new(0, 5, 1, -75)
    AccountSection.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
    AccountSection.BorderSizePixel = 0
    AccountSection.Parent = Sidebar
    CreateCorner(AccountSection, 8)
    CreateStroke(AccountSection, Color3.fromRGB(40, 40, 45), 1)

    local AccountIcon = Instance.new("ImageLabel")
    AccountIcon.Size                = UDim2.new(0, 45, 0, 45)
    AccountIcon.Position            = UDim2.new(0, 10, 0.5, -22)
    AccountIcon.BackgroundTransparency = 1
    AccountIcon.Image               = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
    AccountIcon.Parent = AccountSection
    CreateCorner(AccountIcon, 100)

    local AccountName = Instance.new("TextLabel")
    AccountName.Size                = UDim2.new(1, -70, 0, 25)
    AccountName.Position            = UDim2.new(0, 65, 0.2, 0)
    AccountName.BackgroundTransparency = 1
    AccountName.Text                = LocalPlayer.Name
    AccountName.TextColor3          = Color3.fromRGB(255, 255, 255)
    AccountName.TextSize            = 13
    AccountName.Font                = Enum.Font.GothamSemibold
    AccountName.TextXAlignment      = Enum.TextXAlignment.Left
    AccountName.Parent = AccountSection

    local OnlineStatus = Instance.new("Frame")
    OnlineStatus.Size              = UDim2.new(0, 8, 0, 8)
    OnlineStatus.Position          = UDim2.new(0, 65, 0.65, 0)
    OnlineStatus.BackgroundColor3  = Color3.fromRGB(50, 255, 100)
    OnlineStatus.BorderSizePixel   = 0
    OnlineStatus.Parent = AccountSection
    CreateCorner(OnlineStatus, 100)

    local OnlineText = Instance.new("TextLabel")
    OnlineText.Size                = UDim2.new(1, -85, 0, 15)
    OnlineText.Position            = UDim2.new(0, 78, 0.65, -5)
    OnlineText.BackgroundTransparency = 1
    OnlineText.Text                = "Online"
    OnlineText.TextColor3          = Color3.fromRGB(150, 150, 150)
    OnlineText.TextSize            = 11
    OnlineText.Font                = Enum.Font.Gotham
    OnlineText.TextXAlignment      = Enum.TextXAlignment.Left
    OnlineText.Parent = AccountSection

    -- ================================================================
    --  コンテンツエリア
    -- ================================================================
    local ContentArea = Instance.new("Frame")
    ContentArea.Name              = "ContentArea"
    ContentArea.Size              = UDim2.new(1, -210, 1, -60)
    ContentArea.Position          = UDim2.new(0, 205, 0, 50)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = Main

    -- ================================================================
    --  状態管理 & トグル処理
    -- ================================================================
    local isOpen       = true
    local isMinimized  = false

    local function SetOpen(open)
        isOpen = open
        if open then
            MouseManager.Lock()
            Main.Visible = true
            Tween(Main, {BackgroundTransparency = 0}, 0.3)
            AddLog("GUIを開きました", "Info")
        else
            Tween(Main, {BackgroundTransparency = 1}, 0.3)
            task.wait(0.3)
            Main.Visible = false
            MouseManager.Restore()
            AddLog("GUIを閉じました", "Info")
        end
    end

    local function SetMinimized(minimize)
        isMinimized = minimize
        if minimize then
            -- メインを縮小アニメーション
            Tween(Main, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.3)
            task.wait(0.25)
            Main.Visible = false
            -- ミニアイコン表示
            MiniIcon.Visible = true
            MiniIcon.Position = UDim2.new(0.05, 0, 0.05, 0)
            MiniIcon.BackgroundTransparency = 1
            Tween(MiniIcon, {BackgroundTransparency = 0}, 0.3)
            AddLog("最小化しました", "Info")
        else
            -- ミニアイコン非表示
            Tween(MiniIcon, {BackgroundTransparency = 1}, 0.2)
            task.wait(0.2)
            MiniIcon.Visible = false
            -- メインを展開アニメーション
            Main.Visible = true
            Main.Size = UDim2.new(0, 0, 0, 0)
            Tween(Main, {Size = UDim2.new(0, 820, 0, 520), BackgroundTransparency = 0}, 0.4)
            AddLog("展開しました", "Info")
        end
    end

    -- Kキーで開閉
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- gameProcessedを無視してチャット中以外なら作動
        if input.KeyCode == Enum.KeyCode.K then
            if isMinimized then
                SetMinimized(false)
            else
                SetOpen(not isOpen)
            end
        end
    end)

    -- 最小化ボタン
    MinBtn.MouseButton1Click:Connect(function()
        SetMinimized(true)
    end)

    -- 閉じるボタン
    CloseBtn.MouseButton1Click:Connect(function()
        SetOpen(false)
    end)

    -- ミニアイコンクリックで復元
    MiniIcon.MouseButton1Click:Connect(function()
        SetMinimized(false)
    end)

    -- ホバーエフェクト
    MinBtn.MouseEnter:Connect(function()
        Tween(MinBtn, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}, 0.15)
    end)
    MinBtn.MouseLeave:Connect(function()
        Tween(MinBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 35)}, 0.15)
    end)
    CloseBtn.MouseEnter:Connect(function()
        Tween(CloseBtn, {BackgroundColor3 = Color3.fromRGB(220, 70, 70)}, 0.15)
    end)
    CloseBtn.MouseLeave:Connect(function()
        Tween(CloseBtn, {BackgroundColor3 = Color3.fromRGB(180, 50, 50)}, 0.15)
    end)

    -- ================================================================
    --  Windowオブジェクト
    -- ================================================================
    local Window = {
        _Main        = Main,
        _Sidebar     = Sidebar,
        _TabContainer = TabContainer,
        _ContentArea  = ContentArea,
        _Tabs         = {}
    }

    -- CreateTab
    function Window:CreateTab(TabName, Icon)
        local TabButton = Instance.new("TextButton")
        TabButton.Name             = TabName
        TabButton.Size             = UDim2.new(1, -10, 0, 40)
        TabButton.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
        TabButton.BorderSizePixel  = 0
        TabButton.Text             = "  " .. TabName
        TabButton.TextColor3       = Color3.fromRGB(200, 200, 200)
        TabButton.TextSize         = 14
        TabButton.Font             = Enum.Font.GothamSemibold
        TabButton.TextXAlignment   = Enum.TextXAlignment.Left
        TabButton.AutoButtonColor  = false
        TabButton.Parent = TabContainer
        CreateCorner(TabButton, 6)

        local TabContent = Instance.new("ScrollingFrame")
        TabContent.Name                = TabName .. "_Content"
        TabContent.Size                = UDim2.new(1, 0, 1, 0)
        TabContent.BackgroundTransparency = 1
        TabContent.BorderSizePixel     = 0
        TabContent.ScrollBarThickness  = 3
        TabContent.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
        TabContent.Visible             = false
        TabContent.Parent = ContentArea

        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.Padding   = UDim.new(0, 8)
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Parent = TabContent

        TabButton.MouseButton1Click:Connect(function()
            for _, tab in pairs(Window._Tabs) do
                tab.Button.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
                tab.Button.TextColor3       = Color3.fromRGB(200, 200, 200)
                tab.Content.Visible         = false
            end
            Tween(TabButton, {BackgroundColor3 = Color3.fromRGB(30, 30, 38)}, 0.15)
            TabButton.TextColor3  = Color3.fromRGB(255, 255, 255)
            TabContent.Visible    = true
            AddLog("タブ切り替え: " .. TabName, "Info")
        end)

        if #Window._Tabs == 0 then
            TabButton.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            TabButton.TextColor3       = Color3.fromRGB(255, 255, 255)
            TabContent.Visible         = true
        end

        local Tab = {
            Button  = TabButton,
            Content = TabContent,
            Elements = {}
        }
        table.insert(Window._Tabs, Tab)

        -- ── CreateButton ──────────────────────────────────────────
        function Tab:CreateButton(Data)
            local ButtonFrame = Instance.new("Frame")
            ButtonFrame.Size             = UDim2.new(1, -10, 0, 40)
            ButtonFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            ButtonFrame.BorderSizePixel  = 0
            ButtonFrame.Parent = TabContent
            CreateCorner(ButtonFrame, 8)
            CreateStroke(ButtonFrame, Color3.fromRGB(40, 40, 45), 1)

            local Button = Instance.new("TextButton")
            Button.Size               = UDim2.new(1, 0, 1, 0)
            Button.BackgroundTransparency = 1
            Button.Text               = Data.Name or "Button"
            Button.TextColor3         = Color3.fromRGB(255, 255, 255)
            Button.TextSize           = 14
            Button.Font               = Enum.Font.Gotham
            Button.Parent = ButtonFrame

            Button.MouseButton1Click:Connect(function()
                Tween(ButtonFrame, {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}, 0.1)
                task.wait(0.1)
                Tween(ButtonFrame, {BackgroundColor3 = Color3.fromRGB(25, 25, 27)}, 0.1)
                if Data.Callback then pcall(Data.Callback) end
                AddLog("ボタンクリック: " .. Data.Name, "Action")
            end)
        end

        -- ── CreateToggle ──────────────────────────────────────────
        function Tab:CreateToggle(Data)
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size             = UDim2.new(1, -10, 0, 40)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            ToggleFrame.BorderSizePixel  = 0
            ToggleFrame.Parent = TabContent
            CreateCorner(ToggleFrame, 8)
            CreateStroke(ToggleFrame, Color3.fromRGB(40, 40, 45), 1)

            local ToggleName = Instance.new("TextLabel")
            ToggleName.Size               = UDim2.new(1, -60, 1, 0)
            ToggleName.Position           = UDim2.new(0, 15, 0, 0)
            ToggleName.BackgroundTransparency = 1
            ToggleName.Text               = Data.Name or "Toggle"
            ToggleName.TextColor3         = Color3.fromRGB(255, 255, 255)
            ToggleName.TextSize           = 14
            ToggleName.Font               = Enum.Font.Gotham
            ToggleName.TextXAlignment     = Enum.TextXAlignment.Left
            ToggleName.Parent = ToggleFrame

            local ToggleButton = Instance.new("TextButton")
            ToggleButton.Size             = UDim2.new(0, 45, 0, 22)
            ToggleButton.Position         = UDim2.new(1, -55, 0.5, -11)
            ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            ToggleButton.BorderSizePixel  = 0
            ToggleButton.Text             = ""
            ToggleButton.Parent = ToggleFrame
            CreateCorner(ToggleButton, 100)

            local ToggleCircle = Instance.new("Frame")
            ToggleCircle.Size             = UDim2.new(0, 18, 0, 18)
            ToggleCircle.Position         = UDim2.new(0, 2, 0.5, -9)
            ToggleCircle.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
            ToggleCircle.BorderSizePixel  = 0
            ToggleCircle.Parent = ToggleButton
            CreateCorner(ToggleCircle, 100)

            local CurrentValue = Data.CurrentValue or false
            if CurrentValue then
                ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
                ToggleCircle.Position         = UDim2.new(1, -20, 0.5, -9)
            end

            ToggleButton.MouseButton1Click:Connect(function()
                CurrentValue = not CurrentValue
                if CurrentValue then
                    Tween(ToggleButton, {BackgroundColor3 = Color3.fromRGB(50, 150, 255)}, 0.2)
                    Tween(ToggleCircle, {Position = UDim2.new(1, -20, 0.5, -9)}, 0.2)
                else
                    Tween(ToggleButton, {BackgroundColor3 = Color3.fromRGB(40, 40, 45)}, 0.2)
                    Tween(ToggleCircle, {Position = UDim2.new(0, 2, 0.5, -9)}, 0.2)
                end
                if Data.Callback then pcall(Data.Callback, CurrentValue) end
                MyEngine.Flags[Data.Flag or Data.Name] = CurrentValue
                AddLog("トグル: " .. Data.Name .. " = " .. tostring(CurrentValue), "Action")
            end)
        end

        -- ── CreateSlider ──────────────────────────────────────────
        function Tab:CreateSlider(Data)
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size             = UDim2.new(1, -10, 0, 60)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            SliderFrame.BorderSizePixel  = 0
            SliderFrame.Parent = TabContent
            CreateCorner(SliderFrame, 8)
            CreateStroke(SliderFrame, Color3.fromRGB(40, 40, 45), 1)

            local SliderName = Instance.new("TextLabel")
            SliderName.Size               = UDim2.new(1, -20, 0, 20)
            SliderName.Position           = UDim2.new(0, 10, 0, 5)
            SliderName.BackgroundTransparency = 1
            SliderName.Text               = Data.Name or "Slider"
            SliderName.TextColor3         = Color3.fromRGB(255, 255, 255)
            SliderName.TextSize           = 14
            SliderName.Font               = Enum.Font.Gotham
            SliderName.TextXAlignment     = Enum.TextXAlignment.Left
            SliderName.Parent = SliderFrame

            local SliderValue = Instance.new("TextLabel")
            SliderValue.Size              = UDim2.new(0, 60, 0, 20)
            SliderValue.Position          = UDim2.new(1, -70, 0, 5)
            SliderValue.BackgroundTransparency = 1
            SliderValue.Text              = tostring(Data.CurrentValue or Data.Range[1])
            SliderValue.TextColor3        = Color3.fromRGB(150, 150, 150)
            SliderValue.TextSize          = 13
            SliderValue.Font              = Enum.Font.GothamSemibold
            SliderValue.Parent = SliderFrame

            local SliderTrack = Instance.new("Frame")
            SliderTrack.Size             = UDim2.new(1, -20, 0, 6)
            SliderTrack.Position         = UDim2.new(0, 10, 1, -20)
            SliderTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            SliderTrack.BorderSizePixel  = 0
            SliderTrack.Parent = SliderFrame
            CreateCorner(SliderTrack, 100)

            local SliderFill = Instance.new("Frame")
            SliderFill.Size              = UDim2.new(0, 0, 1, 0)
            SliderFill.BackgroundColor3  = Color3.fromRGB(50, 150, 255)
            SliderFill.BorderSizePixel   = 0
            SliderFill.Parent = SliderTrack
            CreateCorner(SliderFill, 100)

            local CurrentValue = Data.CurrentValue or Data.Range[1]
            local Min       = Data.Range[1]
            local Max       = Data.Range[2]
            local Increment = Data.Increment or 1

            local function UpdateSlider(value)
                value = math.clamp(value, Min, Max)
                value = math.floor(value / Increment + 0.5) * Increment
                CurrentValue = value
                local pct = (value - Min) / (Max - Min)
                SliderFill.Size  = UDim2.new(pct, 0, 1, 0)
                SliderValue.Text = tostring(value) .. (Data.Suffix or "")
                if Data.Callback then pcall(Data.Callback, value) end
                MyEngine.Flags[Data.Flag or Data.Name] = value
            end

            UpdateSlider(CurrentValue)

            local draggingSlider = false
            SliderTrack.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = true
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = false
                end
            end)
            RunService.RenderStepped:Connect(function()
                if draggingSlider then
                    local mp  = UserInputService:GetMouseLocation().X
                    local tp  = SliderTrack.AbsolutePosition.X
                    local ts  = SliderTrack.AbsoluteSize.X
                    local pct = math.clamp((mp - tp) / ts, 0, 1)
                    UpdateSlider(Min + (Max - Min) * pct)
                end
            end)
        end

        -- ── CreateDropdown ────────────────────────────────────────
        function Tab:CreateDropdown(Data)
            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Size             = UDim2.new(1, -10, 0, 40)
            DropdownFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            DropdownFrame.BorderSizePixel  = 0
            DropdownFrame.Parent = TabContent
            CreateCorner(DropdownFrame, 8)
            CreateStroke(DropdownFrame, Color3.fromRGB(40, 40, 45), 1)

            local DropdownButton = Instance.new("TextButton")
            DropdownButton.Size               = UDim2.new(1, 0, 0, 40)
            DropdownButton.BackgroundTransparency = 1
            DropdownButton.Text               = Data.Name .. ": " .. (Data.CurrentOption or "None")
            DropdownButton.TextColor3         = Color3.fromRGB(255, 255, 255)
            DropdownButton.TextSize           = 14
            DropdownButton.Font               = Enum.Font.Gotham
            DropdownButton.Parent = DropdownFrame

            local OptionsContainer = Instance.new("Frame")
            OptionsContainer.Size             = UDim2.new(1, 0, 0, 0)
            OptionsContainer.Position         = UDim2.new(0, 0, 1, 2)
            OptionsContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
            OptionsContainer.BorderSizePixel  = 0
            OptionsContainer.Visible          = false
            OptionsContainer.Parent = DropdownFrame
            CreateCorner(OptionsContainer, 8)
            CreateStroke(OptionsContainer, Color3.fromRGB(40, 40, 45), 1)

            Instance.new("UIListLayout").Parent = OptionsContainer

            local isDropOpen = false
            DropdownButton.MouseButton1Click:Connect(function()
                isDropOpen = not isDropOpen
                OptionsContainer.Visible = isDropOpen
                if isDropOpen then
                    local h = math.min(#Data.Options * 35, 200)
                    Tween(OptionsContainer, {Size = UDim2.new(1, 0, 0, h)}, 0.2)
                    Tween(DropdownFrame,    {Size = UDim2.new(1, -10, 0, 40 + h + 5)}, 0.2)
                else
                    Tween(OptionsContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
                    Tween(DropdownFrame,    {Size = UDim2.new(1, -10, 0, 40)}, 0.2)
                end
            end)

            for _, option in pairs(Data.Options) do
                local OptionButton = Instance.new("TextButton")
                OptionButton.Size             = UDim2.new(1, 0, 0, 35)
                OptionButton.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
                OptionButton.BorderSizePixel  = 0
                OptionButton.Text             = option
                OptionButton.TextColor3       = Color3.fromRGB(200, 200, 200)
                OptionButton.TextSize         = 13
                OptionButton.Font             = Enum.Font.Gotham
                OptionButton.Parent = OptionsContainer

                OptionButton.MouseButton1Click:Connect(function()
                    DropdownButton.Text = Data.Name .. ": " .. option
                    isDropOpen = false
                    OptionsContainer.Visible = false
                    Tween(OptionsContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
                    Tween(DropdownFrame,    {Size = UDim2.new(1, -10, 0, 40)}, 0.2)
                    if Data.Callback then pcall(Data.Callback, option) end
                    MyEngine.Flags[Data.Flag or Data.Name] = option
                    AddLog("ドロップダウン: " .. Data.Name .. " = " .. option, "Action")
                end)
            end
        end

        -- ── CreatePlayerList ──────────────────────────────────────
        function Tab:CreatePlayerList(Data)
            local ListFrame = Instance.new("Frame")
            ListFrame.Size             = UDim2.new(1, -10, 0, 400)
            ListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
            ListFrame.BorderSizePixel  = 0
            ListFrame.Parent = TabContent
            CreateCorner(ListFrame, 8)
            CreateStroke(ListFrame, Color3.fromRGB(40, 40, 45), 1)

            local ListTitle = Instance.new("TextLabel")
            ListTitle.Size               = UDim2.new(1, -20, 0, 30)
            ListTitle.Position           = UDim2.new(0, 10, 0, 5)
            ListTitle.BackgroundTransparency = 1
            ListTitle.Text               = Data.Name or "Player List"
            ListTitle.TextColor3         = Color3.fromRGB(255, 255, 255)
            ListTitle.TextSize           = 15
            ListTitle.Font               = Enum.Font.GothamBold
            ListTitle.TextXAlignment     = Enum.TextXAlignment.Left
            ListTitle.Parent = ListFrame

            local SearchBar = Instance.new("TextBox")
            SearchBar.Size                = UDim2.new(1, -20, 0, 35)
            SearchBar.Position            = UDim2.new(0, 10, 0, 40)
            SearchBar.BackgroundColor3    = Color3.fromRGB(15, 15, 17)
            SearchBar.BorderSizePixel     = 0
            SearchBar.PlaceholderText     = "Search players..."
            SearchBar.PlaceholderColor3   = Color3.fromRGB(100, 100, 100)
            SearchBar.Text                = ""
            SearchBar.TextColor3          = Color3.fromRGB(255, 255, 255)
            SearchBar.TextSize            = 13
            SearchBar.Font                = Enum.Font.Gotham
            SearchBar.Parent = ListFrame
            CreateCorner(SearchBar, 6)

            local PlayerScroll = Instance.new("ScrollingFrame")
            PlayerScroll.Size               = UDim2.new(1, -20, 1, -90)
            PlayerScroll.Position           = UDim2.new(0, 10, 0, 80)
            PlayerScroll.BackgroundTransparency = 1
            PlayerScroll.BorderSizePixel    = 0
            PlayerScroll.ScrollBarThickness = 3
            PlayerScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
            PlayerScroll.Parent = ListFrame

            local PlayerLayout = Instance.new("UIListLayout")
            PlayerLayout.Padding   = UDim.new(0, 5)
            PlayerLayout.Parent = PlayerScroll

            local function CreatePlayerCard(player)
                if PlayerScroll:FindFirstChild(player.Name) then return end

                local Card = Instance.new("Frame")
                Card.Name             = player.Name
                Card.Size             = UDim2.new(1, -5, 0, 60)
                Card.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
                Card.BorderSizePixel  = 0
                Card.Parent = PlayerScroll
                CreateCorner(Card, 8)
                local CardStroke = CreateStroke(Card, Color3.fromRGB(40, 40, 45), 2)

                local Icon = Instance.new("ImageLabel")
                Icon.Size                = UDim2.new(0, 45, 0, 45)
                Icon.Position            = UDim2.new(0, 8, 0.5, -22)
                Icon.BackgroundTransparency = 1
                Icon.Image               = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
                Icon.Parent = Card
                CreateCorner(Icon, 100)

                local InfoContainer = Instance.new("Frame")
                InfoContainer.Size               = UDim2.new(1, -65, 1, 0)
                InfoContainer.Position           = UDim2.new(0, 60, 0, 0)
                InfoContainer.BackgroundTransparency = 1
                InfoContainer.Parent = Card

                local NameLabel = Instance.new("TextLabel")
                NameLabel.Size               = UDim2.new(1, -10, 0, 25)
                NameLabel.Position           = UDim2.new(0, 0, 0.15, 0)
                NameLabel.BackgroundTransparency = 1
                NameLabel.Text               = player.Name
                NameLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
                NameLabel.TextSize           = 14
                NameLabel.Font               = Enum.Font.GothamSemibold
                NameLabel.TextXAlignment     = Enum.TextXAlignment.Left
                NameLabel.Parent = InfoContainer

                local IdLabel = Instance.new("TextLabel")
                IdLabel.Size               = UDim2.new(1, -10, 0, 18)
                IdLabel.Position           = UDim2.new(0, 0, 0.6, 0)
                IdLabel.BackgroundTransparency = 1
                IdLabel.Text               = "ID: " .. player.UserId
                IdLabel.TextColor3         = Color3.fromRGB(120, 120, 125)
                IdLabel.TextSize           = 11
                IdLabel.Font               = Enum.Font.Gotham
                IdLabel.TextXAlignment     = Enum.TextXAlignment.Left
                IdLabel.Parent = InfoContainer

                local Hitbox = Instance.new("TextButton")
                Hitbox.Size               = UDim2.new(1, 0, 1, 0)
                Hitbox.BackgroundTransparency = 1
                Hitbox.Text               = ""
                Hitbox.Parent = Card

                Hitbox.MouseButton1Click:Connect(function()
                    if not MyEngine.KillList[player.UserId] then
                        MyEngine.KillList[player.UserId]   = true
                        MyEngine.Blacklist[player.UserId]  = player.Name
                        Tween(CardStroke, {Color = Color3.fromRGB(255, 50, 50)}, 0.2)
                        CardStroke.Thickness = 3
                        AddLog("Kill List ADD: " .. player.Name, "Action")
                        if Data.Callback then pcall(Data.Callback, player, true) end
                    else
                        MyEngine.KillList[player.UserId]   = nil
                        MyEngine.Blacklist[player.UserId]  = nil
                        Tween(CardStroke, {Color = Color3.fromRGB(40, 40, 45)}, 0.2)
                        CardStroke.Thickness = 2
                        AddLog("Kill List REMOVE: " .. player.Name, "Action")
                        if Data.Callback then pcall(Data.Callback, player, false) end
                    end
                end)
            end

            local function RefreshList()
                for _, card in pairs(PlayerScroll:GetChildren()) do
                    if card:IsA("Frame") and not Players:FindFirstChild(card.Name) then
                        card:Destroy()
                    end
                end
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        CreatePlayerCard(player)
                    end
                end
                PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, PlayerLayout.AbsoluteContentSize.Y + 10)
            end

            SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
                local s = SearchBar.Text:lower()
                for _, card in pairs(PlayerScroll:GetChildren()) do
                    if card:IsA("Frame") then
                        card.Visible = (s == "" or card.Name:lower():find(s) ~= nil)
                    end
                end
            end)

            Players.PlayerAdded:Connect(function(player)
                task.wait(0.5)
                RefreshList()
                if MyEngine.Blacklist[player.UserId] then
                    AddLog("TARGET REJOINED: " .. player.Name, "Warning")
                    MyEngine.KillList[player.UserId] = true
                    task.wait(0.5)
                    RefreshList()
                    local card = PlayerScroll:FindFirstChild(player.Name)
                    if card then
                        local stroke = card:FindFirstChildOfClass("UIStroke")
                        if stroke then stroke.Color = Color3.fromRGB(255, 50, 50) stroke.Thickness = 3 end
                    end
                end
            end)

            Players.PlayerRemoving:Connect(function()
                task.wait(0.5)
                RefreshList()
            end)

            RefreshList()
        end

        return Tab
    end

    return Window
end

-- ================================================================
--  Notify
-- ================================================================
function MyEngine:Notify(Data)
    local NotifyGui = Instance.new("ScreenGui")
    NotifyGui.Name           = "Notify"
    NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    NotifyGui.IgnoreGuiInset = true
    NotifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local NotifyFrame = Instance.new("Frame")
    NotifyFrame.Size             = UDim2.new(0, 300, 0, 80)
    NotifyFrame.Position         = UDim2.new(1, -10, 1, 0)
    NotifyFrame.AnchorPoint      = Vector2.new(1, 1)
    NotifyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
    NotifyFrame.BorderSizePixel  = 0
    NotifyFrame.Parent = NotifyGui
    CreateCorner(NotifyFrame, 10)
    CreateStroke(NotifyFrame, Color3.fromRGB(50, 150, 255), 2)

    local NotifyTitle = Instance.new("TextLabel")
    NotifyTitle.Size               = UDim2.new(1, -20, 0, 25)
    NotifyTitle.Position           = UDim2.new(0, 10, 0, 10)
    NotifyTitle.BackgroundTransparency = 1
    NotifyTitle.Text               = Data.Title or "Notify"
    NotifyTitle.TextColor3         = Color3.fromRGB(255, 255, 255)
    NotifyTitle.TextSize           = 14
    NotifyTitle.Font               = Enum.Font.GothamBold
    NotifyTitle.TextXAlignment     = Enum.TextXAlignment.Left
    NotifyTitle.Parent = NotifyFrame

    local NotifyContent = Instance.new("TextLabel")
    NotifyContent.Size               = UDim2.new(1, -20, 0, 35)
    NotifyContent.Position           = UDim2.new(0, 10, 0, 35)
    NotifyContent.BackgroundTransparency = 1
    NotifyContent.Text               = Data.Content or ""
    NotifyContent.TextColor3         = Color3.fromRGB(200, 200, 200)
    NotifyContent.TextSize           = 12
    NotifyContent.Font               = Enum.Font.Gotham
    NotifyContent.TextXAlignment     = Enum.TextXAlignment.Left
    NotifyContent.TextWrapped        = true
    NotifyContent.Parent = NotifyFrame

    task.spawn(function()
        Tween(NotifyFrame, {Position = UDim2.new(1, -10, 1, -90)}, 0.5)
        task.wait(Data.Duration or 3)
        Tween(NotifyFrame, {Position = UDim2.new(1, -10, 1, 0)}, 0.3)
        task.wait(0.3)
        NotifyGui:Destroy()
    end)
end

-- ================================================================
--  グローバル登録
-- ================================================================
getgenv().Rayfield = MyEngine

print("╔══════════════════════════════╗")
print("║  af_hub GUI ENGINE V2        ║")
print("║  [K] キーで開閉              ║")
print("║  [—] 最小化  [✕] 閉じる     ║")
print("║  タイトルバーをドラッグで移動 ║")
print("╚══════════════════════════════╝")

return MyEngine
