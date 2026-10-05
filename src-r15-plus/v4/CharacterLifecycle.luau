-- Banjo R15 build: 2.3.8-r15.4
local Lifecycle={};Lifecycle.__index=Lifecycle
function Lifecycle.new(player,runtime,visual,onDead)
    local self=setmetatable({player=player,runtime=runtime,visual=visual,onDead=onDead,
        connections={},ready=false,dead=false},Lifecycle)
    self.removing=player.CharacterRemoving:Connect(function(character)
        if character==self.character then self:_die("CHARACTER_REMOVED") end
    end)
    return self
end
function Lifecycle:_die(reason)
    if self.destroyed or self.dead then return end
    self.dead=true;self.ready=false
    self.runtime:SetAttribute("CharacterAlive",false)
    self.runtime:SetAttribute("DeathReason",reason)
    self.visual:setAlive(false)
    self.onDead(self.character)
end
function Lifecycle:_attach(humanoid)
    if self.destroyed then return end
    if self.humanoid~=humanoid then
        self.humanoid=humanoid
        table.insert(self.connections,humanoid.Died:Connect(function()
            if self.humanoid==humanoid then self:_die("DIED") end
        end))
        table.insert(self.connections,humanoid.HealthChanged:Connect(function(health)
            if self.humanoid==humanoid and health<=0 then self:_die("HEALTH_ZERO") end
        end))
    end
    if humanoid.Health<=0 or humanoid:GetState()==Enum.HumanoidStateType.Dead then self:_die("DEAD")
    elseif not self.dead then
        self.ready=true;self.visual:setAlive(true)
        self.runtime:SetAttribute("CharacterAlive",true);self.runtime:SetAttribute("DeathReason",nil)
    end
end
function Lifecycle:bind(character)
    if self.destroyed then return end
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={};self.character=character;self.humanoid=nil;self.dead=false;self.ready=false
    self.visual:setAlive(false);self.runtime:SetAttribute("CharacterAlive",false)
    self.runtime:SetAttribute("DeathReason","WAITING_FOR_HUMANOID")
    table.insert(self.connections,character.DescendantAdded:Connect(function(item)
        if item:IsA("Humanoid") then self:_attach(item) end
    end))
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if humanoid then self:_attach(humanoid) end
end
function Lifecycle:blocked(character)
    if self.destroyed or character~=self.character then return true end
    if self.player.Character~=character or not character.Parent then self:_die("CHARACTER_REMOVED") end
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if not humanoid then self.ready=false;self.visual:setAlive(false)
    elseif humanoid~=self.humanoid or (not self.ready and not self.dead) then self:_attach(humanoid)
    elseif humanoid.Health<=0 or humanoid:GetState()==Enum.HumanoidStateType.Dead then self:_die("DEAD") end
    return self.dead or not self.ready
end
function Lifecycle:destroy()
    if self.destroyed then return end
    self.destroyed=true
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={};self.removing:Disconnect()
end
return Lifecycle
