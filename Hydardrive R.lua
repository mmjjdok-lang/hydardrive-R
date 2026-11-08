--[[
    OceanUI  |  Roblox Lua UI Library
    Window 586x339 | single-finger heavy drag | water-drop ripple | 5D glass look
    Systems: Window, OpenButton, Button, Toggle(+Slider), Slider, Tab, Notify, KeySystem(+HTML site),
             ColorPicker, Textbox, Dropdown(+search), Floating buttons (30 shapes), Config saving
]]
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local CoreGui=game:GetService("CoreGui")
local Debris=game:GetService("Debris")
local LP=Players.LocalPlayer

local Lib={Version="1.0.0"}
local WHITE,BLACK=Color3.new(1,1,1),Color3.new(0,0,0)
local PURPLE,PINK=Color3.fromRGB(150,70,255),Color3.fromRGB(255,80,200)
local ES,ED=Enum.EasingStyle,Enum.EasingDirection
local FONT,FONT_B,FONT_X=Enum.Font.Gotham,Enum.Font.GothamBold,Enum.Font.GothamBlack
local LEFT,RIGHT,CENTER=Enum.TextXAlignment.Left,Enum.TextXAlignment.Right,Enum.TextXAlignment.Center
local FULL=UDim2.fromScale(1,1)
local ICON_URL="https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/solar/dist/Icons.lua"

------------------------------------------------------------------ helpers
local function new(class,props,kids)
	local o=Instance.new(class)
	local parent
	for k,v in pairs(props or {}) do if k=="Parent" then parent=v else o[k]=v end end
	for _,c in ipairs(kids or {}) do c.Parent=o end
	if parent then o.Parent=parent end
	return o
end
local function corner(o,r) return new("UICorner",{CornerRadius=r or UDim.new(0,8),Parent=o}) end
local function stroke(o,c,t,tr) return new("UIStroke",{Color=c or WHITE,Thickness=t or 1,Transparency=tr or .8,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Parent=o}) end
local function tween(o,t,p,s,d) local tw=TweenService:Create(o,TweenInfo.new(t,s or ES.Quint,d or ED.Out),p) tw:Play() return tw end
local function loop(o,t,p,s,rev) TweenService:Create(o,TweenInfo.new(t,s or ES.Linear,ED.InOut,-1,rev or false),p):Play() end
local function isPress(i) return i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 end
local function isMove(active,i) return i==active or (active.UserInputType==Enum.UserInputType.MouseButton1 and i.UserInputType==Enum.UserInputType.MouseMovement) end
local function lbl(p,t,sz,pos,siz,o)
	o=o or {}
	return new("TextLabel",{BackgroundTransparency=1,Text=t,TextSize=sz,Font=o.Font or FONT,TextColor3=o.Color or WHITE,Position=pos,Size=siz,TextXAlignment=o.Align or LEFT,TextTruncate=Enum.TextTruncate.AtEnd,Parent=p})
end
local function enc(v)
	if typeof(v)=="Color3" then return {__c={math.floor(v.R*255+.5),math.floor(v.G*255+.5),math.floor(v.B*255+.5)}} end
	if type(v)=="table" then local r={} for k,x in pairs(v) do r[k]=enc(x) end return r end
	return v
end
local function dec(v)
	if type(v)=="table" then
		if v.__c then return Color3.fromRGB(v.__c[1],v.__c[2],v.__c[3]) end
		local r={} for k,x in pairs(v) do r[k]=dec(x) end return r
	end
	return v
end
local function copy(t) local r={} for k,v in pairs(t) do r[k]=type(v)=="table" and copy(v) or v end return r end

-- water-drop ripple (filled wave + two rings)
local function ripple(parent,x,y,col)
	local ap=parent.AbsolutePosition
	local m=math.max(parent.AbsoluteSize.X,parent.AbsoluteSize.Y)*1.5+20
	local pos=UDim2.fromOffset(x-ap.X,y-ap.Y)
	local z=parent.ZIndex+3
	local fill=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=pos,Size=UDim2.fromOffset(0,0),BackgroundColor3=col or WHITE,BackgroundTransparency=.7,BorderSizePixel=0,ZIndex=z,Parent=parent})
	new("UICorner",{CornerRadius=UDim.new(1,0),Parent=fill})
	tween(fill,.75,{Size=UDim2.fromOffset(m,m),BackgroundTransparency=1})
	Debris:AddItem(fill,.9)
	for k=0,1 do
		task.delay(k*.12,function()
			if not parent.Parent then return end
			local ring=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=pos,Size=UDim2.fromOffset(0,0),BackgroundTransparency=1,ZIndex=z,Parent=parent})
			new("UICorner",{CornerRadius=UDim.new(1,0),Parent=ring})
			local rs=new("UIStroke",{Color=col or WHITE,Thickness=2-k*.7,Transparency=.35,Parent=ring})
			tween(ring,.9,{Size=UDim2.fromOffset(m*(.7-k*.2),m*(.7-k*.2))},ES.Sine)
			tween(rs,.9,{Transparency=1})
			Debris:AddItem(ring,1)
		end)
	end
end

-- generic drag-on-frame (value slider / color areas): follows only the finger that started it
local function slideDrag(frame,onMove,onEnd)
	local active
	frame.InputBegan:Connect(function(i)
		if isPress(i) and not active then
			active=i; onMove(i.Position)
			i.Changed:Connect(function()
				if i.UserInputState==Enum.UserInputState.End and active==i then active=nil if onEnd then onEnd() end end
			end)
		end
	end)
	local c=UIS.InputChanged:Connect(function(i) if active and isMove(active,i) then onMove(i.Position) end end)
	frame.Destroying:Connect(function() c:Disconnect() end)
end

-- heavy drag for window: one finger only, smooth lerp
local function heavyDrag(handle,target,onStart,onEnd)
	local active,start,spos,goal
	handle.InputBegan:Connect(function(i)
		if isPress(i) and not active then
			active,start,spos=i,i.Position,target.Position; goal=spos
			if onStart then onStart(i) end
			i.Changed:Connect(function()
				if i.UserInputState==Enum.UserInputState.End and active==i then active=nil if onEnd then onEnd() end end
			end)
		end
	end)
	local c1=UIS.InputChanged:Connect(function(i)
		if active and isMove(active,i) then
			local d=i.Position-start
			goal=UDim2.new(spos.X.Scale,spos.X.Offset+d.X,spos.Y.Scale,spos.Y.Offset+d.Y)
		end
	end)
	local c2=RunService.RenderStepped:Connect(function(dt)
		if goal then
			target.Position=target.Position:Lerp(goal,math.clamp(dt*7,0,1)) -- heavy feel
			if not active and (target.Position.X.Offset-goal.X.Offset)^2+(target.Position.Y.Offset-goal.Y.Offset)^2<.5 then target.Position=goal goal=nil end
		end
	end)
	target.Destroying:Connect(function() c1:Disconnect() c2:Disconnect() end)
end

-- small draggable-or-click object (floating buttons / open button)
local function dragClick(f,onClick,canDrag,onEnd)
	local sc=f:FindFirstChildOfClass("UIScale") or new("UIScale",{Parent=f})
	local act,start,spos,moved
	f.InputBegan:Connect(function(i)
		if isPress(i) and not act then
			act,start,spos,moved=i,i.Position,f.Position,0
			ripple(f,i.Position.X,i.Position.Y)
			tween(sc,.12,{Scale=.9})
			i.Changed:Connect(function()
				if i.UserInputState==Enum.UserInputState.End and act==i then
					act=nil; tween(sc,.4,{Scale=1},ES.Back)
					if moved<8 then onClick() elseif onEnd then onEnd() end
				end
			end)
		end
	end)
	local c=UIS.InputChanged:Connect(function(i)
		if act and isMove(act,i) then
			local d=i.Position-start; moved=math.max(moved,d.Magnitude)
			if moved>=8 and canDrag() then f.Position=UDim2.new(spos.X.Scale,spos.X.Offset+d.X,spos.Y.Scale,spos.Y.Offset+d.Y) end
		end
	end)
	f.Destroying:Connect(function() c:Disconnect() end)
end

------------------------------------------------------------------ icons
local Icons
pcall(function() Icons=loadstring(game:HttpGet(ICON_URL))() end)
local function setIcon(img,name)
	if not name or name=="" then return false end
	name=tostring(name)
	if name:match("^%d+$") then img.Image="rbxassetid://"..name return true end
	if name:find("rbxassetid") then img.Image=name return true end
	if Icons then
		for _,n in ipairs({name,name:gsub("^solar:","")}) do
			if type(n)=="string" then
				for _,args in ipairs({{n,"solar"},{n}}) do
					local ok,res=pcall(function() return Icons.Icon(unpack(args)) end)
					if ok and type(res)=="table" and res[1] then
						img.Image=res[1]
						if type(res[2])=="table" then img.ImageRectOffset=res[2].ImageRectPosition or Vector2.zero img.ImageRectSize=res[2].ImageRectSize or Vector2.zero end
						return true
					end
				end
			end
		end
	end
	return false
end

------------------------------------------------------------------ data
local ColorList={{"Purple",150,70,255},{"Pink",255,80,200},{"Violet",110,60,220},{"Magenta",230,40,170},{"Rose",255,100,140},{"Red",230,50,50},{"Crimson",170,20,60},{"Orange",255,140,40},{"Amber",255,180,30},{"Gold",230,190,60},{"Yellow",250,230,60},{"Lime",150,230,50},{"Green",50,200,90},{"Emerald",20,170,120},{"Mint",110,240,190},{"Teal",20,170,170},{"Cyan",40,220,240},{"Sky",110,190,255},{"Blue",50,110,255},{"Royal",60,70,200},{"Indigo",80,50,180},{"Navy",25,40,110},{"Lavender",180,150,240},{"Peach",255,190,150},{"Coral",255,110,90},{"Brown",130,85,50},{"Silver",190,195,205},{"Slate",90,100,120},{"Black",25,25,30},{"White",240,240,245}}
Lib.Colors,Lib.ColorNames={},{}
for _,c in ipairs(ColorList) do Lib.Colors[c[1]]=Color3.fromRGB(c[2],c[3],c[4]) table.insert(Lib.ColorNames,c[1]) end

-- {name, corner scale, width multiplier, rotation}  (30 shapes)
local Shapes={{"Circle",.5,1,0},{"Square",0,1,0},{"Soft Square",.18,1,0},{"Rounded",.3,1,0},{"Squircle",.4,1,0},
{"Pill",.5,1.8,0},{"Tall Pill",.5,.55,0},{"Wide",.2,1.5,0},{"Tall",.2,.7,0},{"Wide Sharp",0,1.5,0},
{"Tall Sharp",0,.7,0},{"Diamond",0,1,45},{"Round Diamond",.3,1,45},{"Soft Diamond",.15,1,45},{"Tilt Left",.25,1,-12},
{"Tilt Right",.25,1,12},{"Tilt Pill",.5,1.6,-8},{"Ticket",.1,1.7,0},{"Banner",.12,2.2,0},{"Bar",.5,2.6,0},
{"Oval",.5,1.4,0},{"Tall Oval",.5,.7,0},{"Tab",.22,1.3,0},{"Badge",.35,1.15,0},{"Stamp",.08,1,0},
{"Ruby",.25,1,45},{"Flat Pill",.5,2.2,0},{"Slim Tall",.35,.45,0},{"Wide Round",.45,1.4,0},{"Blob",.45,1.1,-6}}
Lib.ShapeNames,Lib.ShapeIndex={},{}
for i,s in ipairs(Shapes) do table.insert(Lib.ShapeNames,s[1]) Lib.ShapeIndex[s[1]]=i end

Lib.EasingStyles={}
for _,e in ipairs(Enum.EasingStyle:GetEnumItems()) do table.insert(Lib.EasingStyles,e.Name) end

------------------------------------------------------------------ notify
local NotifyGui,NotifyHosts
local NPos={TopLeft={0,0,0,0,"Top","Left"},TopRight={1,0,1,0,"Top","Right"},TopCenter={.5,0,.5,0,"Top","Center"},
	BottomLeft={0,1,0,1,"Bottom","Left"},BottomRight={1,1,1,1,"Bottom","Right"},BottomCenter={.5,1,.5,1,"Bottom","Center"},Center={.5,.5,.5,.5,"Center","Center"}}
local function guiParent() return (gethui and gethui()) or CoreGui end

function Lib:Notify(o)
	o=o or {}
	local pn=NPos[o.Position or "TopRight"] and (o.Position or "TopRight") or "TopRight"
	local P=NPos[pn]
	if not NotifyGui or not NotifyGui.Parent then
		NotifyGui=new("ScreenGui",{Name="OceanUI_Notify",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=guiParent()})
		NotifyHosts={}
	end
	local host=NotifyHosts[pn]
	if not host then
		host=new("Frame",{AnchorPoint=Vector2.new(P[1],P[2]),Position=UDim2.new(P[3],P[1]==0 and 12 or (P[1]==1 and -12 or 0),P[4],P[2]==0 and 12 or (P[2]==1 and -12 or 0)),Size=UDim2.new(0,270,1,-24),BackgroundTransparency=1,Parent=NotifyGui})
		new("UIListLayout",{Padding=UDim.new(0,6),VerticalAlignment=Enum.VerticalAlignment[P[5]],HorizontalAlignment=Enum.HorizontalAlignment[P[6]],SortOrder=Enum.SortOrder.LayoutOrder,Parent=host})
		NotifyHosts[pn]=host
	end
	local accent=o.Color or PURPLE
	local t=o.Time or 4
	local wrap=new("Frame",{Size=UDim2.new(0,260,0,0),BackgroundTransparency=1,ClipsDescendants=false,Parent=host})
	tween(wrap,.3,{Size=UDim2.new(0,260,0,70)},ES.Back)
	local side=(P[1]==1) and 1 or -1
	local card=new("Frame",{Position=UDim2.new(side*1.3,0,0,0),Size=UDim2.new(1,0,0,70),BackgroundColor3=Color3.fromRGB(16,12,28),BackgroundTransparency=.2,ClipsDescendants=true,Parent=wrap})
	corner(card,UDim.new(0,10)); stroke(card,accent,1.5,.3)
	new("UIGradient",{Rotation=0,Color=ColorSequence.new(accent:Lerp(BLACK,.55),Color3.fromRGB(14,10,24)),Parent=card})
	local ic=new("ImageLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(10,14),Size=UDim2.fromOffset(32,32),ImageColor3=accent,Parent=card})
	if not setIcon(ic,o.Icon) then ic:Destroy() lbl(card,"🔔",24,UDim2.fromOffset(10,14),UDim2.fromOffset(32,32),{Align=CENTER}) end
	lbl(card,o.Title or "Notification",14,UDim2.fromOffset(52,8),UDim2.new(1,-60,0,18),{Font=FONT_B})
	local m=lbl(card,o.Message or "",12,UDim2.fromOffset(52,28),UDim2.new(1,-60,0,34),{Color=Color3.fromRGB(190,190,205)})
	m.TextWrapped=true; m.TextYAlignment=Enum.TextYAlignment.Top; m.TextTruncate=Enum.TextTruncate.None
	local bar=new("Frame",{Position=UDim2.new(0,0,1,-3),Size=UDim2.new(1,0,0,3),BackgroundColor3=accent,BorderSizePixel=0,Parent=card})
	tween(card,.5,{Position=UDim2.new()},ES.Back)
	tween(bar,t,{Size=UDim2.new(0,0,0,3)},ES.Linear)
	task.delay(t,function()
		tween(card,.4,{Position=UDim2.new(side*1.3,0,0,0)},ES.Back,ED.In)
		task.wait(.4)
		tween(wrap,.25,{Size=UDim2.new(0,260,0,0)})
		task.wait(.3) wrap:Destroy()
	end)
end

------------------------------------------------------------------ key system
function Lib.FetchKey(url)
	local ok,body=pcall(function() return game:HttpGet(url) end)
	if not ok or type(body)~="string" then return nil end
	local k=body:match('<meta[^>]-name=["\']ocean%-key["\'][^>]-content=["\']([^"\']+)["\']')
		or body:match('<meta[^>]-content=["\']([^"\']+)["\'][^>]-name=["\']ocean%-key["\']')
		or body:match('id=["\']ocean%-key["\'][^>]*>%s*([^<%s][^<]-)%s*<')
		or body:match('data%-ocean%-key=["\']([^"\']+)["\']')
	if not k then
		local t=body:match("^%s*(.-)%s*$")
		if t~="" and #t<=100 and not t:find("<") then k=t end
	end
	return k
end

function Lib:KeySystem(o)
	o=o or {}
	local accent=o.Color or PURPLE
	local folder=o.Folder or "OceanUI"
	local keyFile=folder.."/key_"..tostring(o.Title or "key"):gsub("[^%w]","_")..".txt"
	local function valid(k)
		if not k or k=="" then return false end
		local list=type(o.Key)=="table" and o.Key or {o.Key}
		for _,x in ipairs(list) do if x and k==x then return true end end
		if o.Url then local f=Lib.FetchKey(o.Url) if f and f==k then return true end end
		return false
	end
	if readfile and isfile and isfile(keyFile) then
		local ok,saved=pcall(readfile,keyFile)
		if ok and valid(saved) then if o.Callback then pcall(o.Callback) end return true end
	end
	local result
	local ev=Instance.new("BindableEvent")
	local gui=new("ScreenGui",{Name="OceanUI_Key",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1001,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=guiParent()})
	local f=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(330,230),BackgroundColor3=WHITE,BackgroundTransparency=.15,ClipsDescendants=true,Parent=gui})
	corner(f,UDim.new(0,14))
	new("UIGradient",{Rotation=90,Color=ColorSequence.new(accent:Lerp(BLACK,.45),accent:Lerp(BLACK,.85)),Parent=f})
	local st=stroke(f,WHITE,2,0)
	local sg=new("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,PURPLE),ColorSequenceKeypoint.new(.5,PINK),ColorSequenceKeypoint.new(1,PURPLE)}),Parent=st})
	local sc=new("UIScale",{Scale=0,Parent=f})
	tween(sc,.6,{Scale=1},ES.Back)
	local conn=RunService.RenderStepped:Connect(function() sg.Rotation=(os.clock()*40)%360 end)
	local ic=new("ImageLabel",{BackgroundTransparency=1,Position=UDim2.new(.5,-20,0,12),Size=UDim2.fromOffset(40,40),ImageColor3=WHITE,Parent=f})
	if not setIcon(ic,o.Icon) then ic:Destroy() lbl(f,"🔑",32,UDim2.new(.5,-20,0,10),UDim2.fromOffset(40,40),{Align=CENTER}) end
	lbl(f,o.Title or "Key System",17,UDim2.fromOffset(0,56),UDim2.new(1,0,0,22),{Font=FONT_B,Align=CENTER})
	local status=lbl(f,o.Subtitle or "Enter your key to continue",12,UDim2.fromOffset(0,78),UDim2.new(1,0,0,16),{Color=Color3.fromRGB(190,190,205),Align=CENTER})
	local tb=new("TextBox",{Position=UDim2.fromOffset(20,102),Size=UDim2.new(1,-40,0,32),BackgroundColor3=BLACK,BackgroundTransparency=.5,PlaceholderText="Paste key here...",PlaceholderColor3=Color3.fromRGB(140,140,155),Text="",ClearTextOnFocus=false,Font=FONT,TextSize=13,TextColor3=WHITE,Parent=f})
	corner(tb,UDim.new(0,8)); stroke(tb,accent,1.2,.4)
	local function btn(text,x,w,y,col,cb)
		local b=new("TextButton",{Text=text,Font=FONT_B,TextSize=12,TextColor3=WHITE,BackgroundColor3=col,BackgroundTransparency=.15,AutoButtonColor=false,Position=UDim2.new(0,x,0,y),Size=UDim2.new(0,w,0,30),ClipsDescendants=true,Parent=f})
		corner(b,UDim.new(0,8))
		b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i.Position.X,i.Position.Y) end end)
		b.Activated:Connect(cb) return b
	end
	local function shake()
		for k=1,6 do tween(f,.04,{Position=UDim2.new(.5,(k%2==0 and 8 or -8),.5,0)}) task.wait(.045) end
		tween(f,.1,{Position=UDim2.fromScale(.5,.5)})
	end
	local function close(ok)
		result=ok; conn:Disconnect()
		tween(sc,.4,{Scale=0},ES.Back,ED.In); task.wait(.45) gui:Destroy() ev:Fire()
	end
	local function check(k)
		if valid(k) then
			status.Text="Key accepted!"; status.TextColor3=Color3.fromRGB(90,230,130)
			if writefile then pcall(function() if makefolder and isfolder and not isfolder(folder) then makefolder(folder) end writefile(keyFile,k) end) end
			task.spawn(function() task.wait(.5) close(true) if o.Callback then pcall(o.Callback) end end)
		else
			status.Text="Invalid key"; status.TextColor3=Color3.fromRGB(255,90,90); task.spawn(shake)
		end
	end
	btn("Get Key",20,90,146,accent,function()
		if o.Url and setclipboard then setclipboard(o.Url) status.Text="Link copied!" status.TextColor3=WHITE
		else status.Text=o.Url or "No link set" end
	end)
	btn("Auto Fetch",120,90,146,Color3.fromRGB(40,110,200),function()
		if not o.Url then status.Text="No site set" return end
		status.Text="Fetching..."; status.TextColor3=WHITE
		task.spawn(function()
			local k=Lib.FetchKey(o.Url)
			if k then tb.Text=k status.Text="Key fetched" else status.Text="Could not read key from site" status.TextColor3=Color3.fromRGB(255,90,90) end
		end)
	end)
	btn("Close",220,90,146,Color3.fromRGB(120,40,60),function() close(false) end)
	btn("Check Key",20,290,184,Color3.fromRGB(40,160,90),function() check(tb.Text) end)
	if o.Url and o.AutoFill then task.spawn(function() local k=Lib.FetchKey(o.Url) if k then tb.Text=k end end) end
	ev.Event:Wait()
	return result==true
end

------------------------------------------------------------------ float button visual
local function buildFloat(Win,parent,data,interactive,el)
	local base=Color3.fromRGB(20,16,32)
	local f=new("TextButton",{AnchorPoint=Vector2.new(.5,.5),Text="",AutoButtonColor=false,BackgroundColor3=base,ClipsDescendants=true,ZIndex=5,Parent=parent})
	local cr=new("UICorner",{Parent=f})
	local st=new("UIStroke",{Thickness=2.5,Color=WHITE,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Parent=f})
	local gr=new("UIGradient",{Parent=st})
	local sc=new("UIScale",{Parent=f})
	local lb=new("TextLabel",{BackgroundTransparency=1,Size=FULL,Font=FONT_B,TextColor3=WHITE,TextScaled=true,ZIndex=6,Parent=f})
	new("UITextSizeConstraint",{MaxTextSize=14,MinTextSize=5,Parent=lb})
	new("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),Parent=lb})
	table.insert(Win._spin,{gr,60})
	local function apply()
		local sh=Shapes[Lib.ShapeIndex[data.Shape or "Circle"] or 1]
		local small=(data.W==30 and data.H==30 and (data.Shape or "Circle")=="Circle")
		local w,h=small and 26 or data.W,small and 26 or data.H
		f.Size=UDim2.fromOffset(math.floor(w*sh[3]),h)
		cr.CornerRadius=UDim.new(sh[2],0)
		f.Rotation=sh[4]; lb.Rotation=-sh[4]
		f.BackgroundTransparency=data.Trans
		local c=data.Colors
		gr.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c[1]),ColorSequenceKeypoint.new(.5,c[2]),ColorSequenceKeypoint.new(1,c[3])})
		local s=data.Name or ""
		if data.W<=40 and data.H<=40 then local e=utf8.offset(s,3) if e then s=s:sub(1,e-1) end end
		lb.Text=s
	end
	local function paint()
		if not f.Parent then return end
		local on=el and el.Type=="Toggle" and el.Value
		tween(f,.25,{BackgroundColor3=on and base:Lerp(Win.Accent,.5) or base})
		lb.TextColor3=on and WHITE or Color3.fromRGB(205,205,222)
	end
	Win:OnAccent(paint)
	if interactive then
		dragClick(f,function() if el.Type=="Toggle" then el.Set(not el.Value) else el.Trigger() end end,
			function() return data.Drag end,
			function() data.Pos={f.Position.X.Scale,f.Position.X.Offset,f.Position.Y.Scale,f.Position.Y.Offset} Win:_changed() end)
	end
	return f,apply,paint,sc
end

------------------------------------------------------------------ element builders
local B={}
local function hidden(id) return id:sub(1,6)=="~float" end

local function baseRow(Win,parent,o,extra,mini)
	local hasD=o.Desc and o.Desc~=""
	local bh=hasD and 50 or 38
	local row=new("Frame",{Size=UDim2.new(1,0,0,bh+(extra or 0)),BackgroundColor3=BLACK,BackgroundTransparency=.55,ClipsDescendants=true,Parent=parent})
	corner(row); local st=stroke(row,WHITE,1,.88)
	local left=mini and 40 or 10
	lbl(row,o.Name or "Element",13,UDim2.fromOffset(left,hasD and 7 or 10),UDim2.new(1,-(left+64),0,18),{Font=FONT_B})
	if hasD then lbl(row,o.Desc,11,UDim2.fromOffset(left,26),UDim2.new(1,-(left+64),0,16),{Color=Color3.fromRGB(180,180,196)}) end
	local hit=new("TextButton",{BackgroundTransparency=1,Text="",Size=UDim2.new(1,0,0,bh),ZIndex=2,Parent=row})
	hit.MouseEnter:Connect(function() tween(row,.2,{BackgroundTransparency=.4}) end)
	hit.MouseLeave:Connect(function() tween(row,.2,{BackgroundTransparency=.55}) end)
	hit.InputBegan:Connect(function(i)
		if isPress(i) then ripple(row,i.Position.X,i.Position.Y) tween(st,.1,{Transparency=.4}) task.delay(.15,function() tween(st,.3,{Transparency=.88}) end) end
	end)
	return row,hit,bh,left
end

local function addMini(Win,row,bh,id)
	local m=new("TextButton",{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,10,0,bh/2),Size=UDim2.fromOffset(22,22),BackgroundColor3=WHITE,BackgroundTransparency=.9,Text="",AutoButtonColor=false,ZIndex=5,Parent=row})
	corner(m,UDim.new(0,6)); local ms=stroke(m,Win.Accent,1.6,.15)
	Win:OnAccent(function(c) ms.Color=c end)
	local dot=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(8,8),BackgroundColor3=WHITE,BackgroundTransparency=.45,Parent=m})
	corner(dot,UDim.new(0,2))
	m.MouseEnter:Connect(function() tween(dot,.25,{Size=UDim2.fromOffset(12,12)},ES.Back) end)
	m.MouseLeave:Connect(function() tween(dot,.25,{Size=UDim2.fromOffset(8,8)}) end)
	m.Activated:Connect(function()
		tween(m,.12,{Size=UDim2.fromOffset(18,18)}) task.delay(.12,function() tween(m,.3,{Size=UDim2.fromOffset(22,22)},ES.Back) end)
		Win:OpenFloatPage(id)
	end)
end

local function sliderBar(Win,parent,y,left,right,o,lb,onChange)
	local min,max,step=o.Min or 0,o.Max or 100,o.Step or 1
	local val=o.Default or min
	local hit=new("Frame",{Position=UDim2.new(0,left,0,y),Size=UDim2.new(1,-(left+right),0,20),BackgroundTransparency=1,Active=true,Parent=parent})
	local track=new("Frame",{AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.new(1,0,0,6),BackgroundColor3=WHITE,BackgroundTransparency=.85,Parent=hit})
	corner(track,UDim.new(1,0))
	local fill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=Win.Accent,Parent=track}); corner(fill,UDim.new(1,0))
	local knob=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(12,12),Position=UDim2.fromScale(0,.5),BackgroundColor3=WHITE,Parent=track}); corner(knob,UDim.new(1,0))
	Win:OnAccent(function(c) fill.BackgroundColor3=c end)
	local api={}
	function api.Set(v,silent)
		v=math.clamp(math.floor((v-min)/step+.5)*step+min,min,max)
		v=tonumber(string.format("%.4f",v)); val=v
		local a=(max==min) and 0 or (v-min)/(max-min)
		tween(fill,.12,{Size=UDim2.fromScale(a,1)}); tween(knob,.12,{Position=UDim2.fromScale(a,.5)})
		lb.Text=tostring(v)..(o.Suffix or "")
		if onChange and not silent then onChange(v) end
	end
	function api.Get() return val end
	slideDrag(hit,function(p) api.Set(min+(max-min)*math.clamp((p.X-hit.AbsolutePosition.X)/hit.AbsoluteSize.X,0,1)) end,
		function() tween(knob,.2,{Size=UDim2.fromOffset(12,12)},ES.Back) end)
	hit.InputBegan:Connect(function(i) if isPress(i) then tween(knob,.15,{Size=UDim2.fromOffset(17,17)},ES.Back) end end)
	api.Set(val,true)
	return api
end

function B.Button(Win,parent,o,prefix)
	local id=prefix.."/"..(o.Name or "Button")
	local row,hit,bh=baseRow(Win,parent,o,0,o.Float~=false and not hidden(id))
	local arrow=lbl(row,"›",24,UDim2.new(1,-30,0,0),UDim2.new(0,20,0,bh),{Align=CENTER})
	local el={Type="Button",Id=id,Name=o.Name or "Button"}
	function el.Trigger()
		tween(arrow,.12,{Position=UDim2.new(1,-20,0,0)}) task.delay(.12,function() tween(arrow,.3,{Position=UDim2.new(1,-30,0,0)},ES.Back) end)
		if o.Callback then task.spawn(pcall,o.Callback) end
	end
	hit.Activated:Connect(el.Trigger)
	Win:Reg(id,el)
	if o.Float~=false and not hidden(id) then addMini(Win,row,bh,id) end
	return el
end

function B.Toggle(Win,parent,o,prefix)
	local id=prefix.."/"..(o.Name or "Toggle")
	local hasS=o.Slider~=nil
	local row,hit,bh,left=baseRow(Win,parent,o,hasS and 30 or 0,o.Float~=false and not hidden(id))
	local OFF=Color3.fromRGB(70,70,84)
	local sw=new("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,0,bh/2),Size=UDim2.fromOffset(40,20),BackgroundColor3=OFF,Parent=row}); corner(sw,UDim.new(1,0))
	local kn=new("Frame",{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,3,.5,0),Size=UDim2.fromOffset(14,14),BackgroundColor3=WHITE,Parent=sw}); corner(kn,UDim.new(1,0))
	local el={Type="Toggle",Id=id,Name=o.Name or "Toggle",Value=false}
	local sl
	local function paint()
		tween(sw,.25,{BackgroundColor3=el.Value and Win.Accent or OFF})
		tween(kn,.35,{Position=el.Value and UDim2.new(1,-17,.5,0) or UDim2.new(0,3,.5,0),Size=UDim2.fromOffset(14,14)},ES.Back)
	end
	local function fire() if o.Callback then task.spawn(pcall,o.Callback,el.Value,sl and sl.Get()) end end
	function el.Set(v,silent)
		el.Value=v and true or false; paint(); Win:Flag(id,el.Value)
		if not silent then fire() end
		Win:RefreshFloats(id)
	end
	function el.Trigger() el.Set(not el.Value) end
	Win:OnAccent(paint)
	hit.Activated:Connect(el.Trigger)
	if hasS then
		local vl=lbl(row,"",12,UDim2.new(1,-52,0,bh+1),UDim2.fromOffset(42,18),{Align=RIGHT,Color=Color3.fromRGB(200,200,215)})
		sl=sliderBar(Win,row,bh,left,56,o.Slider,vl,function(v) Win:Flag(id.."#S",v) if el.Value then fire() end end)
		Win:RegS(id.."#S",function(v) sl.Set(v) end)
	end
	Win:Reg(id,el,function(v) el.Set(v) end)
	if o.Float~=false and not hidden(id) then addMini(Win,row,bh,id) end
	if o.Default then el.Set(true) end
	return el
end

function B.Slider(Win,parent,o,prefix)
	if o.Toggle then
		return B.Toggle(Win,parent,{Name=o.Name,Desc=o.Desc,Callback=o.Callback,Float=o.Float,Default=o.ToggleDefault,Slider={Min=o.Min,Max=o.Max,Default=o.Default,Step=o.Step,Suffix=o.Suffix}},prefix)
	end
	local id=prefix.."/"..(o.Name or "Slider")
	local row,_,bh=baseRow(Win,parent,o,26,false)
	local vl=lbl(row,"",12,UDim2.new(1,-72,0,(o.Desc and o.Desc~="") and 7 or 10),UDim2.fromOffset(62,18),{Align=RIGHT,Color=Color3.fromRGB(200,200,215)})
	local el={Type="Slider",Id=id,Name=o.Name or "Slider"}
	local sl=sliderBar(Win,row,bh-2,10,10,o,vl,function(v) Win:Flag(id,v) el.Value=v if o.Callback then task.spawn(pcall,o.Callback,v) end end)
	el.Value=sl.Get(); el.Set=function(v) sl.Set(v) end
	Win:Reg(id,el,el.Set)
	return el
end

function B.Textbox(Win,parent,o,prefix)
	local id=prefix.."/"..(o.Name or "Textbox")
	local row,_,bh=baseRow(Win,parent,o,30,false)
	local tb=new("TextBox",{Position=UDim2.fromOffset(10,bh-4),Size=UDim2.new(1,-20,0,26),BackgroundColor3=BLACK,BackgroundTransparency=.5,PlaceholderText=o.Placeholder or "Type here...",PlaceholderColor3=Color3.fromRGB(140,140,156),Text=o.Default or "",ClearTextOnFocus=false,Font=FONT,TextSize=12,TextColor3=WHITE,TextXAlignment=LEFT,Parent=row})
	corner(tb,UDim.new(0,6)); new("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),Parent=tb})
	local ts=stroke(tb,Win.Accent,1.2,1)
	Win:OnAccent(function(c) ts.Color=c end)
	tb.Focused:Connect(function() tween(ts,.2,{Transparency=.2}) end)
	local el={Type="Textbox",Id=id,Name=o.Name or "Textbox",Value=tb.Text}
	function el.Set(v,silent) tb.Text=tostring(v) el.Value=tb.Text Win:Flag(id,el.Value) if not silent and o.Callback then task.spawn(pcall,o.Callback,el.Value) end end
	tb.FocusLost:Connect(function() tween(ts,.2,{Transparency=1}) el.Set(tb.Text) end)
	Win:Reg(id,el,el.Set)
	return el
end

function B.ColorPicker(Win,parent,o,prefix)
	local id=prefix.."/"..(o.Name or "Color")
	local row,hit=baseRow(Win,parent,o,0,false)
	local sw=new("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,.5,0),Size=UDim2.fromOffset(36,20),BackgroundColor3=o.Default or WHITE,Parent=row})
	corner(sw,UDim.new(0,6)); stroke(sw,WHITE,1,.5)
	local el={Type="ColorPicker",Id=id,Name=o.Name or "Color",Value=o.Default or WHITE}
	function el.Set(c,silent) el.Value=c tween(sw,.2,{BackgroundColor3=c}) Win:Flag(id,c) if not silent and o.Callback then task.spawn(pcall,o.Callback,c) end end
	hit.Activated:Connect(function() Win:_Picker(el.Value,function(c) el.Set(c) end) end)
	Win:Reg(id,el,function(v) if typeof(v)=="Color3" then el.Set(v) end end)
	return el
end

function B.Label(Win,parent,o,prefix)
	local l=lbl(parent,o.Text or o.Name or "",12,UDim2.new(),UDim2.new(1,0,0,0),{Color=o.Color or Color3.fromRGB(200,200,215)})
	l.TextWrapped=true; l.AutoSize=nil; l.AutomaticSize=Enum.AutomaticSize.Y; l.TextTruncate=Enum.TextTruncate.None
	new("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,2),Parent=l})
	return {Set=function(_,t) l.Text=t end,Label=l}
end

function B.Dropdown(Win,parent,o,prefix)
	local id=prefix.."/"..(o.Name or "Dropdown")
	local row,hit,bh=baseRow(Win,parent,o,0,false)
	local multi=o.Multi
	local opts=o.Options or {}
	local value=multi and {} or nil
	local isOpen=false
	local sel=lbl(row,"None",12,UDim2.new(.4,0,0,0),UDim2.new(.6,-30,0,bh),{Align=RIGHT,Color=Color3.fromRGB(200,200,215)})
	local arrow=lbl(row,"▾",16,UDim2.new(1,-24,0,0),UDim2.fromOffset(20,bh),{Align=CENTER})
	local list=new("Frame",{Position=UDim2.fromOffset(8,bh+2),Size=UDim2.new(1,-16,0,0),BackgroundTransparency=1,Parent=row})
	local search=new("TextBox",{Size=UDim2.new(1,-4,0,26),BackgroundColor3=BLACK,BackgroundTransparency=.5,PlaceholderText="Search...",PlaceholderColor3=Color3.fromRGB(140,140,156),Text="",ClearTextOnFocus=false,Font=FONT,TextSize=12,TextColor3=WHITE,Visible=false,Parent=list})
	corner(search,UDim.new(0,6))
	local scroll=new("ScrollingFrame",{Size=UDim2.new(1,0,0,100),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Parent=list})
	new("UIListLayout",{Padding=UDim.new(0,3),Parent=scroll})
	local el={Type="Dropdown",Id=id,Name=o.Name or "Dropdown"}
	local function has(n) if not multi then return value==n end for _,x in ipairs(value) do if x==n then return true end end return false end
	local function mark()
		for _,b in ipairs(scroll:GetChildren()) do
			if b:IsA("TextButton") then
				local s=has(b.Name); b.TextColor3=s and Win.Accent or WHITE; b.BackgroundTransparency=s and .75 or .92
			end
		end
		sel.Text=multi and (#value>0 and table.concat(value,", ") or "None") or tostring(value or "None")
	end
	Win:OnAccent(mark)
	local function height()
		local sh=#opts>6
		local h=math.clamp(#opts,1,5)*27
		return (sh and 30 or 0)+h,sh,h
	end
	local function resize()
		local total,_,_=height()
		if isOpen then tween(row,.35,{Size=UDim2.new(1,0,0,bh+total+10)},ES.Quint) end
	end
	local function build()
		for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		for _,n in ipairs(opts) do
			local b=new("TextButton",{Name=tostring(n),Size=UDim2.new(1,-4,0,24),BackgroundColor3=WHITE,BackgroundTransparency=.92,Text=tostring(n),Font=FONT,TextSize=12,TextColor3=WHITE,AutoButtonColor=false,ClipsDescendants=true,Parent=scroll})
			corner(b,UDim.new(0,6))
			b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i.Position.X,i.Position.Y) end end)
			b.Activated:Connect(function() el.Select(n) end)
		end
		local _,sh,h=height()
		search.Visible=sh; scroll.Position=UDim2.fromOffset(0,sh and 30 or 0); scroll.Size=UDim2.new(1,0,0,h)
		mark(); resize()
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q=search.Text:lower()
		for _,b in ipairs(scroll:GetChildren()) do if b:IsA("TextButton") then b.Visible=(q=="" or b.Name:lower():find(q,1,true)~=nil) end end
	end)
	local function toggleOpen(v)
		isOpen=v
		tween(arrow,.3,{Rotation=v and 180 or 0},ES.Back)
		if v then local total=height() tween(row,.4,{Size=UDim2.new(1,0,0,bh+total+10)},ES.Back) else tween(row,.3,{Size=UDim2.new(1,0,0,bh)}) end
	end
	function el.Select(n)
		if multi then
			local found
			for i,x in ipairs(value) do if x==n then table.remove(value,i) found=true break end end
			if not found then table.insert(value,n) end
		else value=n; toggleOpen(false) end
		el.Value=value; mark(); Win:Flag(id,value)
		if o.Callback then task.spawn(pcall,o.Callback,value) end
	end
	function el.Set(v)
		if multi then value=type(v)=="table" and v or {} else value=v end
		el.Value=value; mark(); Win:Flag(id,value)
		if o.Callback then task.spawn(pcall,o.Callback,value) end
	end
	function el.Refresh(newOpts) opts=newOpts or {} build() end
	hit.Activated:Connect(function() toggleOpen(not isOpen) end)
	Win:Reg(id,el,el.Set)
	build()
	if o.Default~=nil then value=o.Default el.Value=value mark() if o.Callback then task.spawn(pcall,o.Callback,value) end end
	return el
end

------------------------------------------------------------------ window
function Lib:CreateWindow(o)
	o=o or {}
	local Win={Tabs={},Flags={},Setters={},Elements={},Floats={},_acc={},_spin={},Ease=ES.Quint,Loading=false,Visible=true,AutoSave=o.AutoSave~=false}
	Win.Name=o.Name or "Ocean UI"; Win.Folder=o.Folder or "OceanUI"
	local fname=(o.ConfigName or Win.Name):gsub("[^%w_%-]","_")
	Win.File=Win.Folder.."/"..fname..".json"
	Win.Accent=typeof(o.Color)=="Color3" and o.Color or (Lib.Colors[o.Color or "Purple"] or PURPLE)
	Win.ColorName=typeof(o.Color)~="Color3" and (o.Color or "Purple") or nil
	Win.Trans=o.Transparency or .22
	local size=o.Size or UDim2.fromOffset(586,339)

	local parentGui=guiParent()
	local old=parentGui:FindFirstChild("OceanUI_"..Win.Name) if old then old:Destroy() end
	local gui=new("ScreenGui",{Name="OceanUI_"..Win.Name,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=999,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=parentGui})
	Win.Gui=gui
	function Win:OnAccent(fn) table.insert(self._acc,fn) pcall(fn,self.Accent) end
	function Win:Reg(id,el,setter) if hidden(id) then return end self.Elements[id]=el if setter then self.Setters[id]=setter end end
	function Win:RegS(id,setter) if not hidden(id) then self.Setters[id]=setter end end
	function Win:Flag(id,v) if hidden(id) then return end self.Flags[id]=v self:_changed() end
	function Win:_changed()
		if self.Loading or not self.AutoSave then return end
		self._st=(self._st or 0)+1; local n=self._st
		task.delay(.6,function() if n==self._st then self:Save() end end)
	end

	-- main frame
	local Main=new("Frame",{Name="Main",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=size,BackgroundTransparency=1,Parent=gui})
	local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000,700)
	Win.Fit=math.clamp(math.min((vp.X-16)/math.max(size.X.Offset,1),(vp.Y-16)/math.max(size.Y.Offset,1)),.4,1)
	local scale=new("UIScale",{Scale=0,Parent=Main})
	new("ImageLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(-30,-24),Size=UDim2.new(1,60,1,60),Image="rbxassetid://6014261993",ImageColor3=BLACK,ImageTransparency=.45,ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(49,49,450,450),Parent=Main})
	local depth={}
	for k=1,2 do
		local d=new("Frame",{Position=UDim2.fromOffset(0,k*4),Size=FULL,BackgroundColor3=WHITE,BackgroundTransparency=.55+k*.15,Parent=Main}) corner(d,UDim.new(0,12)) table.insert(depth,d)
	end
	local Body=new("Frame",{Name="Body",Size=FULL,BackgroundColor3=WHITE,BackgroundTransparency=Win.Trans,ClipsDescendants=true,Parent=Main})
	corner(Body,UDim.new(0,12))
	local bodyGrad=new("UIGradient",{Rotation=90,Parent=Body})
	local bst=stroke(Body,WHITE,2.5,0)
	local bgrad=new("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,PURPLE),ColorSequenceKeypoint.new(.5,PINK),ColorSequenceKeypoint.new(1,PURPLE)}),Parent=bst})
	local gloss=new("Frame",{Size=UDim2.new(1,0,0,70),BackgroundColor3=WHITE,BorderSizePixel=0,Parent=Body})
	new("UIGradient",{Rotation=90,Transparency=NumberSequence.new(.86,1),Parent=gloss})
	local shine=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(-.3,0,.5,0),Size=UDim2.new(.18,0,2,0),Rotation=20,BackgroundColor3=WHITE,BorderSizePixel=0,Parent=Body})
	new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.93),NumberSequenceKeypoint.new(1,1)}),Parent=shine})
	loop(shine,7,{Position=UDim2.new(1.3,0,.5,0)},ES.Linear)
	local rip=new("Frame",{Size=FULL,BackgroundTransparency=1,ClipsDescendants=true,Parent=Body})

	local function applyColor()
		local c=Win.Accent
		bodyGrad.Color=ColorSequence.new(c:Lerp(BLACK,.4),c:Lerp(BLACK,.82))
		for k,d in ipairs(depth) do d.BackgroundColor3=c:Lerp(BLACK,.5+k*.15) end
		for _,fn in ipairs(Win._acc) do pcall(fn,c) end
	end

	-- header
	local Header=new("Frame",{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,Parent=Body})
	local hic=new("ImageLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(12,8),Size=UDim2.fromOffset(24,24),ImageColor3=WHITE,Parent=Header})
	local hfb=lbl(Header,"🌊",20,UDim2.fromOffset(12,8),UDim2.fromOffset(24,24),{Align=CENTER}); hfb.Visible=false
	local titleL=lbl(Header,Win.Name,14,UDim2.fromOffset(44,4),UDim2.new(1,-120,0,18),{Font=FONT_B})
	local subL=lbl(Header,o.Subtitle or "",11,UDim2.fromOffset(44,21),UDim2.new(1,-120,0,14),{Color=Color3.fromRGB(190,190,208)})
	function Win:SetIcon(i) local ok=setIcon(hic,i) hic.Visible=ok hfb.Visible=not ok end
	function Win:SetName(n) titleL.Text=n self.Name=n end
	function Win:SetSubtitle(s) subL.Text=s end
	function Win:SetTransparency(t) self.Trans=t tween(Body,.3,{BackgroundTransparency=t}) self:_changed() end
	function Win:SetSize(s) size=s tween(Main,.4,{Size=s},ES.Back) end
	function Win:SetColor(c)
		if type(c)=="string" then self.ColorName=c c=Lib.Colors[c] or self.Accent else self.ColorName=nil end
		self.Accent=c applyColor() self:_changed()
	end
	Win:SetIcon(o.Icon or "waterdrops")
	new("Frame",{Position=UDim2.fromOffset(10,40),Size=UDim2.new(1,-20,0,1),BackgroundColor3=WHITE,BackgroundTransparency=.88,BorderSizePixel=0,Parent=Body})
	local function hbtn(txt,x,col)
		local b=new("TextButton",{Text=txt,Font=FONT_B,TextSize=14,TextColor3=WHITE,BackgroundColor3=col,BackgroundTransparency=.7,AutoButtonColor=false,Position=UDim2.new(1,x,0,8),Size=UDim2.fromOffset(24,24),ClipsDescendants=true,Parent=Header})
		corner(b,UDim.new(0,7))
		b.MouseEnter:Connect(function() tween(b,.2,{BackgroundTransparency=.3}) end)
		b.MouseLeave:Connect(function() tween(b,.2,{BackgroundTransparency=.7}) end)
		b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i.Position.X,i.Position.Y) end end)
		return b
	end
	local hide=hbtn("–",-60,Color3.fromRGB(255,255,255)); local close=hbtn("✕",-32,Color3.fromRGB(255,70,90))

	-- sidebar + content
	local Sidebar=new("ScrollingFrame",{Position=UDim2.fromOffset(8,46),Size=UDim2.new(0,118,1,-86),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Parent=Body})
	new("UIListLayout",{Padding=UDim.new(0,4),Parent=Sidebar})
	local Content=new("Frame",{Position=UDim2.new(0,134,0,46),Size=UDim2.new(1,-142,1,-86),BackgroundTransparency=1,ClipsDescendants=true,Parent=Body})

	-- footer scene: animated sea, wooden pier, boat, car bridge
	do
		local F=new("Frame",{Position=UDim2.new(0,0,1,-34),Size=UDim2.new(1,0,0,34),BackgroundColor3=WHITE,BackgroundTransparency=.2,ClipsDescendants=true,Parent=Body})
		new("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(50,40,110),Color3.fromRGB(235,115,175)),Parent=F})
		local sea=new("Frame",{Position=UDim2.fromOffset(0,18),Size=UDim2.new(1,0,1,-18),BackgroundColor3=WHITE,BorderSizePixel=0,ClipsDescendants=true,Parent=F})
		new("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(45,100,200),Color3.fromRGB(8,28,85)),Parent=sea})
		for L=1,2 do
			local c=new("Frame",{Position=UDim2.fromOffset(L==1 and 0 or -20,L==1 and -9 or -3),Size=UDim2.new(0,900,0,20),BackgroundTransparency=1,Parent=sea})
			for k=0,44 do
				local w=new("Frame",{Position=UDim2.fromOffset(k*20,0),Size=UDim2.fromOffset(22,22),BackgroundColor3=L==1 and Color3.fromRGB(150,215,255) or Color3.fromRGB(90,160,235),BackgroundTransparency=L==1 and .35 or .6,Parent=c})
				corner(w,UDim.new(1,0))
			end
			loop(c,L==1 and 1.6 or 2.4,{Position=UDim2.fromOffset(L==1 and -20 or 0,L==1 and -9 or -3)})
		end
		local wood,dark=Color3.fromRGB(150,98,50),Color3.fromRGB(90,58,30)
		local deck=new("Frame",{Position=UDim2.fromOffset(8,13),Size=UDim2.fromOffset(100,5),BackgroundColor3=wood,BorderSizePixel=0,ZIndex=2,Parent=F})
		for k=1,8 do new("Frame",{Position=UDim2.fromOffset(k*12,0),Size=UDim2.fromOffset(1,5),BackgroundColor3=dark,BorderSizePixel=0,Parent=deck}) end
		for _,x in ipairs({12,52,100}) do new("Frame",{Position=UDim2.fromOffset(x,18),Size=UDim2.fromOffset(4,16),BackgroundColor3=dark,BorderSizePixel=0,ZIndex=2,Parent=F}) end
		local bridge=new("Frame",{Position=UDim2.new(.55,0,0,10),Size=UDim2.new(.42,0,0,4),BackgroundColor3=Color3.fromRGB(95,95,112),BorderSizePixel=0,ZIndex=2,Parent=F})
		for _,x in ipairs({.04,.35,.66,.96}) do new("Frame",{Position=UDim2.new(x,0,0,4),Size=UDim2.fromOffset(4,20),BackgroundColor3=Color3.fromRGB(70,70,88),BorderSizePixel=0,Parent=bridge}) end
		for k,car in ipairs({"🚗","🚙","🚌"}) do
			local c=lbl(F,car,13,UDim2.new(.55,0,0,-3),UDim2.fromOffset(18,14),{Align=CENTER}); c.ZIndex=3
			if k%2==1 then c.Position=UDim2.new(.55,0,0,-3); loop(c,4+k,{Position=UDim2.new(.95,0,0,-3)}) else c.Position=UDim2.new(.95,0,0,-3); loop(c,5+k,{Position=UDim2.new(.55,0,0,-3)}) end
		end
		local holder=new("Frame",{Position=UDim2.new(-.1,0,0,5),Size=UDim2.fromOffset(26,26),BackgroundTransparency=1,ZIndex=3,Parent=F})
		loop(holder,20,{Position=UDim2.new(1.1,0,0,5)})
		local boat=lbl(holder,"⛵",22,UDim2.new(),FULL,{Align=CENTER})
		loop(boat,1.3,{Rotation=7,Position=UDim2.fromOffset(0,3)},ES.Sine,true)
		boat.Rotation=-7
	end

	-- loops (border gradient + spinning gradients)
	local t0=os.clock()
	local rs=RunService.RenderStepped:Connect(function()
		local t=os.clock()-t0
		bgrad.Rotation=(t*28)%360
		bgrad.Offset=Vector2.new(math.sin(t*.5)*.25,0)
		for i=#Win._spin,1,-1 do
			local s=Win._spin[i]
			if s[1].Parent then s[1].Rotation=(t*s[2])%360 else table.remove(Win._spin,i) end
		end
	end)
	gui.Destroying:Connect(function() rs:Disconnect() end)

	-- drag (one finger, heavy)
	heavyDrag(Header,Main,function(i) ripple(rip,i.Position.X,i.Position.Y) tween(scale,.25,{Scale=Win.Fit*.97},ES.Back) end,
		function() tween(scale,.5,{Scale=Win.Fit},ES.Elastic) end)

	-- visibility
	function Win:SetVisible(b)
		self.Visible=b
		if b then Main.Visible=true tween(scale,.5,{Scale=self.Fit},self.Ease) else
			tween(scale,.3,{Scale=0},ES.Back,ED.In) task.delay(.32,function() if not self.Visible then Main.Visible=false end end) end
	end
	function Win:Toggle() self:SetVisible(not self.Visible) end
	function Win:Close()
		self:Save(); tween(scale,.35,{Scale=0},ES.Back,ED.In)
		task.delay(.4,function() gui:Destroy() end)
	end
	hide.Activated:Connect(function() Win:SetVisible(false) end)
	close.Activated:Connect(function() Win:Close() end)
	UIS.InputBegan:Connect(function(i,gp) if not gp and i.KeyCode==(o.ToggleKey or Enum.KeyCode.RightShift) then Win:Toggle() end end)

	-- open button (default: top center, transparent)
	local ob=new("TextButton",{Name="OpenButton",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,14),Size=UDim2.fromOffset(120,36),BackgroundColor3=BLACK,BackgroundTransparency=.55,Text="",AutoButtonColor=false,ClipsDescendants=true,Parent=gui})
	corner(ob,UDim.new(0,18))
	local obs=stroke(ob,WHITE,2,0)
	local obg=new("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,PURPLE),ColorSequenceKeypoint.new(.5,PINK),ColorSequenceKeypoint.new(1,PURPLE)}),Parent=obs})
	table.insert(Win._spin,{obg,70})
	local oi=new("ImageLabel",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,10,.5,0),Size=UDim2.fromOffset(20,20),ImageColor3=WHITE,Parent=ob})
	local oicon=lbl(ob,"🌊",16,UDim2.new(0,8,0,0),UDim2.new(0,24,1,0),{Align=CENTER})
	local on=lbl(ob,"Open",13,UDim2.new(0,36,0,0),UDim2.new(1,-42,1,0),{Font=FONT_B})
	function Win:SetOpenButton(c)
		c=c or {}
		if c.Size then ob.Size=c.Size end
		if c.Position then ob.Position=c.Position end
		if c.Name then on.Text=c.Name end
		if c.Image then local ok=setIcon(oi,c.Image) oi.Visible=ok oicon.Visible=not ok end
		if c.Color then ob.BackgroundColor3=c.Color end
		if c.Transparency then ob.BackgroundTransparency=c.Transparency end
		if c.Radius then corner(ob,c.Radius) end
	end
	oi.Visible=false
	dragClick(ob,function() Win:Toggle() end,function() return true end)
	Win:SetOpenButton(o.OpenButton)

	-- config
	function Win:Save()
		if not writefile then return end
		pcall(function()
			if makefolder and isfolder and not isfolder(self.Folder) then makefolder(self.Folder) end
			local fl={} for _,f in ipairs(self.Floats) do table.insert(fl,enc(f.Data)) end
			writefile(self.File,HttpService:JSONEncode({Flags=enc(self.Flags),Floats=fl,Color=self.ColorName,Trans=self.Trans}))
		end)
	end
	function Win:Load()
		if not (readfile and isfile and isfile(self.File)) then return end
		local ok,d=pcall(function() return dec(HttpService:JSONDecode(readfile(self.File))) end)
		if not ok or type(d)~="table" then return end
		self.Loading=true
		if d.Color and Lib.Colors[d.Color] then self.Accent=Lib.Colors[d.Color] self.ColorName=d.Color applyColor() end
		if d.Trans then self.Trans=d.Trans Body.BackgroundTransparency=d.Trans end
		for k,v in pairs(d.Flags or {}) do local s=self.Setters[k] if s then pcall(s,v) end end
		for _,fd in ipairs(d.Floats or {}) do if self.Elements[fd.Id] then self:CreateFloat(fd,true) end end
		self.Loading=false
	end

	-- floating buttons
	function Win:RefreshFloats(id) for _,f in ipairs(self.Floats) do if f.Data.Id==id then f.Paint() end end end
	function Win:RemoveFloats(id)
		for i=#self.Floats,1,-1 do
			local f=self.Floats[i]
			if f.Data.Id==id then tween(f.Scale,.25,{Scale=0},ES.Back,ED.In) task.delay(.3,function() f.Frame:Destroy() end) table.remove(self.Floats,i) end
		end
		self:_changed()
	end
	function Win:CreateFloat(data,noSave)
		local el=self.Elements[data.Id]; if not el then return end
		data=copy(data)
		data.Name=data.Name or el.Name; data.W=data.W or 30; data.H=data.H or 30; data.Trans=data.Trans or .15
		data.Colors=data.Colors or {PURPLE,PINK,PURPLE}; data.Shape=data.Shape or "Circle"
		local f,apply,paint,sc=buildFloat(self,gui,data,true,el)
		apply()
		local p=data.Pos
		if not p then
			if data.PX and data.PY then p={data.PX/100,0,data.PY/100,0}
			elseif data.W==30 and data.H==30 and data.Shape=="Circle" then p={0,26,0,26}
			else p={.5,0,.5,0} end
			data.Pos=p
		end
		f.Position=UDim2.new(p[1],p[2],p[3],p[4])
		sc.Scale=0; tween(sc,.6,{Scale=1},ES.Elastic)
		table.insert(self.Floats,{Data=data,Frame=f,Paint=paint,Scale=sc})
		paint()
		if not noSave then self:_changed() end
	end

	-- color picker
	function Win:_Picker(start,cb)
		local orig=start
		local h,s,v=start:ToHSV()
		local ov=new("TextButton",{Text="",AutoButtonColor=false,Size=FULL,BackgroundColor3=BLACK,BackgroundTransparency=1,ZIndex=70,Parent=Body})
		tween(ov,.25,{BackgroundTransparency=.45})
		local p=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,40),Size=UDim2.fromOffset(240,244),BackgroundColor3=Color3.fromRGB(20,16,32),BackgroundTransparency=.05,Parent=ov})
		corner(p,UDim.new(0,12)); stroke(p,WHITE,1.5,.6)
		tween(p,.45,{Position=UDim2.fromScale(.5,.5)},ES.Back)
		lbl(p,"Color Picker",13,UDim2.fromOffset(12,6),UDim2.new(1,-24,0,20),{Font=FONT_B})
		local sv=new("Frame",{Position=UDim2.fromOffset(12,32),Size=UDim2.fromOffset(216,110),Active=true,ClipsDescendants=true,Parent=p}); corner(sv,UDim.new(0,6))
		local wh=new("Frame",{Size=FULL,BackgroundColor3=WHITE,BorderSizePixel=0,Parent=sv}); new("UIGradient",{Transparency=NumberSequence.new(0,1),Parent=wh})
		local bk=new("Frame",{Size=FULL,BackgroundColor3=BLACK,BorderSizePixel=0,Parent=sv}); new("UIGradient",{Rotation=90,Transparency=NumberSequence.new(1,0),Parent=bk})
		local cur=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(12,12),BackgroundTransparency=1,Parent=sv}); corner(cur,UDim.new(1,0)); stroke(cur,WHITE,2,0)
		local hue=new("Frame",{Position=UDim2.fromOffset(12,150),Size=UDim2.fromOffset(216,14),BackgroundColor3=WHITE,Active=true,Parent=p}); corner(hue,UDim.new(0,7))
		local K=ColorSequenceKeypoint.new
		new("UIGradient",{Color=ColorSequence.new({K(0,Color3.fromRGB(255,0,0)),K(1/6,Color3.fromRGB(255,255,0)),K(2/6,Color3.fromRGB(0,255,0)),K(3/6,Color3.fromRGB(0,255,255)),K(4/6,Color3.fromRGB(0,0,255)),K(5/6,Color3.fromRGB(255,0,255)),K(1,Color3.fromRGB(255,0,0))}),Parent=hue})
		local hc=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(6,20),BackgroundColor3=WHITE,Parent=hue}); corner(hc,UDim.new(0,3)); stroke(hc,BLACK,1,.5)
		local hex=new("TextBox",{Position=UDim2.fromOffset(12,174),Size=UDim2.fromOffset(120,26),BackgroundColor3=BLACK,BackgroundTransparency=.5,Text="",ClearTextOnFocus=false,Font=FONT_B,TextSize=12,TextColor3=WHITE,Parent=p}); corner(hex,UDim.new(0,6))
		local sw=new("Frame",{Position=UDim2.fromOffset(140,174),Size=UDim2.fromOffset(88,26),Parent=p}); corner(sw,UDim.new(0,6)); stroke(sw,WHITE,1,.5)
		local function upd(fire)
			local c=Color3.fromHSV(h,s,v)
			sv.BackgroundColor3=Color3.fromHSV(h,1,1); cur.Position=UDim2.fromScale(s,1-v); hc.Position=UDim2.fromScale(h,.5); sw.BackgroundColor3=c
			hex.Text=string.format("#%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))
			if fire then pcall(cb,c) end
		end
		slideDrag(sv,function(q) s=math.clamp((q.X-sv.AbsolutePosition.X)/sv.AbsoluteSize.X,0,1) v=1-math.clamp((q.Y-sv.AbsolutePosition.Y)/sv.AbsoluteSize.Y,0,1) upd(true) end)
		slideDrag(hue,function(q) h=math.clamp((q.X-hue.AbsolutePosition.X)/hue.AbsoluteSize.X,0,.999) upd(true) end)
		hex.FocusLost:Connect(function()
			local r,g,b=hex.Text:match("#?(%x%x)(%x%x)(%x%x)")
			if r then local c=Color3.fromRGB(tonumber(r,16),tonumber(g,16),tonumber(b,16)) h,s,v=c:ToHSV() upd(true) else upd(false) end
		end)
		local function pill(text,x,col,fn)
			local b=new("TextButton",{Text=text,Font=FONT_B,TextSize=12,TextColor3=WHITE,BackgroundColor3=col,BackgroundTransparency=.1,AutoButtonColor=false,Position=UDim2.fromOffset(x,208),Size=UDim2.fromOffset(104,26),ClipsDescendants=true,Parent=p})
			corner(b,UDim.new(0,8)); b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i.Position.X,i.Position.Y) end end)
			b.Activated:Connect(fn)
		end
		local function out() tween(p,.3,{Position=UDim2.new(.5,0,.5,40)},ES.Back,ED.In) tween(ov,.3,{BackgroundTransparency=1}) task.delay(.32,function() ov:Destroy() end) end
		pill("Cancel",12,Color3.fromRGB(120,40,60),function() pcall(cb,orig) out() end)
		pill("OK",124,Color3.fromRGB(40,160,90),out)
		upd(false)
	end

	-- float creation page
	function Win:OpenFloatPage(id)
		local el=self.Elements[id]; if not el or self._page then return end
		local draft={Id=id,Name=el.Name,W=30,H=30,Trans=.15,Shape="Circle",Drag=true,Colors={PURPLE,PINK,PURPLE}}
		local ov=new("TextButton",{Text="",AutoButtonColor=false,Position=UDim2.fromOffset(0,41),Size=UDim2.new(1,0,1,-41),BackgroundColor3=BLACK,BackgroundTransparency=1,ZIndex=40,Parent=Body})
		self._page=ov
		tween(ov,.3,{BackgroundTransparency=.4})
		local panel=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,50),Size=UDim2.new(1,-20,1,-14),BackgroundColor3=Color3.fromRGB(18,14,30),BackgroundTransparency=.1,Parent=ov})
		corner(panel,UDim.new(0,12)); stroke(panel,WHITE,1.5,.6)
		tween(panel,.5,{Position=UDim2.fromScale(.5,.5)},ES.Back)
		lbl(panel,"Floating Button",13,UDim2.fromOffset(12,6),UDim2.fromOffset(150,18),{Font=FONT_B})
		local prev=new("Frame",{Position=UDim2.fromOffset(12,28),Size=UDim2.fromOffset(130,130),BackgroundColor3=BLACK,BackgroundTransparency=.55,ClipsDescendants=true,Parent=panel})
		corner(prev,UDim.new(0,10)); stroke(prev,self.Accent,1.5,.3)
		local pf,papply,ppaint,psc=buildFloat(self,prev,draft,false,el)
		pf.Position=UDim2.fromScale(.5,.5)
		local ps=new("UIScale",{Parent=pf})
		local function refresh()
			papply(); ppaint()
			local m=math.max(pf.Size.X.Offset,pf.Size.Y.Offset,1)
			ps.Scale=math.min(1,110/m)
		end
		refresh()
		local function close()
			self._page=nil
			tween(panel,.3,{Position=UDim2.new(.5,0,.5,50)},ES.Back,ED.In) tween(ov,.3,{BackgroundTransparency=1})
			task.delay(.32,function() ov:Destroy() end)
		end
		local function pill(text,y,col,fn)
			local b=new("TextButton",{Text=text,Font=FONT_B,TextSize=12,TextColor3=WHITE,BackgroundColor3=col,BackgroundTransparency=.1,AutoButtonColor=false,Position=UDim2.fromOffset(12,y),Size=UDim2.fromOffset(130,28),ClipsDescendants=true,Parent=panel})
			corner(b,UDim.new(0,8)); b.InputBegan:Connect(function(i) if isPress(i) then ripple(b,i.Position.X,i.Position.Y) end end)
			b.Activated:Connect(fn)
		end
		pill("Add Button",166,Color3.fromRGB(40,160,90),function() local d=copy(draft) self:CreateFloat(d) close() end)
		pill("Back (no button)",200,Color3.fromRGB(120,40,60),close)
		pill("Remove existing",234,Color3.fromRGB(70,70,90),function() self:RemoveFloats(id) close() end)
		local scroll=new("ScrollingFrame",{Position=UDim2.fromOffset(152,8),Size=UDim2.new(1,-160,1,-16),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Parent=panel})
		new("UIListLayout",{Padding=UDim.new(0,6),Parent=scroll}); new("UIPadding",{PaddingRight=UDim.new(0,4),Parent=scroll})
		local P="~float"
		B.Textbox(self,scroll,{Name="Button Name",Placeholder="Name shown on the button",Default=el.Name,Callback=function(t) draft.Name=t refresh() end},P)
		B.Slider(self,scroll,{Name="Width",Min=20,Max=200,Default=30,Callback=function(v) draft.W=v refresh() end},P)
		B.Slider(self,scroll,{Name="Height",Min=20,Max=200,Default=30,Callback=function(v) draft.H=v refresh() end},P)
		B.Slider(self,scroll,{Name="Transparency",Min=0,Max=1,Step=.05,Default=.15,Callback=function(v) draft.Trans=v refresh() end},P)
		B.Dropdown(self,scroll,{Name="Shape",Desc="30 shapes",Options=Lib.ShapeNames,Default="Circle",Callback=function(v) draft.Shape=v refresh() end},P)
		B.Toggle(self,scroll,{Name="Draggable",Default=true,Callback=function(v) draft.Drag=v end,Float=false},P)
		for k=1,3 do
			B.Button(self,scroll,{Name="Border Color "..k,Desc="Gradient color "..k,Float=false,Callback=function()
				self:_Picker(draft.Colors[k],function(c) draft.Colors[k]=c refresh() end)
			end},P)
		end
		B.Textbox(self,scroll,{Name="Position X %",Placeholder="auto (leave empty)",Callback=function(t) draft.PX=tonumber(t) refresh() end},P)
		B.Textbox(self,scroll,{Name="Position Y %",Placeholder="auto (leave empty)",Callback=function(t) draft.PY=tonumber(t) refresh() end},P)
	end

	-- tabs
	function Win:Tab(t)
		t=t or {}
		local Tab={Name=t.Name or "Tab",_n=0}
		local btn=new("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundColor3=BLACK,BackgroundTransparency=.6,Text="",AutoButtonColor=false,ClipsDescendants=true,Parent=Sidebar})
		corner(btn)
		local ic=new("ImageLabel",{BackgroundTransparency=1,Size=UDim2.fromOffset(18,18),Position=UDim2.new(0,10,.5,-9),ImageColor3=WHITE,Parent=btn})
		if not setIcon(ic,t.Icon) then ic:Destroy() lbl(btn,"•",18,UDim2.new(0,10,0,0),UDim2.new(0,18,1,0),{Align=CENTER}) end
		local nm=lbl(btn,Tab.Name,12,UDim2.new(0,34,0,0),UDim2.new(1,-38,1,0),{Font=FONT_B,Color=Color3.fromRGB(190,190,208)})
		local bar=new("Frame",{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,0,.5,0),Size=UDim2.fromOffset(3,0),BackgroundColor3=Win.Accent,BorderSizePixel=0,Parent=btn})
		Win:OnAccent(function(c) bar.BackgroundColor3=c end)
		btn.MouseEnter:Connect(function() if Win.Cur~=Tab then tween(btn,.2,{BackgroundTransparency=.45}) end end)
		btn.MouseLeave:Connect(function() if Win.Cur~=Tab then tween(btn,.2,{BackgroundTransparency=.6}) end end)
		btn.InputBegan:Connect(function(i) if isPress(i) then ripple(btn,i.Position.X,i.Position.Y) end end)
		local page=new("Frame",{Size=FULL,BackgroundTransparency=1,Visible=false,Parent=Content})
		local cols={}
		for _,side in ipairs({"Left","Right"}) do
			local c=new("ScrollingFrame",{Position=UDim2.new(side=="Left" and 0 or .5,side=="Left" and 0 or 4,0,0),Size=UDim2.new(.5,-4,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Parent=page})
			new("UIListLayout",{Padding=UDim.new(0,6),Parent=c}); new("UIPadding",{PaddingBottom=UDim.new(0,6),PaddingRight=UDim.new(0,3),Parent=c})
			cols[side]=c
		end
		function Tab._deselect()
			page.Visible=false
			tween(btn,.25,{BackgroundTransparency=.6}) tween(bar,.25,{Size=UDim2.fromOffset(3,0)}) nm.TextColor3=Color3.fromRGB(190,190,208)
		end
		local function select()
			if Win.Cur==Tab then return end
			if Win.Cur then Win.Cur._deselect() end
			Win.Cur=Tab; page.Visible=true; page.Position=UDim2.fromOffset(0,16)
			tween(page,.4,{Position=UDim2.new()},Win.Ease)
			tween(btn,.25,{BackgroundTransparency=.3}); tween(bar,.35,{Size=UDim2.fromOffset(3,18)},ES.Back); nm.TextColor3=WHITE
		end
		btn.Activated:Connect(select)
		if not Win.Cur then select() end
		for _,k in ipairs({"Button","Toggle","Slider","Dropdown","Textbox","ColorPicker","Label"}) do
			Tab[k]=function(self,opt)
				opt=opt or {}
				Tab._n=Tab._n+1
				local col=cols[opt.Side or (Tab._n%2==1 and "Left" or "Right")]
				return B[k](Win,col,opt,Tab.Name)
			end
		end
		table.insert(Win.Tabs,Tab)
		return Tab
	end

	-- welcome intro
	local snd=new("Sound",{SoundId="rbxassetid://3868133279",Volume=1,Parent=gui})
	snd:Play()
	applyColor()
	local wv=new("Frame",{Size=FULL,BackgroundColor3=WHITE,ZIndex=200,Parent=Body})
	new("UIGradient",{Rotation=45,Color=ColorSequence.new(Win.Accent:Lerp(BLACK,.5),Color3.fromRGB(12,8,24)),Parent=wv})
	local wt=lbl(wv,"",28,UDim2.new(0,0,.5,-30),UDim2.new(1,0,0,40),{Font=FONT_X,Align=CENTER}); wt.ZIndex=201
	local ws=lbl(wv,Win.Name,13,UDim2.new(0,0,.5,12),UDim2.new(1,0,0,18),{Color=Color3.fromRGB(200,200,220),Align=CENTER}); ws.ZIndex=201; ws.TextTransparency=1
	tween(scale,.9,{Scale=Win.Fit},ES.Back)
	task.spawn(function()
		local msg="Welcome, "..(LP and LP.DisplayName or "Player")
		for i=1,utf8.len(msg) do wt.Text=msg:sub(1,utf8.offset(msg,i+1)-1) task.wait(.045) end
		tween(ws,.5,{TextTransparency=0}) task.wait(1.1)
		tween(wv,.7,{BackgroundTransparency=1}) tween(wt,.6,{TextTransparency=1}) tween(ws,.6,{TextTransparency=1})
		task.wait(.8) wv:Destroy()
	end)
	task.delay(o.LoadDelay or 2.2,function() Win:Load() end)
	return Win
end

return Lib
