local Graphics=require(script.Parent.Graphics)
local HUD={};HUD.__index=HUD
function HUD.new(player)
    local gui=Instance.new("ScreenGui");gui.Name="BK_CharacterHUD";gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true;gui.DisplayOrder=20;gui.Parent=player.PlayerGui
    local canvas=Instance.new("Frame");canvas.Name="N64Canvas";canvas.BackgroundTransparency=1
    canvas.AnchorPoint=Vector2.new(.5,.5);canvas.Position=UDim2.fromScale(.5,.5);canvas.Size=UDim2.fromOffset(320,240);canvas.Parent=gui
    local scale=Instance.new("UIScale");scale.Parent=canvas
    local self=setmetatable({gui=gui,canvas=canvas,scale=scale,numbers={},time=0},HUD)
    local texture=Graphics.editableTexture("HUD");local rects=Graphics.data().hudRects
    local function icon(name,x,y,w,h)
        local r=rects[name];local image=Instance.new("ImageLabel");image.Name=name
        image.BackgroundTransparency=1;image.Position=UDim2.fromOffset(x,y);image.Size=UDim2.fromOffset(w,h)
        image.ImageContent=texture;image.ImageRectOffset=Vector2.new(r[1],r[2]);image.ImageRectSize=Vector2.new(r[3],r[4]);image.Parent=canvas
        return image
    end
    self.health={}
    for i=1,6 do self.health[i]=icon("health",222+(i-1)*12,16+math.sin((i-1)/5*math.pi)*8,16,16)end
    icon("banjo",14,193,25,25);self.lives=self:number(texture,rects.digits,40,198,"3")
    icon("egg",15,18,24,24);self.eggs=self:number(texture,rects.digits,42,23,"100")
    local help=Instance.new("TextLabel");help.Name="Controls";help.BackgroundColor3=Color3.fromRGB(47,28,14);help.BackgroundTransparency=.15
    help.TextColor3=Color3.fromRGB(255,221,125);help.Font=Enum.Font.Cartoon;help.TextSize=8;help.TextWrapped=true
    help.Size=UDim2.fromOffset(280,56);help.Position=UDim2.fromOffset(20,135);help.Visible=false
    help.Text="WASD move · Space jump/Flutter · T Talon Trot\nCtrl+Space Flip · X attack · Ctrl+X Barge · Z Buster\nRed pad: Space to fly/flap; W+camera steers, Z lands\nGreen pad: hold Space · Truss: W/S climb, Space off\nV eggs · L lighting · R reset · F8 exit";help.Parent=canvas;self.help=help
    local hint=Instance.new("TextLabel");hint.Name="HelpHint";hint.BackgroundTransparency=1;hint.Text="H: controls"
    hint.Font=Enum.Font.Cartoon;hint.TextColor3=Color3.fromRGB(255,221,125);hint.TextStrokeTransparency=.35;hint.TextSize=7
    hint.Size=UDim2.fromOffset(60,12);hint.Position=UDim2.fromOffset(242,213);hint.Parent=canvas
    local lighting=Instance.new("TextButton");lighting.Name="LightingMode";lighting.BackgroundTransparency=1
    lighting.Font=Enum.Font.Cartoon;lighting.TextColor3=Color3.fromRGB(255,221,125);lighting.TextStrokeTransparency=.35;lighting.TextSize=7
    lighting.Text="Lighting: Roblox";lighting.Size=UDim2.fromOffset(74,12);lighting.Position=UDim2.fromOffset(234,201);lighting.Parent=canvas;self.lighting=lighting
    local hint=Instance.new("TextLabel");hint.Name="PadHint";hint.BackgroundTransparency=1
    hint.Font=Enum.Font.Cartoon;hint.TextColor3=Color3.fromRGB(255,221,125);hint.TextStrokeTransparency=.35;hint.TextSize=8
    hint.Size=UDim2.fromOffset(230,12);hint.Position=UDim2.fromOffset(45,121);hint.Visible=false;hint.Parent=canvas;self.padHint=hint
    return self
end
function HUD:number(texture,rects,x,y,value)
    local digits={}
    for i=1,#value do
        local r=rects[tonumber(value:sub(i,i))+1];local im=Instance.new("ImageLabel")
        im.Name="Digit";im.BackgroundTransparency=1;im.Size=UDim2.fromOffset(11,15);im.Position=UDim2.fromOffset(x+(i-1)*10,y)
        im.ImageContent=texture;im.ImageRectOffset=Vector2.new(r[1],r[2]);im.ImageRectSize=Vector2.new(r[3],r[4]);im.Parent=self.canvas;digits[i]=im
    end
    return digits
end
function HUD:update(dt,health,eggs,feathers,state,pad)
    self.time+=dt;local size=workspace.CurrentCamera.ViewportSize;self.scale.Scale=math.min(size.X/320,size.Y/240)
    for i,im in self.health do im.ImageTransparency=i<=math.ceil(health/100*6) and 0 or .8 end
    local text=string.format("%03d",math.clamp(eggs or 100,0,999));local rects=Graphics.data().hudRects.digits
    for i,im in self.eggs do local r=rects[tonumber(text:sub(i,i))+1];im.ImageRectOffset=Vector2.new(r[1],r[2]);im.ImageRectSize=Vector2.new(r[3],r[4])end
    local flying=state=="FLY"or state=="FLY_ENTER"
    self.padHint.Visible=flying or pad~=nil or state=="CLIMB"or state=="SPRING_CHARGE"
    self.padHint.Text=flying and ("Red feathers: "..tostring(feathers or 0).." · Space: flap · Z: descend")or state=="CLIMB"and "W/S: climb · Space: jump off"or (pad=="ShockSpring"or state=="SPRING_CHARGE")and "Hold Space for Shock Spring Jump"or "Space: take flight"
end
return HUD
