        local player = game.Players.LocalPlayer
        if not player then return end
        print("Script loaded")
        if not game:IsLoaded() then game.Loaded:Wait() end
        local UIS = game:GetService("UserInputService")

        -- 🔥 THÊM Ở ĐÂY
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local bv, bg, flyConnection
        local localHumanoid
        local speedOn = _G.speedOn or false
        _G.immortalConnection = _G.immortalConnection or nil
        local speedValue = _G.speedValue or 16
        local jumpOn = _G.jumpOn or false
        local jumpValue = _G.jumpValue or 50
        local flyOn = _G.flyOn or false
        local flySpeed = _G.flySpeed or 60
        local nonclipOn = _G.nonclipOn or false
        local tracerOn = _G.tracerOn or false
        local rejoin1On = _G.rejoin1On or false
        local autoAttackOn = _G.autoAttackOn or false
        local autoAttackRange = _G.autoAttackRange or 100
        local lastAttackTime = 0
        local attackCooldown = _G.attackCooldown or 0.2  -- Delay giữa các attack (0.2s để tránh lag)
        local autoKillModOn = _G.autoKillModOn or false  -- Auto Kill Mobs
        local autoKillModRange = _G.autoKillModRange or 50  -- Detection range for mobs
        local lastModAttackTime = 0
        local modAttackCooldown = _G.modAttackCooldown or 0.15  -- Attack cooldown for mobs
        local autoKillModConnection = nil
        local dupeMoneyOn = _G.dupeMoneyOn or false  -- Auto Dupe Money
        local dupeAmount = _G.dupeAmount or 1000  -- 1k money per click

        local function updateHumanoidState()
            if not localHumanoid then return end
            localHumanoid.WalkSpeed = speedOn and speedValue or 16
            localHumanoid.UseJumpPower = true
            localHumanoid.JumpPower = jumpOn and jumpValue or 50
        end

        -- =========================
        -- AUTO ATTACK FUNCTIONS (định nghĩa trước khi dùng)
        -- =========================
        local autoAttackConnection = nil

        local function findNearestPlayer()
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

            local myPos = char.HumanoidRootPart.Position
            local nearestPlayer = nil
            local nearestDist = autoAttackRange

            for _, otherPlayer in pairs(game.Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    local otherChar = otherPlayer.Character
                    if otherChar:FindFirstChild("HumanoidRootPart") and otherChar:FindFirstChild("Humanoid") then
                        if otherChar.Humanoid.Health > 0 then
                            local distance = (myPos - otherChar.HumanoidRootPart.Position).Magnitude
                            if distance <= nearestDist then
                                nearestDist = distance
                                nearestPlayer = otherPlayer
                            end
                        end
                    end
                end
            end
            return nearestPlayer
        end

        local function updateAutoAttack()
            if not autoAttackOn then return end

            local currentTime = tick()
            if currentTime - lastAttackTime < attackCooldown then return end

            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return end

            local tool = char:FindFirstChildOfClass("Tool")
            if not tool then return end

            local myHRP = char.HumanoidRootPart
            local hum = char:FindFirstChild("Humanoid")
            if not hum then return end

            local myPos = myHRP.Position

            -- Normal auto attack mode: attack nearest player
            local nearestPlayer = findNearestPlayer()
            if nearestPlayer and nearestPlayer.Character and nearestPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local targetHRP = nearestPlayer.Character.HumanoidRootPart

                -- Teleport on top of enemy head (small offset)
                local targetPos = targetHRP.Position
                local onHeadPos = targetPos + Vector3.new(0, 5.5, 0) -- 5.5 studs above head
                myHRP.CFrame = CFrame.new(onHeadPos, targetPos) -- Look down at enemy

                -- Freeze player in place - không bị bay
                hum.PlatformStand = true
                myHRP.Velocity = Vector3.new(0, 0, 0)
                myHRP.RotVelocity = Vector3.new(0, 0, 0)

                -- Bypass game weapon delay
                pcall(function()
                    if tool:FindFirstChild("Cooldown") then
                        tool.Cooldown.Value = 0
                    end
                end)
                
                pcall(function()
                    if tool:FindFirstChild("Delay") then
                        tool.Delay.Value = 0
                    end
                end)

                -- Perform M1 attack
                local vim = game:GetService("VirtualInputManager")
                for i = 1, 3 do
                    pcall(function()
                        tool:Activate()
                    end)
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end

                -- Keep following enemy while PlatformStand is on
                local attackStartTime = currentTime
                local followConnection
                followConnection = RunService.Heartbeat:Connect(function()
                    if not autoAttackOn or not char or not char.Parent or not nearestPlayer or not nearestPlayer.Character then
                        if followConnection then followConnection:Disconnect() end
                        hum.PlatformStand = false
                        return
                    end
                    
                    local elapsedTime = tick() - attackStartTime
                    if elapsedTime > attackCooldown then
                        if followConnection then followConnection:Disconnect() end
                        hum.PlatformStand = false
                        return
                    end
                    
                    local newTargetHRP = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if newTargetHRP then
                        local newTargetPos = newTargetHRP.Position
                        local newOnHeadPos = newTargetPos + Vector3.new(0, 5.5, 0)
                        myHRP.CFrame = CFrame.new(newOnHeadPos, newTargetPos)
                        myHRP.Velocity = Vector3.new(0, 0, 0)
                        myHRP.RotVelocity = Vector3.new(0, 0, 0)
                    end
                end)

                lastAttackTime = currentTime
            end
        end

        local function startAutoAttack()
            if autoAttackConnection then autoAttackConnection:Disconnect() end
            autoAttackConnection = RunService.Heartbeat:Connect(updateAutoAttack)
        end

        local function stopAutoAttack()
            if autoAttackConnection then
                autoAttackConnection:Disconnect()
                autoAttackConnection = nil
            end
        end

        -- =========================
        -- AUTO KILL MOD FUNCTIONS
        -- =========================

        -- Hàm kiểm tra nếu object là NPC (có Dialog)
        local function isNPC(object)
            if not object then return false end
            -- Kiểm tra nếu có Dialog object (NPC maker)
            if object:FindFirstChild("Dialog") then return true end
            -- Kiểm tra nếu có HumanoidDialogueState attribute hoặc similar
            if object:FindFirstChildOfClass("Dialog") then return true end
            -- Kiểm tra tên NPC phổ biến
            local name = object.Name
            if name:lower():find("npc") or name:lower():find("quest") or name:lower():find("merchant") or name:lower():find("vendor") then
                return true
            end
            return false
        end

        -- Hàm tìm NPC gần nhất
        local function findNearestNPC()
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

            local myPos = char.HumanoidRootPart.Position
            local nearestNPC = nil
            local nearestDist = 100

            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj ~= char and isNPC(obj) and obj:FindFirstChild("HumanoidRootPart") then
                    local distance = (myPos - obj.HumanoidRootPart.Position).Magnitude
                    if distance <= nearestDist then
                        nearestDist = distance
                        nearestNPC = obj
                    end
                end
            end
            return nearestNPC
        end

        -- Hàm auto accept quest từ NPC (cải thiện)
        local function autoAcceptQuestFromNPC(npcObject)
            if not npcObject or not isNPC(npcObject) then return end
            
            pcall(function()
                -- Phương pháp 1: Tìm Dialog và tương tác
                local dialog = npcObject:FindFirstChild("Dialog") or npcObject:FindFirstChildOfClass("Dialog")
                if dialog then
                    -- Thử tìm nút "Accept" hoặc quest-related buttons
                    for _, choice in pairs(dialog:GetChildren()) do
                        pcall(function()
                            if choice:IsA("DialogChoice") then
                                -- Thử invoke như RemoteEvent/RemoteFunction
                                if choice:FindFirstChild("InvokeServer") then
                                    choice:InvokeServer()
                                elseif choice.Invoke then
                                    choice:Invoke()
                                end
                            end
                        end)
                    end
                end
                
                -- Phương pháp 2: Tìm RemoteEvent/RemoteFunction cho quest
                local questFolder = npcObject:FindFirstChild("Quests") or npcObject:FindFirstChild("Quest")
                if questFolder then
                    for _, item in pairs(questFolder:GetChildren()) do
                        if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
                            pcall(function()
                                if item:IsA("RemoteFunction") then
                                    item:InvokeServer("accept")
                                else
                                    item:FireServer("accept")
                                end
                            end)
                        end
                    end
                end
                
                -- Phương pháp 3: Tìm các attribute liên quan đến quest
                for _, attr in pairs(npcObject:GetAttributes()) do
                    if tostring(attr):lower():find("quest") then
                        pcall(function()
                            npcObject:SetAttribute(attr, true)
                        end)
                    end
                end
            end)
        end

        -- Hàm tìm kiếm mobs thật (không phải NPC)
        local function findNearestMod()
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

            local myPos = char.HumanoidRootPart.Position
            local nearestMod = nil
            local nearestDist = autoKillModRange

            -- Tìm kiếm mobs trong workspace
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj ~= char and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                    -- Kiểm tra nó không phải player
                    local hasPlayer = false
                    for _, plr in pairs(game.Players:GetPlayers()) do
                        if obj == plr.Character then
                            hasPlayer = true
                            break
                        end
                    end

                    -- KHÔNG tấn công NPC
                    if not hasPlayer and not isNPC(obj) and obj:FindFirstChild("Humanoid").Health > 0 then
                        local distance = (myPos - obj.HumanoidRootPart.Position).Magnitude
                        if distance <= nearestDist then
                            nearestDist = distance
                            nearestMod = obj
                        end
                    end
                end
            end
            return nearestMod
        end

        local function updateAutoKillMod()
            if not autoKillModOn then return end

            local currentTime = tick()
            if currentTime - lastModAttackTime < modAttackCooldown then return end

            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return end

            local tool = char:FindFirstChildOfClass("Tool")
            if not tool then return end

            local myHRP = char.HumanoidRootPart
            local hum = char:FindFirstChild("Humanoid")
            if not hum then return end

            -- Auto accept quest từ NPC gần nhất
            local nearestNPC = findNearestNPC()
            if nearestNPC then
                autoAcceptQuestFromNPC(nearestNPC)
            end

            -- Find nearest mob (không phải NPC)
            local nearestMod = findNearestMod()
            if nearestMod and nearestMod:FindFirstChild("HumanoidRootPart") then
                local targetHRP = nearestMod.HumanoidRootPart

                -- Teleport on top of mod head
                local targetPos = targetHRP.Position
                local onHeadPos = targetPos + Vector3.new(0, 6, 0) -- 6 studs above head
                myHRP.CFrame = CFrame.new(onHeadPos, targetPos) -- Look down at mod

                -- Freeze player in place
                hum.PlatformStand = true
                myHRP.Velocity = Vector3.new(0, 0, 0)
                myHRP.RotVelocity = Vector3.new(0, 0, 0)

                -- Bypass game weapon delay
                pcall(function()
                    if tool:FindFirstChild("Cooldown") then
                        tool.Cooldown.Value = 0
                    end
                end)
                
                pcall(function()
                    if tool:FindFirstChild("Delay") then
                        tool.Delay.Value = 0
                    end
                end)

                -- Perform M1 attack
                local vim = game:GetService("VirtualInputManager")
                for i = 1, 3 do
                    pcall(function()
                        tool:Activate()
                    end)
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end

                -- Keep following mod while attacking
                local attackStartTime = currentTime
                local followConnection
                followConnection = RunService.Heartbeat:Connect(function()
                    if not autoKillModOn or not char or not char.Parent or not nearestMod or not nearestMod.Parent then
                        if followConnection then followConnection:Disconnect() end
                        hum.PlatformStand = false
                        return
                    end
                    
                    local elapsedTime = tick() - attackStartTime
                    if elapsedTime > modAttackCooldown then
                        if followConnection then followConnection:Disconnect() end
                        hum.PlatformStand = false
                        return
                    end
                    
                    local newTargetHRP = nearestMod:FindFirstChild("HumanoidRootPart")
                    if newTargetHRP then
                        local newTargetPos = newTargetHRP.Position
                        local newOnHeadPos = newTargetPos + Vector3.new(0, 6, 0)
                        myHRP.CFrame = CFrame.new(newOnHeadPos, newTargetPos)
                        myHRP.Velocity = Vector3.new(0, 0, 0)
                        myHRP.RotVelocity = Vector3.new(0, 0, 0)
                    end
                end)

                lastModAttackTime = currentTime
            end
        end

        local function startAutoKillMod()
            if autoKillModConnection then autoKillModConnection:Disconnect() end
            autoKillModConnection = RunService.Heartbeat:Connect(updateAutoKillMod)
        end

        local function stopAutoKillMod()
            if autoKillModConnection then
                autoKillModConnection:Disconnect()
                autoKillModConnection = nil
            end
        end

        -- =========================
        -- AUTO FARM 2 FUNCTIONS (TWEEN VERSION)
        -- =========================

        -- =========================
        -- FIX KHI CHẾT / RESPAWN
        -- =========================
        local function applyFly(char)
            if not char then return end
            local hum = char:WaitForChild("Humanoid")
            local hrp = char:WaitForChild("HumanoidRootPart")

            -- Ngắt kết nối fly cũ
            if flyConnection then flyConnection:Disconnect() flyConnection = nil end
            if bg then bg:Destroy() bg = nil end
            if bv then bv:Destroy() bv = nil end

            if _G.flyOn then
                hum.PlatformStand = true

                bg = Instance.new("BodyGyro")
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.P = 9e4
                bg.Parent = hrp

                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.new(0,0,0)
                bv.Parent = hrp

                flyConnection = RunService.RenderStepped:Connect(function()
                    local cam = workspace.CurrentCamera
                    local move = Vector3.new()

                    if UIS:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end

                    if move.Magnitude > 0 then
                        move = move.Unit
                        bv.Velocity = move * (_G.flySpeed or 60)
                    else
                        bv.Velocity = Vector3.new(0,0,0)
                    end

                    bg.CFrame = cam.CFrame
                end)
            else
                hum.PlatformStand = false
                if bv then bv:Destroy() bv = nil end
                if bg then bg:Destroy() bg = nil end
            end
        end

        local function setupCharacter(char)
            local success, err = pcall(function()
                local hum = char:WaitForChild("Humanoid")
                local hrp = char:WaitForChild("HumanoidRootPart")

                localHumanoid = hum

                -- Khôi phục trạng thái từ global
                speedOn = _G.speedOn or false
                jumpOn = _G.jumpOn or false
                flyOn = _G.flyOn or false
                nonclipOn = _G.nonclipOn or false
                autoAttackOn = _G.autoAttackOn or false
                autoKillModOn = _G.autoKillModOn or false
                speedValue = _G.speedValue or 16
                jumpValue = _G.jumpValue or 50
                flySpeed = _G.flySpeed or 60
                attackCooldown = _G.attackCooldown or 0.2
                modAttackCooldown = _G.modAttackCooldown or 0.15

                -- áp dụng giá trị từ toggle
                updateHumanoidState()

                -- Reset (nếu đảm bảo mặc định khi off)
                if not speedOn then hum.WalkSpeed = 16 end
                if not jumpOn then hum.JumpPower = 50 end

                -- Fly / NonClip áp dụng lại sau respawn
                applyFly(char)

                if autoAttackOn then
                    startAutoAttack()
                end

                if autoKillModOn then
                    startAutoKillMod()
                end

                if nonclipOn then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end

                
                -- Update UI buttons nếu chúng tồn tại
                if localPlayerFrame and localPlayerFrame.Parent then
                    local speedBtn = localPlayerFrame:FindFirstChild("SpeedBtn")
                    local jumpBtn = localPlayerFrame:FindFirstChild("JumpBtn")
                    if speedBtn then speedBtn.Text = "Speed: " .. (speedOn and "ON" or "OFF") end
                    if jumpBtn then jumpBtn.Text = "Jump: " .. (jumpOn and "ON" or "OFF") end
                end
            end)
            if not success then
                warn("Error in setupCharacter: " .. err)
            end
        end

        -- Gọi lần đầu nếu đã có character
        if player.Character then
            setupCharacter(player.Character)
        end

        -- Lắng nghe respawn
        player.CharacterAdded:Connect(function(char)
            setupCharacter(char)
        end)

        -- =========================
        -- GUI
        -- =========================
        local gui = Instance.new("ScreenGui")
        gui.Name = "XEP.HUB"
        gui.ResetOnSpawn = false
        gui.Parent = player:WaitForChild("PlayerGui")

        -- 🔥 ICON BUTTON
        local toggleBtn = Instance.new("ImageButton")
        toggleBtn.Size = UDim2.new(0, 48, 0, 48)
        toggleBtn.Position = UDim2.new(0.5, -24, 0.1, -24)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
        toggleBtn.Image = "rbxassetid://72810918956594"
        toggleBtn.Parent = gui
        toggleBtn.ZIndex = 10
        toggleBtn.Active = true
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1,0)

        -- MAIN FRAME (SMALLER FOR MOBILE)
        local frame = Instance.new("Frame")
        local screenW = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1280
        local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
        local targetW = math.clamp(360, 220, screenW - 40)
        local targetH = math.clamp(300, 240, screenH - 80)

        frame.Size = UDim2.new(0, targetW, 0, targetH)
        frame.Position = UDim2.new(0.5, -targetW/2, 0.5, -targetH/2)
        frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
        frame.Parent = gui
        frame.Active = true
        Instance.new("UICorner", frame)

        -- TITLE BAR
        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1,0,0,28)
        titleBar.BackgroundColor3 = Color3.fromRGB(20,20,20)
        titleBar.Parent = frame
        titleBar.Active = true

        -- TITLE
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1,-100,1,0)
        title.Position = UDim2.new(0,10,0,0)
        title.Text = "XEP.HUB"
        title.TextColor3 = Color3.new(1,1,1)
        title.BackgroundTransparency = 1
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = titleBar

        -- CLOSE
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0,40,1,0)
        close.Position = UDim2.new(1,-40,0,0)
        close.Text = "X"
        close.BackgroundColor3 = Color3.fromRGB(80,0,0)
        close.TextColor3 = Color3.new(1,1,1)
        close.Parent = titleBar

        -- MINIMIZE
        local minimize = Instance.new("TextButton")
        minimize.Size = UDim2.new(0,40,1,0)
        minimize.Position = UDim2.new(1,-80,0,0)
        minimize.Text = "-"
        minimize.BackgroundColor3 = Color3.fromRGB(40,40,40)
        minimize.TextColor3 = Color3.new(1,1,1)
        minimize.Parent = titleBar

        -- MENU
        local menu = Instance.new("Frame")
        menu.Size = UDim2.new(0,100,1,-34)
        menu.Position = UDim2.new(0,0,0,28)
        menu.BackgroundColor3 = Color3.fromRGB(15,15,15)
        menu.Parent = frame

        -- CONTENT FRAME
        local contentFrame = Instance.new("Frame")
        contentFrame.Size = UDim2.new(1,-100,1,-34)
        contentFrame.Position = UDim2.new(0,100,0,28)
        contentFrame.BackgroundTransparency = 1
        contentFrame.Parent = frame

        -- =========================
        -- DỮ LIỆU NÚT RIÊNG CHO TAB
        -- =========================
        local tabButtons = {
            ["Local Player"] = {
                {Name="Nút 1", Action=function() print("Local Player - Nút 1") end},
                {Name="Nút 2", Action=function() print("Local Player - Nút 2") end},
            },
            ["Auto Farm"] = {
            },
            ["PVP"] = {
                {Name="Auto Attack", Action=function(on)
                    autoAttackOn = on
                    _G.autoAttackOn = on
                    if on then
                        startAutoAttack()
                    else
                        stopAutoAttack()
                    end
                end},
                {Name="Auto Parry", Action=function() print("PVP - Auto Parry") end},
            },
            ["Auto Rejoin"] = {
            {Name="Auto Rejoin When Disconnect", Action=function(on)
                if on then
                    repeat wait() until game.CoreGui:FindFirstChild('RobloxPromptGui')
                    local po = game.CoreGui.RobloxPromptGui.promptOverlay
                    local ts = game:GetService("TeleportService")

                    if _G.RejoinConnection then _G.RejoinConnection:Disconnect() end

                    _G.RejoinConnection = po.ChildAdded:Connect(function(a)
                        if a.Name == 'ErrorPrompt' then
                            repeat
                                ts:Teleport(game.PlaceId)
                                wait(2)
                            until false
                        end
                    end)
                    _G.rejoin1On = true
                else
                    if _G.RejoinConnection then _G.RejoinConnection:Disconnect() end
                    _G.rejoin1On = false
                end
            end}},
        }

        -- =========================
        -- trạng thái Local Player global
        -- =========================
        local createLocalPlayer
        local createAutoFarm
        local createPVP
        local currentTab
        local localPlayerCreated = false
        local localPlayerFrame
        local tabFrames = {}

        local function ensureLocalPlayerUI()
            -- NẾU respawn thì tạo lại UI
            if localPlayerFrame and localPlayerFrame.Parent then
                localPlayerFrame:Destroy()
            end
            
            localPlayerFrame = Instance.new("Frame")
            localPlayerFrame.Size = UDim2.new(1,0,1,0)
            localPlayerFrame.BackgroundTransparency = 1
            localPlayerFrame.Parent = contentFrame

            createLocalPlayer(localPlayerFrame)
        end

        local function createButtons(tabName)
            -- nếu click cùng tab thì không load lại, giữ trạng thái đang bật
            if currentTab == tabName then
                return
            end

            currentTab = tabName

            -- ẩn UI cũ
            for _,v in pairs(contentFrame:GetChildren()) do
                v.Visible = false
            end

            -- 🔥 FIX: nếu là Local Player thì chạy code thật (chỉ 1 lần)
            if tabName == "Local Player" then
                ensureLocalPlayerUI()
                localPlayerFrame.Visible = true
                return
            end

            -- 🔥 FIX: nếu là Auto Farm thì chạy code thật
            if tabName == "Auto Farm" then
                if localPlayerFrame and localPlayerFrame.Parent then
                    localPlayerFrame:Destroy()
                    localPlayerFrame = nil
                end
                localPlayerFrame = Instance.new("Frame")
                localPlayerFrame.Size = UDim2.new(1,0,1,0)
                localPlayerFrame.BackgroundTransparency = 1
                localPlayerFrame.Parent = contentFrame
                createAutoFarm(localPlayerFrame)
                localPlayerFrame.Visible = true
                return
            end

            -- 🔥 FIX: nếu là PVP thì chạy code thật
            if tabName == "PVP" then
                if localPlayerFrame and localPlayerFrame.Parent then
                    localPlayerFrame:Destroy()
                    localPlayerFrame = nil
                end
                localPlayerFrame = Instance.new("Frame")
                localPlayerFrame.Size = UDim2.new(1,0,1,0)
                localPlayerFrame.BackgroundTransparency = 1
                localPlayerFrame.Parent = contentFrame
                createPVP(localPlayerFrame)
                localPlayerFrame.Visible = true
                return
            end

            -- 🔥 FIX: nếu là ITEM thì chạy code thật
            if tabName == "ITEM" then
                if localPlayerFrame and localPlayerFrame.Parent then
                    localPlayerFrame:Destroy()
                    localPlayerFrame = nil
                end
                localPlayerFrame = Instance.new("Frame")
                localPlayerFrame.Size = UDim2.new(1,0,1,0)
                localPlayerFrame.BackgroundTransparency = 1
                localPlayerFrame.Parent = contentFrame
                createItems(localPlayerFrame)
                localPlayerFrame.Visible = true
                return
            end

            -- Tab khác giữ nguyên
            local buttons = tabButtons[tabName] or {}
            for i,data in ipairs(buttons) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0,200,0,50)
                btn.Position = UDim2.new(0,20,0,(i-1)*60)
                btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
                btn.TextColor3 = Color3.new(1,1,1)
                btn.Parent = contentFrame

                local toggled = false
                if data.Name == "Auto Rejoin When Disconnect" then
                    toggled = rejoin1On
                elseif data.Name == "Auto Attack" then
                    toggled = autoAttackOn
                end
                btn.Text = data.Name .. ": " .. (toggled and "ON" or "OFF")

        btn.MouseButton1Click:Connect(function()
            toggled = not toggled
            btn.Text = data.Name .. ": " .. (toggled and "ON" or "OFF")
            if data.Name == "Auto Rejoin When Disconnect" then
                rejoin1On = toggled
                _G.rejoin1On = toggled
            elseif data.Name == "Auto Attack" then
                autoAttackOn = toggled
                _G.autoAttackOn = toggled
            end
            if data.Action then
                data.Action(toggled)
            end
        end)
            end
        end

        -- =========================
        -- MENU BUTTONS
        -- =========================
        local items = {"Local Player","Auto Farm","PVP","Auto Rejoin"}

        for i,v in ipairs(items) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1,0,0,40)
            btn.Position = UDim2.new(0,0,0,(i-1)*40)
            btn.Text = v
            btn.TextColor3 = Color3.new(1,1,1)
            btn.BackgroundColor3 = Color3.fromRGB(25,25,25)
            btn.Parent = menu

            btn.MouseButton1Click:Connect(function()
                createButtons(v)
            end)
        end

        createLocalPlayer = function(parent)

            local frameParent = parent or contentFrame
            local hum = (player.Character or player.CharacterAdded:Wait()):WaitForChild("Humanoid")
            localHumanoid = hum

            -- Scrollable container để tránh tràn UI
            local scrollFrame = Instance.new("ScrollingFrame", frameParent)
            scrollFrame.Size = UDim2.new(1,0,1,0)
            scrollFrame.Position = UDim2.new(0,0,0,0)
            scrollFrame.BackgroundTransparency = 1
            scrollFrame.ScrollBarThickness = 12
            scrollFrame.CanvasSize = UDim2.new(0,0,0,700)

            local uiParent = scrollFrame

            -- SPEED
            local speedBtn = Instance.new("TextButton", uiParent)
            speedBtn.Name = "SpeedBtn"
            speedBtn.Size = UDim2.new(0,200,0,40)
            speedBtn.Position = UDim2.new(0,20,0,20)
            speedBtn.Text = "Speed: " .. (speedOn and "ON" or "OFF")

            local speedBar = Instance.new("Frame", uiParent)
            speedBar.Size = UDim2.new(0,300,0,10)
            speedBar.Position = UDim2.new(0,20,0,70)
            speedBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

            local speedFill = Instance.new("Frame", speedBar)
            speedFill.Size = UDim2.new(math.clamp((speedValue - 1) / 199, 0, 1), 0, 1, 0)
            speedFill.BackgroundColor3 = Color3.fromRGB(0,170,255)

            local draggingSpeed = false

            speedBtn.MouseButton1Click:Connect(function()
                speedOn = not speedOn
                _G.speedOn = speedOn
                speedBtn.Text = "Speed: "..(speedOn and "ON" or "OFF")
                updateHumanoidState()
            end)

            speedBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingSpeed = true end
            end)

            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingSpeed = false end
            end)

            UIS.InputChanged:Connect(function(i)
                if draggingSpeed then
                    local pos = math.clamp((i.Position.X - speedBar.AbsolutePosition.X)/speedBar.AbsoluteSize.X,0,1)
                    speedFill.Size = UDim2.new(pos,0,1,0)
                    speedValue = math.floor(1 + pos*199)
                    _G.speedValue = speedValue
                    updateHumanoidState()
                end
            end)

            -- JUMP
            local jumpBtn = Instance.new("TextButton", uiParent)
            jumpBtn.Name = "JumpBtn"
            jumpBtn.Size = UDim2.new(0,200,0,40)
            jumpBtn.Position = UDim2.new(0,20,0,100)
            jumpBtn.Text = "Jump: " .. (jumpOn and "ON" or "OFF")

            local jumpBar = Instance.new("Frame", uiParent)
            jumpBar.Size = UDim2.new(0,300,0,10)
            jumpBar.Position = UDim2.new(0,20,0,150)
            jumpBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

            local jumpFill = Instance.new("Frame", jumpBar)
            jumpFill.Size = UDim2.new(math.clamp((jumpValue - 1) / 199, 0, 1), 0, 1, 0)
            jumpFill.BackgroundColor3 = Color3.fromRGB(0,255,100)

            local draggingJump = false

            jumpBtn.MouseButton1Click:Connect(function()
                jumpOn = not jumpOn
                _G.jumpOn = jumpOn
                jumpBtn.Text = "Jump: "..(jumpOn and "ON" or "OFF")
                updateHumanoidState()
            end)

            jumpBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingJump = true end
            end)

            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingJump = false end
            end)

            UIS.InputChanged:Connect(function(i)
                if draggingJump then
                    local pos = math.clamp((i.Position.X - jumpBar.AbsolutePosition.X)/jumpBar.AbsoluteSize.X,0,1)
                    jumpFill.Size = UDim2.new(pos,0,1,0)
                    jumpValue = math.floor(1 + pos*199)
                    _G.jumpValue = jumpValue
                    updateHumanoidState()
                end
            end)

            -- FLY
        local flyBtn = Instance.new("TextButton", uiParent)
        flyBtn.Size = UDim2.new(0,200,0,40)
        flyBtn.Position = UDim2.new(0,20,0,180)
        flyBtn.Text = "Fly: " .. (flyOn and "ON" or "OFF")

        local flyBar = Instance.new("Frame", uiParent)
        flyBar.Size = UDim2.new(0,300,0,10)
        flyBar.Position = UDim2.new(0,20,0,230)
        flyBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

        local flyFill = Instance.new("Frame", flyBar)
        flyFill.Size = UDim2.new(math.clamp((flySpeed - 10) / 190, 0, 1), 0, 1, 0)
        flyFill.BackgroundColor3 = Color3.fromRGB(255,200,0)

        local draggingFly = false

        flyBtn.MouseButton1Click:Connect(function()
            flyOn = not flyOn
            _G.flyOn = flyOn
            flyBtn.Text = "Fly: "..(flyOn and "ON" or "OFF")

            local char = player.Character
            if not char then
                repeat wait(0.1) until player.Character
                char = player.Character
            end
            applyFly(char)
        end)

        flyBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingFly = true end
        end)

        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingFly = false end
        end)

        UIS.InputChanged:Connect(function(i)
            if draggingFly then
                local pos = math.clamp((i.Position.X - flyBar.AbsolutePosition.X)/flyBar.AbsoluteSize.X,0,1)
                flyFill.Size = UDim2.new(pos,0,1,0)
                flySpeed = math.floor(10 + pos*190)
                _G.flySpeed = flySpeed
            end
        end)
        -- =========================
        -- NONCLIP
        -- =========================
        local nonclipBtn = Instance.new("TextButton", uiParent)
        nonclipBtn.Size = UDim2.new(0,200,0,40)
        nonclipBtn.Position = UDim2.new(0,20,0,260)
        nonclipBtn.Text = "NonClip: " .. (nonclipOn and "ON" or "OFF")

        nonclipBtn.MouseButton1Click:Connect(function()
            nonclipOn = not nonclipOn
            _G.nonclipOn = nonclipOn
            nonclipBtn.Text = "NonClip: " .. (nonclipOn and "ON" or "OFF")

            local char = player.Character or player.CharacterAdded:Wait()

            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = not nonclipOn
                end
            end
        end)

        -- =========================
        -- NON-PLAYER SPECIFIC FEATURES
        -- =========================

        end

        -- =========================
        -- CREATE AUTO FARM UI
        -- =========================
        createAutoFarm = function(parent)
            local frameParent = parent or contentFrame
            
            local scrollFrame = Instance.new("ScrollingFrame", frameParent)
            scrollFrame.Size = UDim2.new(1,0,1,0)
            scrollFrame.Position = UDim2.new(0,0,0,0)
            scrollFrame.BackgroundTransparency = 1
            scrollFrame.ScrollBarThickness = 12
            scrollFrame.CanvasSize = UDim2.new(0,0,0,500)

            local uiParent = scrollFrame

            -- =========================
            -- AUTO KILL MOD (Farm)
            -- =========================
            local autoKillModBtn = Instance.new("TextButton", uiParent)
            autoKillModBtn.Size = UDim2.new(0,200,0,40)
            autoKillModBtn.Position = UDim2.new(0,20,0,20)
            autoKillModBtn.Text = "Auto Kill Mod: " .. (autoKillModOn and "ON" or "OFF")
            autoKillModBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
            autoKillModBtn.TextColor3 = Color3.new(1,1,1)

            autoKillModBtn.MouseButton1Click:Connect(function()
                autoKillModOn = not autoKillModOn
                _G.autoKillModOn = autoKillModOn
                autoKillModBtn.Text = "Auto Kill Mod: " .. (autoKillModOn and "ON" or "OFF")
                if autoKillModOn then
                    startAutoKillMod()
                else
                    stopAutoKillMod()
                end
            end)

            -- MOD DETECTION RANGE SLIDER
            local modRangeLabel = Instance.new("TextLabel", uiParent)
            modRangeLabel.Size = UDim2.new(0,200,0,20)
            modRangeLabel.Position = UDim2.new(0,20,0,65)
            modRangeLabel.Text = "Mod Range: " .. autoKillModRange
            modRangeLabel.BackgroundTransparency = 1
            modRangeLabel.TextColor3 = Color3.new(1,1,1)
            modRangeLabel.TextScaled = false
            modRangeLabel.TextSize = 16

            local modRangeBar = Instance.new("Frame", uiParent)
            modRangeBar.Size = UDim2.new(0,300,0,10)
            modRangeBar.Position = UDim2.new(0,20,0,90)
            modRangeBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

            local modRangeFill = Instance.new("Frame", modRangeBar)
            modRangeFill.Size = UDim2.new(math.clamp((autoKillModRange - 10) / 990, 0, 1), 0, 1, 0)
            modRangeFill.BackgroundColor3 = Color3.fromRGB(150,100,255)

            local draggingModRange = false

            modRangeBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingModRange = true end
            end)

            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingModRange = false end
            end)

            UIS.InputChanged:Connect(function(i)
                if draggingModRange then
                    local pos = math.clamp((i.Position.X - modRangeBar.AbsolutePosition.X)/modRangeBar.AbsoluteSize.X,0,1)
                    modRangeFill.Size = UDim2.new(pos,0,1,0)
                    autoKillModRange = math.floor(10 + pos*990)
                    _G.autoKillModRange = autoKillModRange
                    modRangeLabel.Text = "Mod Range: " .. autoKillModRange
                end
            end)

            -- MOD ATTACK SPEED SLIDER
            local modSpeedLabel = Instance.new("TextLabel", uiParent)
            modSpeedLabel.Size = UDim2.new(0,200,0,20)
            modSpeedLabel.Position = UDim2.new(0,20,0,105)
            modSpeedLabel.Text = "Mod Speed: " .. string.format("%.2f", modAttackCooldown)
            modSpeedLabel.BackgroundTransparency = 1
            modSpeedLabel.TextColor3 = Color3.new(1,1,1)
            modSpeedLabel.TextScaled = false
            modSpeedLabel.TextSize = 16

            local modSpeedBar = Instance.new("Frame", uiParent)
            modSpeedBar.Size = UDim2.new(0,300,0,10)
            modSpeedBar.Position = UDim2.new(0,20,0,130)
            modSpeedBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

            local modSpeedFill = Instance.new("Frame", modSpeedBar)
            modSpeedFill.Size = UDim2.new(math.clamp((0.3 - modAttackCooldown) / 0.25, 0, 1), 0, 1, 0)
            modSpeedFill.BackgroundColor3 = Color3.fromRGB(150,255,100)

            local draggingModSpeed = false

            modSpeedBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingModSpeed = true end
            end)

            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingModSpeed = false end
            end)

            UIS.InputChanged:Connect(function(i)
                if draggingModSpeed then
                    local pos = math.clamp((i.Position.X - modSpeedBar.AbsolutePosition.X)/modSpeedBar.AbsoluteSize.X,0,1)
                    modSpeedFill.Size = UDim2.new(pos,0,1,0)
                    modAttackCooldown = math.max(0.05, 0.3 - pos * 0.25)
                    _G.modAttackCooldown = modAttackCooldown
                    modSpeedLabel.Text = "Mod Speed: " .. string.format("%.2f", modAttackCooldown)
                end
            end)

            -- =========================
            -- DUPE MONEY BUTTON
            -- =========================
            local dupeMoneyBtn = Instance.new("TextButton", uiParent)
            dupeMoneyBtn.Size = UDim2.new(0,200,0,40)
            dupeMoneyBtn.Position = UDim2.new(0,20,0,155)
            dupeMoneyBtn.Text = "Dupe Money: " .. (dupeMoneyOn and "ON" or "OFF")
            dupeMoneyBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
            dupeMoneyBtn.TextColor3 = Color3.new(1,1,1)

            dupeMoneyBtn.MouseButton1Click:Connect(function()
                dupeMoneyOn = not dupeMoneyOn
                _G.dupeMoneyOn = dupeMoneyOn
                dupeMoneyBtn.Text = "Dupe Money: " .. (dupeMoneyOn and "ON" or "OFF")
                
                if dupeMoneyOn then
                    -- Add money when activated
                    local playerStats = player:FindFirstChild("leaderstats")
                    if playerStats then
                        local money = playerStats:FindFirstChild("Money") or playerStats:FindFirstChild("Cash") or playerStats:FindFirstChild("Coins")
                        if money then
                            pcall(function()
                                if money.Value then
                                    money.Value = money.Value + dupeAmount
                                end
                            end)
                        end
                    end
                end
            end)

            -- DUPE AMOUNT SLIDER
            local dupeAmountLabel = Instance.new("TextLabel", uiParent)
            dupeAmountLabel.Size = UDim2.new(0,200,0,20)
            dupeAmountLabel.Position = UDim2.new(0,20,0,200)
            dupeAmountLabel.Text = "Dupe Amount: " .. dupeAmount
            dupeAmountLabel.BackgroundTransparency = 1
            dupeAmountLabel.TextColor3 = Color3.new(1,1,1)
            dupeAmountLabel.TextScaled = false
            dupeAmountLabel.TextSize = 16

            local dupeAmountBar = Instance.new("Frame", uiParent)
            dupeAmountBar.Size = UDim2.new(0,300,0,10)
            dupeAmountBar.Position = UDim2.new(0,20,0,225)
            dupeAmountBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

            local dupeAmountFill = Instance.new("Frame", dupeAmountBar)
            dupeAmountFill.Size = UDim2.new(math.clamp((dupeAmount - 100) / 99900, 0, 1), 0, 1, 0)
            dupeAmountFill.BackgroundColor3 = Color3.fromRGB(0,255,0)

            local draggingDupeAmount = false

            dupeAmountBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingDupeAmount = true end
            end)

            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingDupeAmount = false end
            end)

            UIS.InputChanged:Connect(function(i)
                if draggingDupeAmount then
                    local pos = math.clamp((i.Position.X - dupeAmountBar.AbsolutePosition.X)/dupeAmountBar.AbsoluteSize.X,0,1)
                    dupeAmountFill.Size = UDim2.new(pos,0,1,0)
                    dupeAmount = math.floor(100 + pos*99900)
                    _G.dupeAmount = dupeAmount
                    dupeAmountLabel.Text = "Dupe Amount: " .. dupeAmount
                end
            end)
        end

        -- =========================
        -- CREATE PVP UI
        -- =========================
        local espLines = {}
        local espConnection
        local espNameGuis = {}
        local selectedPlayer = nil
        local selectedBtn = nil

        local function createESPLine(from, to)
            local part = Instance.new("Part")
            part.Shape = Enum.PartType.Block
            part.CanCollide = false
            part.CastShadow = false
            
            local direction = (to - from)
            local distance = direction.Magnitude
            local midpoint = from + direction * 0.5
            
            part.Size = Vector3.new(0.3, 0.3, distance)
            part.CFrame = CFrame.new(midpoint, to)
            part.Color = Color3.fromRGB(255, 0, 0)
            part.Transparency = 0.15
            part.Material = Enum.Material.Neon
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            part.Parent = workspace
            
            return part
        end

        local function createESPNameGui(otherPlayer)
            if not otherPlayer or not otherPlayer.Character or not otherPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
            local hrp = otherPlayer.Character.HumanoidRootPart

            if espNameGuis[otherPlayer] then
                return
            end

            local billboard = Instance.new("BillboardGui")
            billboard.Name = "ESPNameGui"
            billboard.Adornee = hrp
            billboard.AlwaysOnTop = true
            billboard.Size = UDim2.new(0, 150, 0, 35)
            billboard.StudsOffset = Vector3.new(0, 2.5, 0)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 0.5
            nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextStrokeTransparency = 0.5
            nameLabel.Text = otherPlayer.Name
            nameLabel.TextScaled = true
            nameLabel.Parent = billboard

            billboard.Parent = hrp
            espNameGuis[otherPlayer] = billboard
        end

        local function removeAllESPGuis()
            for _, guiObj in pairs(espNameGuis) do
                if guiObj and guiObj.Parent then
                    guiObj:Destroy()
                end
            end
            espNameGuis = {}
        end

        local function updateESP()
            if not tracerOn then
                for _, part in pairs(espLines) do
                    if part and part.Parent then
                        part:Destroy()
                    end
                end
                espLines = {}
                return
            end

            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return end
            
            local myPos = char.HumanoidRootPart.Position
            
            for _, part in pairs(espLines) do
                if part and part.Parent then
                    part:Destroy()
                end
            end
            espLines = {}

            for _, otherPlayer in pairs(game.Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    local otherChar = otherPlayer.Character
                    if otherChar:FindFirstChild("HumanoidRootPart") and otherChar:FindFirstChild("Humanoid") then
                        if otherChar.Humanoid.Health > 0 then
                            local enemyPos = otherChar.HumanoidRootPart.Position
                            local line = createESPLine(myPos, enemyPos)
                            table.insert(espLines, line)
                            createESPNameGui(otherPlayer)
                        end
                    end
                end
            end
        end

        createPVP = function(parent)
            local frameParent = parent or contentFrame
            
            local scrollFrame = Instance.new("ScrollingFrame", frameParent)
            scrollFrame.Size = UDim2.new(1,0,1,0)
            scrollFrame.Position = UDim2.new(0,0,0,0)
            scrollFrame.BackgroundTransparency = 1
            scrollFrame.ScrollBarThickness = 12
            scrollFrame.CanvasSize = UDim2.new(0,0,0,1200)

            local uiParent = scrollFrame

            -- AUTO ATTACK BUTTON
            local autoAttackBtn = Instance.new("TextButton", uiParent)
            autoAttackBtn.Size = UDim2.new(0,200,0,40)
            autoAttackBtn.Position = UDim2.new(0,20,0,20)
            autoAttackBtn.Text = "Auto Attack: " .. (autoAttackOn and "ON" or "OFF")
            autoAttackBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
            autoAttackBtn.TextColor3 = Color3.new(1,1,1)

            autoAttackBtn.MouseButton1Click:Connect(function()
                autoAttackOn = not autoAttackOn
                _G.autoAttackOn = autoAttackOn
                autoAttackBtn.Text = "Auto Attack: " .. (autoAttackOn and "ON" or "OFF")
                if autoAttackOn then
                    startAutoAttack()
                else
                    stopAutoAttack()
                end
            end)

            -- ATTACK RANGE SLIDER
            local rangeLabel = Instance.new("TextLabel", uiParent)
            rangeLabel.Size = UDim2.new(0,200,0,20)
            rangeLabel.Position = UDim2.new(0,20,0,65)
            rangeLabel.Text = "Range: " .. autoAttackRange
            rangeLabel.BackgroundTransparency = 1
            rangeLabel.TextColor3 = Color3.new(1,1,1)
            rangeLabel.TextScaled = false
            rangeLabel.TextSize = 16

            local rangeBar = Instance.new("Frame", uiParent)
            rangeBar.Size = UDim2.new(0,300,0,10)
            rangeBar.Position = UDim2.new(0,20,0,90)
            rangeBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

            local rangeFill = Instance.new("Frame", rangeBar)
            rangeFill.Size = UDim2.new(math.clamp((autoAttackRange - 1) / 999, 0, 1), 0, 1, 0)
            rangeFill.BackgroundColor3 = Color3.fromRGB(255,100,0)

            local draggingRange = false

            rangeBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingRange = true end
            end)

            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingRange = false end
            end)

            UIS.InputChanged:Connect(function(i)
                if draggingRange then
                    local pos = math.clamp((i.Position.X - rangeBar.AbsolutePosition.X)/rangeBar.AbsoluteSize.X,0,1)
                    rangeFill.Size = UDim2.new(pos,0,1,0)
                    autoAttackRange = math.floor(1 + pos*999)
                    _G.autoAttackRange = autoAttackRange
                    rangeLabel.Text = "Range: " .. autoAttackRange
                end
            end)

            -- ATTACK SPEED SLIDER
            local speedLabel = Instance.new("TextLabel", uiParent)
            speedLabel.Size = UDim2.new(0,200,0,20)
            speedLabel.Position = UDim2.new(0,20,0,105)
            speedLabel.Text = "Speed: " .. string.format("%.2f", attackCooldown)
            speedLabel.BackgroundTransparency = 1
            speedLabel.TextColor3 = Color3.new(1,1,1)
            speedLabel.TextScaled = false
            speedLabel.TextSize = 16

            local speedBar = Instance.new("Frame", uiParent)
            speedBar.Size = UDim2.new(0,300,0,10)
            speedBar.Position = UDim2.new(0,20,0,130)
            speedBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

            local speedFill = Instance.new("Frame", speedBar)
            speedFill.Size = UDim2.new(math.clamp((0.3 - attackCooldown) / 0.25, 0, 1), 0, 1, 0)
            speedFill.BackgroundColor3 = Color3.fromRGB(100,200,255)

            local draggingSpeed = false

            speedBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingSpeed = true end
            end)

            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingSpeed = false end
            end)

            UIS.InputChanged:Connect(function(i)
                if draggingSpeed then
                    local pos = math.clamp((i.Position.X - speedBar.AbsolutePosition.X)/speedBar.AbsoluteSize.X,0,1)
                    speedFill.Size = UDim2.new(pos,0,1,0)
                    attackCooldown = math.max(0.05, 0.3 - pos * 0.25)
                    _G.attackCooldown = attackCooldown
                    speedLabel.Text = "Speed: " .. string.format("%.2f", attackCooldown)
                end
            end)

            -- ESP BUTTON
            local espBtn = Instance.new("TextButton", uiParent)
            espBtn.Size = UDim2.new(0,200,0,40)
            espBtn.Position = UDim2.new(0,20,0,150)
            espBtn.Text = "ESP: " .. (tracerOn and "ON" or "OFF")
            espBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
            espBtn.TextColor3 = Color3.new(1,1,1)

            espBtn.MouseButton1Click:Connect(function()
                tracerOn = not tracerOn
                _G.tracerOn = tracerOn
                espBtn.Text = "ESP: " .. (tracerOn and "ON" or "OFF")

                if tracerOn then
                    if espConnection then espConnection:Disconnect() end
                    espConnection = RunService.Heartbeat:Connect(updateESP)
                else
                    if espConnection then espConnection:Disconnect() end
                    for _, part in pairs(espLines) do
                        if part and part.Parent then
                            part:Destroy()
                        end
                    end
                    espLines = {}
                    removeAllESPGuis()
                end
            end)





            -- TELEPORT SECTION
            local teleportLabel = Instance.new("TextLabel", uiParent)
            teleportLabel.Size = UDim2.new(0,200,0,30)
            teleportLabel.Position = UDim2.new(0,20,0,250)
            teleportLabel.Text = "Teleport to Player"
            teleportLabel.BackgroundTransparency = 1
            teleportLabel.TextColor3 = Color3.new(1,1,1)
            teleportLabel.TextXAlignment = Enum.TextXAlignment.Left

            local playerList = Instance.new("ScrollingFrame", uiParent)
            playerList.Size = UDim2.new(0,300,0,120)
            playerList.Position = UDim2.new(0,20,0,280)
            playerList.BackgroundColor3 = Color3.fromRGB(20,20,20)
            playerList.CanvasSize = UDim2.new(0,0,0,0)
            playerList.ScrollBarThickness = 10

            local function updatePlayerList()
                for _, child in pairs(playerList:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                local players = game.Players:GetPlayers()
                local yPos = 0
                for _, p in ipairs(players) do
                    if p ~= player then
                        local btn = Instance.new("TextButton", playerList)
                        btn.Size = UDim2.new(1,-10,0,30)
                        btn.Position = UDim2.new(0,0,0,yPos)
                        btn.Text = p.Name
                        btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
                        btn.TextColor3 = Color3.new(1,1,1)
                        btn.MouseButton1Click:Connect(function()
                            selectedPlayer = p
                            if selectedBtn then selectedBtn.BackgroundColor3 = Color3.fromRGB(40,40,40) end
                            selectedBtn = btn
                            btn.BackgroundColor3 = Color3.fromRGB(0,100,255)
                        end)
                        yPos = yPos + 30
                    end
                end
                playerList.CanvasSize = UDim2.new(0,0,0,yPos)
            end

            updatePlayerList()

            local teleportBtn = Instance.new("TextButton", uiParent)
            teleportBtn.Size = UDim2.new(0,200,0,40)
            teleportBtn.Position = UDim2.new(0,20,0,525)
            teleportBtn.Text = "Teleport"
            teleportBtn.BackgroundColor3 = Color3.fromRGB(0,100,0)
            teleportBtn.TextColor3 = Color3.new(1,1,1)

            teleportBtn.MouseButton1Click:Connect(function()
                if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame
                    end
                end
            end)

            -- Update player list when players join/leave
            game.Players.PlayerAdded:Connect(updatePlayerList)
            game.Players.PlayerRemoving:Connect(updatePlayerList)
        end

        createItems = function(parent)
            local frameParent = parent or contentFrame
            
            local scrollFrame = Instance.new("ScrollingFrame", frameParent)
            scrollFrame.Size = UDim2.new(1,0,1,0)
            scrollFrame.Position = UDim2.new(0,0,0,0)
            scrollFrame.BackgroundTransparency = 1
            scrollFrame.ScrollBarThickness = 12
            scrollFrame.CanvasSize = UDim2.new(0,0,0,400)

            local uiParent = scrollFrame

            -- KATANA ITEM LABEL
            local katanaLabel = Instance.new("TextLabel", uiParent)
            katanaLabel.Size = UDim2.new(0,300,0,30)
            katanaLabel.Position = UDim2.new(0,20,0,20)
            katanaLabel.Text = "⚔ Katana"
            katanaLabel.BackgroundColor3 = Color3.fromRGB(50,50,50)
            katanaLabel.TextColor3 = Color3.fromRGB(255,200,0)
            katanaLabel.TextScaled = true

            -- KATANA CLAIM BUTTON
            local katanaClaimBtn = Instance.new("TextButton", uiParent)
            katanaClaimBtn.Size = UDim2.new(0,200,0,40)
            katanaClaimBtn.Position = UDim2.new(0,20,0,60)
            katanaClaimBtn.Text = "Claim Katana"
            katanaClaimBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
            katanaClaimBtn.TextColor3 = Color3.new(1,1,1)

            katanaClaimBtn.MouseButton1Click:Connect(function()
                local char = player.Character
                if char and not char:FindFirstChild("Katana") then
                    -- Create katana tool
                    local katana = Instance.new("Tool")
                    katana.Name = "Katana"
                    katana.RequiresHandle = true
                    katana.ToolTip = "Swing to attack"
                    katana.CanBeDropped = false
                    
                    -- Create blade handle
                    local handle = Instance.new("Part")
                    handle.Name = "Handle"
                    handle.Shape = Enum.PartType.Block
                    handle.Material = Enum.Material.Metal
                    handle.Size = Vector3.new(0.5, 3.5, 0.1)
                    handle.CanCollide = false
                    handle.Color = Color3.fromRGB(255, 200, 0)
                    handle.TopSurface = Enum.SurfaceType.Smooth
                    handle.BottomSurface = Enum.SurfaceType.Smooth
                    handle.Parent = katana
                    
                    katana.GripPos = Vector3.new(0, -1.2, 0)
                    
                    -- Store hit tracking in tool
                    local lastHitTime = Instance.new("Folder")
                    lastHitTime.Name = "HitTracker"
                    lastHitTime.Parent = katana
                    
                    local hitCooldown = 0.3
                    
                    -- Use Heartbeat for consistent damage checking
                    local hitConnection
                    hitConnection = RunService.Heartbeat:Connect(function()
                        if not katana or not katana.Parent then
                            if hitConnection then hitConnection:Disconnect() end
                            return
                        end
                        
                        local charRef = player.Character
                        if not charRef or not charRef:FindFirstChild("HumanoidRootPart") then return end
                        
                        local handle = katana:FindFirstChild("Handle")
                        if not handle then return end
                        
                        -- Check all players nearby
                        for _, otherPlayer in pairs(game.Players:GetPlayers()) do
                            if otherPlayer ~= player and otherPlayer.Character then
                                local otherChar = otherPlayer.Character
                                local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
                                local otherHum = otherChar:FindFirstChild("Humanoid")
                                
                                if otherHRP and otherHum and otherHum.Health > 0 then
                                    local dist = (handle.Position - otherHRP.Position).Magnitude
                                    if dist < 6 then  -- Hit range
                                        local trackKey = tostring(otherPlayer.UserId)
                                        local lastTime = lastHitTime:GetAttribute(trackKey) or 0
                                        if tick() - lastTime >= hitCooldown then
                                            otherHum:TakeDamage(50)
                                            lastHitTime:SetAttribute(trackKey, tick())
                                            print("[Katana] Hit " .. otherPlayer.Name .. " for 50 damage!")
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    
                    -- Store connection in tool
                    katana:SetAttribute("HitConnection", true)
                    
                    -- ANIMATION SYSTEM
                    local isSwinging = false
                    local lastSwingTime = 0
                    
                    katana.Activated:Connect(function()
                        if isSwinging or tick() - lastSwingTime < 0.4 then return end
                        
                        isSwinging = true
                        lastSwingTime = tick()
                        
                        local handle = katana:FindFirstChild("Handle")
                        local charRef = player.Character
                        if not handle or not charRef then return end
                        
                        local startHandleCFrame = handle.CFrame
                        local startTime = tick()
                        local swingDuration = 0.5
                        
                        -- Swing animation - only handle moves, body stays still
                        local swingConnection
                        swingConnection = RunService.RenderStepped:Connect(function()
                            if not isSwinging or not handle or not handle.Parent then
                                swingConnection:Disconnect()
                                return
                            end
                            
                            local elapsed = tick() - startTime
                            local progress = math.min(elapsed / swingDuration, 1)
                            
                            -- Swing the handle in an arc motion
                            if progress < 0.5 then
                                -- First half: swing up and forward
                                local swingAngle = progress * 2 * math.rad(160)
                                handle.CFrame = startHandleCFrame * CFrame.Angles(swingAngle, 0, 0)
                            else
                                -- Second half: swing back to rest
                                local remainingProgress = (progress - 0.5) * 2
                                local swingAngle = (1 - remainingProgress) * math.rad(160)
                                handle.CFrame = startHandleCFrame * CFrame.Angles(swingAngle, 0, 0)
                            end
                            
                            if progress >= 1 then
                                handle.CFrame = startHandleCFrame
                                isSwinging = false
                                swingConnection:Disconnect()
                            end
                        end)
                    end)
                    
                    katana.Parent = char
                    
                    -- Store tool globally to prevent GC
                    _G.katanaTool = katana
                    _G.katanaHitConnection = hitConnection
                    
                    katanaClaimBtn.Text = "✓ Claimed!"
                    katanaClaimBtn.BackgroundColor3 = Color3.fromRGB(50,150,50)
                    
                    task.wait(1)
                    katanaClaimBtn.Text = "Claim Katana"
                    katanaClaimBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
                elseif char:FindFirstChild("Katana") then
                    katanaClaimBtn.Text = "Already have Katana!"
                    katanaClaimBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
                    task.wait(2)
                    katanaClaimBtn.Text = "Claim Katana"
                    katanaClaimBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
                end
            end)
        end

        createButtons("Local Player")

        -- =========================
        -- TOGGLE UI
        -- =========================
        local uiVisible = true
        toggleBtn.MouseButton1Click:Connect(function()
            uiVisible = not uiVisible
            frame.Visible = uiVisible
        end)

        -- CLOSE
        close.MouseButton1Click:Connect(function()

            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum.WalkSpeed = 16
                    hum.JumpPower = 50
                    hum.PlatformStand = false
                end
            end

            if flyConnection then
                flyConnection:Disconnect()
            end

            if bg then bg:Destroy() end

            if espConnection then
                espConnection:Disconnect()
            end
            
            if autoAttackConnection then
                autoAttackConnection:Disconnect()
            end
            
            if autoKillModConnection then
                autoKillModConnection:Disconnect()
            end
            
            if autoFarm2Connection then
                autoFarm2Connection:Disconnect()
            end
            
            for _, part in pairs(espLines or {}) do
                if part and part.Parent then
                    part:Destroy()
                end
            end

            -- Reset all global states
            _G.speedOn = false
            _G.speedValue = 16
            _G.jumpOn = false
            _G.jumpValue = 50
            _G.flyOn = false
            _G.flySpeed = 60
            _G.nonclipOn = false
            _G.tracerOn = false
            _G.autoAttackOn = false
            _G.autoAttackRange = 100
            _G.attackCooldown = 0.2
            _G.autoKillModOn = false
            _G.autoKillModRange = 50
            _G.modAttackCooldown = 0.15
            _G.rejoin1On = false
            if _G.RejoinConnection then _G.RejoinConnection:Disconnect() end

            gui:Destroy()
        end)

        -- MINIMIZE
        local minimized = false
        minimize.MouseButton1Click:Connect(function()
            minimized = not minimized
            if minimized then
                frame.Size = UDim2.new(0,600,0,40)
                menu.Visible = false
                contentFrame.Visible = false
            else
                frame.Size = UDim2.new(0,600,0,500)
                menu.Visible = true
                contentFrame.Visible = true
            end
        end)

        -- =========================
        -- DRAG FRAME
        -- =========================
        local dragging = false
        local dragStart, startPos
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        titleBar.InputChanged:Connect(function(input)
            if dragging then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)

        -- =========================
        -- DRAG TOGGLE BUTTON
        -- =========================
        local draggingBtn = false
        local dragStartBtn, startPosBtn

        -- Bắt đầu kéo
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingBtn = true
                dragStartBtn = input.Position
                startPosBtn = toggleBtn.Position
            end
        end)

        -- Thả chuột = dừng kéo
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingBtn = false
            end
        end)

        -- Kéo mượt
        UIS.InputChanged:Connect(function(input)
            if draggingBtn and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStartBtn
                toggleBtn.Position = UDim2.new(
                    startPosBtn.X.Scale,
                    startPosBtn.X.Offset + delta.X,
                    startPosBtn.Y.Scale,
                    startPosBtn.Y.Offset + delta.Y
                )
            end
        end)
