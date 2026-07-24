-- BELISIMUS - Rivals Script

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")
local Camera=workspace.CurrentCamera
local VirtualInputManager=game:GetService("VirtualInputManager")
local HttpService=game:GetService("HttpService")

local Player=Players.LocalPlayer
local Mouse=Player:GetMouse()
local DISCORD="https://discord.gg/MPjUNh3z2"

-- НАСТРОЙКИ
local S={
    silentAim=true,silentAimFOV=150,
    aimbot=false,aimbotSmooth=3,aimbotFOV=120,aimKey="MouseButton2",aimLock=false,
    tbot=false,tbotDelay=0.05,tbotKey="MouseButton2",tbotHead=false,
    esp=true,espName=true,espDist=true,espHealth=true,
    noRecoil=true,noSpread=true,
    speed=false,speedVal=30,
    fly=false,flySpeed=50,
    jump=false,
    skin=false,skinSel="Golden",
}

local espObjs={}
local lastESP=0
local enemyCache={}
local cacheTime=0
local CACHE_DUR=0.15
local lastTrigger=0
local flyVel=Vector3.new(0,0,0)

local function getChar()
    local c=Player.Character
    if not c or not c.Parent then Player.CharacterAdded:Wait();c=Player.Character end
    return c
end

local function getRoot()
    local c=getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c=getChar()
    return c and c:FindFirstChild("Humanoid")
end

local function getHead()
    local c=getChar()
    return c and c:FindFirstChild("Head")
end

local function getEnemies()
    local now=tick()
    if now-cacheTime<CACHE_DUR then return enemyCache end
    enemyCache={}
    for _,plr in pairs(Players:GetPlayers())do
        if plr~=Player and plr.Character then
            local hrp=plr.Character:FindFirstChild("HumanoidRootPart")
            local hum=plr.Character:FindFirstChild("Humanoid")
            local head=plr.Character:FindFirstChild("Head")
            if hrp and hum and hum.Health>0 then
                table.insert(enemyCache,{player=plr,character=plr.Character,root=hrp,head=head,humanoid=hum})
            end
        end
    end
    cacheTime=now
    return enemyCache
end

local function isKeyDown(k)
    if k=="MouseButton2"then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)end
    if k=="MouseButton1"then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)end
    if k=="MouseButton3"then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)end
    for _,e in pairs(Enum.KeyCode:GetEnumItems())do
        if tostring(e):gsub("Enum.KeyCode.","")==k then return UserInputService:IsKeyDown(e)end
    end
    return false
end

local function getKeyName(k)
    if k=="MouseButton2"then return"ПКМ"end
    if k=="MouseButton1"then return"ЛКМ"end
    if k=="MouseButton3"then return"Средняя"end
    if k=="RightShift"then return"Right Shift"end
    if k=="LeftShift"then return"Left Shift"end
    if k=="RightControl"then return"Right Ctrl"end
    if k=="LeftControl"then return"Left Ctrl"end
    return k
end

local function getTarget(fov,useHead)
    local root=getRoot()
    if not root then return nil end
    local enemies=getEnemies()
    if #enemies==0 then return nil end
    local mx,my=Mouse.X,Mouse.Y
    local best,bd=nil,fov or 360
    for _,en in pairs(enemies)do
        local part=useHead and en.head or en.root
        if part then
            local sp,on=Camera:WorldToViewportPoint(part.Position)
            if on then
                local d=(Vector2.new(sp.X,sp.Y)-Vector2.new(mx,my)).Magnitude
                if d<bd then bd=d;best=en end
            end
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if not S.silentAim then return end
    local target=getTarget(S.silentAimFOV,false)
end)

local function updateAimbot()
    if not S.aimbot then return end
    local key=isKeyDown(S.aimKey)
    if S.aimLock then key=true end
    if not key then return end
    local target=getTarget(S.aimbotFOV,false)
    if not target then return end
    local part=target.head or target.root
    if not part then return end
    local sp,on=Camera:WorldToViewportPoint(part.Position)
    if not on then return end
    local cx,cy=Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2
    local ox,oy=sp.X-cx,sp.Y-cy
    if math.abs(ox)<2 and math.abs(oy)<2 then return end
    local sm=S.aimbotSmooth
    local sx,sy=ox/(sm*60),oy/(sm*60)
    local ms=15
    sx,sy=math.clamp(sx,-ms,ms),math.clamp(sy,-ms,ms)
    if math.abs(sx)>0.1 or math.abs(sy)>0.1 then
        VirtualInputManager:SendMouseMoveEvent(sx,sy,0,game)
    end
end

local function updateTbot()
    if not S.tbot then return end
    if not isKeyDown(S.tbotKey) then return end
    if tick()-lastTrigger<S.tbotDelay then return end
    local target=getTarget(360,S.tbotHead)
    if not target then return end
    local part=S.tbotHead and target.head or target.root
    if not part then return end
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
    lastTrigger=tick()
end

local function updateESP()
    if not S.esp then
        for _,o in pairs(espObjs)do pcall(function()o:Destroy()end)end
        espObjs={}
        return
    end
    local now=tick()
    if now-lastESP<0.12 then return end
    lastESP=now
    local enemies=getEnemies()
    for i,en in pairs(enemies)do
        local part=en.head or en.root
        if not part then continue end
        local sp,on=Camera:WorldToViewportPoint(part.Position)
        if on then
            local esp=espObjs[i]
            if not esp then
                esp=Instance.new("Frame")
                esp.Parent=CoreGui
                esp.Size=UDim2.new(0,30,0,50)
                esp.BackgroundColor3=Color3.fromRGB(255,215,0)
                esp.BackgroundTransparency=0.4
                esp.BorderSizePixel=2
                esp.BorderColor3=Color3.fromRGB(255,215,0)
                local c=Instance.new("UICorner")
                c.Parent=esp
                c.CornerRadius=UDim.new(0,4)
                table.insert(espObjs,esp)
            end
            local sc=1/sp.Z
            local sz=30*sc
            esp.Size=UDim2.new(0,sz,0,sz*1.5)
            esp.Position=UDim2.new(0,sp.X-sz/2,0,sp.Y-sz/2)
            local pulse=0.7+math.sin(tick()*3)*0.3
            esp.BackgroundTransparency=0.3+(1-pulse)*0.3
            esp.BorderColor3=Color3.fromRGB(255*pulse,215*pulse,50*pulse)
            if S.espHealth and en.humanoid then
                local h=en.humanoid.Health/en.humanoid.MaxHealth
                esp.BackgroundColor3=Color3.fromRGB(255*(1-h),255*h,50)
            end
            if S.espName then
                local nl=esp:FindFirstChild("NameLabel")or Instance.new("TextLabel",esp)
                nl.Size=UDim2.new(1,0,0,15)
                nl.Position=UDim2.new(0,0,1,0)
                nl.Text=en.player.Name
                nl.TextColor3=Color3.fromRGB(255,255,255)
                nl.TextSize=10
                nl.Font=Enum.Font.SourceSansBold
                nl.BackgroundTransparency=1
                nl.TextStrokeColor3=Color3.fromRGB(255,215,0)
                nl.TextStrokeTransparency=0.5
            end
            if S.espDist then
                local dl=esp:FindFirstChild("DistLabel")or Instance.new("TextLabel",esp)
                dl.Size=UDim2.new(1,0,0,12)
                dl.Position=UDim2.new(0,0,0,-12)
                local dist=(part.Position-Camera.CFrame.Position).Magnitude
                dl.Text=string.format("%.0fм",dist)
                dl.TextColor3=Color3.fromRGB(255,215,0)
                dl.TextSize=9
                dl.Font=Enum.Font.SourceSans
                dl.BackgroundTransparency=1
            end
        end
    end
    for i=#enemies+1,#espObjs do
        pcall(function()espObjs[i]:Destroy()end)
        espObjs[i]=nil
    end
end

local function applyNoRecoil()
    if not S.noRecoil and not S.noSpread then return end
    local char=getChar()
    if not char then return end
    for _,child in pairs(char:GetChildren())do
        if child:IsA("Tool")then
            for _,script in pairs(child:GetDescendants())do
                if script:IsA("Script")or script:IsA("LocalScript")then
                    pcall(function()
                        if S.noRecoil then
                            local rm=script:FindFirstChild("Recoil")
                            if rm then rm.Disabled=true end
                            local rs=script:FindFirstChild("RecoilScript")
                            if rs then rs.Disabled=true end
                        end
                        if S.noSpread then
                            local sm=script:FindFirstChild("Spread")
                            if sm then sm.Disabled=true end
                        end
                    end)
                end
            end
        end
    end
end

local function speedHack()
    local hum=getHumanoid()
    if hum then
        hum.WalkSpeed=S.speed and S.speedVal or 16
    end
end

local flyActive=false
local function updateFly()
    if not S.fly then flyActive=false;return end
    local root=getRoot()
    if not root then return end
    flyActive=true
    local sp=S.flySpeed
    local fwd=Camera.CFrame.LookVector
    local right=Camera.CFrame.RightVector
    local up=Vector3.new(0,1,0)
    local vel=Vector3.new(0,0,0)
    if UserInputService:IsKeyDown(Enum.KeyCode.W)then vel=fwd*sp
    elseif UserInputService:IsKeyDown(Enum.KeyCode.S)then vel=-fwd*sp
    elseif UserInputService:IsKeyDown(Enum.KeyCode.A)then vel=-right*sp
    elseif UserInputService:IsKeyDown(Enum.KeyCode.D)then vel=right*sp
    elseif UserInputService:IsKeyDown(Enum.KeyCode.Space)then vel=up*sp
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)then vel=-up*sp
    else flyVel=flyVel*0.9;root.Velocity=flyVel;return end
    flyVel=vel;root.Velocity=vel;root.CFrame=root.CFrame+vel*0.05
end

UserInputService.JumpRequest:Connect(function()
    if S.jump then
        local hum=getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping)end
    end
end)

local function updateSkin()
    if not S.skin then return end
    local char=getChar()
    if not char then return end
    for _,child in pairs(char:GetChildren())do
        if child:IsA("Tool")then
            for _,part in pairs(child:GetDescendants())do
                if part:IsA("BasePart")then
                    if S.skinSel=="Golden"then
                        part.Color=Color3.fromRGB(255,215,0)
                        part.Material=Enum.Material.SmoothPlastic
                    elseif S.skinSel=="Zeus"then
                        part.Color=Color3.fromRGB(255,215,0)
                        part.Material=Enum.Material.Neon
                        part.Transparency=0.2
                    elseif S.skinSel=="Marble"then
                        part.Color=Color3.fromRGB(220,220,230)
                        part.Material=Enum.Material.SmoothPlastic
                    elseif S.skinSel=="Lightning"then
                        part.Color=Color3.fromRGB(100,150,255)
                        part.Material=Enum.Material.Neon
                    elseif S.skinSel=="Dark"then
                        part.Color=Color3.fromRGB(30,30,35)
                        part.Material=Enum.Material.SmoothPlastic
                    end
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    updateESP()
    applyNoRecoil()
    speedHack()
    if S.fly then updateFly() end
    if S.skin then updateSkin() end
    updateTbot()
    updateAimbot()
end)

-- ========== МЕНЮ ==========
local function createMenu()
    local sg=Instance.new("ScreenGui")
    sg.Name="Belisimus_Menu"
    sg.Parent=CoreGui
    sg.ResetOnSpawn=false
    
    local mf=Instance.new("Frame")
    mf.Parent=sg
    mf.Size=UDim2.new(0,320,0,400)
    mf.Position=UDim2.new(0.5,-160,0.5,-200)
    mf.BackgroundColor3=Color3.fromRGB(20,18,16)
    mf.BackgroundTransparency=0.05
    mf.BorderSizePixel=2
    mf.BorderColor3=Color3.fromRGB(255,215,0)
    mf.ClipsDescendants=true
    mf.Active=true
    mf.Draggable=true
    
    local mc=Instance.new("UICorner")
    mc.Parent=mf
    mc.CornerRadius=UDim.new(0,10)
    
    local glow=Instance.new("Frame")
    glow.Parent=mf
    glow.Size=UDim2.new(1,10,1,10)
    glow.Position=UDim2.new(0,-5,0,-5)
    glow.BackgroundColor3=Color3.fromRGB(255,215,0)
    glow.BackgroundTransparency=0.85
    glow.BorderSizePixel=0
    glow.ZIndex=0
    local gc=Instance.new("UICorner")
    gc.Parent=glow
    gc.CornerRadius=UDim.new(0,14)
    
    local tb=Instance.new("Frame")
    tb.Parent=mf
    tb.Size=UDim2.new(1,0,0,40)
    tb.BackgroundColor3=Color3.fromRGB(15,13,11)
    tb.BackgroundTransparency=0.3
    tb.BorderSizePixel=1
    tb.BorderColor3=Color3.fromRGB(255,215,0)
    
    local icon=Instance.new("TextLabel")
    icon.Parent=tb
    icon.Size=UDim2.new(0,30,0,30)
    icon.Position=UDim2.new(0,8,0,5)
    icon.Text="🏛️"
    icon.TextColor3=Color3.fromRGB(255,215,0)
    icon.TextSize=22
    icon.BackgroundTransparency=1
    icon.Font=Enum.Font.SourceSansBold
    
    local title=Instance.new("TextLabel")
    title.Parent=tb
    title.Size=UDim2.new(1,-80,0,20)
    title.Position=UDim2.new(0,42,0,4)
    title.Text="BELISIMUS"
    title.TextColor3=Color3.fromRGB(255,255,255)
    title.TextSize=16
    title.Font=Enum.Font.SourceSansBold
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.BackgroundTransparency=1
    title.TextStrokeColor3=Color3.fromRGB(255,215,0)
    title.TextStrokeTransparency=0.3
    
    local sub=Instance.new("TextLabel")
    sub.Parent=tb
    sub.Size=UDim2.new(1,-80,0,14)
    sub.Position=UDim2.new(0,42,0,24)
    sub.Text="⚡ Rivals"
    sub.TextColor3=Color3.fromRGB(255,215,0)
    sub.TextSize=10
    sub.Font=Enum.Font.SourceSans
    sub.TextXAlignment=Enum.TextXAlignment.Left
    sub.BackgroundTransparency=1
    
    local function winBtn(text,x,color,cb)
        local btn=Instance.new("TextButton")
        btn.Parent=tb
        btn.Size=UDim2.new(0,22,0,22)
        btn.Position=UDim2.new(1,x,0,9)
        btn.Text=text
        btn.TextColor3=color
        btn.TextSize=14
        btn.Font=Enum.Font.SourceSansBold
        btn.BackgroundTransparency=1
        btn.BorderSizePixel=0
        btn.MouseButton1Click:Connect(cb)
        return btn
    end
    winBtn("_",-52,Color3.fromRGB(255,215,0),function()mf.Visible=false end)
    winBtn("✕",-28,Color3.fromRGB(255,80,80),function()mf.Visible=false end)
    
    local tc=Instance.new("Frame")
    tc.Parent=mf
    tc.Size=UDim2.new(1,0,0,30)
    tc.Position=UDim2.new(0,0,0,40)
    tc.BackgroundColor3=Color3.fromRGB(10,8,6)
    tc.BackgroundTransparency=0.5
    tc.BorderSizePixel=0
    
    local tabs={"🎯A","👁️E","💨M","🎨S","💬D"}
    local tabsFull={"AIM","ESP","MOVE","SKIN","DISCORD"}
    local tabBtns={}
    local curTab="AIM"
    
    for i,t in ipairs(tabs)do
        local btn=Instance.new("TextButton")
        btn.Parent=tc
        btn.Size=UDim2.new(0.2,-4,1,-6)
        btn.Position=UDim2.new((i-1)*0.2,2,0,3)
        btn.Text=t
        btn.TextColor3=Color3.fromRGB(180,170,150)
        btn.TextSize=12
        btn.Font=Enum.Font.SourceSansBold
        btn.BackgroundColor3=Color3.fromRGB(25,20,15)
        btn.BackgroundTransparency=0.7
        btn.BorderSizePixel=1
        btn.BorderColor3=Color3.fromRGB(255,215,0)
        btn.Name=tabsFull[i]
        local bc=Instance.new("UICorner")
        bc.Parent=btn
        bc.CornerRadius=UDim.new(0,4)
        btn.MouseButton1Click:Connect(function()
            for _,b in pairs(tabBtns)do
                TweenService:Create(b,TweenInfo.new(0.2),{BackgroundTransparency=0.7,TextColor3=Color3.fromRGB(180,170,150)}):Play()
            end
            TweenService:Create(btn,TweenInfo.new(0.2),{BackgroundTransparency=0.2,TextColor3=Color3.fromRGB(255,215,0)}):Play()
            curTab=tabsFull[i]
            updateContent(tabsFull[i])
        end)
        table.insert(tabBtns,btn)
    end
    TweenService:Create(tabBtns[1],TweenInfo.new(0.2),{BackgroundTransparency=0.2,TextColor3=Color3.fromRGB(255,215,0)}):Play()
    
    local cf=Instance.new("Frame")
    cf.Parent=mf
    cf.Size=UDim2.new(1,-20,1,-100)
    cf.Position=UDim2.new(0,10,0,78)
    cf.BackgroundTransparency=1
    
    local items={}
    local function clearContent()
        for _,it in pairs(items)do pcall(function()it:Destroy()end)end;items={}
    end
    
    local function addLabel(text,y,c,s,e)
        local fr=Instance.new("Frame")
        fr.Parent=cf
        fr.Size=UDim2.new(1,0,0,22)
        fr.Position=UDim2.new(0,0,0,y)
        fr.BackgroundTransparency=1
        table.insert(items,fr)
        local lbl=Instance.new("TextLabel")
        lbl.Parent=fr
        lbl.Size=UDim2.new(1,0,1,0)
        lbl.Text=(e or"").." "..text
        lbl.TextColor3=c or Color3.fromRGB(255,215,0)
        lbl.TextSize=s or 13
        lbl.Font=Enum.Font.SourceSansBold
        lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.BackgroundTransparency=1
        table.insert(items,lbl)
        return fr
    end
    
    local function addToggle(label,y,get,set,desc)
        local fr=Instance.new("Frame")
        fr.Parent=cf
        fr.Size=UDim2.new(1,0,0,30)
        fr.Position=UDim2.new(0,0,0,y)
        fr.BackgroundTransparency=1
        table.insert(items,fr)
        local lbl=Instance.new("TextLabel")
        lbl.Parent=fr
        lbl.Size=UDim2.new(0.6,-10,0,16)
        lbl.Text=label
        lbl.TextColor3=Color3.fromRGB(220,210,200)
        lbl.TextSize=11
        lbl.Font=Enum.Font.SourceSans
        lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.BackgroundTransparency=1
        table.insert(items,lbl)
        if desc then
            local dl=Instance.new("TextLabel")
            dl.Parent=fr
            dl.Size=UDim2.new(0.6,-10,0,12)
            dl.Position=UDim2.new(0,0,0,16)
            dl.Text=desc
            dl.TextColor3=Color3.fromRGB(150,140,130)
            dl.TextSize=9
            dl.Font=Enum.Font.SourceSans
            dl.TextXAlignment=Enum.TextXAlignment.Left
            dl.BackgroundTransparency=1
            table.insert(items,dl)
        end
        local btn=Instance.new("TextButton")
        btn.Parent=fr
        btn.Size=UDim2.new(0,45,0,20)
        btn.Position=UDim2.new(1,-50,0.5,-10)
        btn.Text=get()and"ON"or"OFF"
        btn.TextColor3=get()and Color3.fromRGB(255,215,0)or Color3.fromRGB(255,80,80)
        btn.TextSize=10
        btn.Font=Enum.Font.SourceSansBold
        btn.BackgroundColor3=get()and Color3.fromRGB(50,40,15)or Color3.fromRGB(50,15,15)
        btn.BorderSizePixel=1
        btn.BorderColor3=get()and Color3.fromRGB(255,215,0)or Color3.fromRGB(255,80,80)
        local bc=Instance.new("UICorner")
        bc.Parent=btn
        bc.CornerRadius=UDim.new(0,4)
        table.insert(items,btn)
        btn.MouseButton1Click:Connect(function()
            local nv=not get();set(nv)
            btn.Text=nv and"ON"or"OFF"
            btn.TextColor3=nv and Color3.fromRGB(255,215,0)or Color3.fromRGB(255,80,80)
            btn.BackgroundColor3=nv and Color3.fromRGB(50,40,15)or Color3.fromRGB(50,15,15)
            btn.BorderColor3=nv and Color3.fromRGB(255,215,0)or Color3.fromRGB(255,80,80)
        end)
        return fr
    end
    
    local function addSlider(label,y,minv,maxv,get,set,fmt,col)
        local fr=Instance.new("Frame")
        fr.Parent=cf
        fr.Size=UDim2.new(1,0,0,38)
        fr.Position=UDim2.new(0,0,0,y)
        fr.BackgroundTransparency=1
        table.insert(items,fr)
        local lbl=Instance.new("TextLabel")
        lbl.Parent=fr
        lbl.Size=UDim2.new(0.7,0,0,16)
        lbl.Text=label..": "..(fmt and fmt(get())or tostring(math.round(get())))
        lbl.TextColor3=Color3.fromRGB(220,210,200)
        lbl.TextSize=11
        lbl.Font=Enum.Font.SourceSans
        lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.BackgroundTransparency=1
        table.insert(items,lbl)
        local sf=Instance.new("Frame")
        sf.Parent=fr
        sf.Size=UDim2.new(1,0,0,4)
        sf.Position=UDim2.new(0,0,0,24)
        sf.BackgroundColor3=Color3.fromRGB(30,25,20)
        sf.BorderSizePixel=1
        sf.BorderColor3=Color3.fromRGB(255,215,0)
        local sc=Instance.new("UICorner")
        sc.Parent=sf
        sc.CornerRadius=UDim.new(0,2)
        table.insert(items,sf)
        local fc=col or Color3.fromRGB(255,215,0)
        local fill=Instance.new("Frame")
        fill.Parent=sf
        fill.Size=UDim2.new((get()-minv)/(maxv-minv),0,1,0)
        fill.BackgroundColor3=fc
        fill.BorderSizePixel=0
        local fcc=Instance.new("UICorner")
        fcc.Parent=fill
        fcc.CornerRadius=UDim.new(0,2)
        table.insert(items,fill)
        local sb=Instance.new("TextButton")
        sb.Parent=sf
        sb.Size=UDim2.new(0,12,0,12)
        sb.Position=UDim2.new((get()-minv)/(maxv-minv),-6,0,-4)
        sb.BackgroundColor3=Color3.fromRGB(255,215,0)
        sb.BorderSizePixel=1
        sb.BorderColor3=Color3.fromRGB(255,255,255)
        sb.Text=""
        local sbc=Instance.new("UICorner")
        sbc.Parent=sb
        sbc.CornerRadius=UDim.new(0,6)
        table.insert(items,sb)
        local drag=false
        sb.MouseButton1Down:Connect(function()drag=true end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
        end)
        RunService.Heartbeat:Connect(function()
            if not drag then return end
            local pos=UserInputService:GetMouseLocation()
            local fp=sf.AbsolutePosition
            local fs=sf.AbsoluteSize.X
            if fs==0 then return end
            local pct=math.clamp((pos.X-fp.X)/fs,0,1)
            local val=minv+(maxv-minv)*pct
            set(val)
            fill.Size=UDim2.new(pct,0,1,0)
            sb.Position=UDim2.new(pct,-6,0,-4)
            lbl.Text=label..": "..(fmt and fmt(val)or tostring(math.round(val)))
        end)
        return fr
    end
    
    local function addKeybind(label,y,get,set,desc)
        local fr=Instance.new("Frame")
        fr.Parent=cf
        fr.Size=UDim2.new(1,0,0,34)
        fr.Position=UDim2.new(0,0,0,y)
        fr.BackgroundTransparency=1
        table.insert(items,fr)
        local lbl=Instance.new("TextLabel")
        lbl.Parent=fr
        lbl.Size=UDim2.new(0.5,-10,0,16)
        lbl.Text=label
        lbl.TextColor3=Color3.fromRGB(220,210,200)
        lbl.TextSize=11
        lbl.Font=Enum.Font.SourceSans
        lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.BackgroundTransparency=1
        table.insert(items,lbl)
        if desc then
            local dl=Instance.new("TextLabel")
            dl.Parent=fr
            dl.Size=UDim2.new(0.5,-10,0,12)
            dl.Position=UDim2.new(0,0,0,16)
            dl.Text=desc
            dl.TextColor3=Color3.fromRGB(150,140,130)
            dl.TextSize=9
            dl.Font=Enum.Font.SourceSans
            dl.TextXAlignment=Enum.TextXAlignment.Left
            dl.BackgroundTransparency=1
            table.insert(items,dl)
        end
        local btn=Instance.new("TextButton")
        btn.Parent=fr
        btn.Size=UDim2.new(0,80,0,22)
        btn.Position=UDim2.new(1,-85,0.5,-11)
        btn.Text=getKeyName(get())
        btn.TextColor3=Color3.fromRGB(255,215,0)
        btn.TextSize=10
        btn.Font=Enum.Font.SourceSansBold
        btn.BackgroundColor3=Color3.fromRGB(30,25,20)
        btn.BorderSizePixel=1
        btn.BorderColor3=Color3.fromRGB(255,215,0)
        local bc=Instance.new("UICorner")
        bc.Parent=btn
        bc.CornerRadius=UDim.new(0,4)
        table.insert(items,btn)
        local listen=false
        btn.MouseButton1Click:Connect(function()
            listen=true;btn.Text="...";btn.TextColor3=Color3.fromRGB(255,255,100)
            local conn
            conn=UserInputService.InputBegan:Connect(function(inp)
                if listen then
                    local kn=nil
                    if inp.UserInputType==Enum.UserInputType.MouseButton2 then kn="MouseButton2"
                    elseif inp.UserInputType==Enum.UserInputType.MouseButton1 then kn="MouseButton1"
                    elseif inp.UserInputType==Enum.UserInputType.MouseButton3 then kn="MouseButton3"
                    elseif inp.UserInputType==Enum.UserInputType.Keyboard then
                        kn=tostring(inp.KeyCode):gsub("Enum.KeyCode.","")
                    end
                    if kn then
                        listen=false;set(kn)
                        btn.Text=getKeyName(kn);btn.TextColor3=Color3.fromRGB(255,215,0)
                        conn:Disconnect()
                    end
                end
            end)
            task.wait(5)
            if listen then
                listen=false;btn.Text=getKeyName(get());btn.TextColor3=Color3.fromRGB(255,215,0)
                conn:Disconnect()
            end
        end)
        return fr
    end
    
    local function openDiscord()
        pcall(function()HttpService:OpenBrowser(DISCORD)end)
    end
    
    function updateContent(tab)
        clearContent()
        local y=4
        
        if tab=="AIM" then
            addLabel("⚡ ПРИЦЕЛ",y,Color3.fromRGB(255,215,0),14)
            y=y+26
            addToggle("Silent Aim",y,function()return S.silentAim end,function(v)S.silentAim=v end)
            y=y+34
            addSlider("FOV",y,30,360,function()return S.silentAimFOV end,function(v)S.silentAimFOV=v end,function(v)return math.round(v).."°"end)
            y=y+42
            addLabel("━ AIMBOT ━",y,Color3.fromRGB(200,180,150),11)
            y=y+24
            addToggle("AimBot",y,function()return S.aimbot end,function(v)S.aimbot=v end)
            y=y+34
            addSlider("Плавность",y,1,10,function()return S.aimbotSmooth end,function(v)S.aimbotSmooth=v end,function(v)return string.format("%.1fс",v)end,Color3.fromRGB(255,200,50))
            y=y+42
            addSlider("FOV",y,30,360,function()return S.aimbotFOV end,function(v)S.aimbotFOV=v end,function(v)return math.round(v).."°"end)
            y=y+42
            addKeybind("Клавиша",y,function()return S.aimKey end,function(v)S.aimKey=v end)
            y=y+38
            addToggle("Lock",y,function()return S.aimLock end,function(v)S.aimLock=v end)
            y=y+34
            addLabel("━ TRIGGER ━",y,Color3.fromRGB(200,180,150),11)
            y=y+24
            addToggle("TriggerBot",y,function()return S.tbot end,function(v)S.tbot=v end)
            y=y+34
            addKeybind("Клавиша",y,function()return S.tbotKey end,function(v)S.tbotKey=v end)
            y=y+38
            addSlider("Задержка",y,0.01,0.5,function()return S.tbotDelay end,function(v)S.tbotDelay=v end,function(v)return string.format("%.2fс",v)end)
            y=y+42
            addToggle("Только голова",y,function()return S.tbotHead end,function(v)S.tbotHead=v end)
            
        elseif tab=="ESP" then
            addLabel("👁️ ESP",y,Color3.fromRGB(255,215,0),14)
            y=y+26
            addToggle("ESP",y,function()return S.esp end,function(v)S.esp=v end)
            y=y+34
            addToggle("Имена",y,function()return S.espName end,function(v)S.espName=v end)
            y=y+34
            addToggle("Дистанция",y,function()return S.espDist end,function(v)S.espDist=v end)
            y=y+34
            addToggle("Здоровье",y,function()return S.espHealth end,function(v)S.espHealth=v end)
            
        elseif tab=="MOVE" then
            addLabel("💨 ДВИЖЕНИЕ",y,Color3.fromRGB(255,215,0),14)
            y=y+26
            addToggle("No Recoil",y,function()return S.noRecoil end,function(v)S.noRecoil=v end)
            y=y+34
            addToggle("No Spread",y,function()return S.noSpread end,function(v)S.noSpread=v end)
            y=y+34
            addToggle("Speed",y,function()return S.speed end,function(v)S.speed=v end)
            y=y+34
            addSlider("Скорость",y,20,80,function()return S.speedVal end,function(v)S.speedVal=v end,function(v)return math.round(v).."ед"end)
            y=y+42
            addToggle("Fly",y,function()return S.fly end,function(v)S.fly=v end)
            y=y+34
            addSlider("Скорость Fly",y,20,150,function()return S.flySpeed end,function(v)S.flySpeed=v end,function(v)return math.round(v).."ед"end)
            y=y+42
            addToggle("Inf Jump",y,function()return S.jump end,function(v)S.jump=v end)
            
        elseif tab=="SKIN" then
            addLabel("🎨 СКИНЫ",y,Color3.fromRGB(255,215,0),14)
            y=y+26
            addToggle("Skin Changer",y,function()return S.skin end,function(v)S.skin=v end)
            y=y+34
            local skins={"Golden","Zeus","Marble","Lightning","Dark"}
            for i,sk in ipairs(skins)do
                local btn=Instance.new("TextButton")
                btn.Parent=cf
                btn.Size=UDim2.new(0.45,-4,0,24)
                btn.Position=UDim2.new((i%2==1 and 0 or 0.55),0,0,y+math.floor((i-1)/2)*28)
                btn.Text=sk
                btn.TextColor3=Color3.fromRGB(255,255,255)
                btn.TextSize=10
                btn.Font=Enum.Font.SourceSansBold
                local colors={Golden=Color3.fromRGB(255,215,0),Zeus=Color3.fromRGB(255,215,0),Marble=Color3.fromRGB(220,220,230),Lightning=Color3.fromRGB(100,150,255),Dark=Color3.fromRGB(30,30,35)}
                btn.BackgroundColor3=colors[sk]
                btn.BackgroundTransparency=0.3
                btn.BorderSizePixel=1
                btn.BorderColor3=S.skinSel==sk and Color3.fromRGB(255,215,0)or Color3.fromRGB(80,80,80)
                local bc=Instance.new("UICorner")
                bc.Parent=btn
                bc.CornerRadius=UDim.new(0,4)
                table.insert(items,btn)
                btn.MouseButton1Click:Connect(function()
                    S.skinSel=sk
                    for _,ch in pairs(cf:GetChildren())do
                        if ch:IsA("TextButton")and ch.Text~=""then
                            ch.BorderColor3=ch.Text==sk and Color3.fromRGB(255,215,0)or Color3.fromRGB(80,80,80)
                        end
                    end
                end)
            end
            y=y+90
            
        elseif tab=="DISCORD" then
            addLabel("💬 DISCORD",y,Color3.fromRGB(255,215,0),14)
            y=y+28
            addLabel("Belisimus",y,Color3.fromRGB(255,255,255),13)
            y=y+22
            addLabel("👥 8 участников • 7 в сети",y,Color3.fromRGB(180,180,200),11)
            y=y+24
            local lf=Instance.new("Frame")
            lf.Parent=cf
            lf.Size=UDim2.new(1,0,0,28)
            lf.Position=UDim2.new(0,0,0,y)
            lf.BackgroundColor3=Color3.fromRGB(30,25,20)
            lf.BackgroundTransparency=0.5
            lf.BorderSizePixel=1
            lf.BorderColor3=Color3.fromRGB(255,215,0)
            local lc=Instance.new("UICorner")
            lc.Parent=lf
            lc.CornerRadius=UDim.new(0,4)
            table.insert(items,lf)
            local ll=Instance.new("TextLabel")
            ll.Parent=lf
            ll.Size=UDim2.new(0.6,-5,1,0)
            ll.Position=UDim2.new(0,5,0,0)
            ll.Text=DISCORD
            ll.TextColor3=Color3.fromRGB(100,200,255)
            ll.TextSize=9
            ll.Font=Enum.Font.SourceSans
            ll.TextXAlignment=Enum.TextXAlignment.Left
            ll.BackgroundTransparency=1
            table.insert(items,ll)
            local cb=Instance.new("TextButton")
            cb.Parent=lf
            cb.Size=UDim2.new(0,45,0,18)
            cb.Position=UDim2.new(1,-50,0.5,-9)
            cb.Text="📋Копи"
            cb.TextColor3=Color3.fromRGB(255,215,0)
            cb.TextSize=8
            cb.Font=Enum.Font.SourceSansBold
            cb.BackgroundColor3=Color3.fromRGB(40,35,30)
            cb.BorderSizePixel=1
            cb.BorderColor3=Color3.fromRGB(255,215,0)
            local cbc=Instance.new("UICorner")
            cbc.Parent=cb
            cbc.CornerRadius=UDim.new(0,3)
            table.insert(items,cb)
            cb.MouseButton1Click:Connect(function()
                pcall(function()setclipboard(DISCORD)end)
            end)
            y=y+36
            local ob=Instance.new("TextButton")
            ob.Parent=cf
            ob.Size=UDim2.new(0.8,0,0,30)
            ob.Position=UDim2.new(0.1,0,0,y)
            ob.Text="🌐 ОТКРЫТЬ"
            ob.TextColor3=Color3.fromRGB(255,255,255)
            ob.TextSize=12
            ob.Font=Enum.Font.SourceSansBold
            ob.BackgroundColor3=Color3.fromRGB(88,101,242)
            ob.BorderSizePixel=0
            local obc=Instance.new("UICorner")
            obc.Parent=ob
            obc.CornerRadius=UDim.new(0,6)
            table.insert(items,ob)
            ob.MouseButton1Click:Connect(openDiscord)
            ob.MouseEnter:Connect(function()
                TweenService:Create(ob,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(108,121,262)}):Play()
            end)
            ob.MouseLeave:Connect(function()
                TweenService:Create(ob,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(88,101,242)}):Play()
            end)
        end
    end
    
    UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode==Enum.KeyCode.RightShift then
            mf.Visible=not mf.Visible
        end
    end)
    
    updateContent("AIM")
    return mf
end

print("🏛️ BELISIMUS загружен! Right Shift - меню")
print("💬 "..DISCORD)
createMenu()
