-- af_hub GUI ENGINE - ULTIMATE V3.3
-- Rayfield互換 / 完全日本語 / 一人称視点対応
-- V3.2: CreateTextInput + CreateColorPicker + :Set()メソッド + CreateLogViewer
-- V3.2 PATCH: PlayerList / LogViewer / GameInfo に折りたたみ機能追加
-- V3.3: CreateCollapsibleSection 追加（セクション単位での折りたたみ対応）
-- V3.3 PATCH: CreatePlayerList をテーブル式マルチ選択に変更（複数人同時選択対応）

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
    l.TextSize = 16
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k,v in pairs(props) do pcall(function() l[k] = v end) end
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
    Btn.Size          = UDim2.new(0, 28, 0, 28)
    Btn.Position      = UDim2.new(1, -36, 0, (headerH - 28) / 2)
    Btn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    Btn.BorderSizePixel  = 0
    Btn.Text          = "▲"
    Btn.TextColor3    = Color3.fromRGB(95, 115, 155)
    Btn.TextSize      = 14
    Btn.Font          = Enum.Font.GothamBold
    Btn.AutoButtonColor = false
    Btn.ZIndex        = 20
    Btn.Parent        = F
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
    Flags={}, KillList={}, Blacklist={}, Logs={},
    ToggleKey = Enum.KeyCode.K,
}

local LogListeners = {}
local function AddLog(msg, t)
    table.insert(MyEngine.Logs, {Message=msg, Type=t or "Info", Time=GetTime()})
    if #MyEngine.Logs > 100 then table.remove(MyEngine.Logs, 1) end
    for _, cb in pairs(LogListeners) do pcall(cb) end
end

-- ================================================================
--  起動アニメーション V3 ULTRA
-- ================================================================
local function PlayBoot(sg, onDone)
    local Boot = Instance.new("Frame")
    Boot.Size = UDim2.new(1,0,1,0)
    Boot.BackgroundColor3 = Color3.fromRGB(2,2,5)
    Boot.BorderSizePixel = 0; Boot.ZIndex = 200; Boot.Parent = sg

    for i = 0, 20 do
        local fh = Instance.new("Frame")
        fh.BackgroundColor3 = Color3.fromRGB(14,32,62)
        fh.BackgroundTransparency = 0.80; fh.BorderSizePixel = 0; fh.ZIndex = 201
        fh.Size = UDim2.new(1,0,0,1); fh.Position = UDim2.new(0,0,i/20,0); fh.Parent = Boot
        local fv = Instance.new("Frame")
        fv.BackgroundColor3 = Color3.fromRGB(14,32,62)
        fv.BackgroundTransparency = 0.80; fv.BorderSizePixel = 0; fv.ZIndex = 201
        fv.Size = UDim2.new(0,1,1,0); fv.Position = UDim2.new(i/20,0,0,0); fv.Parent = Boot
    end

    local function MkScan(color, thick, glowH, speed)
        local S = Instance.new("Frame")
        S.Size = UDim2.new(1,0,0,thick); S.BackgroundColor3 = color
        S.BackgroundTransparency = 0.12; S.BorderSizePixel = 0; S.ZIndex = 215; S.Parent = Boot
        local SG2 = Instance.new("Frame")
        SG2.Size = UDim2.new(1,0,0,glowH); SG2.BackgroundColor3 = color
        SG2.BackgroundTransparency = 0.83; SG2.BorderSizePixel = 0; SG2.ZIndex = 214; SG2.Parent = Boot
        task.spawn(function()
            while S.Parent do
                S.Position = UDim2.new(0,0,0,-thick); SG2.Position = UDim2.new(0,0,0,-glowH/2)
                TW(S,{Position=UDim2.new(0,0,1,thick)},speed,Enum.EasingStyle.Linear)
                TW(SG2,{Position=UDim2.new(0,0,1,glowH)},speed,Enum.EasingStyle.Linear)
                task.wait(speed+0.06)
            end
        end)
    end
    MkScan(Color3.fromRGB(40,155,255),2,30,0.95)
    MkScan(Color3.fromRGB(110,220,255),1,14,1.5)

    local function Bracket(corner, delay)
        local sz=38; local pad=22
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0,sz,0,sz); f.BackgroundTransparency = 1; f.ZIndex = 218; f.Parent = Boot
        if corner=="TL" then     f.Position=UDim2.new(0,pad,0,pad)
        elseif corner=="TR" then f.Position=UDim2.new(1,-pad-sz,0,pad)
        elseif corner=="BL" then f.Position=UDim2.new(0,pad,1,-pad-sz)
        else                     f.Position=UDim2.new(1,-pad-sz,1,-pad-sz) end
        local h = Instance.new("Frame")
        h.Size=UDim2.new(0,0,0,2); h.BackgroundColor3=Color3.fromRGB(55,185,255)
        h.BorderSizePixel=0; h.ZIndex=219; h.Parent=f
        local v = Instance.new("Frame")
        v.Size=UDim2.new(0,2,0,0); v.BackgroundColor3=Color3.fromRGB(55,185,255)
        v.BorderSizePixel=0; v.ZIndex=219; v.Parent=f
        if corner=="TR" then
            h.AnchorPoint=Vector2.new(1,0); h.Position=UDim2.new(1,0,0,0); v.Position=UDim2.new(1,-2,0,0)
        elseif corner=="BL" then
            h.Position=UDim2.new(0,0,1,-2); v.AnchorPoint=Vector2.new(0,1); v.Position=UDim2.new(0,0,1,0)
        elseif corner=="BR" then
            h.AnchorPoint=Vector2.new(1,0); h.Position=UDim2.new(1,0,1,-2)
            v.AnchorPoint=Vector2.new(0,1); v.Position=UDim2.new(1,-2,1,0)
        end
        task.spawn(function()
            task.wait(delay)
            TW(h,{Size=UDim2.new(1,0,0,2)},0.22,Enum.EasingStyle.Quint)
            TW(v,{Size=UDim2.new(0,2,1,0)},0.22,Enum.EasingStyle.Quint)
        end)
    end
    Bracket("TL",0.08); Bracket("TR",0.18); Bracket("BL",0.28); Bracket("BR",0.38)

    local hexChars = "0123456789ABCDEF"
    for _ = 1, 26 do
        local xPos = math.random()*0.91
        local hl = MkLabel(Boot,{
            Size=UDim2.new(0,130,0,12), Position=UDim2.new(xPos,0,-0.06,0),
            Text="", TextColor3=Color3.fromRGB(18,55,100), TextSize=9,
            Font=Enum.Font.Code, ZIndex=202, TextXAlignment=Enum.TextXAlignment.Left,
        })
        task.spawn(function()
            task.wait(math.random()*1.8)
            while hl.Parent do
                hl.Position=UDim2.new(xPos,0,-0.06,0); hl.TextTransparency=0
                local fallT=1.6+math.random()*1.4
                TW(hl,{Position=UDim2.new(xPos,0,1.06,0),TextTransparency=0.5},fallT,Enum.EasingStyle.Linear)
                local elapsed=0
                while elapsed<fallT and hl.Parent do
                    local s=""
                    for _=1,math.random(7,16) do s=s..hexChars:sub(math.random(1,16),math.random(1,16)) end
                    hl.Text=s
                    local w=0.07+math.random()*0.09; task.wait(w); elapsed=elapsed+w
                end
                task.wait(math.random()*0.6)
            end
        end)
    end

    local Panel = Instance.new("Frame")
    Panel.Size=UDim2.new(0,490,0,225); Panel.AnchorPoint=Vector2.new(0.5,0.5)
    Panel.Position=UDim2.new(0.5,0,0.75,0); Panel.BackgroundColor3=Color3.fromRGB(6,6,10)
    Panel.BackgroundTransparency=1; Panel.BorderSizePixel=0; Panel.ZIndex=220; Panel.Parent=Boot
    CC(Panel,8)
    local PanelStroke=CS(Panel,Color3.fromRGB(32,105,205),1.5)
    local PanelGrad=Instance.new("UIGradient")
    PanelGrad.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(13,13,20)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(5,5,9)),
    }
    PanelGrad.Rotation=135; PanelGrad.Parent=Panel

    local TopLine=Instance.new("Frame")
    TopLine.Size=UDim2.new(0,0,0,2); TopLine.BackgroundColor3=Color3.fromRGB(50,170,255)
    TopLine.BorderSizePixel=0; TopLine.ZIndex=221; TopLine.Parent=Panel; CC(TopLine,100)
    local BotLine=Instance.new("Frame")
    BotLine.Size=UDim2.new(0,0,0,1); BotLine.Position=UDim2.new(0,0,1,-1)
    BotLine.BackgroundColor3=Color3.fromRGB(28,95,195)
    BotLine.BorderSizePixel=0; BotLine.ZIndex=221; BotLine.Parent=Panel; CC(BotLine,100)

    local Logo=MkLabel(Panel,{
        Size=UDim2.new(1,0,0,56),Position=UDim2.new(0,0,0,16),
        Text="af_hub",TextColor3=Color3.fromRGB(255,255,255),TextSize=46,
        Font=Enum.Font.GothamBold,TextTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Center,ZIndex=222,
    })
    local Sub=MkLabel(Panel,{
        Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,77),
        Text="",TextColor3=Color3.fromRGB(45,145,255),TextSize=11,
        Font=Enum.Font.SourceSansSemibold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=222,
    })

    local TrkBG=Instance.new("Frame")
    TrkBG.Size=UDim2.new(1,-40,0,5); TrkBG.Position=UDim2.new(0,20,0,112)
    TrkBG.BackgroundColor3=Color3.fromRGB(14,14,22); TrkBG.BorderSizePixel=0
    TrkBG.ZIndex=222; TrkBG.Parent=Panel; CC(TrkBG,100); CS(TrkBG,Color3.fromRGB(28,55,115),1)
    local Fill=Instance.new("Frame")
    Fill.Size=UDim2.new(0,0,1,0); Fill.BackgroundColor3=Color3.fromRGB(45,145,255)
    Fill.BorderSizePixel=0; Fill.ZIndex=223; Fill.Parent=TrkBG; CC(Fill,100)
    local Glow=Instance.new("Frame")
    Glow.Size=UDim2.new(0,0,0,18); Glow.Position=UDim2.new(0,0,0.5,-9)
    Glow.BackgroundColor3=Color3.fromRGB(70,175,255); Glow.BackgroundTransparency=0.76
    Glow.BorderSizePixel=0; Glow.ZIndex=221; Glow.Parent=TrkBG; CC(Glow,100)
    local Chip=Instance.new("Frame")
    Chip.Size=UDim2.new(0,7,0,7); Chip.AnchorPoint=Vector2.new(0.5,0.5)
    Chip.Position=UDim2.new(1,0,0.5,0); Chip.BackgroundColor3=Color3.fromRGB(210,240,255)
    Chip.BackgroundTransparency=0.1; Chip.BorderSizePixel=0; Chip.ZIndex=225; Chip.Parent=Fill; CC(Chip,100)

    local PctLbl=MkLabel(Panel,{
        Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,124),
        Text="0%",TextColor3=Color3.fromRGB(55,95,148),TextSize=11,
        Font=Enum.Font.SourceSansSemibold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=222,
    })
    local StatusLbl=MkLabel(Panel,{
        Size=UDim2.new(1,-24,0,16),Position=UDim2.new(0,12,0,148),
        Text="",TextColor3=Color3.fromRGB(38,72,112),TextSize=11,
        Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=222,
    })
    MkLabel(Panel,{
        Size=UDim2.new(1,-16,0,14),Position=UDim2.new(0,8,1,-18),
        Text="v3.3  //  "..LocalPlayer.Name,
        TextColor3=Color3.fromRGB(28,52,82),TextSize=10,
        Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=222,
    })

    local statMsgs={
        "[ CORE_MODULES.LOAD ............. OK ]",
        "[ GUI_ENGINE.INJECT ............. OK ]",
        "[ PLAYER_DATA.LINK .............. OK ]",
        "[ SECURITY_BYPASS.EXEC .......... OK ]",
        "[ SYSTEM.READY .................. OK ]",
    }

    task.spawn(function()
        task.spawn(function()
            local cols={Color3.fromRGB(32,105,205),Color3.fromRGB(50,165,255),
                        Color3.fromRGB(95,215,255),Color3.fromRGB(50,165,255)}
            local ci=1
            while Panel.Parent and Boot.Parent do
                ci=ci%#cols+1; TW(PanelStroke,{Color=cols[ci]},0.45); task.wait(0.5)
            end
        end)
        task.wait(0.12)
        TW(Panel,{Position=UDim2.new(0.5,0,0.5,0),BackgroundTransparency=0},
            0.52,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
        task.wait(0.28)
        TW(TopLine,{Size=UDim2.new(1,0,0,2)},0.38,Enum.EasingStyle.Quint)
        TW(BotLine,{Size=UDim2.new(1,0,0,1)},0.38,Enum.EasingStyle.Quint)
        task.wait(0.18)
        TW(Logo,{TextTransparency=0},0.38,Enum.EasingStyle.Quint)
        task.wait(0.12)
        task.spawn(function()
            for _=1,5 do
                task.wait(0.07+math.random()*0.18)
                if not Logo.Parent then break end
                Logo.Position=UDim2.new(0,math.random(-4,4),0,16)
                Logo.TextColor3=Color3.fromRGB(195+math.random(0,60),math.random(175,255),255)
                task.wait(0.035)
                Logo.Position=UDim2.new(0,0,0,16); Logo.TextColor3=Color3.fromRGB(255,255,255)
            end
        end)
        task.spawn(function() TypeWrite(Sub,"ULTIMATE  //  SYSTEM INITIALIZING...",0.024) end)
        task.wait(0.08)
        local prevMi=0
        for i=1,100 do
            task.wait(0.012)
            local p=i/100; Fill.Size=UDim2.new(p,0,1,0); Glow.Size=UDim2.new(p,0,0,18)
            PctLbl.Text=i.."%"
            local mi=math.ceil(p*#statMsgs)
            if mi>=1 and mi<=#statMsgs and mi~=prevMi then StatusLbl.Text=statMsgs[mi]; prevMi=mi end
        end
        for _=1,3 do
            task.wait(0.055); Fill.BackgroundColor3=Color3.fromRGB(130,215,255)
            task.wait(0.035); Fill.BackgroundColor3=Color3.fromRGB(45,145,255)
        end
        task.wait(0.14)
        local function FlashFrame(col,alpha,fadeOut)
            local Fl=Instance.new("Frame"); Fl.Size=UDim2.new(1,0,1,0)
            Fl.BackgroundColor3=col; Fl.BackgroundTransparency=1
            Fl.BorderSizePixel=0; Fl.ZIndex=300; Fl.Parent=Boot
            TW(Fl,{BackgroundTransparency=alpha},0.07); task.wait(0.07)
            TW(Fl,{BackgroundTransparency=1},fadeOut)
            task.delay(fadeOut,function() pcall(function() Fl:Destroy() end) end)
        end
        FlashFrame(Color3.fromRGB(0,100,255),0.50,0.14);   task.wait(0.11)
        FlashFrame(Color3.fromRGB(255,255,255),0.32,0.16); task.wait(0.09)
        FlashFrame(Color3.fromRGB(100,210,255),0.60,0.10); task.wait(0.07)
        TW(Panel,{Position=UDim2.new(0.5,0,-0.12,0),BackgroundTransparency=1},
            0.38,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
        local Final=Instance.new("Frame"); Final.Size=UDim2.new(1,0,1,0)
        Final.BackgroundColor3=Color3.fromRGB(255,255,255); Final.BackgroundTransparency=1
        Final.BorderSizePixel=0; Final.ZIndex=350; Final.Parent=Boot
        task.wait(0.18); TW(Final,{BackgroundTransparency=0},0.10); task.wait(0.10)
        TW(Final,{BackgroundTransparency=1},0.28); task.wait(0.30)
        Boot:Destroy(); if onDone then onDone() end
    end)
end

-- ================================================================
--  ドラッグ
-- ================================================================
local function MakeDraggable(handle, target)
    local drag,di,ds,sp=false,nil,nil,nil
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
    local WinName=Config.Name or "af_hub"
    if Config.ToggleKey then MyEngine.ToggleKey=Config.ToggleKey end

    local SG=Instance.new("ScreenGui")
    SG.Name="afHub_"..HttpService:GenerateGUID()
    SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    SG.DisplayOrder=100
    SG.ResetOnSpawn=false
    pcall(function() SG.IgnoreGuiInset=true end)
    SG.Parent=LocalPlayer:WaitForChild("PlayerGui")

    PlayBoot(SG,function()
        AddLog("GUI起動完了","Success")
        MouseManager.ShowCursor()
    end)

    local Main=Instance.new("Frame")
    Main.Name="Main"; Main.Size=UDim2.new(0,820,0,520)
    Main.AnchorPoint=Vector2.new(0.5,0.5); Main.Position=UDim2.new(0.5,0,0.5,0)
    Main.BackgroundColor3=Color3.fromRGB(14,14,16); Main.BorderSizePixel=0
    Main.BackgroundTransparency=1; Main.Parent=SG
    CC(Main,12); CS(Main,Color3.fromRGB(38,38,48),2)
    local Grad=Instance.new("UIGradient")
    Grad.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(20,20,24)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(14,14,16)),
    }
    Grad.Rotation=140; Grad.Parent=Main
    task.delay(2.7,function() TW(Main,{BackgroundTransparency=0},0.45) end)
    MouseManager.BindFrame(Main)

    local Sidebar=Instance.new("Frame")
    Sidebar.Size=UDim2.new(0,210,1,0); Sidebar.BackgroundColor3=Color3.fromRGB(10,10,12)
    Sidebar.BorderSizePixel=0; Sidebar.Parent=Main; CC(Sidebar,12)
    local SideDiv=Instance.new("Frame")
    SideDiv.Size=UDim2.new(0,1,1,0); SideDiv.Position=UDim2.new(1,0,0,0)
    SideDiv.BackgroundColor3=Color3.fromRGB(30,30,38); SideDiv.BorderSizePixel=0; SideDiv.Parent=Sidebar

    local TitleBar=Instance.new("Frame")
    TitleBar.Size=UDim2.new(1,0,0,54); TitleBar.BackgroundTransparency=1; TitleBar.Parent=Main
    MakeDraggable(TitleBar,Main)
    MkLabel(TitleBar,{
        Size=UDim2.new(1,-115,1,0),Position=UDim2.new(0,15,0,0),
        Text=WinName,TextSize=20,Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(255,255,255),ZIndex=2,
    })

    local function CtrlBtn(txt,bg,xoff)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0,30,0,30); b.Position=UDim2.new(1,xoff,0.5,-15)
        b.BackgroundColor3=bg; b.BorderSizePixel=0
        b.Text=txt; b.TextColor3=Color3.fromRGB(255,255,255)
        b.TextSize=15; b.Font=Enum.Font.GothamBold
        b.AutoButtonColor=false; b.Parent=TitleBar; CC(b,6); return b
    end
    local CloseBtn=CtrlBtn("✕",Color3.fromRGB(170,48,48),-10)
    local MinBtn=CtrlBtn("—",Color3.fromRGB(26,26,32),-46)
    CloseBtn.MouseEnter:Connect(function() TW(CloseBtn,{BackgroundColor3=Color3.fromRGB(205,58,58)},0.1) end)
    CloseBtn.MouseLeave:Connect(function() TW(CloseBtn,{BackgroundColor3=Color3.fromRGB(170,48,48)},0.1) end)
    MinBtn.MouseEnter:Connect(function()   TW(MinBtn,{BackgroundColor3=Color3.fromRGB(42,42,52)},0.1) end)
    MinBtn.MouseLeave:Connect(function()   TW(MinBtn,{BackgroundColor3=Color3.fromRGB(26,26,32)},0.1) end)

    local Mini=Instance.new("TextButton")
    Mini.Size=UDim2.new(0,50,0,50); Mini.AnchorPoint=Vector2.new(0,1)
    Mini.Position=UDim2.new(0,20,1,-20); Mini.BackgroundColor3=Color3.fromRGB(14,14,16)
    Mini.BorderSizePixel=0; Mini.Text="◈"; Mini.TextColor3=Color3.fromRGB(50,150,255)
    Mini.TextSize=22; Mini.Font=Enum.Font.GothamBold
    Mini.AutoButtonColor=false; Mini.Visible=false; Mini.ZIndex=50; Mini.Parent=SG
    CC(Mini,10); CS(Mini,Color3.fromRGB(50,150,255),2)
    MakeDraggable(Mini,Mini); MouseManager.BindFrame(Mini)

    local TabScroll=Instance.new("ScrollingFrame")
    TabScroll.Size=UDim2.new(1,-10,1,-190); TabScroll.Position=UDim2.new(0,5,0,58)
    TabScroll.BackgroundTransparency=1; TabScroll.BorderSizePixel=0
    TabScroll.ScrollBarThickness=2; TabScroll.ScrollBarImageColor3=Color3.fromRGB(55,55,65)
    TabScroll.Parent=Sidebar
    local TL=Instance.new("UIListLayout")
    TL.Padding=UDim.new(0,5); TL.SortOrder=Enum.SortOrder.LayoutOrder; TL.Parent=TabScroll
    TL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabScroll.CanvasSize=UDim2.new(0,0,0,TL.AbsoluteContentSize.Y+8)
    end)

    local AccSec=Instance.new("Frame")
    AccSec.Size=UDim2.new(1,-10,0,80); AccSec.Position=UDim2.new(0,5,1,-85)
    AccSec.BackgroundColor3=Color3.fromRGB(15,15,18); AccSec.BorderSizePixel=0; AccSec.Parent=Sidebar
    CC(AccSec,8); CS(AccSec,Color3.fromRGB(36,36,44),1)
    local AccIco=Instance.new("ImageLabel")
    AccIco.Size=UDim2.new(0,50,0,50); AccIco.Position=UDim2.new(0,10,0.5,-25)
    AccIco.BackgroundTransparency=1
    AccIco.Image="rbxthumb://type=AvatarHeadShot&id="..LocalPlayer.UserId.."&w=150&h=150"
    AccIco.Parent=AccSec; CC(AccIco,100)
    MkLabel(AccSec,{
        Size=UDim2.new(1,-72,0,26),Position=UDim2.new(0,66,0.15,0),
        Text=LocalPlayer.DisplayName,TextSize=16,Font=Enum.Font.SourceSansBold,
    })
    MkLabel(AccSec,{
        Size=UDim2.new(1,-72,0,18),Position=UDim2.new(0,66,0.60,0),
        Text="@"..LocalPlayer.Name,TextSize=14,Font=Enum.Font.SourceSans,
        TextColor3=Color3.fromRGB(65,125,195),
    })
    local ODot=Instance.new("Frame")
    ODot.Size=UDim2.new(0,8,0,8); ODot.Position=UDim2.new(0,56,1,-16)
    ODot.BackgroundColor3=Color3.fromRGB(50,225,100); ODot.BorderSizePixel=0; ODot.Parent=AccSec; CC(ODot,100)

    local CA=Instance.new("Frame")
    CA.Size=UDim2.new(1,-220,1,-64); CA.Position=UDim2.new(0,215,0,54)
    CA.BackgroundTransparency=1; CA.Parent=Main

    local isOpen=true; local isMin=false; local busy=false

    local function Open(v)
        if busy then return end; isOpen=v
        if v then
            busy=true; Main.Visible=true
            MouseManager.ShowCursor()
            Main.Size=UDim2.new(0,785,0,498); Main.BackgroundTransparency=1
            TW(Main,{Size=UDim2.new(0,820,0,520),BackgroundTransparency=0},
                0.38,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
            task.delay(0.38,function() busy=false end)
        else
            busy=true
            local t=TW(Main,{Size=UDim2.new(0,795,0,508),BackgroundTransparency=1},
                0.3,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
            t.Completed:Connect(function()
                Main.Visible=false; Main.Size=UDim2.new(0,820,0,520)
                MouseManager.StopOverride(); MouseManager.HideCursor(); busy=false
            end)
        end
    end

    local function Minimize(v)
        if busy then return end; isMin=v; busy=true
        if v then
            TW(Main,{Size=UDim2.new(0,50,0,50),BackgroundTransparency=1},
                0.36,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
            task.delay(0.36,function()
                Main.Visible=false; Main.Size=UDim2.new(0,820,0,520)
                Mini.Visible=true; Mini.BackgroundTransparency=1; Mini.Size=UDim2.new(0,38,0,38)
                TW(Mini,{BackgroundTransparency=0,Size=UDim2.new(0,50,0,50)},
                    0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                MouseManager.HideCursor()
                busy=false
            end)
        else
            TW(Mini,{BackgroundTransparency=1,Size=UDim2.new(0,38,0,38)},
                0.2,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
            task.delay(0.2,function()
                Mini.Visible=false; Mini.Size=UDim2.new(0,50,0,50)
                Main.Visible=true; Main.Size=UDim2.new(0,785,0,498); Main.BackgroundTransparency=1
                MouseManager.ShowCursor()
                TW(Main,{Size=UDim2.new(0,820,0,520),BackgroundTransparency=0},
                    0.38,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                task.delay(0.38,function() busy=false end)
            end)
        end
    end

    UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode==MyEngine.ToggleKey then
            if busy then return end
            if isMin then Minimize(false) else Open(not isOpen) end
        end
    end)

    MinBtn.MouseButton1Click:Connect(function() Minimize(true) end)
    CloseBtn.MouseButton1Click:Connect(function() Open(false) end)
    Mini.MouseButton1Click:Connect(function() Minimize(false) end)

    -- ================================================================
    --  Window
    -- ================================================================
    local Window={_Main=Main,_Sidebar=Sidebar,_TabScroll=TabScroll,_CA=CA,_Tabs={}}

    local TAB_ACTIVE_BG   = Color3.fromRGB(255,255,255)
    local TAB_ACTIVE_TEXT = Color3.fromRGB(16,16,20)
    local TAB_IDLE_BG     = Color3.fromRGB(17,17,20)
    local TAB_IDLE_TEXT   = Color3.fromRGB(155,155,170)

    function Window:CreateTab(TabName)
        local TBtn=Instance.new("TextButton")
        TBtn.Size=UDim2.new(1,-8,0,44)
        TBtn.BackgroundColor3=TAB_IDLE_BG
        TBtn.BorderSizePixel=0
        TBtn.Text="  "..TabName
        TBtn.TextColor3=TAB_IDLE_TEXT
        TBtn.TextSize=17
        TBtn.Font=Enum.Font.GothamSemibold
        TBtn.TextXAlignment=Enum.TextXAlignment.Left
        TBtn.AutoButtonColor=false; TBtn.Parent=TabScroll
        CC(TBtn,7)

        local Acc=Instance.new("Frame")
        Acc.Size=UDim2.new(0,3,0.55,0); Acc.Position=UDim2.new(0,0,0.225,0)
        Acc.BackgroundColor3=Color3.fromRGB(50,150,255)
        Acc.BorderSizePixel=0; Acc.BackgroundTransparency=1; Acc.Parent=TBtn; CC(Acc,100)

        local TC=Instance.new("ScrollingFrame")
        TC.Name=TabName.."_C"; TC.Size=UDim2.new(1,0,1,0)
        TC.BackgroundTransparency=1; TC.BorderSizePixel=0
        TC.ScrollBarThickness=3; TC.ScrollBarImageColor3=Color3.fromRGB(55,55,65)
        TC.Visible=false; TC.Parent=CA
        local CL=Instance.new("UIListLayout")
        CL.Padding=UDim.new(0,8); CL.SortOrder=Enum.SortOrder.LayoutOrder; CL.Parent=TC
        local CP=Instance.new("UIPadding")
        CP.PaddingTop=UDim.new(0,8); CP.PaddingRight=UDim.new(0,10); CP.Parent=TC
        CL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TC.CanvasSize=UDim2.new(0,0,0,CL.AbsoluteContentSize.Y+18)
        end)

        TBtn.MouseButton1Click:Connect(function()
            for _,t in pairs(Window._Tabs) do
                TW(t.B,{BackgroundColor3=TAB_IDLE_BG,TextColor3=TAB_IDLE_TEXT},0.14)
                t.A.BackgroundTransparency=1; t.C.Visible=false
            end
            TW(TBtn,{BackgroundColor3=TAB_ACTIVE_BG,TextColor3=TAB_ACTIVE_TEXT},0.14)
            Acc.BackgroundTransparency=1
            TC.Visible=true
        end)

        if #Window._Tabs==0 then
            TBtn.BackgroundColor3=TAB_ACTIVE_BG
            TBtn.TextColor3=TAB_ACTIVE_TEXT
            Acc.BackgroundTransparency=1; TC.Visible=true
        end

        local Tab={B=TBtn,A=Acc,C=TC,Elements={}}
        table.insert(Window._Tabs,Tab)

        -- ================================================================
        --  要素ビルダー（コンテナを引数に取り、全要素を生成して返す）
        --  ※ Tab直下 / CreateCollapsibleSection 両方で共用
        -- ================================================================
        local function buildCreators(container)
            local Creators = {}

            -- ── セクション ────────────────────────────────────────
            function Creators:CreateSection(n)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,26); f.BackgroundTransparency=1; f.Parent=container
                MkLabel(f,{
                    Size=UDim2.new(0.65,0,1,0),Position=UDim2.new(0,6,0,0),
                    Text=n,TextColor3=Color3.fromRGB(85,125,175),TextSize=14,
                    Font=Enum.Font.GothamSemibold,
                })
                local ln=Instance.new("Frame")
                ln.Size=UDim2.new(1,-8,0,1); ln.Position=UDim2.new(0,4,1,-1)
                ln.BackgroundColor3=Color3.fromRGB(28,28,36); ln.BorderSizePixel=0; ln.Parent=f
            end

            -- ── ラベル ────────────────────────────────────────────
            function Creators:CreateLabel(text)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,28); f.BackgroundTransparency=1; f.Parent=container
                MkLabel(f,{
                    Size=UDim2.new(1,-18,1,0),Position=UDim2.new(0,12,0,0),
                    Text=text or "",TextSize=14,Font=Enum.Font.SourceSans,
                    TextColor3=Color3.fromRGB(145,150,168),TextWrapped=true,
                })
            end

            -- ── パラグラフ ────────────────────────────────────────
            function Creators:CreateParagraph(Data)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,60); f.BackgroundColor3=Color3.fromRGB(18,18,22)
                f.BorderSizePixel=0; f.Parent=container; CC(f,7); CS(f,Color3.fromRGB(34,34,42),1)
                MkLabel(f,{
                    Size=UDim2.new(1,-18,0,22),Position=UDim2.new(0,12,0,6),
                    Text=Data.Title or "",TextSize=15,Font=Enum.Font.GothamSemibold,
                    TextColor3=Color3.fromRGB(200,210,230),
                })
                local body=MkLabel(f,{
                    Size=UDim2.new(1,-18,0,30),Position=UDim2.new(0,12,0,30),
                    Text=Data.Content or "",TextSize=14,Font=Enum.Font.SourceSans,
                    TextColor3=Color3.fromRGB(140,148,168),TextWrapped=true,
                })
                local function resize()
                    local ts=game:GetService("TextService")
                    local h=ts:GetTextSize(body.Text,14,Enum.Font.SourceSans,
                        Vector2.new(body.AbsoluteSize.X,9999)).Y
                    body.Size=UDim2.new(1,-18,0,h+4)
                    f.Size=UDim2.new(1,0,0,h+44)
                end
                body:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
                task.defer(resize)
            end

            -- ── ボタン ────────────────────────────────────────────
            function Creators:CreateButton(Data)
                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,44); F.BackgroundColor3=Color3.fromRGB(20,20,24)
                F.BorderSizePixel=0; F.Parent=container; CC(F,7); CS(F,Color3.fromRGB(34,34,42),1)
                local B=Instance.new("TextButton")
                B.Size=UDim2.new(1,0,1,0); B.BackgroundTransparency=1
                B.Text=Data.Name or "ボタン"; B.TextColor3=Color3.fromRGB(235,235,245)
                B.TextSize=17; B.Font=Enum.Font.SourceSansSemibold; B.Parent=F
                B.MouseButton1Click:Connect(function()
                    TW(F,{BackgroundColor3=Color3.fromRGB(30,30,38)},0.08)
                    task.delay(0.08,function() TW(F,{BackgroundColor3=Color3.fromRGB(20,20,24)},0.12) end)
                    if Data.Callback then pcall(Data.Callback) end
                    AddLog("実行: "..(Data.Name or "?"),"Action")
                end)
            end

            -- ── トグル ────────────────────────────────────────────
            function Creators:CreateToggle(Data)
                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,44); F.BackgroundColor3=Color3.fromRGB(20,20,24)
                F.BorderSizePixel=0; F.Parent=container; CC(F,7); CS(F,Color3.fromRGB(34,34,42),1)
                MkLabel(F,{
                    Size=UDim2.new(1,-72,1,0),Position=UDim2.new(0,14,0,0),
                    Text=Data.Name or "トグル",TextSize=17,Font=Enum.Font.SourceSans,
                })
                local Trk=Instance.new("Frame")
                Trk.Size=UDim2.new(0,48,0,24); Trk.Position=UDim2.new(1,-58,0.5,-12)
                Trk.BackgroundColor3=Color3.fromRGB(36,36,44); Trk.BorderSizePixel=0
                Trk.Parent=F; CC(Trk,100)
                local Cir=Instance.new("Frame")
                Cir.Size=UDim2.new(0,20,0,20); Cir.Position=UDim2.new(0,2,0.5,-10)
                Cir.BackgroundColor3=Color3.fromRGB(185,185,200); Cir.BorderSizePixel=0
                Cir.Parent=Trk; CC(Cir,100)
                local HitBtn=Instance.new("TextButton")
                HitBtn.Size=UDim2.new(1,0,1,0); HitBtn.Position=UDim2.new(0,0,0,0)
                HitBtn.BackgroundTransparency=1; HitBtn.Text=""
                HitBtn.AutoButtonColor=false; HitBtn.ZIndex=5; HitBtn.Parent=F
                local val=Data.CurrentValue or false
                local function ApplyVisual(v, animate)
                    if v then
                        if animate then TW(Trk,{BackgroundColor3=Color3.fromRGB(42,138,242)},0.18)
                                         TW(Cir,{Position=UDim2.new(1,-22,0.5,-10)},0.18)
                        else Trk.BackgroundColor3=Color3.fromRGB(42,138,242)
                             Cir.Position=UDim2.new(1,-22,0.5,-10) end
                    else
                        if animate then TW(Trk,{BackgroundColor3=Color3.fromRGB(36,36,44)},0.18)
                                         TW(Cir,{Position=UDim2.new(0,2,0.5,-10)},0.18)
                        else Trk.BackgroundColor3=Color3.fromRGB(36,36,44)
                             Cir.Position=UDim2.new(0,2,0.5,-10) end
                    end
                end
                ApplyVisual(val, false)
                HitBtn.MouseEnter:Connect(function() TW(F,{BackgroundColor3=Color3.fromRGB(26,26,32)},0.08) end)
                HitBtn.MouseLeave:Connect(function() TW(F,{BackgroundColor3=Color3.fromRGB(20,20,24)},0.08) end)
                HitBtn.MouseButton1Click:Connect(function()
                    val=not val; ApplyVisual(val, true)
                    if Data.Callback then pcall(Data.Callback,val) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=val
                    AddLog("トグル: "..(Data.Name or "?").." = "..tostring(val),"Action")
                end)
                local Elem={}
                function Elem:Set(v) val=v; ApplyVisual(val,true)
                    if Data.Callback then pcall(Data.Callback,val) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=val
                end
                function Elem:Get() return val end
                return Elem
            end

            -- ── スライダー ────────────────────────────────────────
            function Creators:CreateSlider(Data)
                local Min=Data.Range[1]; local Max=Data.Range[2]
                local Inc=Data.Increment or 1
                local cur=math.clamp(Data.CurrentValue or Min,Min,Max)
                local dr=false
                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,54); F.BackgroundColor3=Color3.fromRGB(20,20,24)
                F.BorderSizePixel=0; F.Parent=container; CC(F,7); CS(F,Color3.fromRGB(34,34,42),1)
                MkLabel(F,{
                    Size=UDim2.new(1,-90,0,30),Position=UDim2.new(0,14,0,0),
                    Text=Data.Name or "スライダー",TextSize=17,Font=Enum.Font.SourceSans,
                    TextColor3=Color3.fromRGB(220,225,240),
                })
                local VL=MkLabel(F,{
                    Size=UDim2.new(0,72,0,30),Position=UDim2.new(1,-80,0,0),
                    Text="",TextColor3=Color3.fromRGB(50,138,220),TextSize=15,
                    Font=Enum.Font.GothamSemibold,TextXAlignment=Enum.TextXAlignment.Right,
                })
                local TrkBG=Instance.new("Frame")
                TrkBG.Size=UDim2.new(1,-28,0,8); TrkBG.Position=UDim2.new(0,14,1,-18)
                TrkBG.BackgroundColor3=Color3.fromRGB(25,25,30)
                TrkBG.BorderSizePixel=0; TrkBG.ZIndex=2; TrkBG.Parent=F; CC(TrkBG,100)
                CS(TrkBG,Color3.fromRGB(40,40,52),1)
                local Fil=Instance.new("Frame")
                Fil.Size=UDim2.new(0,0,1,0); Fil.BackgroundColor3=Color3.fromRGB(50,138,220)
                Fil.BorderSizePixel=0; Fil.ZIndex=3; Fil.Parent=TrkBG; CC(Fil,100)
                local FilStroke=Instance.new("UIStroke")
                FilStroke.Color=Color3.fromRGB(58,163,255); FilStroke.Thickness=1.2
                FilStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; FilStroke.Parent=Fil
                local Hit=Instance.new("TextButton")
                Hit.Size=UDim2.new(1,0,1,0); Hit.BackgroundTransparency=1
                Hit.Text=""; Hit.AutoButtonColor=false; Hit.ZIndex=10; Hit.Parent=F
                local function MouseRatio()
                    local ax=TrkBG.AbsolutePosition.X; local aw=TrkBG.AbsoluteSize.X
                    if aw<=0 then return 0 end
                    return math.clamp((UserInputService:GetMouseLocation().X-ax)/aw,0,1)
                end
                local function Upd(v)
                    v=math.clamp(math.floor(v/Inc+0.5)*Inc,Min,Max); cur=v
                    local ratio=(Max==Min) and 0 or (v-Min)/(Max-Min)
                    Fil.Size=UDim2.new(ratio,0,1,0)
                    VL.Text=tostring(v)..(Data.Suffix or "")
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=v
                end
                Upd(cur)
                Hit.InputBegan:Connect(function(i)
                    if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                    dr=true; Upd(Min+(Max-Min)*MouseRatio())
                    TW(Fil,{BackgroundColor3=Color3.fromRGB(65,155,255)},0.1)
                    TW(FilStroke,{Color=Color3.fromRGB(90,185,255)},0.1)
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if dr and i.UserInputType==Enum.UserInputType.MouseMovement then
                        Upd(Min+(Max-Min)*MouseRatio())
                    end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 and dr then
                        dr=false
                        TW(Fil,{BackgroundColor3=Color3.fromRGB(50,138,220)},0.15)
                        TW(FilStroke,{Color=Color3.fromRGB(58,163,255)},0.15)
                        if Data.Callback then pcall(Data.Callback,cur) end
                        AddLog((Data.Name or "スライダー").." = "..tostring(cur),"Action")
                    end
                end)
                Hit.MouseEnter:Connect(function() TW(F,{BackgroundColor3=Color3.fromRGB(25,25,30)},0.1) end)
                Hit.MouseLeave:Connect(function()
                    if not dr then TW(F,{BackgroundColor3=Color3.fromRGB(20,20,24)},0.1) end
                end)
                local Elem={}
                function Elem:Set(v) Upd(v); if Data.Callback then pcall(Data.Callback,cur) end end
                function Elem:Get() return cur end
                return Elem
            end

            -- ── ドロップダウン ────────────────────────────────────
            function Creators:CreateDropdown(Data)
                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,44); F.BackgroundColor3=Color3.fromRGB(20,20,24)
                F.BorderSizePixel=0; F.Parent=container; CC(F,7); CS(F,Color3.fromRGB(34,34,42),1)
                local DB=Instance.new("TextButton")
                DB.Size=UDim2.new(1,0,1,0); DB.BackgroundTransparency=1
                DB.Text="  "..(Data.Name or "選択")..":  "..(Data.CurrentOption or "未選択")
                DB.TextColor3=Color3.fromRGB(235,235,245); DB.TextSize=17
                DB.Font=Enum.Font.SourceSans; DB.TextXAlignment=Enum.TextXAlignment.Left; DB.Parent=F
                local Arr=MkLabel(F,{
                    Size=UDim2.new(0,24,1,0),Position=UDim2.new(1,-28,0,0),
                    Text="▾",TextColor3=Color3.fromRGB(95,115,145),TextSize=16,
                    Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,
                })
                local OC=Instance.new("Frame")
                OC.Size=UDim2.new(1,0,0,0); OC.Position=UDim2.new(0,0,1,3)
                OC.BackgroundColor3=Color3.fromRGB(16,16,20); OC.BorderSizePixel=0
                OC.Visible=false; OC.ZIndex=10; OC.Parent=F; CC(OC,7); CS(OC,Color3.fromRGB(34,34,42),1)
                Instance.new("UIListLayout").Parent=OC
                local op=false
                DB.MouseButton1Click:Connect(function()
                    op=not op; OC.Visible=op
                    if op then
                        local h=math.min(#(Data.Options or {})*34,185)
                        TW(OC,{Size=UDim2.new(1,0,0,h)},0.18)
                        TW(F,{Size=UDim2.new(1,0,0,44+h+4)},0.18); Arr.Text="▴"
                    else
                        TW(OC,{Size=UDim2.new(1,0,0,0)},0.18)
                        TW(F,{Size=UDim2.new(1,0,0,44)},0.18); Arr.Text="▾"
                    end
                end)
                for _,opt in pairs(Data.Options or {}) do
                    local OB=Instance.new("TextButton")
                    OB.Size=UDim2.new(1,0,0,34); OB.BackgroundColor3=Color3.fromRGB(20,20,26)
                    OB.BorderSizePixel=0; OB.Text="  "..opt
                    OB.TextColor3=Color3.fromRGB(195,200,215); OB.TextSize=16
                    OB.Font=Enum.Font.SourceSans; OB.TextXAlignment=Enum.TextXAlignment.Left
                    OB.AutoButtonColor=false; OB.ZIndex=11; OB.Parent=OC
                    OB.MouseEnter:Connect(function() TW(OB,{BackgroundColor3=Color3.fromRGB(28,28,36)},0.08) end)
                    OB.MouseLeave:Connect(function() TW(OB,{BackgroundColor3=Color3.fromRGB(20,20,26)},0.08) end)
                    OB.MouseButton1Click:Connect(function()
                        DB.Text="  "..(Data.Name or "選択")..":  "..opt
                        op=false; OC.Visible=false; Arr.Text="▾"
                        TW(OC,{Size=UDim2.new(1,0,0,0)},0.18)
                        TW(F,{Size=UDim2.new(1,0,0,44)},0.18)
                        if Data.Callback then pcall(Data.Callback,opt) end
                        MyEngine.Flags[Data.Flag or Data.Name or ""]=opt
                    end)
                end
                local Elem={}
                function Elem:Set(opt)
                    DB.Text="  "..(Data.Name or "選択")..":  "..opt
                    op=false; OC.Visible=false; Arr.Text="▾"
                    TW(OC,{Size=UDim2.new(1,0,0,0)},0.18); TW(F,{Size=UDim2.new(1,0,0,44)},0.18)
                    if Data.Callback then pcall(Data.Callback,opt) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=opt
                end
                function Elem:Refresh(newOptions)
                    for _,c in pairs(OC:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    Data.Options = newOptions
                    for _,opt in pairs(newOptions or {}) do
                        local OB=Instance.new("TextButton")
                        OB.Size=UDim2.new(1,0,0,34); OB.BackgroundColor3=Color3.fromRGB(20,20,26)
                        OB.BorderSizePixel=0; OB.Text="  "..opt
                        OB.TextColor3=Color3.fromRGB(195,200,215); OB.TextSize=16
                        OB.Font=Enum.Font.SourceSans; OB.TextXAlignment=Enum.TextXAlignment.Left
                        OB.AutoButtonColor=false; OB.ZIndex=11; OB.Parent=OC
                        OB.MouseEnter:Connect(function() TW(OB,{BackgroundColor3=Color3.fromRGB(28,28,36)},0.08) end)
                        OB.MouseLeave:Connect(function() TW(OB,{BackgroundColor3=Color3.fromRGB(20,20,26)},0.08) end)
                        OB.MouseButton1Click:Connect(function()
                            DB.Text="  "..(Data.Name or "選択")..":  "..opt
                            op=false; OC.Visible=false; Arr.Text="▾"
                            TW(OC,{Size=UDim2.new(1,0,0,0)},0.18)
                            TW(F,{Size=UDim2.new(1,0,0,44)},0.18)
                            if Data.Callback then pcall(Data.Callback,opt) end
                            MyEngine.Flags[Data.Flag or Data.Name or ""]=opt
                        end)
                    end
                end
                function Elem:Get() local t=DB.Text:match(":  (.+)$"); return t end
                return Elem
            end

            -- ── キーバインド設定 ──────────────────────────────────
            function Creators:CreateKeybind(Data)
                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,44); F.BackgroundColor3=Color3.fromRGB(20,20,24)
                F.BorderSizePixel=0; F.Parent=container; CC(F,7); CS(F,Color3.fromRGB(34,34,42),1)
                MkLabel(F,{
                    Size=UDim2.new(1,-118,1,0),Position=UDim2.new(0,14,0,0),
                    Text=Data.Name or "キーバインド",TextSize=17,Font=Enum.Font.SourceSans,
                })
                local KB=Instance.new("TextButton")
                KB.Size=UDim2.new(0,102,0,28); KB.Position=UDim2.new(1,-110,0.5,-14)
                KB.BackgroundColor3=Color3.fromRGB(26,26,36); KB.BorderSizePixel=0
                KB.Font=Enum.Font.GothamSemibold; KB.TextSize=15
                KB.TextColor3=Color3.fromRGB(155,200,255); KB.AutoButtonColor=false; KB.Parent=F
                CC(KB,6); CS(KB,Color3.fromRGB(48,78,130),1)
                local function KeyName(kc)
                    local s=tostring(kc); return s:match("Enum%.KeyCode%.(.+)") or s
                end
                local isMain=(Data.IsToggleKey==true)
                local curKey=Data.CurrentKey or MyEngine.ToggleKey
                KB.Text="[ "..KeyName(curKey).." ]"
                local listening=false; local listenConn=nil; local blinking=false
                KB.MouseButton1Click:Connect(function()
                    if listening then return end
                    listening=true; blinking=true
                    TW(KB,{BackgroundColor3=Color3.fromRGB(16,16,26)},0.1)
                    TW(KB,{TextColor3=Color3.fromRGB(255,220,55)},0.1)
                    KB.Text="[ ??? ]"
                    task.spawn(function()
                        while blinking and KB.Parent do
                            KB.BackgroundTransparency=0; task.wait(0.32)
                            if blinking then KB.BackgroundTransparency=0.45; task.wait(0.32) end
                        end
                        KB.BackgroundTransparency=0
                    end)
                    listenConn=UserInputService.InputBegan:Connect(function(inp)
                        if not listening then return end
                        if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
                        local kc=inp.KeyCode; listening=false; blinking=false
                        if kc==Enum.KeyCode.Escape then KB.Text="[ "..KeyName(curKey).." ]"
                        else
                            curKey=kc; KB.Text="[ "..KeyName(curKey).." ]"
                            if isMain then MyEngine.ToggleKey=curKey
                                AddLog("トグルキー変更 → "..KeyName(curKey),"Action")
                            end
                            if Data.Callback then pcall(Data.Callback,curKey) end
                            MyEngine.Flags[Data.Flag or Data.Name or ""]=curKey
                        end
                        TW(KB,{BackgroundColor3=Color3.fromRGB(26,26,36),TextColor3=Color3.fromRGB(155,200,255)},0.15)
                        if listenConn then listenConn:Disconnect(); listenConn=nil end
                    end)
                end)
                KB.MouseEnter:Connect(function()
                    if not listening then TW(KB,{BackgroundColor3=Color3.fromRGB(34,34,48)},0.1) end
                end)
                KB.MouseLeave:Connect(function()
                    if not listening then TW(KB,{BackgroundColor3=Color3.fromRGB(26,26,36)},0.1) end
                end)
            end

            -- ── テキスト入力 ──────────────────────────────────────
            function Creators:CreateTextInput(Data)
                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,70); F.BackgroundColor3=Color3.fromRGB(20,20,24)
                F.BorderSizePixel=0; F.Parent=container; CC(F,7); CS(F,Color3.fromRGB(34,34,42),1)
                MkLabel(F,{
                    Size=UDim2.new(1,-20,0,22),Position=UDim2.new(0,14,0,6),
                    Text=Data.Name or "テキスト入力",TextSize=14,Font=Enum.Font.GothamSemibold,
                    TextColor3=Color3.fromRGB(95,115,155),
                })
                local TB=Instance.new("TextBox")
                TB.Size=UDim2.new(1,-18,0,32); TB.Position=UDim2.new(0,9,1,-39)
                TB.BackgroundColor3=Color3.fromRGB(13,13,18); TB.BorderSizePixel=0
                TB.PlaceholderText=Data.PlaceholderText or "入力..."
                TB.PlaceholderColor3=Color3.fromRGB(70,75,95)
                TB.Text=Data.DefaultValue or ""
                TB.TextColor3=Color3.fromRGB(220,225,240); TB.TextSize=16
                TB.Font=Enum.Font.SourceSans; TB.ClearTextOnFocus=false; TB.Parent=F; CC(TB,6)
                CS(TB,Color3.fromRGB(34,34,52),1)
                TB.Focused:Connect(function() TW(TB,{BackgroundColor3=Color3.fromRGB(16,16,26)},0.1) end)
                TB.FocusLost:Connect(function(enter)
                    TW(TB,{BackgroundColor3=Color3.fromRGB(13,13,18)},0.1)
                    if Data.Callback then pcall(Data.Callback,TB.Text,enter) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=TB.Text
                    if enter then AddLog("入力確定: "..(Data.Name or "?").." = "..TB.Text,"Action") end
                end)
                local Elem={}
                function Elem:Set(text) TB.Text=text or ""
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=TB.Text
                end
                function Elem:Get() return TB.Text end
                return Elem
            end

            -- ── カラーピッカー ────────────────────────────────────
            function Creators:CreateColorPicker(Data)
                local initCol=Data.Color or Color3.fromRGB(255,85,85)
                local H,S,V=initCol:ToHSV()
                local opened=false
                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,44); F.BackgroundColor3=Color3.fromRGB(20,20,24)
                F.BorderSizePixel=0; F.Parent=container; CC(F,7); CS(F,Color3.fromRGB(34,34,42),1)
                MkLabel(F,{
                    Size=UDim2.new(1,-80,1,0),Position=UDim2.new(0,14,0,0),
                    Text=Data.Name or "カラー",TextSize=17,Font=Enum.Font.SourceSans,
                })
                local Preview=Instance.new("Frame")
                Preview.Size=UDim2.new(0,28,0,28); Preview.Position=UDim2.new(1,-68,0.5,-14)
                Preview.BackgroundColor3=initCol; Preview.BorderSizePixel=0; Preview.Parent=F; CC(Preview,6)
                CS(Preview,Color3.fromRGB(55,55,70),1)
                local HexLbl=MkLabel(F,{
                    Size=UDim2.new(0,50,0,20),Position=UDim2.new(1,-118,0.5,-10),
                    Text="",TextSize=11,Font=Enum.Font.Code,
                    TextColor3=Color3.fromRGB(95,115,155),TextXAlignment=Enum.TextXAlignment.Right,
                })
                local TogBtn=Instance.new("TextButton")
                TogBtn.Size=UDim2.new(0,22,0,22); TogBtn.Position=UDim2.new(1,-36,0.5,-11)
                TogBtn.BackgroundColor3=Color3.fromRGB(28,28,38); TogBtn.BorderSizePixel=0
                TogBtn.Text="▾"; TogBtn.TextColor3=Color3.fromRGB(155,160,185)
                TogBtn.TextSize=14; TogBtn.Font=Enum.Font.GothamBold
                TogBtn.AutoButtonColor=false; TogBtn.Parent=F; CC(TogBtn,6)
                local CPanel=Instance.new("Frame")
                CPanel.Size=UDim2.new(1,0,0,0); CPanel.Position=UDim2.new(0,0,1,4)
                CPanel.BackgroundColor3=Color3.fromRGB(15,15,19); CPanel.BorderSizePixel=0
                CPanel.Visible=false; CPanel.ZIndex=5; CPanel.Parent=F; CC(CPanel,7)
                CS(CPanel,Color3.fromRGB(34,34,48),1)
                local BigPrev=Instance.new("Frame")
                BigPrev.Size=UDim2.new(1,-20,0,46); BigPrev.Position=UDim2.new(0,10,0,10)
                BigPrev.BackgroundColor3=initCol; BigPrev.BorderSizePixel=0; BigPrev.ZIndex=6; BigPrev.Parent=CPanel
                CC(BigPrev,8); CS(BigPrev,Color3.fromRGB(50,50,70),1.5)
                local function MkHsvSlider(label,yPos,initVal,col1,col2)
                    MkLabel(CPanel,{
                        Size=UDim2.new(0,14,0,16),Position=UDim2.new(0,10,0,yPos),
                        Text=label,TextSize=12,Font=Enum.Font.GothamSemibold,
                        TextColor3=Color3.fromRGB(95,115,155),ZIndex=6,
                    })
                    local ValLbl=MkLabel(CPanel,{
                        Size=UDim2.new(0,28,0,16),Position=UDim2.new(1,-34,0,yPos),
                        Text="",TextSize=11,Font=Enum.Font.Code,
                        TextColor3=Color3.fromRGB(95,115,155),ZIndex=6,
                        TextXAlignment=Enum.TextXAlignment.Right,
                    })
                    local TrkBG2=Instance.new("Frame")
                    TrkBG2.Size=UDim2.new(1,-54,0,8); TrkBG2.Position=UDim2.new(0,26,0,yPos+4)
                    TrkBG2.BorderSizePixel=0; TrkBG2.ZIndex=6; TrkBG2.Parent=CPanel; CC(TrkBG2,100)
                    local Grad2=Instance.new("UIGradient")
                    Grad2.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,col1),ColorSequenceKeypoint.new(1,col2)}
                    Grad2.Parent=TrkBG2
                    local Knob=Instance.new("Frame")
                    Knob.Size=UDim2.new(0,14,0,14); Knob.AnchorPoint=Vector2.new(0.5,0.5)
                    Knob.Position=UDim2.new(initVal,0,0.5,0); Knob.BackgroundColor3=Color3.fromRGB(255,255,255)
                    Knob.BorderSizePixel=0; Knob.ZIndex=8; Knob.Parent=TrkBG2; CC(Knob,100)
                    CS(Knob,Color3.fromRGB(120,120,140),1)
                    local dr2=false
                    TrkBG2.InputBegan:Connect(function(i)
                        if i.UserInputType==Enum.UserInputType.MouseButton1 then dr2=true end
                    end)
                    UserInputService.InputEnded:Connect(function(i)
                        if i.UserInputType==Enum.UserInputType.MouseButton1 then dr2=false end
                    end)
                    local curVal=initVal
                    RunService.RenderStepped:Connect(function()
                        if dr2 and CPanel.Visible then
                            local mx=UserInputService:GetMouseLocation().X
                            curVal=math.clamp((mx-TrkBG2.AbsolutePosition.X)/TrkBG2.AbsoluteSize.X,0,1)
                            Knob.Position=UDim2.new(curVal,0,0.5,0)
                            ValLbl.Text=tostring(math.floor(curVal*100)).."%"
                        end
                    end)
                    ValLbl.Text=tostring(math.floor(initVal*100)).."%"
                    return function() return curVal end, ValLbl, Knob
                end
                local GetH,HValLbl,HKnob=MkHsvSlider("H",66,H,Color3.fromRGB(255,0,0),Color3.fromRGB(255,0,0))
                local GetS,SValLbl,SKnob=MkHsvSlider("S",92,S,Color3.fromRGB(180,180,180),Color3.fromRGB(255,85,85))
                local GetV,VValLbl,VKnob=MkHsvSlider("V",118,V,Color3.fromRGB(0,0,0),Color3.fromRGB(255,255,255))
                local HTrkBG=HKnob.Parent
                local oldGrad=HTrkBG:FindFirstChildOfClass("UIGradient")
                if oldGrad then oldGrad:Destroy() end
                local RainbowGrad=Instance.new("UIGradient")
                RainbowGrad.Color=ColorSequence.new{
                    ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),
                    ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),
                    ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)),
                    ColorSequenceKeypoint.new(0.50,Color3.fromRGB(0,255,255)),
                    ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)),
                    ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)),
                    ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0)),
                }
                RainbowGrad.Parent=HTrkBG
                local function ToHex(c)
                    return string.format("#%02X%02X%02X",math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255))
                end
                local curColor=initCol
                task.spawn(function()
                    while F.Parent do
                        if CPanel.Visible then
                            local newH=GetH(); local newS=GetS(); local newV=GetV()
                            local nc=Color3.fromHSV(newH,newS,newV)
                            if nc~=curColor then
                                curColor=nc; Preview.BackgroundColor3=curColor
                                BigPrev.BackgroundColor3=curColor; HexLbl.Text=ToHex(curColor)
                                local STrk=SKnob.Parent
                                local sg2=STrk:FindFirstChildOfClass("UIGradient")
                                if sg2 then
                                    sg2.Color=ColorSequence.new{
                                        ColorSequenceKeypoint.new(0,Color3.fromHSV(newH,0,newV)),
                                        ColorSequenceKeypoint.new(1,Color3.fromHSV(newH,1,newV)),
                                    }
                                end
                                if Data.Callback then pcall(Data.Callback,curColor) end
                                MyEngine.Flags[Data.Flag or Data.Name or ""]=curColor
                            end
                        end
                        task.wait(0.05)
                    end
                end)
                HexLbl.Text=ToHex(initCol)
                local PANEL_H=148
                TogBtn.MouseButton1Click:Connect(function()
                    opened=not opened; CPanel.Visible=opened; TogBtn.Text=opened and "▴" or "▾"
                    TW(F,{Size=UDim2.new(1,0,0,opened and 44+PANEL_H+6 or 44)},0.2)
                    if opened then CPanel.Size=UDim2.new(1,0,0,PANEL_H) end
                end)
                local Elem={}
                function Elem:Set(color3)
                    curColor=color3; H,S,V=color3:ToHSV()
                    HKnob.Position=UDim2.new(H,0,0.5,0); SKnob.Position=UDim2.new(S,0,0.5,0)
                    VKnob.Position=UDim2.new(V,0,0.5,0)
                    HValLbl.Text=tostring(math.floor(H*100)).."%"
                    SValLbl.Text=tostring(math.floor(S*100)).."%"
                    VValLbl.Text=tostring(math.floor(V*100)).."%"
                    Preview.BackgroundColor3=curColor; BigPrev.BackgroundColor3=curColor
                    HexLbl.Text=ToHex(curColor)
                    if Data.Callback then pcall(Data.Callback,curColor) end
                    MyEngine.Flags[Data.Flag or Data.Name or ""]=curColor
                end
                function Elem:Get() return curColor end
                return Elem
            end

            -- ================================================================
            --  【V3.3 NEW】折りたたみセクション
            --  使い方: local Sec = Tab:CreateCollapsibleSection("セクション名")
            --          Sec:CreateToggle({...})  ← Tab と全く同じ API
            -- ================================================================
            function Creators:CreateCollapsibleSection(sectionName)
                local HEADER_H = 40

                -- 外枠フレーム（折りたたみで高さが変わる）
                local Outer = Instance.new("Frame")
                Outer.Size = UDim2.new(1, 0, 0, HEADER_H)
                Outer.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
                Outer.BorderSizePixel = 0
                Outer.ClipsDescendants = true
                Outer.Parent = container
                CC(Outer, 8)
                CS(Outer, Color3.fromRGB(38, 50, 75), 1.5)

                -- ヘッダーグラデーション
                local HdrGrad = Instance.new("UIGradient")
                HdrGrad.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 22, 32)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 13, 17)),
                }
                HdrGrad.Rotation = 90
                HdrGrad.Parent = Outer

                -- 左アクセントライン
                local AccLine = Instance.new("Frame")
                AccLine.Size = UDim2.new(0, 3, 0, 24)
                AccLine.Position = UDim2.new(0, 0, 0, (HEADER_H - 24) / 2)
                AccLine.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
                AccLine.BorderSizePixel = 0
                AccLine.Parent = Outer
                CC(AccLine, 2)

                -- ヘッダーボタン（クリックで開閉）
                local HeaderBtn = Instance.new("TextButton")
                HeaderBtn.Size = UDim2.new(1, 0, 0, HEADER_H)
                HeaderBtn.BackgroundTransparency = 1
                HeaderBtn.Text = "  " .. (sectionName or "セクション")
                HeaderBtn.TextColor3 = Color3.fromRGB(110, 160, 235)
                HeaderBtn.TextSize = 15
                HeaderBtn.Font = Enum.Font.GothamSemibold
                HeaderBtn.TextXAlignment = Enum.TextXAlignment.Left
                HeaderBtn.AutoButtonColor = false
                HeaderBtn.ZIndex = 5
                HeaderBtn.Parent = Outer

                -- 矢印アイコン
                local Arrow = MkLabel(Outer, {
                    Size = UDim2.new(0, 28, 0, HEADER_H),
                    Position = UDim2.new(1, -32, 0, 0),
                    Text = "▶",
                    TextColor3 = Color3.fromRGB(70, 110, 180),
                    TextSize = 13,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 6,
                })

                -- 区切りライン
                local Sep = Instance.new("Frame")
                Sep.Size = UDim2.new(1, -12, 0, 1)
                Sep.Position = UDim2.new(0, 6, 0, HEADER_H - 1)
                Sep.BackgroundColor3 = Color3.fromRGB(32, 42, 65)
                Sep.BorderSizePixel = 0
                Sep.Parent = Outer

                -- コンテンツエリア
                local Inner = Instance.new("Frame")
                Inner.Name = "_SecInner"
                Inner.Size = UDim2.new(1, 0, 0, 0)
                Inner.Position = UDim2.new(0, 0, 0, HEADER_H + 1)
                Inner.BackgroundTransparency = 1
                Inner.BorderSizePixel = 0
                Inner.Parent = Outer

                local IL = Instance.new("UIListLayout")
                IL.Padding = UDim.new(0, 6)
                IL.SortOrder = Enum.SortOrder.LayoutOrder
                IL.Parent = Inner

                local IP = Instance.new("UIPadding")
                IP.PaddingTop = UDim.new(0, 6)
                IP.PaddingBottom = UDim.new(0, 10)
                IP.PaddingLeft = UDim.new(0, 4)
                IP.PaddingRight = UDim.new(0, 4)
                IP.Parent = Inner

                local expanded = false  -- デフォルト折りたたみ

                local function getContentH()
                    return IL.AbsoluteContentSize.Y + 16
                end

                local function getFullH()
                    return HEADER_H + 1 + getContentH()
                end

                -- コンテンツ変化時に高さを更新
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

                HeaderBtn.MouseButton1Click:Connect(function()
                    expanded = not expanded
                    if expanded then
                        -- 展開
                        Arrow.Text = "▼"
                        TW(AccLine, {BackgroundColor3 = Color3.fromRGB(95, 195, 255)}, 0.15)
                        TW(Outer, {Size = UDim2.new(1, 0, 0, getFullH())},
                            0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                        TW(CS(Outer, Color3.fromRGB(55, 130, 225), 1.5), {}, 0)
                    else
                        -- 折りたたみ
                        Arrow.Text = "▶"
                        TW(AccLine, {BackgroundColor3 = Color3.fromRGB(50, 130, 255)}, 0.15)
                        TW(Outer, {Size = UDim2.new(1, 0, 0, HEADER_H)},
                            0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        TW(CS(Outer, Color3.fromRGB(38, 50, 75), 1.5), {}, 0)
                    end
                end)

                -- Inner を container として再帰的にビルダーを返す
                return buildCreators(Inner)
            end

            -- ================================================================
            --  ログビューアー ── 折りたたみ対応
            -- ================================================================
            function Creators:CreateLogViewer()
                local FULL_H   = 360
                local HEADER_H = 48

                local LOG_COLORS={
                    Info=Color3.fromRGB(160,170,190), Action=Color3.fromRGB(70,150,255),
                    Success=Color3.fromRGB(65,210,100), Warning=Color3.fromRGB(240,175,45),
                    Error=Color3.fromRGB(215,70,70),
                }
                local LOG_BADGES={Info="INFO",Action="ACT",Success="OK",Warning="WARN",Error="ERR"}

                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,FULL_H); F.BackgroundColor3=Color3.fromRGB(16,16,20)
                F.BorderSizePixel=0; F.Parent=container; CC(F,8); CS(F,Color3.fromRGB(34,34,42),1)

                MkLabel(F,{
                    Size=UDim2.new(1,-130,0,32),Position=UDim2.new(0,14,0,8),
                    Text="ログ",TextSize=18,Font=Enum.Font.SourceSansBold,
                    TextColor3=Color3.fromRGB(255,255,255),
                })

                local ClearBtn=Instance.new("TextButton")
                ClearBtn.Size=UDim2.new(0,64,0,26); ClearBtn.Position=UDim2.new(1,-114,0,11)
                ClearBtn.BackgroundColor3=Color3.fromRGB(22,22,30); ClearBtn.BorderSizePixel=0
                ClearBtn.Text="クリア"; ClearBtn.TextColor3=Color3.fromRGB(180,80,80)
                ClearBtn.TextSize=14; ClearBtn.Font=Enum.Font.GothamSemibold
                ClearBtn.AutoButtonColor=false; ClearBtn.ZIndex=10; ClearBtn.Parent=F; CC(ClearBtn,6)
                CS(ClearBtn,Color3.fromRGB(80,30,30),1)
                ClearBtn.MouseEnter:Connect(function() TW(ClearBtn,{BackgroundColor3=Color3.fromRGB(32,18,18)},0.1) end)
                ClearBtn.MouseLeave:Connect(function() TW(ClearBtn,{BackgroundColor3=Color3.fromRGB(22,22,30)},0.1) end)

                MakeCollapsible(F, FULL_H, HEADER_H)

                local Sep=Instance.new("Frame")
                Sep.Size=UDim2.new(1,-24,0,1); Sep.Position=UDim2.new(0,12,0,42)
                Sep.BackgroundColor3=Color3.fromRGB(28,28,38); Sep.BorderSizePixel=0; Sep.Parent=F

                local SF=Instance.new("ScrollingFrame")
                SF.Size=UDim2.new(1,-12,0,302); SF.Position=UDim2.new(0,6,0,48)
                SF.BackgroundTransparency=1; SF.BorderSizePixel=0
                SF.ScrollBarThickness=3; SF.ScrollBarImageColor3=Color3.fromRGB(55,55,65)
                SF.ScrollingDirection=Enum.ScrollingDirection.Y; SF.Parent=F
                local LL=Instance.new("UIListLayout")
                LL.Padding=UDim.new(0,2); LL.SortOrder=Enum.SortOrder.LayoutOrder; LL.Parent=SF
                local LP2=Instance.new("UIPadding")
                LP2.PaddingTop=UDim.new(0,4); LP2.PaddingBottom=UDim.new(0,4)
                LP2.PaddingLeft=UDim.new(0,4); LP2.PaddingRight=UDim.new(0,4); LP2.Parent=SF

                local function Rebuild()
                    for _,c in pairs(SF:GetChildren()) do
                        if c:IsA("Frame") then c:Destroy() end
                    end
                    local logs=MyEngine.Logs
                    for i=#logs,math.max(1,#logs-79),-1 do
                        local log=logs[i]
                        local col=LOG_COLORS[log.Type] or LOG_COLORS.Info
                        local badge=LOG_BADGES[log.Type] or "INFO"
                        local Row=Instance.new("Frame")
                        Row.Size=UDim2.new(1,0,0,26); Row.BackgroundTransparency=1; Row.Parent=SF
                        local BadgeF=Instance.new("Frame")
                        BadgeF.Size=UDim2.new(0,38,0,18); BadgeF.Position=UDim2.new(0,0,0.5,-9)
                        BadgeF.BackgroundColor3=col; BadgeF.BackgroundTransparency=0.72
                        BadgeF.BorderSizePixel=0; BadgeF.Parent=Row; CC(BadgeF,4)
                        MkLabel(BadgeF,{Size=UDim2.new(1,0,1,0),Text=badge,TextSize=10,
                            Font=Enum.Font.GothamBold,TextColor3=col,TextXAlignment=Enum.TextXAlignment.Center})
                        MkLabel(Row,{Size=UDim2.new(0,62,1,0),Position=UDim2.new(0,42,0,0),
                            Text=log.Time,TextSize=11,Font=Enum.Font.Code,TextColor3=Color3.fromRGB(55,65,90)})
                        MkLabel(Row,{Size=UDim2.new(1,-108,1,0),Position=UDim2.new(0,108,0,0),
                            Text=log.Message,TextSize=13,Font=Enum.Font.SourceSans,
                            TextColor3=col,TextTruncate=Enum.TextTruncate.AtEnd})
                    end
                    SF.CanvasSize=UDim2.new(0,0,0,LL.AbsoluteContentSize.Y+8)
                end
                Rebuild()

                ClearBtn.MouseButton1Click:Connect(function()
                    MyEngine.Logs={}
                    TW(ClearBtn,{BackgroundColor3=Color3.fromRGB(40,20,20)},0.06)
                    task.delay(0.08,function() TW(ClearBtn,{BackgroundColor3=Color3.fromRGB(22,22,30)},0.12) end)
                    Rebuild(); AddLog("ログをクリアしました","Info")
                end)

                local listenId=tostring(tick())
                LogListeners[listenId]=Rebuild
                F.AncestryChanged:Connect(function()
                    if not F.Parent then LogListeners[listenId]=nil end
                end)
            end

            -- ================================================================
            --  プレイヤーリスト ── テーブル式マルチ選択 ── 折りたたみ対応
            --
            --  【V3.3 PATCH】selectedTable を導入し、何人でも同時選択可能に変更。
            --
            --  selectedTable の構造:
            --    selectedTable[player.Name] = true   ← 選択中
            --    selectedTable[player.Name] = nil    ← 未選択
            --
            --  コールバック署名（後方互換 + テーブル追加）:
            --    Data.Callback(player, isSelected, selectedTable)
            --      player       : 操作対象の Player オブジェクト
            --      isSelected   : true=追加 / false=解除
            --      selectedTable: 現在選択中の全プレイヤーテーブル（読み取り専用として扱うこと）
            --
            --  戻り値 Elem の API:
            --    Elem:GetSelected()          → selectedTable のシャローコピーを返す
            --    Elem:IsSelected(player)     → bool（そのプレイヤーが選択中か）
            --    Elem:ClearAll()             → 全選択を解除し UI を更新
            --    Elem:SelectPlayer(player)   → 指定プレイヤーを選択状態にする
            --    Elem:DeselectPlayer(player) → 指定プレイヤーを選択解除する
            -- ================================================================
            function Creators:CreatePlayerList(Data)
                local FULL_H   = 420
                local HEADER_H = 48

                -- ── テーブル式マルチ選択の核心 ──────────────────────
                -- キー: player.Name (string)、値: true
                -- 空テーブル = 誰も選択していない
                local selectedTable = {}

                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,FULL_H); F.BackgroundColor3=Color3.fromRGB(16,16,20)
                F.BorderSizePixel=0; F.Parent=container; CC(F,8); CS(F,Color3.fromRGB(34,34,42),1)

                MkLabel(F,{
                    Size=UDim2.new(1,-55,0,30),Position=UDim2.new(0,13,0,9),
                    Text=Data.Name or "プレイヤーリスト",TextSize=18,Font=Enum.Font.SourceSansBold,
                    TextColor3=Color3.fromRGB(255,255,255),
                })

                -- 選択人数バッジ（右上）
                local CountLbl = MkLabel(F, {
                    Size=UDim2.new(0,80,0,20), Position=UDim2.new(1,-122,0,14),
                    Text="選択: 0人", TextSize=13, Font=Enum.Font.GothamSemibold,
                    TextColor3=Color3.fromRGB(70,150,255),
                    TextXAlignment=Enum.TextXAlignment.Right,
                })

                local function UpdateCountLbl()
                    local n = 0
                    for _ in pairs(selectedTable) do n = n + 1 end
                    CountLbl.Text = "選択: " .. n .. "人"
                    CountLbl.TextColor3 = n > 0
                        and Color3.fromRGB(70, 195, 100)
                        or  Color3.fromRGB(70, 100, 150)
                end

                MakeCollapsible(F, FULL_H, HEADER_H)

                local SB=Instance.new("TextBox")
                SB.Size=UDim2.new(1,-18,0,34); SB.Position=UDim2.new(0,9,0,44)
                SB.BackgroundColor3=Color3.fromRGB(10,10,14); SB.BorderSizePixel=0
                SB.PlaceholderText="プレイヤーを検索..."
                SB.PlaceholderColor3=Color3.fromRGB(75,80,95); SB.Text=""
                SB.TextColor3=Color3.fromRGB(255,255,255); SB.TextSize=16
                SB.Font=Enum.Font.SourceSans; SB.ClearTextOnFocus=false; SB.Parent=F; CC(SB,6)

                local PS=Instance.new("ScrollingFrame")
                PS.Size=UDim2.new(1,-16,1,-88); PS.Position=UDim2.new(0,8,0,82)
                PS.BackgroundTransparency=1; PS.BorderSizePixel=0
                PS.ScrollBarThickness=3; PS.ScrollBarImageColor3=Color3.fromRGB(55,55,65); PS.Parent=F
                local PL=Instance.new("UIListLayout"); PL.Padding=UDim.new(0,5); PL.Parent=PS
                PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    PS.CanvasSize=UDim2.new(0,0,0,PL.AbsoluteContentSize.Y+8)
                end)

                -- カードの選択/解除ビジュアルを適用する内部関数
                local function ApplyCardVisual(Card, Stk, isSelected)
                    if isSelected then
                        TW(Stk, {Color=Color3.fromRGB(55,180,100)}, 0.2)
                        Stk.Thickness = 2
                        TW(Card, {BackgroundColor3=Color3.fromRGB(14,26,16)}, 0.2)
                    else
                        TW(Stk, {Color=Color3.fromRGB(36,36,46)}, 0.2)
                        Stk.Thickness = 1.5
                        TW(Card, {BackgroundColor3=Color3.fromRGB(20,20,26)}, 0.2)
                    end
                end

                local function MkCard(player)
                    if PS:FindFirstChild("p_"..player.UserId) then return end
                    local Card=Instance.new("Frame")
                    Card.Name="p_"..player.UserId; Card.Size=UDim2.new(1,-4,0,60)
                    Card.BackgroundColor3=Color3.fromRGB(20,20,26); Card.BorderSizePixel=0
                    Card.Parent=PS; CC(Card,7)
                    local Stk=CS(Card,Color3.fromRGB(36,36,46),1.5)
                    local Ico=Instance.new("ImageLabel")
                    Ico.Size=UDim2.new(0,44,0,44); Ico.Position=UDim2.new(0,8,0.5,-22)
                    Ico.BackgroundTransparency=1
                    Ico.Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150"
                    Ico.Parent=Card; CC(Ico,100)
                    MkLabel(Card,{Size=UDim2.new(1,-66,0,24),Position=UDim2.new(0,58,0.08,0),
                        Text=player.DisplayName,TextSize=18,Font=Enum.Font.SourceSansBold})
                    MkLabel(Card,{Size=UDim2.new(1,-66,0,17),Position=UDim2.new(0,58,0.60,0),
                        Text="@"..player.Name,TextSize=14,Font=Enum.Font.SourceSans,
                        TextColor3=Color3.fromRGB(65,125,195)})

                    -- チェックマークアイコン（選択時に表示）
                    local CheckLbl = MkLabel(Card, {
                        Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-28,0.5,-11),
                        Text="✓", TextSize=16, Font=Enum.Font.GothamBold,
                        TextColor3=Color3.fromRGB(55,210,100),
                        TextXAlignment=Enum.TextXAlignment.Center,
                        TextTransparency=1,  -- 未選択時は非表示
                    })

                    -- 既に選択中なら即時ビジュアル適用
                    if selectedTable[player.Name] then
                        Card.BackgroundColor3 = Color3.fromRGB(14,26,16)
                        Stk.Color = Color3.fromRGB(55,180,100)
                        Stk.Thickness = 2
                        CheckLbl.TextTransparency = 0
                    end

                    local Hit=Instance.new("TextButton")
                    Hit.Size=UDim2.new(1,0,1,0); Hit.BackgroundTransparency=1; Hit.Text=""; Hit.Parent=Card

                    Hit.MouseEnter:Connect(function()
                        if not selectedTable[player.Name] then
                            TW(Card,{BackgroundColor3=Color3.fromRGB(26,26,32)},0.1)
                        end
                    end)
                    Hit.MouseLeave:Connect(function()
                        if not selectedTable[player.Name] then
                            TW(Card,{BackgroundColor3=Color3.fromRGB(20,20,26)},0.1)
                        end
                    end)

                    Hit.MouseButton1Click:Connect(function()
                        -- テーブルへの追加/削除トグル
                        if not selectedTable[player.Name] then
                            -- ── 選択追加 ──
                            selectedTable[player.Name] = true
                            MyEngine.KillList[player.UserId] = true
                            MyEngine.Blacklist[player.UserId] = player.Name
                            ApplyCardVisual(Card, Stk, true)
                            TW(CheckLbl, {TextTransparency=0}, 0.15)
                            UpdateCountLbl()
                            AddLog("選択追加: "..player.Name.." (計"..
                                (function() local n=0; for _ in pairs(selectedTable) do n=n+1 end; return n end)()
                                .."人)","Action")
                            if Data.Callback then pcall(Data.Callback, player, true, selectedTable) end
                        else
                            -- ── 選択解除 ──
                            selectedTable[player.Name] = nil
                            MyEngine.KillList[player.UserId] = nil
                            MyEngine.Blacklist[player.UserId] = nil
                            ApplyCardVisual(Card, Stk, false)
                            TW(CheckLbl, {TextTransparency=1}, 0.15)
                            UpdateCountLbl()
                            AddLog("選択解除: "..player.Name,"Action")
                            if Data.Callback then pcall(Data.Callback, player, false, selectedTable) end
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
                    -- 既に選択テーブルに入っていたプレイヤーが戻ってきた場合
                    if selectedTable[p.Name] then
                        AddLog("選択済みプレイヤー再参加: "..p.Name,"Warning")
                        MyEngine.KillList[p.UserId] = true
                        task.wait(0.5); Refresh()
                        -- カードのビジュアルを復元
                        local c = PS:FindFirstChild("p_"..p.UserId)
                        if c then
                            local s = c:FindFirstChildOfClass("UIStroke")
                            if s then s.Color=Color3.fromRGB(55,180,100); s.Thickness=2 end
                            c.BackgroundColor3 = Color3.fromRGB(14,26,16)
                        end
                    end
                end)
                Players.PlayerRemoving:Connect(function() task.wait(0.5); Refresh() end)

                Refresh()
                UpdateCountLbl()

                -- ================================================================
                --  戻り値: Elem（マルチ選択テーブルを外部から操作するための API）
                -- ================================================================
                local Elem = {}

                -- 現在選択中の全プレイヤーをテーブルで返す（シャローコピー）
                -- 戻り値: { [playerName] = true, ... }
                function Elem:GetSelected()
                    local copy = {}
                    for k, v in pairs(selectedTable) do copy[k] = v end
                    return copy
                end

                -- 指定プレイヤーが選択中か判定
                function Elem:IsSelected(player)
                    return selectedTable[player.Name] == true
                end

                -- 全選択を解除し UI を更新
                function Elem:ClearAll()
                    for name, _ in pairs(selectedTable) do
                        selectedTable[name] = nil
                    end
                    -- KillList / Blacklist も連動してクリア
                    MyEngine.KillList = {}
                    MyEngine.Blacklist = {}
                    -- 全カードのビジュアルをリセット
                    for _, c in pairs(PS:GetChildren()) do
                        if c:IsA("Frame") then
                            local s = c:FindFirstChildOfClass("UIStroke")
                            if s then
                                s.Color = Color3.fromRGB(36,36,46)
                                s.Thickness = 1.5
                            end
                            TW(c, {BackgroundColor3=Color3.fromRGB(20,20,26)}, 0.15)
                            local chk = c:FindFirstChild("TextLabel") -- ✓ラベルを探して非表示
                            -- ✓ はインデックス順で最後のTextLabelなので FindFirstChildWhichIsA で安全に探す
                            for _, lbl in pairs(c:GetDescendants()) do
                                if lbl:IsA("TextLabel") and lbl.Text == "✓" then
                                    TW(lbl, {TextTransparency=1}, 0.15)
                                end
                            end
                        end
                    end
                    UpdateCountLbl()
                    AddLog("全選択を解除しました","Action")
                end

                -- 指定プレイヤーをプログラムから選択状態にする
                function Elem:SelectPlayer(player)
                    if not player or selectedTable[player.Name] then return end
                    selectedTable[player.Name] = true
                    MyEngine.KillList[player.UserId] = true
                    MyEngine.Blacklist[player.UserId] = player.Name
                    local c = PS:FindFirstChild("p_"..player.UserId)
                    if c then
                        local s = c:FindFirstChildOfClass("UIStroke")
                        if s then ApplyCardVisual(c, s, true) end
                        for _, lbl in pairs(c:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Text == "✓" then
                                TW(lbl, {TextTransparency=0}, 0.15)
                            end
                        end
                    end
                    UpdateCountLbl()
                    if Data.Callback then pcall(Data.Callback, player, true, selectedTable) end
                end

                -- 指定プレイヤーをプログラムから選択解除する
                function Elem:DeselectPlayer(player)
                    if not player or not selectedTable[player.Name] then return end
                    selectedTable[player.Name] = nil
                    MyEngine.KillList[player.UserId] = nil
                    MyEngine.Blacklist[player.UserId] = nil
                    local c = PS:FindFirstChild("p_"..player.UserId)
                    if c then
                        local s = c:FindFirstChildOfClass("UIStroke")
                        if s then ApplyCardVisual(c, s, false) end
                        for _, lbl in pairs(c:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Text == "✓" then
                                TW(lbl, {TextTransparency=1}, 0.15)
                            end
                        end
                    end
                    UpdateCountLbl()
                    if Data.Callback then pcall(Data.Callback, player, false, selectedTable) end
                end

                return Elem
            end

            -- ================================================================
            --  ゲーム情報 ── 折りたたみ対応
            -- ================================================================
            function Creators:CreateGameInfo()
                local FULL_H   = 300
                local HEADER_H = 48

                local F=Instance.new("Frame")
                F.Size=UDim2.new(1,0,0,FULL_H); F.BackgroundColor3=Color3.fromRGB(16,16,20)
                F.BorderSizePixel=0; F.Parent=container; CC(F,8); CS(F,Color3.fromRGB(34,34,42),1)

                MkLabel(F,{
                    Size=UDim2.new(1,-55,0,30),Position=UDim2.new(0,14,0,9),
                    Text="サーバー情報",TextSize=18,Font=Enum.Font.SourceSansBold,
                    TextColor3=Color3.fromRGB(255,255,255),
                })

                MakeCollapsible(F, FULL_H, HEADER_H)

                local Sep=Instance.new("Frame")
                Sep.Size=UDim2.new(1,-24,0,1); Sep.Position=UDim2.new(0,12,0,40)
                Sep.BackgroundColor3=Color3.fromRGB(28,28,38); Sep.BorderSizePixel=0; Sep.Parent=F
                local function Row(lbl,y)
                    MkLabel(F,{Size=UDim2.new(0.42,-4,0,26),Position=UDim2.new(0,16,0,y),
                        Text=lbl,TextSize=15,Font=Enum.Font.GothamSemibold,
                        TextColor3=Color3.fromRGB(95,115,155)})
                    local v=MkLabel(F,{Size=UDim2.new(0.58,-4,0,26),Position=UDim2.new(0.42,0,0,y),
                        Text="…",TextSize=15,Font=Enum.Font.SourceSans,
                        TextColor3=Color3.fromRGB(200,210,230)})
                    return v
                end
                local vSrv  = Row("サーバーID",   46)
                local vPly  = Row("プレイヤー数",  74)
                local vPing = Row("Ping",         102)
                local vFPS  = Row("FPS",          130)
                local vUp   = Row("稼働時間",     158)
                local vGame = Row("ゲーム名",     186)
                local vPID  = Row("PlaceID",      214)
                local vMe   = Row("自分のUserId",  242)
                pcall(function()
                    local jid=tostring(game.JobId)
                    vSrv.Text=jid~="" and (jid:sub(1,18).."...") or "ローカル"
                    vGame.Text=tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
                end)
                pcall(function() vPID.Text=tostring(game.PlaceId) end)
                pcall(function() vMe.Text=tostring(LocalPlayer.UserId) end)
                local startT=tick(); local lastPing=0
                local function UpdLive()
                    pcall(function()
                        lastPing=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                    end)
                    local pc=Color3.fromRGB(65,210,100)
                    if lastPing>300 then pc=Color3.fromRGB(215,70,70)
                    elseif lastPing>150 then pc=Color3.fromRGB(240,175,45) end
                    vPing.Text=lastPing.." ms"; vPing.TextColor3=pc
                    local fps=0
                    pcall(function()
                        local s=tick(); RunService.RenderStepped:Wait(); fps=math.floor(1/(tick()-s))
                    end)
                    vFPS.Text=fps.." fps"
                    local e=tick()-startT
                    vUp.Text=string.format("%02d:%02d:%02d",math.floor(e/3600),math.floor(e/60)%60,math.floor(e)%60)
                    vPly.Text=tostring(#Players:GetPlayers()).." / "..tostring(Players.MaxPlayers)
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
-- ================================================================
function MyEngine:Notify(Data)
    local NG=Instance.new("ScreenGui")
    NG.Name="afNotify"; NG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    NG.DisplayOrder=101
    pcall(function() NG.IgnoreGuiInset=true end)
    NG.Parent=LocalPlayer:WaitForChild("PlayerGui")
    local NF=Instance.new("Frame")
    NF.Size=UDim2.new(0,308,0,84); NF.Position=UDim2.new(1,10,1,-20)
    NF.AnchorPoint=Vector2.new(1,1); NF.BackgroundColor3=Color3.fromRGB(16,16,20)
    NF.BorderSizePixel=0; NF.Parent=NG
    CC(NF,10); CS(NF,Color3.fromRGB(45,145,255),1.5)
    local Bar=Instance.new("Frame")
    Bar.Size=UDim2.new(0,3,1,-16); Bar.Position=UDim2.new(0,8,0,8)
    Bar.BackgroundColor3=Color3.fromRGB(45,145,255); Bar.BorderSizePixel=0; Bar.Parent=NF; CC(Bar,100)
    MkLabel(NF,{Size=UDim2.new(1,-28,0,25),Position=UDim2.new(0,20,0,10),
        Text=Data.Title or "通知",TextSize=16,Font=Enum.Font.SourceSansBold})
    MkLabel(NF,{Size=UDim2.new(1,-28,0,36),Position=UDim2.new(0,20,0,35),
        Text=Data.Content or "",TextSize=15,Font=Enum.Font.SourceSans,
        TextColor3=Color3.fromRGB(175,180,200),TextWrapped=true})
    task.spawn(function()
        TW(NF,{Position=UDim2.new(1,-10,1,-20)},0.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
        task.wait(Data.Duration or 3)
        TW(NF,{Position=UDim2.new(1,10,1,-20)},0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
        task.wait(0.3); NG:Destroy()
    end)
end

-- ================================================================
getgenv().Rayfield = MyEngine
print("[af_hub] v3.3 PATCH 起動完了 | トグルキー: "..tostring(MyEngine.ToggleKey))
print("[af_hub] v3.3 PATCH: CreatePlayerList がテーブル式マルチ選択に対応しました")
print("[af_hub] 使い方: local list = Tab:CreatePlayerList({...})")
print("[af_hub]   list:GetSelected()          → 選択中テーブル { [name]=true }")
print("[af_hub]   list:IsSelected(player)     → bool")
print("[af_hub]   list:ClearAll()             → 全解除")
print("[af_hub]   list:SelectPlayer(player)   → プログラムから選択")
print("[af_hub]   list:DeselectPlayer(player) → プログラムから解除")
return MyEngine
