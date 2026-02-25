-- af_hub GUI ENGINE - ULTIMATE V2.5
-- Rayfield互換 / 完全日本語 / 一人称視点対応

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local Stats            = game:GetService("Stats")

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
    s.Color = col or Color3.fromRGB(45,45,50)
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
        math.floor(t/3600)%24, math.floor(t/60)%60, math.floor(t)%60)
end

local function MkLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.SourceSans
    l.TextColor3 = Color3.fromRGB(255,255,255)
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k,v in pairs(props) do pcall(function() l[k] = v end) end
    l.Parent = parent
    return l
end

-- ================================================================
--  マウス管理（Rayfield方式）
--  GUIにマウスが乗っている時だけオーバーライド
--  → GUI外では普通に視点が動く
-- ================================================================
local MouseManager = {}
local _overConn = nil
local _hoverCount = 0  -- 複数フレームのホバー管理

function MouseManager.StartOverride()
    UserInputService.MouseIconEnabled = true
    if _overConn then return end
    _overConn = RunService.RenderStepped:Connect(function()
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)
end

function MouseManager.StopOverride()
    if _overConn then
        _overConn:Disconnect()
        _overConn = nil
    end
end

function MouseManager.BindFrame(frame)
    frame.MouseEnter:Connect(function()
        _hoverCount = _hoverCount + 1
        MouseManager.StartOverride()
    end)
    frame.MouseLeave:Connect(function()
        _hoverCount = math.max(0, _hoverCount - 1)
        if _hoverCount <= 0 then
            _hoverCount = 0
            -- マウスボタン押下中は解除しない
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                MouseManager.StopOverride()
            end
        end
    end)
end

-- ================================================================
--  エンジン
-- ================================================================
local MyEngine = {
    Flags={}, KillList={}, Blacklist={}, Logs={},
}

local function AddLog(msg, t)
    table.insert(MyEngine.Logs, {Message=msg, Type=t or "Info", Time=GetTime()})
    if #MyEngine.Logs > 100 then table.remove(MyEngine.Logs, 1) end
end

-- ================================================================
--  起動アニメーション（超ハイテック版）
-- ================================================================
local function PlayBoot(sg, onDone)
    local Boot = Instance.new("Frame")
    Boot.Size = UDim2.new(1,0,1,0)
    Boot.BackgroundColor3 = Color3.fromRGB(3,3,6)
    Boot.BorderSizePixel = 0
    Boot.ZIndex = 200
    Boot.Parent = sg

    -- グリッド
    for i = 0, 10 do
        local function Line(horiz)
            local f = Instance.new("Frame")
            f.BackgroundColor3 = Color3.fromRGB(20,50,90)
            f.BackgroundTransparency = 0.75
            f.BorderSizePixel = 0
            f.ZIndex = 201
            f.Parent = Boot
            if horiz then
                f.Size = UDim2.new(1,0,0,1)
                f.Position = UDim2.new(0,0,i/10,0)
            else
                f.Size = UDim2.new(0,1,1,0)
                f.Position = UDim2.new(i/10,0,0,0)
            end
        end
        Line(true); Line(false)
    end

    -- スキャンライン
    local Scan = Instance.new("Frame")
    Scan.Size = UDim2.new(1,0,0,2)
    Scan.BackgroundColor3 = Color3.fromRGB(40,160,255)
    Scan.BackgroundTransparency = 0.2
    Scan.BorderSizePixel = 0
    Scan.ZIndex = 215
    Scan.Parent = Boot
    local ScanGlow = Instance.new("Frame")
    ScanGlow.Size = UDim2.new(1,0,0,24)
    ScanGlow.BackgroundColor3 = Color3.fromRGB(40,140,255)
    ScanGlow.BackgroundTransparency = 0.88
    ScanGlow.BorderSizePixel = 0
    ScanGlow.ZIndex = 214
    ScanGlow.Parent = Boot

    -- コーナーブラケット
    local function Bracket(corner)
        local s = 32
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0,s,0,s)
        f.BackgroundTransparency = 1
        f.ZIndex = 218
        f.Parent = Boot
        local pad = 28
        if corner=="TL" then f.Position=UDim2.new(0,pad,0,pad)
        elseif corner=="TR" then f.Position=UDim2.new(1,-pad-s,0,pad)
        elseif corner=="BL" then f.Position=UDim2.new(0,pad,1,-pad-s)
        else f.Position=UDim2.new(1,-pad-s,1,-pad-s) end
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1,0,0,2)
        h.BackgroundColor3 = Color3.fromRGB(50,180,255)
        h.BorderSizePixel=0 h.ZIndex=219 h.Parent=f
        if corner=="BL" or corner=="BR" then h.Position=UDim2.new(0,0,1,-2) end
        local v = Instance.new("Frame")
        v.Size = UDim2.new(0,2,1,0)
        v.BackgroundColor3 = Color3.fromRGB(50,180,255)
        v.BorderSizePixel=0 v.ZIndex=219 v.Parent=f
        if corner=="TR" or corner=="BR" then v.Position=UDim2.new(1,-2,0,0) end
    end
    Bracket("TL") Bracket("TR") Bracket("BL") Bracket("BR")

    -- ヘックスコード雨
    local hexChars = "0123456789ABCDEF"
    for i = 1, 20 do
        local hl = MkLabel(Boot, {
            Size=UDim2.new(0,180,0,13),
            Position=UDim2.new(math.random()*0.88,0,math.random()*0.88,0),
            Text="",
            TextColor3=Color3.fromRGB(25,70,110),
            TextSize=10,
            Font=Enum.Font.Code,
            ZIndex=202,
            TextXAlignment=Enum.TextXAlignment.Left,
        })
        task.spawn(function()
            task.wait(math.random()*0.6)
            while hl.Parent do
                local s=""
                for _=1, math.random(10,22) do
                    local idx = math.random(1,16)
                    s = s .. hexChars:sub(idx,idx)
                end
                hl.Text = s
                task.wait(0.07+math.random()*0.11)
            end
        end)
    end

    -- 中央パネル
    local Panel = Instance.new("Frame")
    Panel.Size = UDim2.new(0,460,0,210)
    Panel.AnchorPoint = Vector2.new(0.5,0.5)
    Panel.Position = UDim2.new(0.5,0,0.5,0)
    Panel.BackgroundColor3 = Color3.fromRGB(7,7,11)
    Panel.BorderSizePixel = 0
    Panel.ZIndex = 220
    Panel.Parent = Boot
    CC(Panel,6)
    CS(Panel, Color3.fromRGB(40,130,230), 1.5)

    -- トップアクセントライン
    local TopLine = Instance.new("Frame")
    TopLine.Size = UDim2.new(0,0,0,2)
    TopLine.BackgroundColor3 = Color3.fromRGB(50,170,255)
    TopLine.BorderSizePixel = 0
    TopLine.ZIndex = 221
    TopLine.Parent = Panel

    -- ロゴ
    local Logo = MkLabel(Panel, {
        Size=UDim2.new(1,0,0,52),
        Position=UDim2.new(0,0,0,18),
        Text="af_hub",
        TextColor3=Color3.fromRGB(255,255,255),
        TextSize=40,
        Font=Enum.Font.GothamBold,
        TextTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Center,
        ZIndex=222,
    })
    local Sub = MkLabel(Panel, {
        Size=UDim2.new(1,0,0,18),
        Position=UDim2.new(0,0,0,73),
        Text="ULTIMATE // システム初期化中...",
        TextColor3=Color3.fromRGB(45,145,255),
        TextSize=12,
        Font=Enum.Font.SourceSansSemibold,
        TextTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Center,
        ZIndex=222,
    })

    -- プログレスバー
    local TrkBG = Instance.new("Frame")
    TrkBG.Size = UDim2.new(1,-40,0,5)
    TrkBG.Position = UDim2.new(0,20,0,108)
    TrkBG.BackgroundColor3 = Color3.fromRGB(18,18,26)
    TrkBG.BorderSizePixel = 0
    TrkBG.ZIndex = 222
    TrkBG.Parent = Panel
    CC(TrkBG,100)
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(0,0,1,0)
    Fill.BackgroundColor3 = Color3.fromRGB(45,145,255)
    Fill.BorderSizePixel = 0
    Fill.ZIndex = 223
    Fill.Parent = TrkBG
    CC(Fill,100)
    local Glow = Instance.new("Frame")
    Glow.Size = UDim2.new(0,0,0,16)
    Glow.Position = UDim2.new(0,0,0.5,-8)
    Glow.BackgroundColor3 = Color3.fromRGB(70,175,255)
    Glow.BackgroundTransparency = 0.76
    Glow.BorderSizePixel = 0
    Glow.ZIndex = 221
    Glow.Parent = TrkBG
    CC(Glow,100)

    local PctLbl = MkLabel(Panel,{
        Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,120),
        Text="0%",TextColor3=Color3.fromRGB(70,110,155),TextSize=11,
        Font=Enum.Font.SourceSansSemibold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=222})
    local StatusLbl = MkLabel(Panel,{
        Size=UDim2.new(1,-24,0,16),Position=UDim2.new(0,12,0,146),
        Text="",TextColor3=Color3.fromRGB(45,80,115),TextSize=11,
        Font=Enum.Font.SourceSans,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=222})
    MkLabel(Panel,{
        Size=UDim2.new(1,-16,0,14),Position=UDim2.new(0,8,1,-20),
        Text="v2.5  //  "..LocalPlayer.Name,
        TextColor3=Color3.fromRGB(35,65,95),TextSize=10,
        Font=Enum.Font.SourceSans,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=222})

    local statMsgs = {
        "[ コアモジュール読み込み中... ]",
        "[ GUIエンジン注入中... ]",
        "[ プレイヤーデータ接続中... ]",
        "[ セキュリティバイパス中... ]",
        "[ システム準備完了 ]",
    }

    task.spawn(function()
        -- スキャンライン ループ
        task.spawn(function()
            while Scan.Parent do
                Scan.Position = UDim2.new(0,0,0,-2)
                ScanGlow.Position = UDim2.new(0,0,0,-14)
                TW(Scan, {Position=UDim2.new(0,0,1,0)}, 1.1, Enum.EasingStyle.Linear)
                TW(ScanGlow,{Position=UDim2.new(0,0,1,0)}, 1.1, Enum.EasingStyle.Linear)
                task.wait(1.15)
            end
        end)

        -- トップライン展開
        TW(TopLine,{Size=UDim2.new(1,0,0,2)},0.5,Enum.EasingStyle.Quint)
        task.wait(0.2)
        TW(Logo,{TextTransparency=0},0.5,Enum.EasingStyle.Quint)
        TW(Sub, {TextTransparency=0},0.7,Enum.EasingStyle.Quint)
        task.wait(0.35)

        -- プログレス
        for i = 1, 100 do
            task.wait(0.013)
            local p = i/100
            Fill.Size = UDim2.new(p,0,1,0)
            Glow.Size = UDim2.new(p,0,0,16)
            PctLbl.Text = i .. "%"
            local mi = math.ceil(p*#statMsgs)
            if mi>=1 and mi<=#statMsgs then StatusLbl.Text=statMsgs[mi] end
        end

        task.wait(0.12)

        -- フラッシュ
        local Fl = Instance.new("Frame")
        Fl.Size=UDim2.new(1,0,1,0)
        Fl.BackgroundColor3=Color3.fromRGB(190,220,255)
        Fl.BackgroundTransparency=1
        Fl.BorderSizePixel=0
        Fl.ZIndex=300
        Fl.Parent=Boot
        TW(Fl,{BackgroundTransparency=0.45},0.09)
        task.wait(0.09)
        TW(Fl,{BackgroundTransparency=1},0.28)
        TW(Boot,{BackgroundTransparency=1},0.35)
        task.wait(0.35)
        Boot:Destroy()
        if onDone then onDone() end
    end)
end

-- ================================================================
--  ドラッグ
-- ================================================================
local function MakeDraggable(handle, target)
    local drag, di, ds, sp = false, nil, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=inp.Position; sp=target.Position
            inp.Changed:Connect(function()
                if inp.UserInputState==Enum.UserInputState.End then drag=false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch then di=inp end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp==di and drag then
            local d=inp.Position-ds
            target.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- ================================================================
--  CreateWindow
-- ================================================================
function MyEngine:CreateWindow(Config)
    local WinName = Config.Name or "af_hub"

    local SG = Instance.new("ScreenGui")
    SG.Name = "afHub_"..HttpService:GenerateGUID()
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.ResetOnSpawn = false
    pcall(function() SG.IgnoreGuiInset=true end)
    SG.Parent = LocalPlayer:WaitForChild("PlayerGui")

    PlayBoot(SG, function() AddLog("GUI起動完了","Success") end)

    -- メインフレーム
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0,820,0,520)
    Main.AnchorPoint = Vector2.new(0.5,0.5)
    Main.Position = UDim2.new(0.5,0,0.5,0)
    Main.BackgroundColor3 = Color3.fromRGB(14,14,16)
    Main.BorderSizePixel = 0
    Main.BackgroundTransparency = 1
    Main.Parent = SG
    CC(Main,12) CS(Main,Color3.fromRGB(38,38,48),2)

    local Grad = Instance.new("UIGradient")
    Grad.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(20,20,24)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(14,14,16))}
    Grad.Rotation=140; Grad.Parent=Main

    task.delay(2.1,function() TW(Main,{BackgroundTransparency=0},0.45) end)

    -- マウス管理バインド（メインフレーム）
    MouseManager.BindFrame(Main)

    -- サイドバー
    local Sidebar = Instance.new("Frame")
    Sidebar.Size=UDim2.new(0,200,1,0)
    Sidebar.BackgroundColor3=Color3.fromRGB(10,10,12)
    Sidebar.BorderSizePixel=0
    Sidebar.Parent=Main
    CC(Sidebar,12)
    local SideDiv=Instance.new("Frame")
    SideDiv.Size=UDim2.new(0,1,1,0)
    SideDiv.Position=UDim2.new(1,0,0,0)
    SideDiv.BackgroundColor3=Color3.fromRGB(30,30,38)
    SideDiv.BorderSizePixel=0
    SideDiv.Parent=Sidebar

    -- タイトルバー
    local TitleBar=Instance.new("Frame")
    TitleBar.Size=UDim2.new(1,0,0,50)
    TitleBar.BackgroundTransparency=1
    TitleBar.Parent=Main
    MakeDraggable(TitleBar,Main)

    MkLabel(TitleBar,{
        Size=UDim2.new(1,-115,1,0),Position=UDim2.new(0,15,0,0),
        Text=WinName,TextSize=18,Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(255,255,255),ZIndex=2})

    -- コントロールボタン
    local function CtrlBtn(txt, bg, xoff)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0,28,0,28)
        b.Position=UDim2.new(1,xoff,0.5,-14)
        b.BackgroundColor3=bg
        b.BorderSizePixel=0
        b.Text=txt
        b.TextColor3=Color3.fromRGB(255,255,255)
        b.TextSize=13
        b.Font=Enum.Font.GothamBold
        b.AutoButtonColor=false
        b.Parent=TitleBar
        CC(b,6)
        return b
    end
    local CloseBtn=CtrlBtn("✕",Color3.fromRGB(170,48,48),-10)
    local MinBtn  =CtrlBtn("—",Color3.fromRGB(26,26,32),-44)

    CloseBtn.MouseEnter:Connect(function() TW(CloseBtn,{BackgroundColor3=Color3.fromRGB(205,58,58)},0.1) end)
    CloseBtn.MouseLeave:Connect(function() TW(CloseBtn,{BackgroundColor3=Color3.fromRGB(170,48,48)},0.1) end)
    MinBtn.MouseEnter:Connect(function()   TW(MinBtn,  {BackgroundColor3=Color3.fromRGB(42,42,52)}, 0.1) end)
    MinBtn.MouseLeave:Connect(function()   TW(MinBtn,  {BackgroundColor3=Color3.fromRGB(26,26,32)}, 0.1) end)

    -- ミニアイコン（左下・ドラッグ可）
    local Mini=Instance.new("TextButton")
    Mini.Size=UDim2.new(0,50,0,50)
    Mini.AnchorPoint=Vector2.new(0,1)
    Mini.Position=UDim2.new(0,20,1,-20)
    Mini.BackgroundColor3=Color3.fromRGB(14,14,16)
    Mini.BorderSizePixel=0
    Mini.Text="◈"
    Mini.TextColor3=Color3.fromRGB(50,150,255)
    Mini.TextSize=22
    Mini.Font=Enum.Font.GothamBold
    Mini.AutoButtonColor=false
    Mini.Visible=false
    Mini.ZIndex=50
    Mini.Parent=SG
    CC(Mini,10) CS(Mini,Color3.fromRGB(50,150,255),2)
    MakeDraggable(Mini,Mini)
    MouseManager.BindFrame(Mini)

    -- タブスクロール
    local TabScroll=Instance.new("ScrollingFrame")
    TabScroll.Size=UDim2.new(1,-10,1,-185)
    TabScroll.Position=UDim2.new(0,5,0,55)
    TabScroll.BackgroundTransparency=1
    TabScroll.BorderSizePixel=0
    TabScroll.ScrollBarThickness=2
    TabScroll.ScrollBarImageColor3=Color3.fromRGB(55,55,65)
    TabScroll.Parent=Sidebar
    local TL=Instance.new("UIListLayout")
    TL.Padding=UDim.new(0,4)
    TL.SortOrder=Enum.SortOrder.LayoutOrder
    TL.Parent=TabScroll
    TL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabScroll.CanvasSize=UDim2.new(0,0,0,TL.AbsoluteContentSize.Y+8)
    end)

    -- アカウントセクション
    local AccSec=Instance.new("Frame")
    AccSec.Size=UDim2.new(1,-10,0,72)
    AccSec.Position=UDim2.new(0,5,1,-77)
    AccSec.BackgroundColor3=Color3.fromRGB(15,15,18)
    AccSec.BorderSizePixel=0
    AccSec.Parent=Sidebar
    CC(AccSec,8) CS(AccSec,Color3.fromRGB(36,36,44),1)
    local AccIco=Instance.new("ImageLabel")
    AccIco.Size=UDim2.new(0,46,0,46)
    AccIco.Position=UDim2.new(0,10,0.5,-23)
    AccIco.BackgroundTransparency=1
    AccIco.Image="rbxthumb://type=AvatarHeadShot&id="..LocalPlayer.UserId.."&w=150&h=150"
    AccIco.Parent=AccSec
    CC(AccIco,100)
    MkLabel(AccSec,{Size=UDim2.new(1,-68,0,24),Position=UDim2.new(0,63,0.18,0),
        Text=LocalPlayer.DisplayName,TextSize=14,Font=Enum.Font.SourceSansBold})
    MkLabel(AccSec,{Size=UDim2.new(1,-68,0,16),Position=UDim2.new(0,63,0.62,0),
        Text="@"..LocalPlayer.Name,TextSize=11,Font=Enum.Font.SourceSans,
        TextColor3=Color3.fromRGB(65,125,195)})
    local ODot=Instance.new("Frame")
    ODot.Size=UDim2.new(0,7,0,7)
    ODot.Position=UDim2.new(0,53,1,-14)
    ODot.BackgroundColor3=Color3.fromRGB(50,225,100)
    ODot.BorderSizePixel=0
    ODot.Parent=AccSec
    CC(ODot,100)

    -- コンテンツエリア
    local CA=Instance.new("Frame")
    CA.Size=UDim2.new(1,-210,1,-60)
    CA.Position=UDim2.new(0,205,0,50)
    CA.BackgroundTransparency=1
    CA.Parent=Main

    -- 開閉ロジック
    local isOpen=true
    local isMin=false
    local busy=false

    local function Open(v)
        if busy then return end
        isOpen=v
        if v then
            busy=true
            Main.Visible=true
            Main.Size=UDim2.new(0,785,0,498)
            Main.BackgroundTransparency=1
            TW(Main,{Size=UDim2.new(0,820,0,520),BackgroundTransparency=0},
                0.38,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
            task.delay(0.38,function() busy=false end)
        else
            busy=true
            local t=TW(Main,{Size=UDim2.new(0,795,0,508),BackgroundTransparency=1},
                0.3,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
            t.Completed:Connect(function()
                Main.Visible=false
                Main.Size=UDim2.new(0,820,0,520)
                MouseManager.StopOverride()
                busy=false
            end)
        end
    end

    local function Minimize(v)
        if busy then return end
        isMin=v; busy=true
        if v then
            TW(Main,{Size=UDim2.new(0,50,0,50),BackgroundTransparency=1},
                0.36,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
            task.delay(0.36,function()
                Main.Visible=false; Main.Size=UDim2.new(0,820,0,520)
                Mini.Visible=true; Mini.BackgroundTransparency=1; Mini.Size=UDim2.new(0,38,0,38)
                TW(Mini,{BackgroundTransparency=0,Size=UDim2.new(0,50,0,50)},
                    0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                busy=false
            end)
        else
            TW(Mini,{BackgroundTransparency=1,Size=UDim2.new(0,38,0,38)},
                0.2,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
            task.delay(0.2,function()
                Mini.Visible=false; Mini.Size=UDim2.new(0,50,0,50)
                Main.Visible=true; Main.Size=UDim2.new(0,785,0,498); Main.BackgroundTransparency=1
                TW(Main,{Size=UDim2.new(0,820,0,520),BackgroundTransparency=0},
                    0.38,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                task.delay(0.38,function() busy=false end)
            end)
        end
    end

    UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode==Enum.KeyCode.K then
            if busy then return end
            if isMin then Minimize(false)
            else Open(not isOpen) end
        end
    end)

    MinBtn.MouseButton1Click:Connect(function() Minimize(true) end)
    CloseBtn.MouseButton1Click:Connect(function() Open(false) end)
    Mini.MouseButton1Click:Connect(function() Minimize(false) end)

    -- ================================================================
    --  Window
    -- ================================================================
    local Window={_Main=Main,_Sidebar=Sidebar,_TabScroll=TabScroll,_CA=CA,_Tabs={}}

    function Window:CreateTab(TabName)
        local TBtn=Instance.new("TextButton")
        TBtn.Size=UDim2.new(1,-8,0,38)
        TBtn.BackgroundColor3=Color3.fromRGB(17,17,20)
        TBtn.BorderSizePixel=0
        TBtn.Text="  "..TabName
        TBtn.TextColor3=Color3.fromRGB(170,170,185)
        TBtn.TextSize=13
        TBtn.Font=Enum.Font.SourceSansSemibold
        TBtn.TextXAlignment=Enum.TextXAlignment.Left
        TBtn.AutoButtonColor=false
        TBtn.Parent=TabScroll
        CC(TBtn,6)

        local Acc=Instance.new("Frame")
        Acc.Size=UDim2.new(0,3,0.6,0)
        Acc.Position=UDim2.new(0,0,0.2,0)
        Acc.BackgroundColor3=Color3.fromRGB(50,150,255)
        Acc.BorderSizePixel=0
        Acc.BackgroundTransparency=1
        Acc.Parent=TBtn
        CC(Acc,100)

        local TC=Instance.new("ScrollingFrame")
        TC.Name=TabName.."_C"
        TC.Size=UDim2.new(1,0,1,0)
        TC.BackgroundTransparency=1
        TC.BorderSizePixel=0
        TC.ScrollBarThickness=3
        TC.ScrollBarImageColor3=Color3.fromRGB(55,55,65)
        TC.Visible=false
        TC.Parent=CA
        local CL=Instance.new("UIListLayout")
        CL.Padding=UDim.new(0,6)
        CL.SortOrder=Enum.SortOrder.LayoutOrder
        CL.Parent=TC
        local CP=Instance.new("UIPadding")
        CP.PaddingTop=UDim.new(0,6); CP.PaddingRight=UDim.new(0,8)
        CP.Parent=TC
        CL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TC.CanvasSize=UDim2.new(0,0,0,CL.AbsoluteContentSize.Y+16)
        end)

        TBtn.MouseButton1Click:Connect(function()
            for _,t in pairs(Window._Tabs) do
                TW(t.B,{BackgroundColor3=Color3.fromRGB(17,17,20),
                    TextColor3=Color3.fromRGB(170,170,185)},0.12)
                t.A.BackgroundTransparency=1; t.C.Visible=false
            end
            TW(TBtn,{BackgroundColor3=Color3.fromRGB(24,24,30),
                TextColor3=Color3.fromRGB(255,255,255)},0.12)
            TW(Acc,{BackgroundTransparency=0},0.12)
            TC.Visible=true
        end)

        if #Window._Tabs==0 then
            TBtn.BackgroundColor3=Color3.fromRGB(24,24,30)
            TBtn.TextColor3=Color3.fromRGB(255,255,255)
            Acc.BackgroundTransparency=0; TC.Visible=true
        end

        local Tab={B=TBtn,A=Acc,C=TC,Elements={}}
        table.insert(Window._Tabs,Tab)

        -- セクション
        function Tab:CreateSection(n)
            local f=Instance.new("Frame")
            f.Size=UDim2.new(1,0,0,20)
            f.BackgroundTransparency=1
            f.Parent=TC
            MkLabel(f,{Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,4,0,0),
                Text=n,TextColor3=Color3.fromRGB(85,125,175),TextSize=11,
                Font=Enum.Font.SourceSansSemibold})
            local ln=Instance.new("Frame")
            ln.Size=UDim2.new(1,-8,0,1)
            ln.Position=UDim2.new(0,4,1,-1)
            ln.BackgroundColor3=Color3.fromRGB(28,28,36)
            ln.BorderSizePixel=0
            ln.Parent=f
        end

        -- ボタン
        function Tab:CreateButton(Data)
            local F=Instance.new("Frame")
            F.Size=UDim2.new(1,0,0,36)
            F.BackgroundColor3=Color3.fromRGB(20,20,24)
            F.BorderSizePixel=0
            F.Parent=TC
            CC(F,7) CS(F,Color3.fromRGB(34,34,42),1)
            local B=Instance.new("TextButton")
            B.Size=UDim2.new(1,0,1,0)
            B.BackgroundTransparency=1
            B.Text=Data.Name or "ボタン"
            B.TextColor3=Color3.fromRGB(235,235,245)
            B.TextSize=13
            B.Font=Enum.Font.SourceSans
            B.Parent=F
            B.MouseButton1Click:Connect(function()
                TW(F,{BackgroundColor3=Color3.fromRGB(30,30,38)},0.08)
                task.delay(0.08,function() TW(F,{BackgroundColor3=Color3.fromRGB(20,20,24)},0.12) end)
                if Data.Callback then pcall(Data.Callback) end
                AddLog("実行: "..(Data.Name or "?"),"Action")
            end)
        end

        -- トグル
        function Tab:CreateToggle(Data)
            local F=Instance.new("Frame")
            F.Size=UDim2.new(1,0,0,36)
            F.BackgroundColor3=Color3.fromRGB(20,20,24)
            F.BorderSizePixel=0
            F.Parent=TC
            CC(F,7) CS(F,Color3.fromRGB(34,34,42),1)
            MkLabel(F,{Size=UDim2.new(1,-58,1,0),Position=UDim2.new(0,12,0,0),
                Text=Data.Name or "トグル",TextSize=13,Font=Enum.Font.SourceSans})
            local Trk=Instance.new("TextButton")
            Trk.Size=UDim2.new(0,42,0,20)
            Trk.Position=UDim2.new(1,-50,0.5,-10)
            Trk.BackgroundColor3=Color3.fromRGB(36,36,44)
            Trk.BorderSizePixel=0
            Trk.Text=""
            Trk.AutoButtonColor=false
            Trk.Parent=F
            CC(Trk,100)
            local Cir=Instance.new("Frame")
            Cir.Size=UDim2.new(0,16,0,16)
            Cir.Position=UDim2.new(0,2,0.5,-8)
            Cir.BackgroundColor3=Color3.fromRGB(185,185,200)
            Cir.BorderSizePixel=0
            Cir.Parent=Trk
            CC(Cir,100)
            local val=Data.CurrentValue or false
            if val then
                Trk.BackgroundColor3=Color3.fromRGB(42,138,242)
                Cir.Position=UDim2.new(1,-18,0.5,-8)
            end
            Trk.MouseButton1Click:Connect(function()
                val=not val
                if val then
                    TW(Trk,{BackgroundColor3=Color3.fromRGB(42,138,242)},0.18)
                    TW(Cir,{Position=UDim2.new(1,-18,0.5,-8)},0.18)
                else
                    TW(Trk,{BackgroundColor3=Color3.fromRGB(36,36,44)},0.18)
                    TW(Cir,{Position=UDim2.new(0,2,0.5,-8)},0.18)
                end
                if Data.Callback then pcall(Data.Callback,val) end
                MyEngine.Flags[Data.Flag or Data.Name or ""]=val
                AddLog("トグル: "..(Data.Name or "?").." = "..tostring(val),"Action")
            end)
        end

        -- スライダー
        function Tab:CreateSlider(Data)
            local F=Instance.new("Frame")
            F.Size=UDim2.new(1,0,0,54)
            F.BackgroundColor3=Color3.fromRGB(20,20,24)
            F.BorderSizePixel=0
            F.Parent=TC
            CC(F,7) CS(F,Color3.fromRGB(34,34,42),1)
            local VL=MkLabel(F,{Size=UDim2.new(0,52,0,18),Position=UDim2.new(1,-58,0,5),
                Text="",TextColor3=Color3.fromRGB(75,135,205),TextSize=12,
                Font=Enum.Font.SourceSansSemibold,TextXAlignment=Enum.TextXAlignment.Right})
            MkLabel(F,{Size=UDim2.new(1,-70,0,18),Position=UDim2.new(0,10,0,5),
                Text=Data.Name or "スライダー",TextSize=13,Font=Enum.Font.SourceSans})
            local Trk=Instance.new("Frame")
            Trk.Size=UDim2.new(1,-20,0,5)
            Trk.Position=UDim2.new(0,10,1,-17)
            Trk.BackgroundColor3=Color3.fromRGB(30,30,38)
            Trk.BorderSizePixel=0
            Trk.Parent=F
            CC(Trk,100)
            local Fil=Instance.new("Frame")
            Fil.Size=UDim2.new(0,0,1,0)
            Fil.BackgroundColor3=Color3.fromRGB(42,138,242)
            Fil.BorderSizePixel=0
            Fil.Parent=Trk
            CC(Fil,100)
            local Knob=Instance.new("Frame")
            Knob.Size=UDim2.new(0,12,0,12)
            Knob.Position=UDim2.new(1,-6,0.5,-6)
            Knob.BackgroundColor3=Color3.fromRGB(255,255,255)
            Knob.BorderSizePixel=0
            Knob.ZIndex=2
            Knob.Parent=Fil
            CC(Knob,100)
            local Min,Max=Data.Range[1],Data.Range[2]
            local Inc=Data.Increment or 1
            local cur=Data.CurrentValue or Min
            local dr=false
            local function Upd(v)
                v=math.clamp(math.floor(v/Inc+0.5)*Inc,Min,Max)
                cur=v
                Fil.Size=UDim2.new((v-Min)/(Max-Min),0,1,0)
                VL.Text=tostring(v)..(Data.Suffix or "")
                if Data.Callback then pcall(Data.Callback,v) end
                MyEngine.Flags[Data.Flag or Data.Name or ""]=v
            end
            Upd(cur)
            Trk.InputBegan:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end
            end)
            RunService.RenderStepped:Connect(function()
                if dr then
                    local mx=UserInputService:GetMouseLocation().X
                    Upd(Min+(Max-Min)*math.clamp((mx-Trk.AbsolutePosition.X)/Trk.AbsoluteSize.X,0,1))
                end
            end)
        end

        -- ドロップダウン
        function Tab:CreateDropdown(Data)
            local F=Instance.new("Frame")
            F.Size=UDim2.new(1,0,0,36)
            F.BackgroundColor3=Color3.fromRGB(20,20,24)
            F.BorderSizePixel=0
            F.Parent=TC
            CC(F,7) CS(F,Color3.fromRGB(34,34,42),1)
            local DB=Instance.new("TextButton")
            DB.Size=UDim2.new(1,0,1,0)
            DB.BackgroundTransparency=1
            DB.Text="  "..(Data.Name or "選択")..":  "..(Data.CurrentOption or "未選択")
            DB.TextColor3=Color3.fromRGB(235,235,245)
            DB.TextSize=13
            DB.Font=Enum.Font.SourceSans
            DB.TextXAlignment=Enum.TextXAlignment.Left
            DB.Parent=F
            local Arr=MkLabel(F,{Size=UDim2.new(0,20,1,0),Position=UDim2.new(1,-24,0,0),
                Text="▾",TextColor3=Color3.fromRGB(95,115,145),TextSize=14,
                Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center})
            local OC=Instance.new("Frame")
            OC.Size=UDim2.new(1,0,0,0)
            OC.Position=UDim2.new(0,0,1,3)
            OC.BackgroundColor3=Color3.fromRGB(16,16,20)
            OC.BorderSizePixel=0
            OC.Visible=false
            OC.ZIndex=10
            OC.Parent=F
            CC(OC,7) CS(OC,Color3.fromRGB(34,34,42),1)
            Instance.new("UIListLayout").Parent=OC
            local op=false
            DB.MouseButton1Click:Connect(function()
                op=not op; OC.Visible=op
                if op then
                    local h=math.min(#(Data.Options or {})*30,170)
                    TW(OC,{Size=UDim2.new(1,0,0,h)},0.18)
                    TW(F,{Size=UDim2.new(1,0,0,36+h+4)},0.18)
                    Arr.Text="▴"
                else
                    TW(OC,{Size=UDim2.new(1,0,0,0)},0.18)
                    TW(F,{Size=UDim2.new(1,0,0,36)},0.18)
                    Arr.Text="▾"
                end
            end)
            for _,opt in pairs(Data.Options or {}) do
                local OB=Instance.new("TextButton")
                OB.Size=UDim2.new(1,0,0,30)
                OB.BackgroundColor3=Color3.fromRGB(20,20,26)
                OB.BorderSizePixel=0
                OB.Text="  "..opt
                OB.TextColor3=Color3.fromRGB(195,200,215)
                OB.TextSize=12
                OB.Font=Enum.Font.SourceSans
                OB.TextXAlignment=Enum.TextXAlignment.Left
                OB.AutoButtonColor=false
                OB.ZIndex=11
                OB.Parent=OC
                OB.MouseEnter:Connect(function() TW(OB,{BackgroundColor3=Color3.fromRGB(28,28,36)},0.08) end)
                OB.MouseLeave:Connect(function() TW(OB,{BackgroundColor3=Color3.fromRGB(20,20,26)},0.08) end)
                OB.MouseButton1Click:Connect(function()
                    DB.Text="  "..(Data.Name or "選択")..":  "..opt
                    op=false; OC.Visible=false; Arr.Text="▾"
                    TW(OC,{Size=UDim2.new(1,0,0,0)},0.18)
                    TW(F,{Size=UDim2.new(1,0,0,36)},0.18)
                    if Data.Callback then pcall(Data.Callback,opt) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=opt
                end)
            end
        end

        -- プレイヤーリスト
        function Tab:CreatePlayerList(Data)
            local F=Instance.new("Frame")
            F.Size=UDim2.new(1,0,0,400)
            F.BackgroundColor3=Color3.fromRGB(16,16,20)
            F.BorderSizePixel=0
            F.Parent=TC
            CC(F,8) CS(F,Color3.fromRGB(34,34,42),1)
            MkLabel(F,{Size=UDim2.new(1,-20,0,26),Position=UDim2.new(0,10,0,6),
                Text=Data.Name or "プレイヤーリスト",TextSize=14,Font=Enum.Font.SourceSansBold,
                TextColor3=Color3.fromRGB(255,255,255)})
            local SB=Instance.new("TextBox")
            SB.Size=UDim2.new(1,-18,0,29)
            SB.Position=UDim2.new(0,9,0,36)
            SB.BackgroundColor3=Color3.fromRGB(10,10,14)
            SB.BorderSizePixel=0
            SB.PlaceholderText="プレイヤーを検索..."
            SB.PlaceholderColor3=Color3.fromRGB(75,80,95)
            SB.Text=""
            SB.TextColor3=Color3.fromRGB(255,255,255)
            SB.TextSize=12
            SB.Font=Enum.Font.SourceSans
            SB.ClearTextOnFocus=false
            SB.Parent=F
            CC(SB,6)
            local PS=Instance.new("ScrollingFrame")
            PS.Size=UDim2.new(1,-16,1,-76)
            PS.Position=UDim2.new(0,8,0,70)
            PS.BackgroundTransparency=1
            PS.BorderSizePixel=0
            PS.ScrollBarThickness=3
            PS.ScrollBarImageColor3=Color3.fromRGB(55,55,65)
            PS.Parent=F
            local PL=Instance.new("UIListLayout")
            PL.Padding=UDim.new(0,4)
            PL.Parent=PS
            PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                PS.CanvasSize=UDim2.new(0,0,0,PL.AbsoluteContentSize.Y+8)
            end)
            local function MkCard(player)
                if PS:FindFirstChild("p_"..player.UserId) then return end
                local Card=Instance.new("Frame")
                Card.Name="p_"..player.UserId
                Card.Size=UDim2.new(1,-4,0,54)
                Card.BackgroundColor3=Color3.fromRGB(20,20,26)
                Card.BorderSizePixel=0
                Card.Parent=PS
                CC(Card,7)
                local Stk=CS(Card,Color3.fromRGB(36,36,46),1.5)
                local Ico=Instance.new("ImageLabel")
                Ico.Size=UDim2.new(0,40,0,40)
                Ico.Position=UDim2.new(0,7,0.5,-20)
                Ico.BackgroundTransparency=1
                Ico.Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150"
                Ico.Parent=Card
                CC(Ico,100)
                MkLabel(Card,{Size=UDim2.new(1,-62,0,22),Position=UDim2.new(0,54,0.1,0),
                    Text=player.DisplayName,TextSize=15,Font=Enum.Font.SourceSansBold})
                MkLabel(Card,{Size=UDim2.new(1,-62,0,15),Position=UDim2.new(0,54,0.6,0),
                    Text="@"..player.Name,TextSize=11,Font=Enum.Font.SourceSans,
                    TextColor3=Color3.fromRGB(65,125,195)})
                local Hit=Instance.new("TextButton")
                Hit.Size=UDim2.new(1,0,1,0)
                Hit.BackgroundTransparency=1
                Hit.Text=""
                Hit.Parent=Card
                Hit.MouseEnter:Connect(function()
                    if not MyEngine.KillList[player.UserId] then
                        TW(Card,{BackgroundColor3=Color3.fromRGB(26,26,32)},0.1)
                    end
                end)
                Hit.MouseLeave:Connect(function()
                    if not MyEngine.KillList[player.UserId] then
                        TW(Card,{BackgroundColor3=Color3.fromRGB(20,20,26)},0.1)
                    end
                end)
                Hit.MouseButton1Click:Connect(function()
                    if not MyEngine.KillList[player.UserId] then
                        MyEngine.KillList[player.UserId]=true
                        MyEngine.Blacklist[player.UserId]=player.Name
                        TW(Stk,{Color=Color3.fromRGB(210,48,48)},0.2)
                        Stk.Thickness=2
                        TW(Card,{BackgroundColor3=Color3.fromRGB(28,16,16)},0.2)
                        AddLog("キルリスト追加: "..player.Name,"Action")
                        if Data.Callback then pcall(Data.Callback,player,true) end
                    else
                        MyEngine.KillList[player.UserId]=nil
                        MyEngine.Blacklist[player.UserId]=nil
                        TW(Stk,{Color=Color3.fromRGB(36,36,46)},0.2)
                        Stk.Thickness=1.5
                        TW(Card,{BackgroundColor3=Color3.fromRGB(20,20,26)},0.2)
                        AddLog("キルリスト解除: "..player.Name,"Action")
                        if Data.Callback then pcall(Data.Callback,player,false) end
                    end
                end)
            end
            local function Refresh()
                for _,c in pairs(PS:GetChildren()) do
                    if c:IsA("Frame") then
                        local uid=tonumber(c.Name:match("p_(%d+)"))
                        if uid and not Players:GetPlayerByUserId(uid) then c:Destroy() end
                    end
                end
                for _,p in pairs(Players:GetPlayers()) do
                    if p~=LocalPlayer then MkCard(p) end
                end
            end
            SB:GetPropertyChangedSignal("Text"):Connect(function()
                local s=SB.Text:lower()
                for _,c in pairs(PS:GetChildren()) do
                    if c:IsA("Frame") then
                        local uid=tonumber(c.Name:match("p_(%d+)"))
                        if uid then
                            local p=Players:GetPlayerByUserId(uid)
                            c.Visible=p and(s=="" or p.DisplayName:lower():find(s,1,true)~=nil
                                or p.Name:lower():find(s,1,true)~=nil) or false
                        end
                    end
                end
            end)
            Players.PlayerAdded:Connect(function(p)
                task.wait(0.5); Refresh()
                if MyEngine.Blacklist[p.UserId] then
                    AddLog("ターゲット再参加: "..p.Name,"Warning")
                    MyEngine.KillList[p.UserId]=true
                    task.wait(0.5); Refresh()
                    local c=PS:FindFirstChild("p_"..p.UserId)
                    if c then
                        local s=c:FindFirstChildOfClass("UIStroke")
                        if s then s.Color=Color3.fromRGB(210,48,48); s.Thickness=2 end
                        TW(c,{BackgroundColor3=Color3.fromRGB(28,16,16)},0.2)
                    end
                end
            end)
            Players.PlayerRemoving:Connect(function() task.wait(0.5); Refresh() end)
            Refresh()
        end

        -- ゲーム情報タブ
        function Tab:CreateGameInfo()
            local F=Instance.new("Frame")
            F.Size=UDim2.new(1,0,0,280)
            F.BackgroundColor3=Color3.fromRGB(16,16,20)
            F.BorderSizePixel=0
            F.Parent=TC
            CC(F,8) CS(F,Color3.fromRGB(34,34,42),1)

            MkLabel(F,{Size=UDim2.new(1,-20,0,26),Position=UDim2.new(0,12,0,6),
                Text="サーバー情報",TextSize=14,Font=Enum.Font.SourceSansBold,
                TextColor3=Color3.fromRGB(255,255,255)})

            -- セパレーター
            local Sep=Instance.new("Frame")
            Sep.Size=UDim2.new(1,-24,0,1)
            Sep.Position=UDim2.new(0,12,0,34)
            Sep.BackgroundColor3=Color3.fromRGB(28,28,38)
            Sep.BorderSizePixel=0
            Sep.Parent=F

            local function Row(lbl, y)
                MkLabel(F,{Size=UDim2.new(0.42,-4,0,22),Position=UDim2.new(0,14,0,y),
                    Text=lbl,TextSize=12,Font=Enum.Font.SourceSansSemibold,
                    TextColor3=Color3.fromRGB(95,115,155)})
                local v=MkLabel(F,{Size=UDim2.new(0.58,-4,0,22),
                    Position=UDim2.new(0.42,0,0,y),
                    Text="…",TextSize=12,Font=Enum.Font.SourceSans,
                    TextColor3=Color3.fromRGB(200,210,230)})
                return v
            end

            local vSrv  = Row("サーバーID",   42)
            local vPly  = Row("プレイヤー数",  66)
            local vPing = Row("Ping",          90)
            local vFPS  = Row("FPS",          114)
            local vUp   = Row("稼働時間",     138)
            local vGame = Row("ゲーム名",     162)
            local vPID  = Row("PlaceID",      186)
            local vMe   = Row("自分のUserId",  210)

            -- 固定値
            pcall(function()
                local jid=tostring(game.JobId)
                vSrv.Text = jid~="" and (jid:sub(1,18).."...") or "ローカル"
                vGame.Text = tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
            end)
            pcall(function() vPID.Text = tostring(game.PlaceId) end)
            pcall(function() vMe.Text  = tostring(LocalPlayer.UserId) end)

            local startT=tick()
            local lastPing=0

            local function UpdLive()
                pcall(function()
                    local p=Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                    lastPing=math.floor(p)
                end)

                local pc=Color3.fromRGB(65,210,100)
                if lastPing>150 then pc=Color3.fromRGB(240,175,45)
                elseif lastPing>300 then pc=Color3.fromRGB(215,70,70) end
                vPing.Text    = lastPing.." ms"
                vPing.TextColor3 = pc

                local fps=0
                pcall(function()
                    local s=tick()
                    RunService.RenderStepped:Wait()
                    fps=math.floor(1/(tick()-s))
                end)
                vFPS.Text=fps.." fps"

                local e=tick()-startT
                vUp.Text=string.format("%02d:%02d:%02d",math.floor(e/3600),math.floor(e/60)%60,math.floor(e)%60)
                vPly.Text=tostring(#Players:GetPlayers()).." / "..tostring(Players.MaxPlayers)
            end

            task.spawn(function()
                while F.Parent do
                    pcall(UpdLive)
                    task.wait(1)
                end
            end)
        end

        return Tab
    end

    return Window
end

-- ================================================================
--  通知
-- ================================================================
function MyEngine:Notify(Data)
    local NG=Instance.new("ScreenGui")
    NG.Name="afNotify"
    NG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    pcall(function() NG.IgnoreGuiInset=true end)
    NG.Parent=LocalPlayer:WaitForChild("PlayerGui")

    local NF=Instance.new("Frame")
    NF.Size=UDim2.new(0,295,0,76)
    NF.Position=UDim2.new(1,10,1,-20)
    NF.AnchorPoint=Vector2.new(1,1)
    NF.BackgroundColor3=Color3.fromRGB(16,16,20)
    NF.BorderSizePixel=0
    NF.Parent=NG
    CC(NF,10) CS(NF,Color3.fromRGB(45,145,255),1.5)

    local Bar=Instance.new("Frame")
    Bar.Size=UDim2.new(0,3,1,-16)
    Bar.Position=UDim2.new(0,8,0,8)
    Bar.BackgroundColor3=Color3.fromRGB(45,145,255)
    Bar.BorderSizePixel=0
    Bar.Parent=NF
    CC(Bar,100)

    MkLabel(NF,{Size=UDim2.new(1,-28,0,22),Position=UDim2.new(0,18,0,9),
        Text=Data.Title or "通知",TextSize=13,Font=Enum.Font.SourceSansBold})
    MkLabel(NF,{Size=UDim2.new(1,-28,0,30),Position=UDim2.new(0,18,0,31),
        Text=Data.Content or "",TextSize=12,Font=Enum.Font.SourceSans,
        TextColor3=Color3.fromRGB(175,180,200),TextWrapped=true})

    task.spawn(function()
        TW(NF,{Position=UDim2.new(1,-10,1,-20)},0.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
        task.wait(Data.Duration or 3)
        TW(NF,{Position=UDim2.new(1,10,1,-20)},0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
        task.wait(0.3)
        NG:Destroy()
    end)
end

-- ================================================================
getgenv().Rayfield = MyEngine
print("[af_hub] v2.5 起動完了 | マウス管理: Rayfield方式(GUI上のみ)")
return MyEngine
