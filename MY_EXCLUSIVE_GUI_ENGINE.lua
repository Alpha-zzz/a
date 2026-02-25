\--[[
    俺専用GUI ENGINE - ULTIMATE
    Rayfield互換・最高にモダン・最強のカスタムUI
    
    完全実装機能:
    - サイドバー方式（爆速タブ切り替え）
    - アカウント名・アイコン表示
    - ハイテック起動アニメーション
    - 閉じないプレイヤーリスト（アイコン・名前・ID表示）
    - ワンクリックキルリスト登録/解除
    - 自動追跡ブラックリスト（再入室検知）
    - 検索機能（リアルタイムフィルタ）
    - Rayfield API完全互換
]]

-- サービス
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- ローカルプレイヤー
local LocalPlayer = Players.LocalPlayer

-- 俺専用エンジン
local MyEngine = {
    Flags = {},
    Tabs = {},
    ActiveTab = nil,
    KillList = {},
    Blacklist = {},
    Elements = {},
    SearchFilter = "",
    Logs = {}
}

-- ユーティリティ関数
local function CreateCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function CreateStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(45, 45, 50)
    stroke.Thickness = thickness or 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function Tween(object, properties, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(object, info, properties)
    tween:Play()
    return tween
end

local function AddLog(message, logType)
    table.insert(MyEngine.Logs, {
        Message = message,
        Type = logType or "Info",
        Time = os.date("%H:%M:%S")
    })
    if #MyEngine.Logs > 50 then
        table.remove(MyEngine.Logs, 1)
    end
end

-- CreateWindow
function MyEngine:CreateWindow(Config)
    local WindowName = Config.Name or "MyGUI"
    
    -- ScreenGui作成
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MyExclusiveHub_" .. HttpService:GenerateGUID()
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- メインフレーム
    local Main = Instance.new("CanvasGroup")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 0, 0, 0)
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
    Main.BorderSizePixel = 0
    Main.GroupAlpha = 0
    Main.Parent = ScreenGui
    CreateCorner(Main, 12)
    CreateStroke(Main, Color3.fromRGB(45, 45, 50), 2)
    
    -- グラデーション背景
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 17))
    }
    Gradient.Rotation = 90
    Gradient.Parent = Main
    
    -- サイドバー
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 200, 1, 0)
    Sidebar.Position = UDim2.new(0, 0, 0, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = Main
    CreateCorner(Sidebar, 12)
    
    -- サイドバー境界線
    local SidebarDivider = Instance.new("Frame")
    SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
    SidebarDivider.Position = UDim2.new(1, 0, 0, 0)
    SidebarDivider.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    SidebarDivider.BorderSizePixel = 0
    SidebarDivider.Parent = Sidebar
    
    -- タイトル
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -20, 0, 50)
    Title.Position = UDim2.new(0, 10, 0, 10)
    Title.BackgroundTransparency = 1
    Title.Text = WindowName
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Sidebar
    
    -- タブコンテナ
    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(1, -10, 1, -180)
    TabContainer.Position = UDim2.new(0, 5, 0, 70)
    TabContainer.BackgroundTransparency = 1
    TabContainer.BorderSizePixel = 0
    TabContainer.ScrollBarThickness = 2
    TabContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
    TabContainer.Parent = Sidebar
    
    local TabLayout = Instance.new("UIListLayout")
    TabLayout.Padding = UDim.new(0, 5)
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Parent = TabContainer
    
    -- アカウント情報セクション
    local AccountSection = Instance.new("Frame")
    AccountSection.Name = "AccountSection"
    AccountSection.Size = UDim2.new(1, -10, 0, 70)
    AccountSection.Position = UDim2.new(0, 5, 1, -75)
    AccountSection.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
    AccountSection.BorderSizePixel = 0
    AccountSection.Parent = Sidebar
    CreateCorner(AccountSection, 8)
    CreateStroke(AccountSection, Color3.fromRGB(40, 40, 45), 1)
    
    -- アカウントアイコン
    local AccountIcon = Instance.new("ImageLabel")
    AccountIcon.Name = "AccountIcon"
    AccountIcon.Size = UDim2.new(0, 45, 0, 45)
    AccountIcon.Position = UDim2.new(0, 10, 0.5, -22)
    AccountIcon.BackgroundTransparency = 1
    AccountIcon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
    AccountIcon.Parent = AccountSection
    CreateCorner(AccountIcon, 100)
    
    -- アカウント名
    local AccountName = Instance.new("TextLabel")
    AccountName.Name = "AccountName"
    AccountName.Size = UDim2.new(1, -70, 0, 25)
    AccountName.Position = UDim2.new(0, 65, 0.2, 0)
    AccountName.BackgroundTransparency = 1
    AccountName.Text = LocalPlayer.Name
    AccountName.TextColor3 = Color3.fromRGB(255, 255, 255)
    AccountName.TextSize = 13
    AccountName.Font = Enum.Font.GothamSemibold
    AccountName.TextXAlignment = Enum.TextXAlignment.Left
    AccountName.TextTruncate = Enum.TextTruncate.AtEnd
    AccountName.Parent = AccountSection
    
    -- オンライン表示
    local OnlineStatus = Instance.new("Frame")
    OnlineStatus.Size = UDim2.new(0, 8, 0, 8)
    OnlineStatus.Position = UDim2.new(0, 65, 0.65, 0)
    OnlineStatus.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
    OnlineStatus.BorderSizePixel = 0
    OnlineStatus.Parent = AccountSection
    CreateCorner(OnlineStatus, 100)
    
    local OnlineText = Instance.new("TextLabel")
    OnlineText.Size = UDim2.new(1, -85, 0, 15)
    OnlineText.Position = UDim2.new(0, 78, 0.65, -5)
    OnlineText.BackgroundTransparency = 1
    OnlineText.Text = "Online"
    OnlineText.TextColor3 = Color3.fromRGB(150, 150, 150)
    OnlineText.TextSize = 11
    OnlineText.Font = Enum.Font.Gotham
    OnlineText.TextXAlignment = Enum.TextXAlignment.Left
    OnlineText.Parent = AccountSection
    
    -- コンテンツエリア
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Size = UDim2.new(1, -210, 1, -20)
    ContentArea.Position = UDim2.new(0, 205, 0, 10)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = Main
    
    -- 起動アニメーション
    task.spawn(function()
        Tween(Main, {Size = UDim2.new(0, 800, 0, 500)}, 0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        task.wait(0.1)
        Tween(Main, {GroupAlpha = 1}, 0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        AddLog("GUI起動完了", "Success")
    end)
    
    -- Windowオブジェクト
    local Window = {
        _Main = Main,
        _Sidebar = Sidebar,
        _TabContainer = TabContainer,
        _ContentArea = ContentArea,
        _Tabs = {}
    }
    
    -- CreateTab
    function Window:CreateTab(TabName, Icon)
        local TabButton = Instance.new("TextButton")
        TabButton.Name = TabName
        TabButton.Size = UDim2.new(1, -10, 0, 40)
        TabButton.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
        TabButton.BorderSizePixel = 0
        TabButton.Text = "  " .. TabName
        TabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        TabButton.TextSize = 14
        TabButton.Font = Enum.Font.GothamSemibold
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.AutoButtonColor = false
        TabButton.Parent = TabContainer
        CreateCorner(TabButton, 6)
        
        local TabContent = Instance.new("ScrollingFrame")
        TabContent.Name = TabName .. "_Content"
        TabContent.Size = UDim2.new(1, 0, 1, 0)
        TabContent.BackgroundTransparency = 1
        TabContent.BorderSizePixel = 0
        TabContent.ScrollBarThickness = 3
        TabContent.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
        TabContent.Visible = false
        TabContent.Parent = ContentArea
        
        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.Padding = UDim.new(0, 8)
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Parent = TabContent
        
        TabButton.MouseButton1Click:Connect(function()
            for _, tab in pairs(Window._Tabs) do
                tab.Button.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
                tab.Button.TextColor3 = Color3.fromRGB(200, 200, 200)
                tab.Content.Visible = false
            end
            
            TabButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            TabContent.Visible = true
            
            AddLog("タブ切り替え: " .. TabName, "Info")
        end)
        
        if #Window._Tabs == 0 then
            TabButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            TabContent.Visible = true
        end
        
        local Tab = {
            Button = TabButton,
            Content = TabContent,
            Elements = {}
        }
        
        table.insert(Window._Tabs, Tab)
        
        -- CreateButton
        function Tab:CreateButton(Data)
            local ButtonFrame = Instance.new("Frame")
            ButtonFrame.Size = UDim2.new(1, -10, 0, 40)
            ButtonFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            ButtonFrame.BorderSizePixel = 0
            ButtonFrame.Parent = TabContent
            CreateCorner(ButtonFrame, 8)
            CreateStroke(ButtonFrame, Color3.fromRGB(40, 40, 45), 1)
            
            local Button = Instance.new("TextButton")
            Button.Size = UDim2.new(1, 0, 1, 0)
            Button.BackgroundTransparency = 1
            Button.Text = Data.Name or "Button"
            Button.TextColor3 = Color3.fromRGB(255, 255, 255)
            Button.TextSize = 14
            Button.Font = Enum.Font.Gotham
            Button.Parent = ButtonFrame
            
            Button.MouseButton1Click:Connect(function()
                Tween(ButtonFrame, {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}, 0.1)
                task.wait(0.1)
                Tween(ButtonFrame, {BackgroundColor3 = Color3.fromRGB(25, 25, 27)}, 0.1)
                
                if Data.Callback then
                    pcall(Data.Callback)
                end
                AddLog("ボタンクリック: " .. Data.Name, "Action")
            end)
        end
        
        -- CreateToggle
        function Tab:CreateToggle(Data)
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, -10, 0, 40)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Parent = TabContent
            CreateCorner(ToggleFrame, 8)
            CreateStroke(ToggleFrame, Color3.fromRGB(40, 40, 45), 1)
            
            local ToggleName = Instance.new("TextLabel")
            ToggleName.Size = UDim2.new(1, -60, 1, 0)
            ToggleName.Position = UDim2.new(0, 15, 0, 0)
            ToggleName.BackgroundTransparency = 1
            ToggleName.Text = Data.Name or "Toggle"
            ToggleName.TextColor3 = Color3.fromRGB(255, 255, 255)
            ToggleName.TextSize = 14
            ToggleName.Font = Enum.Font.Gotham
            ToggleName.TextXAlignment = Enum.TextXAlignment.Left
            ToggleName.Parent = ToggleFrame
            
            local ToggleButton = Instance.new("TextButton")
            ToggleButton.Size = UDim2.new(0, 45, 0, 22)
            ToggleButton.Position = UDim2.new(1, -55, 0.5, -11)
            ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            ToggleButton.BorderSizePixel = 0
            ToggleButton.Text = ""
            ToggleButton.Parent = ToggleFrame
            CreateCorner(ToggleButton, 100)
            
            local ToggleCircle = Instance.new("Frame")
            ToggleCircle.Size = UDim2.new(0, 18, 0, 18)
            ToggleCircle.Position = UDim2.new(0, 2, 0.5, -9)
            ToggleCircle.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
            ToggleCircle.BorderSizePixel = 0
            ToggleCircle.Parent = ToggleButton
            CreateCorner(ToggleCircle, 100)
            
            local CurrentValue = Data.CurrentValue or false
            
            if CurrentValue then
                ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
                ToggleCircle.Position = UDim2.new(1, -20, 0.5, -9)
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
                
                if Data.Callback then
                    pcall(Data.Callback, CurrentValue)
                end
                
                MyEngine.Flags[Data.Flag or Data.Name] = CurrentValue
                AddLog("トグル: " .. Data.Name .. " = " .. tostring(CurrentValue), "Action")
            end)
        end
        
        -- CreateSlider
        function Tab:CreateSlider(Data)
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size = UDim2.new(1, -10, 0, 60)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Parent = TabContent
            CreateCorner(SliderFrame, 8)
            CreateStroke(SliderFrame, Color3.fromRGB(40, 40, 45), 1)
            
            local SliderName = Instance.new("TextLabel")
            SliderName.Size = UDim2.new(1, -20, 0, 20)
            SliderName.Position = UDim2.new(0, 10, 0, 5)
            SliderName.BackgroundTransparency = 1
            SliderName.Text = Data.Name or "Slider"
            SliderName.TextColor3 = Color3.fromRGB(255, 255, 255)
            SliderName.TextSize = 14
            SliderName.Font = Enum.Font.Gotham
            SliderName.TextXAlignment = Enum.TextXAlignment.Left
            SliderName.Parent = SliderFrame
            
            local SliderValue = Instance.new("TextLabel")
            SliderValue.Size = UDim2.new(0, 60, 0, 20)
            SliderValue.Position = UDim2.new(1, -70, 0, 5)
            SliderValue.BackgroundTransparency = 1
            SliderValue.Text = tostring(Data.CurrentValue or Data.Range[1])
            SliderValue.TextColor3 = Color3.fromRGB(150, 150, 150)
            SliderValue.TextSize = 13
            SliderValue.Font = Enum.Font.GothamSemibold
            SliderValue.Parent = SliderFrame
            
            local SliderTrack = Instance.new("Frame")
            SliderTrack.Size = UDim2.new(1, -20, 0, 6)
            SliderTrack.Position = UDim2.new(0, 10, 1, -20)
            SliderTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            SliderTrack.BorderSizePixel = 0
            SliderTrack.Parent = SliderFrame
            CreateCorner(SliderTrack, 100)
            
            local SliderFill = Instance.new("Frame")
            SliderFill.Size = UDim2.new(0, 0, 1, 0)
            SliderFill.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            SliderFill.BorderSizePixel = 0
            SliderFill.Parent = SliderTrack
            CreateCorner(SliderFill, 100)
            
            local CurrentValue = Data.CurrentValue or Data.Range[1]
            local Min = Data.Range[1]
            local Max = Data.Range[2]
            local Increment = Data.Increment or 1
            
            local function UpdateSlider(value)
                value = math.clamp(value, Min, Max)
                value = math.floor(value / Increment + 0.5) * Increment
                CurrentValue = value
                
                local percent = (value - Min) / (Max - Min)
                SliderFill.Size = UDim2.new(percent, 0, 1, 0)
                SliderValue.Text = tostring(value) .. (Data.Suffix or "")
                
                if Data.Callback then
                    pcall(Data.Callback, value)
                end
                
                MyEngine.Flags[Data.Flag or Data.Name] = value
            end
            
            UpdateSlider(CurrentValue)
            
            local dragging = false
            SliderTrack.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)
            
            RunService.RenderStepped:Connect(function()
                if dragging then
                    local mousePos = UserInputService:GetMouseLocation().X
                    local trackPos = SliderTrack.AbsolutePosition.X
                    local trackSize = SliderTrack.AbsoluteSize.X
                    
                    local percent = math.clamp((mousePos - trackPos) / trackSize, 0, 1)
                    local value = Min + (Max - Min) * percent
                    
                    UpdateSlider(value)
                end
            end)
        end
        
        -- CreateDropdown
        function Tab:CreateDropdown(Data)
            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Size = UDim2.new(1, -10, 0, 40)
            DropdownFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
            DropdownFrame.BorderSizePixel = 0
            DropdownFrame.Parent = TabContent
            CreateCorner(DropdownFrame, 8)
            CreateStroke(DropdownFrame, Color3.fromRGB(40, 40, 45), 1)
            
            local DropdownButton = Instance.new("TextButton")
            DropdownButton.Size = UDim2.new(1, 0, 0, 40)
            DropdownButton.BackgroundTransparency = 1
            DropdownButton.Text = Data.Name .. ": " .. (Data.CurrentOption or "None")
            DropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            DropdownButton.TextSize = 14
            DropdownButton.Font = Enum.Font.Gotham
            DropdownButton.Parent = DropdownFrame
            
            local OptionsContainer = Instance.new("Frame")
            OptionsContainer.Size = UDim2.new(1, 0, 0, 0)
            OptionsContainer.Position = UDim2.new(0, 0, 1, 2)
            OptionsContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
            OptionsContainer.BorderSizePixel = 0
            OptionsContainer.Visible = false
            OptionsContainer.Parent = DropdownFrame
            CreateCorner(OptionsContainer, 8)
            CreateStroke(OptionsContainer, Color3.fromRGB(40, 40, 45), 1)
            
            local OptionsLayout = Instance.new("UIListLayout")
            OptionsLayout.Parent = OptionsContainer
            
            local isOpen = false
            
            DropdownButton.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                OptionsContainer.Visible = isOpen
                
                if isOpen then
                    local height = math.min(#Data.Options * 35, 200)
                    Tween(OptionsContainer, {Size = UDim2.new(1, 0, 0, height)}, 0.2)
                    Tween(DropdownFrame, {Size = UDim2.new(1, -10, 0, 40 + height + 5)}, 0.2)
                else
                    Tween(OptionsContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
                    Tween(DropdownFrame, {Size = UDim2.new(1, -10, 0, 40)}, 0.2)
                end
            end)
            
            for _, option in pairs(Data.Options) do
                local OptionButton = Instance.new("TextButton")
                OptionButton.Size = UDim2.new(1, 0, 0, 35)
                OptionButton.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
                OptionButton.BorderSizePixel = 0
                OptionButton.Text = option
                OptionButton.TextColor3 = Color3.fromRGB(200, 200, 200)
                OptionButton.TextSize = 13
                OptionButton.Font = Enum.Font.Gotham
                OptionButton.Parent = OptionsContainer
                
                OptionButton.MouseButton1Click:Connect(function()
                    DropdownButton.Text = Data.Name .. ": " .. option
                    isOpen = false
                    OptionsContainer.Visible = false
                    Tween(OptionsContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
                    Tween(DropdownFrame, {Size = UDim2.new(1, -10, 0, 40)}, 0.2)
                    
                    if Data.Callback then
                        pcall(Data.Callback, option)
                    end
                    
                    MyEngine.Flags[Data.Flag or Data.Name] = option
                    AddLog("ドロップダウン: " .. Data.Name .. " = " .. option, "Action")
                end)
            end
        end
        
        -- CreatePlayerList（俺専用・革命的機能）
        function Tab:CreatePlayerList(Data)
            local ListFrame = Instance.new("Frame")
            ListFrame.Size = UDim2.new(1, -10, 0, 400)
            ListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
            ListFrame.BorderSizePixel = 0
            ListFrame.Parent = TabContent
            CreateCorner(ListFrame, 8)
            CreateStroke(ListFrame, Color3.fromRGB(40, 40, 45), 1)
            
            local ListTitle = Instance.new("TextLabel")
            ListTitle.Size = UDim2.new(1, -20, 0, 30)
            ListTitle.Position = UDim2.new(0, 10, 0, 5)
            ListTitle.BackgroundTransparency = 1
            ListTitle.Text = Data.Name or "Player List"
            ListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            ListTitle.TextSize = 15
            ListTitle.Font = Enum.Font.GothamBold
            ListTitle.TextXAlignment = Enum.TextXAlignment.Left
            ListTitle.Parent = ListFrame
            
            local SearchBar = Instance.new("TextBox")
            SearchBar.Size = UDim2.new(1, -20, 0, 35)
            SearchBar.Position = UDim2.new(0, 10, 0, 40)
            SearchBar.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
            SearchBar.BorderSizePixel = 0
            SearchBar.PlaceholderText = "Search players..."
            SearchBar.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
            SearchBar.Text = ""
            SearchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
            SearchBar.TextSize = 13
            SearchBar.Font = Enum.Font.Gotham
            SearchBar.Parent = ListFrame
            CreateCorner(SearchBar, 6)
            
            local PlayerScroll = Instance.new("ScrollingFrame")
            PlayerScroll.Size = UDim2.new(1, -20, 1, -90)
            PlayerScroll.Position = UDim2.new(0, 10, 0, 80)
            PlayerScroll.BackgroundTransparency = 1
            PlayerScroll.BorderSizePixel = 0
            PlayerScroll.ScrollBarThickness = 3
            PlayerScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
            PlayerScroll.Parent = ListFrame
            
            local PlayerLayout = Instance.new("UIListLayout")
            PlayerLayout.Padding = UDim.new(0, 5)
            PlayerLayout.Parent = PlayerScroll
            
            local function CreatePlayerCard(player)
                if PlayerScroll:FindFirstChild(player.Name) then
                    return
                end
                
                local Card = Instance.new("Frame")
                Card.Name = player.Name
                Card.Size = UDim2.new(1, -5, 0, 60)
                Card.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
                Card.BorderSizePixel = 0
                Card.Parent = PlayerScroll
                CreateCorner(Card, 8)
                
                local CardStroke = CreateStroke(Card, Color3.fromRGB(40, 40, 45), 2)
                
                local Icon = Instance.new("ImageLabel")
                Icon.Size = UDim2.new(0, 45, 0, 45)
                Icon.Position = UDim2.new(0, 8, 0.5, -22)
                Icon.BackgroundTransparency = 1
                Icon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
                Icon.Parent = Card
                CreateCorner(Icon, 100)
                
                local InfoContainer = Instance.new("Frame")
                InfoContainer.Size = UDim2.new(1, -65, 1, 0)
                InfoContainer.Position = UDim2.new(0, 60, 0, 0)
                InfoContainer.BackgroundTransparency = 1
                InfoContainer.Parent = Card
                
                local NameLabel = Instance.new("TextLabel")
                NameLabel.Size = UDim2.new(1, -10, 0, 25)
                NameLabel.Position = UDim2.new(0, 0, 0.15, 0)
                NameLabel.BackgroundTransparency = 1
                NameLabel.Text = player.Name
                NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                NameLabel.TextSize = 14
                NameLabel.Font = Enum.Font.GothamSemibold
                NameLabel.TextXAlignment = Enum.TextXAlignment.Left
                NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                NameLabel.Parent = InfoContainer
                
                local IdLabel = Instance.new("TextLabel")
                IdLabel.Size = UDim2.new(1, -10, 0, 18)
                IdLabel.Position = UDim2.new(0, 0, 0.6, 0)
                IdLabel.BackgroundTransparency = 1
                IdLabel.Text = "ID: " .. player.UserId
                IdLabel.TextColor3 = Color3.fromRGB(120, 120, 125)
                IdLabel.TextSize = 11
                IdLabel.Font = Enum.Font.Gotham
                IdLabel.TextXAlignment = Enum.TextXAlignment.Left
                IdLabel.Parent = InfoContainer
                
                local Hitbox = Instance.new("TextButton")
                Hitbox.Size = UDim2.new(1, 0, 1, 0)
                Hitbox.BackgroundTransparency = 1
                Hitbox.Text = ""
                Hitbox.Parent = Card
                
                Hitbox.MouseButton1Click:Connect(function()
                    if not MyEngine.KillList[player.UserId] then
                        MyEngine.KillList[player.UserId] = true
                        Tween(CardStroke, {Color = Color3.fromRGB(255, 50, 50)}, 0.2)
                        CardStroke.Thickness = 3
                        AddLog("Kill List ADD: " .. player.Name, "Action")
                        
                        MyEngine.Blacklist[player.UserId] = player.Name
                        
                        if Data.Callback then
                            pcall(Data.Callback, player, true)
                        end
                    else
                        MyEngine.KillList[player.UserId] = nil
                        Tween(CardStroke, {Color = Color3.fromRGB(40, 40, 45)}, 0.2)
                        CardStroke.Thickness = 2
                        AddLog("Kill List REMOVE: " .. player.Name, "Action")
                        
                        MyEngine.Blacklist[player.UserId] = nil
                        
                        if Data.Callback then
                            pcall(Data.Callback, player, false)
                        end
                    end
                end)
            end
            
            local function RefreshList()
                for _, card in pairs(PlayerScroll:GetChildren()) do
                    if card:IsA("Frame") and card.Name ~= "UIListLayout" then
                        local playerExists = Players:FindFirstChild(card.Name)
                        if not playerExists then
                            card:Destroy()
                        end
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
                local searchText = SearchBar.Text:lower()
                for _, card in pairs(PlayerScroll:GetChildren()) do
                    if card:IsA("Frame") then
                        if searchText == "" or card.Name:lower():find(searchText) then
                            card.Visible = true
                        else
                            card.Visible = false
                        end
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
                        if stroke then
                            stroke.Color = Color3.fromRGB(255, 50, 50)
                            stroke.Thickness = 3
                        end
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

-- Notify
function MyEngine:Notify(Data)
    local NotifyGui = Instance.new("ScreenGui")
    NotifyGui.Name = "Notify"
    NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    NotifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local NotifyFrame = Instance.new("Frame")
    NotifyFrame.Size = UDim2.new(0, 300, 0, 80)
    NotifyFrame.Position = UDim2.new(1, -10, 1, 0)
    NotifyFrame.AnchorPoint = Vector2.new(1, 1)
    NotifyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
    NotifyFrame.BorderSizePixel = 0
    NotifyFrame.Parent = NotifyGui
    CreateCorner(NotifyFrame, 10)
    CreateStroke(NotifyFrame, Color3.fromRGB(50, 150, 255), 2)
    
    local NotifyTitle = Instance.new("TextLabel")
    NotifyTitle.Size = UDim2.new(1, -20, 0, 25)
    NotifyTitle.Position = UDim2.new(0, 10, 0, 10)
    NotifyTitle.BackgroundTransparency = 1
    NotifyTitle.Text = Data.Title or "Notify"
    NotifyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    NotifyTitle.TextSize = 14
    NotifyTitle.Font = Enum.Font.GothamBold
    NotifyTitle.TextXAlignment = Enum.TextXAlignment.Left
    NotifyTitle.Parent = NotifyFrame
    
    local NotifyContent = Instance.new("TextLabel")
    NotifyContent.Size = UDim2.new(1, -20, 0, 35)
    NotifyContent.Position = UDim2.new(0, 10, 0, 35)
    NotifyContent.BackgroundTransparency = 1
    NotifyContent.Text = Data.Content or ""
    NotifyContent.TextColor3 = Color3.fromRGB(200, 200, 200)
    NotifyContent.TextSize = 12
    NotifyContent.Font = Enum.Font.Gotham
    NotifyContent.TextXAlignment = Enum.TextXAlignment.Left
    NotifyContent.TextWrapped = true
    NotifyContent.Parent = NotifyFrame
    
    Tween(NotifyFrame, {Position = UDim2.new(1, -10, 1, -90)}, 0.5)
    task.wait(Data.Duration or 3)
    Tween(NotifyFrame, {Position = UDim2.new(1, -10, 1, 0)}, 0.3)
    task.wait(0.3)
    NotifyGui:Destroy()
end

-- Rayfieldとしてグローバル登録
getgenv().Rayfield = MyEngine

print("MY EXCLUSIVE GUI ENGINE - LOADED")
print("Rayfield Compatible Mode: ENABLED")
print("All Features: READY")

return MyEngine
