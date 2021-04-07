---@module WeaponMgr 服务端的枪械管理模块
---@copyright Lilith Games, Avatar Team
---@author Sharif Ma
local WeaponMgr, this = {}, nil

---枪械系统的服务端的事件
local _SERVER_EVENT_ = {
    'WeaponHitPlayerEvent',
    'CreateAmmoEvent',
    'DestroyAmmoEvent',
    'PlayerPickAmmoEvent',
    'PlayerEventCreateOverEvent',
    'PlayerDataModifiEvent',
    'SyncAndSaveEvent',
    'WeaponObjCreatedEvent',
}

---服务端模块加载
local function ModuleRequire()
    for k, v in pairs(PluginRoot.Module.S_Module:GetChildren()) do
        local moduleName = string.sub(v.Name, 1, string.len(v.Name) - 6)
        if not _G[moduleName] then
            _G[moduleName] = require(v)
        end
    end
end

---模块初始化函数
function WeaponMgr:Init()
    this = self
    ModuleRequire()
    self:InitListeners()
    ---服务端枪械实体存贮列表
    self.weaponList = {}
    ---服务端枪械配件实体存储列表
    self.accessoryList = {}
    ---服务端枪械子弹实体存储列表
    self.ammoList = {}
    ---道具的可拾取范围
    self.distance = GunConfig.GlobalConfig.Distance
    ---当前玩家拥有的子弹数量列表
    self.playerHaveAmmoList = {}
    ---世界下放置枪械的文件夹
    self.weaponFolder = world:CreateObject('FolderObject', 'Weapons', world)
    ---世界下放置配件的文件夹
    self.accFolder = world:CreateObject('FolderObject', 'Accessories', world)
    ---世界下放置子弹的文件夹
    self.ammoFolder = world:CreateObject('FolderObject', 'Ammo', world)
    world.OnPlayerAdded:Connect(function(_player)
        self:OnPlayerAdded(_player)
    end)
    world.OnPlayerRemoved:Connect(function(_player)
        self:OnPlayerRemoved(_player)
    end)
    ---根据配置表刷新所有配置枪械
    self:CreateAllUnitSlot()
	invoke(function()
		self:StartUpdate()
    end)
    DataMgr:Init()
    CacheDestroyMgr:Init()
end

function WeaponMgr:StartUpdate()
    if self.isRun then
        return
    end
    self.isRun = true
    ---用于优化寻址时间
    local time = Timer.GetTimeMillisecond
    local prevTime, nowTime = time() / 1000, nil -- two timestamps
    while (self.isRun and wait()) do
        nowTime = time() / 1000
        self.dt = nowTime - prevTime
        self:Update(self.dt)
        prevTime = nowTime
    end
end

function WeaponMgr:InitListeners()
    if world.S_Event == nil then
        world:CreateObject('FolderObject', 'S_Event', world)
    end
    for _, v in pairs(_SERVER_EVENT_) do
        local event_S = world.S_Event[v]
        if event_S == nil then
            event_S = world:CreateObject('CustomEvent', v, world.S_Event)
        end
    end
    LinkConnects(world.S_Event, WeaponMgr, this)
end

---Update函数
---@param dt number delta time 每帧时间
function WeaponMgr:Update(dt)

end

---创建一把枪,并放到指定的位置
function WeaponMgr:CreateWeapon(_id, _pos, _rot, _parent, _ammoCount)
    if not GunConfig.GunConfig[_id] then
        return
    end
    _parent = _parent or self.weaponFolder
    local name = GunConfig.GunConfig[_id].Name
    ---@type Accessory
    local weaponObj = world:CreateInstance(name, name, _parent, _pos, _rot)
    weaponObj.Module.IsStatic = true
    weaponObj.Module.GravityEnable = false
    weaponObj.Module.Block = false
    weaponObj.Pickable = false
    weaponObj.GravityEnable = false
    weaponObj.CollisionGroup = 3
    weaponObj.IsStatic = true
    weaponObj.Collide = pickRegion
    weaponObj.Block = false
    local uuid = WeaponUUID()
    world:CreateObject('StringValueObject', 'UUID', weaponObj).Value = uuid
    world:CreateObject('IntValueObject', 'ID', weaponObj).Value = _id
    world:CreateObject('IntValueObject', 'AmmoLeft', weaponObj).Value = _ammoCount
    world:CreateObject('ObjRefValueObject', 'Player', weaponObj)
    local pickRegion = world:CreateObject('Sphere', 'PickRegion', weaponObj)
    pickRegion.LocalPosition = Vector3.Zero
    pickRegion.Size = Vector3(self.distance * 2, self.distance * 2, self.distance * 2)
    pickRegion.Color = Color(0, 0, 0, 0)
    pickRegion.Block = false
    pickRegion.GravityEnable = false
    pickRegion.CollisionGroup = 3
    self.weaponList[uuid] = weaponObj
end

---创建一个枪械配件
function WeaponMgr:CreateWeaponAccessory(_id, _pos, _rot, _parent)
    if not GunConfig.WeaponAccessoryConfig[_id] then
        return
    end
    _parent = _parent or self.accFolder
    local name = GunConfig.WeaponAccessoryConfig[_id].Name
    local model = GunConfig.WeaponAccessoryConfig[_id].Model
    local accessoryObj = world:CreateInstance(model, name, _parent, _pos, _rot)
    local uuid = WeaponUUID()
    accessoryObj.Module.IsStatic = true
    accessoryObj.Module.GravityEnable = false
    accessoryObj.Module.Block = false
    accessoryObj.Pickable = false
    accessoryObj.GravityEnable = false
    accessoryObj.CollisionGroup = 3
    accessoryObj.Block = false
    accessoryObj.IsStatic = true
    world:CreateObject('StringValueObject', 'UUID', accessoryObj).Value = uuid
    world:CreateObject('IntValueObject', 'ID', accessoryObj).Value = _id
    world:CreateObject('ObjRefValueObject', 'Player', accessoryObj)
    local pickRegion = world:CreateObject('Sphere', 'PickRegion', accessoryObj)
    pickRegion.LocalPosition = Vector3.Zero
    pickRegion.Size = Vector3(self.distance * 2, self.distance * 2, self.distance * 2)
    pickRegion.Color = Color(0, 0, 0, 0)
    pickRegion.GravityEnable = false
    pickRegion.Block = false
    pickRegion.CollisionGroup = 3
    self.accessoryList[uuid] = accessoryObj
end

---创建子弹
function WeaponMgr:CreateWeaponAmmo(_id, _count, _pos, _rot, _parent)
    if _count <= 0 then
        return
    end
    if not GunConfig.AmmoConfig[_id] then
        return
    end
    _parent = _parent or self.ammoFolder
    local name = GunConfig.AmmoConfig[_id].Name
    local model = GunConfig.AmmoConfig[_id].Model
    local ammoObj = world:CreateInstance(model, name, _parent, _pos, _rot)
    ammoObj.Pickable = false
    ammoObj.CollisionGroup = 3
    ammoObj.Block = false
    ammoObj.IsStatic = true
    ammoObj.GravityEnable = false
    ammoObj.Module.IsStatic = true
    ammoObj.Module.GravityEnable = false
    ammoObj.Module.Block = false
    local uuid = WeaponUUID()
    world:CreateObject('StringValueObject', 'UUID', ammoObj).Value = uuid
    world:CreateObject('IntValueObject', 'ID', ammoObj).Value = _id
    world:CreateObject('IntValueObject', 'Count', ammoObj).Value = _count
    world:CreateObject('ObjRefValueObject', 'Player', ammoObj)
    local pickRegion = world:CreateObject('Sphere', 'PickRegion', ammoObj)
    pickRegion.LocalPosition = Vector3.Zero
    pickRegion.Size = Vector3(self.distance * 2, self.distance * 2, self.distance * 2)
    pickRegion.Color = Color(0, 0, 0, 0)
    pickRegion.GravityEnable = false
    pickRegion.Block = false
    pickRegion.CollisionGroup = 3
    self.ammoList[uuid] = ammoObj
end

---读取配置表,创建配置表中的所有武器槽位
function WeaponMgr:CreateAllUnitSlot()
    local weaponSpawnConfig = {}
    local accSpawnConfig = {}
    local ammoSpawnConfig = {}
    for k, v in pairs(GunConfig.SpawnConfig) do
        if v.Usable then
            if v.Type == UnitTypeEnum.Weapon then
                weaponSpawnConfig[k] = v
            elseif v.Type == UnitTypeEnum.Accessory then
                accSpawnConfig[k] = v
            elseif v.Type == UnitTypeEnum.Ammo then
                ammoSpawnConfig[k] = v
            end
        end
    end
    for k, v in pairs(weaponSpawnConfig) do
        local node = world:CreateObject('NodeObject', 'WeaponSlotNode', self.weaponFolder)
        world:CreateObject('IntValueObject', 'ID', node).Value = v.UnitId
        world:CreateObject('Vector3ValueObject', 'Pos', node).Value = v.Position
        world:CreateObject('IntValueObject', 'AmmoCount', node).Value = v.Count
        world:CreateObject('EulerDegreeValueObject', 'Rot', node).Value = v.Rotation
        world:CreateObject('FloatValueObject', 'RespawnTime', node).Value = v.RespawnTime
        self:CreateWeapon(v.UnitId, v.Position, v.Rotation, node, v.Count)
        node.OnChildRemoved:Connect(function(_child)
            self:OnSlotChildRemoved(_child, node)
        end)
    end
    for k, v in pairs(accSpawnConfig) do
        local node = world:CreateObject('NodeObject', 'AccSlotNode', self.accFolder)
        world:CreateObject('IntValueObject', 'ID', node).Value = v.UnitId
        world:CreateObject('Vector3ValueObject', 'Pos', node).Value = v.Position
        world:CreateObject('EulerDegreeValueObject', 'Rot', node).Value = v.Rotation
        world:CreateObject('FloatValueObject', 'RespawnTime', node).Value = v.RespawnTime
        self:CreateWeaponAccessory(v.UnitId, v.Position, v.Rotation, node)
        node.OnChildRemoved:Connect(function(_child)
            self:OnSlotChildRemoved(_child, node)
        end)
    end
    for k, v in pairs(ammoSpawnConfig) do
        local node = world:CreateObject('NodeObject', 'AmmoSlotNode', self.ammoFolder)
        world:CreateObject('IntValueObject', 'ID', node).Value = v.UnitId
        world:CreateObject('IntValueObject', 'Count', node).Value = v.Count
        world:CreateObject('Vector3ValueObject', 'Pos', node).Value = v.Position
        world:CreateObject('EulerDegreeValueObject', 'Rot', node).Value = v.Rotation
        world:CreateObject('FloatValueObject', 'RespawnTime', node).Value = v.RespawnTime
        self:CreateWeaponAmmo(v.UnitId, v.Count, v.Position, v.Rotation, node)
        node.OnChildRemoved:Connect(function(_child)
            self:OnSlotChildRemoved(_child, node)
        end)
    end
end

---unit从槽位移除时候触发,延迟一定时间后在创建一个指定的对象
function WeaponMgr:OnSlotChildRemoved(_child, _node)
    local respawnTime = _node.RespawnTime.Value
    if respawnTime < 0 then
        return
    end
    if _node.Parent == self.weaponFolder then
        invoke(function()
            self:CreateWeapon(_node.ID.Value, _node.Pos.Value, _node.Rot.Value, _node, _node.AmmoCount.Value)
            world.Players:BroadcastEvent('CreateAllUnitEvent', self.weaponList, self.accessoryList, self.ammoList)
        end, respawnTime)
    elseif _node.Parent == self.accFolder then
        invoke(function()
            self:CreateWeaponAccessory(_node.ID.Value, _node.Pos.Value, _node.Rot.Value, _node)
            world.Players:BroadcastEvent('CreateAllUnitEvent', self.weaponList, self.accessoryList, self.ammoList)
        end, respawnTime)
    elseif _node.Parent == self.ammoFolder then
        invoke(function()
            self:CreateWeaponAmmo(_node.ID.Value,_node.Count.Value, _node.Pos.Value, _node.Rot.Value, _node)
            world.Players:BroadcastEvent('CreateAllUnitEvent', self.weaponList, self.accessoryList, self.ammoList)
        end, respawnTime)
    end
end

---玩家将一堆子弹全部拾取,需要将实体销毁
function WeaponMgr:DestroyAmmoEventHandler(_ammo)
    self.ammoList[_ammo.UUID.Value] = nil
    _ammo:Destroy()
end

---枪械击中角色后触发的事件,需要服务端进行一定的校验
function WeaponMgr:WeaponHitPlayerEventHandler(_msg)
    local msg = {}
    for k, v in pairs(_msg) do
		local shooter = v[1]
		local receiver = v[2]
		if(shooter.Health > 0 and receiver.Health > 0) then
			msg[receiver] = msg[receiver] or {}
			table.insert(msg[receiver], {shooter, v[3], v[4],v[5]})
		end
    end
	for k, v in pairs(msg) do
		k.C_Event.PlayerBeHitEvent:Fire(v)
	end
end

---玩家加入事件
function WeaponMgr:OnPlayerAdded(_player)
    print('玩家加入事件', _player)
    self.playerHaveAmmoList[_player] = {}
end

---玩家离开事件
function WeaponMgr:OnPlayerRemoved(_player)
    print('玩家离开事件', _player)
    ---将玩家身上的枪和配件卸下
    for k, v in pairs(self.weaponList) do
        if v.Player.Value == _player then
            v:SetActive(true)
            v:SetParentTo(world, v.Position, v.Rotation)
        end
    end
    for k, v in pairs(self.accessoryList) do
        if v.Player.Value == _player then
            v:SetActive(true)
            v:SetParentTo(world, v.Position, v.Rotation)
        end
    end
    for k, v in pairs(self.playerHaveAmmoList[_player]) do
        self:CreateWeaponAmmo(k, v, _player.Position)
    end
    world.Players:BroadcastEvent('CreateAllUnitEvent', self.weaponList, self.accessoryList, self.ammoList)
    self.playerHaveAmmoList[_player] = {}
end

---客户端请求创建子弹实体的事件
function WeaponMgr:CreateAmmoEventHandler(_id, _count, _pos, _rot)
    self:CreateWeaponAmmo(_id, _count, _pos, _rot)
    world.Players:BroadcastEvent('CreateAllUnitEvent', self.weaponList, self.accessoryList, self.ammoList)
end

---玩家拾取子弹的事件
function WeaponMgr:PlayerPickAmmoEventHandler(_player, _ammoList)
    if not self.playerHaveAmmoList[_player] then
        self.playerHaveAmmoList[_player] = {}
    end
    for k, v in pairs(_ammoList) do
        if not self.playerHaveAmmoList[_player][k] then
            self.playerHaveAmmoList[_player][k] = 0
        end
        self.playerHaveAmmoList[_player][k] = self.playerHaveAmmoList[_player][k] + v
        if self.playerHaveAmmoList[_player][k] <= 0 then
            self.playerHaveAmmoList[_player][k] = 0
        end
    end
end

---玩家身上的事件创建结束的事件
function WeaponMgr:PlayerEventCreateOverEventHandler(_player)
    _player.C_Event.CreateAllUnitEvent:Fire(self.weaponList, self.accessoryList, self.ammoList)
    --- 读取玩家数据
    DataMgr:LoadGameDataAsync(_player.UserId)
end

return WeaponMgr