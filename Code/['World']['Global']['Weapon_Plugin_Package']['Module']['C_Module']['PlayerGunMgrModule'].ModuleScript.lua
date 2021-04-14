--- @module PlayerGunMgr 枪械模块：玩家端的枪械管理模块.处理玩家的输入等
--- @copyright Lilith Games, Avatar Team
--- @author Sharif Ma
local PlayerGunMgr, this =
    {
        --- @type table 本玩家的数据
        myData = {}
    },
    nil

---枪械的客户端事件名称
local _CLIENT_EVENT_ = {
    'PlayerBeHitEvent',
    'PlayerNearWeaponEvent',
    'PlayerFarWeaponEvent',
    'PlayerNearWeaponAccessoryEvent',
    'PlayerFarWeaponAccessoryEvent',
    'PlayerNearAmmoEvent',
    'PlayerFarAmmoEvent',
    'PlayerDieEvent',
    'CreateAllUnitEvent',
    'SettingAssAimRefreshEvent',
    'SyncDataEvent',
    'OnEquipWeaponEvent',
    'SettingReadyEvent',
    'WeaponObjCreatedEvent',
    'WeaponObjActiveChangeEvent'
}
local waitTime, damageQueue, consumeAmmoQueue = 0.1, {}, {}

---按键输入事件 按下
local function OnKeyDown()
    if localPlayer.Health <= 0 then
        return
    end
    if Input.GetPressKeyData(Enum.KeyCode.LeftAlt) == Enum.KeyState.KeyStatePress then
        ---显示鼠标
        local camera = world.CurrentCamera
        --camera.EnableMouseDrag = false
        camera.CursorLock = false
        camera.CursorDisplay = true
    end
    if not PlayerGunMgr.curGun then
        return
    end
    if localPlayer.Health <= 0 then
        return
    end
    if Input.GetPressKeyData(Enum.KeyCode.Mouse2) ~= Enum.KeyState.KeyStateNone then
        PlayerGunMgr.curGun:TryFireOneBullet()
    end
    if Input.GetPressKeyData(Enum.KeyCode.R) ~= Enum.KeyState.KeyStateNone then
        ---尝试换子弹
        PlayerGunMgr.curGun:LoadMagazine()
    end
    if Input.GetPressKeyData(Enum.KeyCode.Mouse1) == Enum.KeyState.KeyStatePress then
        ---尝试开镜
        PlayerGunMgr.curGun:MechanicalAimStart()
    end
    --[[
    if Input.GetPressKeyData(Enum.KeyCode.Mouse0) == Enum.KeyState.KeyStatePress then
        ---开始拖动屏幕
        PlayerGunMgr.curGun.m_cameraControl:DragStart()
    end]]
end

---按键输入事件 按住
local function OnKeyHold()
    if localPlayer.Health <= 0 then
        return
    end
    if not PlayerGunMgr.curGun then
        return
    end

    if Input.GetPressKeyData(Enum.KeyCode.Mouse2) ~= Enum.KeyState.KeyStateNone then
        if localPlayer.Health <= 0 then
            return
        end
        ---尝试保持射击
        PlayerGunMgr.curGun:TryKeepFire()
    end
    if Input.GetPressKeyData(Enum.KeyCode.Mouse0) ~= Enum.KeyState.KeyStateNone then
        if localPlayer.Health <= 0 then
            ---结束拖动屏幕
            PlayerGunMgr.curGun.m_cameraControl:DragEnd()
            return
        end
    ---中键拖动屏幕
    --PlayerGunMgr.curGun.m_cameraControl:DragHold()
    end
end

---按键输入事件 抬起
local function OnKeyUp()
    if Input.GetPressKeyData(Enum.KeyCode.LeftAlt) == Enum.KeyState.KeyStateRelease then
        ---不显示鼠标
        local camera = world.CurrentCamera
        camera.CursorDisplay = false
        camera.CursorLock = true
    --camera.EnableMouseDrag = true
    end
    if not PlayerGunMgr.curGun then
        return
    end
    if Input.GetPressKeyData(Enum.KeyCode.Mouse1) == Enum.KeyState.KeyStateRelease then
        ---尝试离开瞄准
        PlayerGunMgr.curGun:MechanicalAimStop()
    end
    --[[if Input.GetPressKeyData(Enum.KeyCode.Mouse0) == Enum.KeyState.KeyStateRelease then
        ---结束拖动屏幕
        PlayerGunMgr.curGun.m_cameraControl:DragEnd()
    end--]]
    if Input.GetPressKeyData(Enum.KeyCode.Mouse2) ~= Enum.KeyState.KeyStateNone then
        ---尝试拉栓(只有配置了拉栓并且在开镜状态时候才会响应此函数)
        PlayerGunMgr.curGun:TryPump()
    end
end

---开始装弹的回调
local function StartReload()
    --print('开始装弹')
end

---开始开火的回调
local function StartFire()
end

---开了一枪的回调
local function Fired()
end

---停止开火的回调
local function StopFire()
end

---装满子弹时的回调
local function FullyLoaded()
end

---开始装弹时的回调
local function BulletLoadStarted()
    --print('开始装弹时的回调')
end

---每发子弹上弹时的回调
local function BulletLoaded()
    --print('每发子弹上弹时的回调')
end

---放空枪时候的回调
local function EmptyFire()
    --print('放空枪时候的回调')
end

local function SuccessfullyHit(_sender, _infoList)
    if GunConfig.GlobalConfig.EnableHitCallBack then
        PlayerMgr:SuccessHitCallBack(_sender, _infoList)
    end
end

---击中靶子的回调
local function SuccessfullyHitTarget(_sender, _infoList)
    HallInteractObj:HitTargetCallback(_infoList)
end

---客户端模块加载
local function ModuleRequire()
    _G.Local = {}
    for k, v in pairs(PluginRoot.Module.C_Module:GetChildren()) do
        local moduleName = string.sub(v.Name, 1, string.len(v.Name) - 6)
        if not _G[moduleName] then
            _G[moduleName] = require(v)
            _G.Local[moduleName] = _G[moduleName]
        end
    end
    for k, v in pairs(PluginRoot.Module.Cls_Module:GetChildren()) do
        local moduleName = string.sub(v.Name, 1, string.len(v.Name) - 6)
        if not _G[moduleName] then
            _G[moduleName] = require(v)
        end
    end
    GunBase.static.utility = GunUtility:new()
end

---模块初始化函数
function PlayerGunMgr:Init()
    this = self
    ModuleRequire()
    self:InitListeners()
    ---@type PlayerInstance 当前的玩家对象
    self.player = localPlayer
    ---当前画质
    self.quality = QualityBalance.QualityEnum.High
    ---播放其他玩家音频的cd
    self.canPlayOtherSoundCD = true
    ---@type GunBase 角色当前的枪
    self.curGun = nil

    ---@type GunBase 角色的主枪
    self.mainGun = nil
    ---@type GunBase 角色的副枪
    self.deputyGun = nil
    ---@type GunBase 角色的手枪
    self.miniGun = nil
    ---@type GunBase 角色的一号道具
    self.prop1 = nil
    ---@type GunBase 角色的一号道具
    self.prop2 = nil

    ---玩家目前拥有的配件列表,存储配件实体类
    self.hadAccessoryList = {}
    ---玩家当前拥有的子弹类列表
    self.hadAmmoList = {}

    self.canUpdateGun = true

    ---切枪按钮事件的绑定
    Input.OnKeyDown:Connect(
        function()
            if Input.GetPressKeyData(Enum.KeyCode.One) == Enum.KeyState.KeyStatePress then
                self:SwitchWeapon(1)
            end
            if Input.GetPressKeyData(Enum.KeyCode.Two) == Enum.KeyState.KeyStatePress then
                self:SwitchWeapon(2)
            end
            if Input.GetPressKeyData(Enum.KeyCode.Three) == Enum.KeyState.KeyStatePress then
                self:SwitchWeapon(3)
            end
            if Input.GetPressKeyData(Enum.KeyCode.Four) == Enum.KeyState.KeyStatePress then
                self:SwitchWeapon(4)
            end
            if Input.GetPressKeyData(Enum.KeyCode.Five) == Enum.KeyState.KeyStatePress then
                self:SwitchWeapon(5)
            end
            if Input.GetPressKeyData(Enum.KeyCode.X) == Enum.KeyState.KeyStatePress then
            ---self:SwitchWeapon(0)
            end
            if Input.GetPressKeyData(Enum.KeyCode.G) == Enum.KeyState.KeyStatePress then
            ---self:DropWeapon()
            end
            if Input.GetPressKeyData(Enum.KeyCode.B) == Enum.KeyState.KeyStatePress then
                self:ChangeShootMode()
            end
        end
    )

    ---绑定按钮输入事件
    Input.OnKeyDown:Connect(OnKeyDown)
    Input.OnKeyHold:Connect(OnKeyHold)
    Input.OnKeyUp:Connect(OnKeyUp)

    ---玩家自身的爆头判定区域和身体判定区域初始化
    world:CreateInstance('HeadPoint', 'HeadPoint', localPlayer.Avatar.Bone_Head).LocalPosition =
        Vector3(-0.229, 0.032, 0)
    world:CreateInstance('BodyPoint', 'BodyPoint', localPlayer.Avatar.Bone_Pelvis).LocalPosition =
        Vector3(-0.1684, 0, 0)
    world:CreateInstance('LimbPoint', 'LimbPoint', localPlayer.Avatar.Bone_Pelvis).LocalPosition = Vector3(0.391, 0, 0)

    self:ModulesInit()
    -- TODO: 所有模块完成初始化后开始每个模块的更新
    ---保证服务端事件生成成功之后再发事件过去
    if world.S_Event and world.S_Event.PlayerEventCreateOverEvent then
        world.S_Event.PlayerEventCreateOverEvent:Fire(localPlayer)
    else
        invoke(
            function()
                while not world.S_Event or not world.S_Event.PlayerEventCreateOverEvent do
                    wait()
                end
                world.S_Event.PlayerEventCreateOverEvent:Fire(localPlayer)
            end
        )
    end
    invoke(
        function()
            self:StartUpdate()
        end
    )
    ---玩家死亡时候尝试停止一切操作
    localPlayer.OnDead:Connect(
        function()
            self.canUpdateGun = false
            if not self.curGun then
                return
            end
            ---尝试离开瞄准
            PlayerGunMgr.curGun:MechanicalAimStop()
            ---结束拖动屏幕
            PlayerGunMgr.curGun.m_cameraControl:DragEnd()
        end
    )
    ---玩家重生后尝试更新枪械
    localPlayer.OnSpawn:Connect(
        function()
            wait(0.2)
            self.canUpdateGun = true
        end
    )

    localPlayer.Avatar:SetBlendSubtree(Enum.BodyPart.UpperBody, 4)
    localPlayer.Avatar:SetBlendSubtree(Enum.BodyPart.UpperBody, 5)
    localPlayer.Avatar:SetBlendSubtree(Enum.BodyPart.UpperBody, 6)
end

---枪械模块自用上行函数,用于子弹命中的Fire
function PlayerGunMgr:FireGunDamage(...)
    local content = {...}
    table.insert(damageQueue, content)
end

---枪械模块自用上行函数,用于子弹消耗的fire
function PlayerGunMgr:FireConsumeAmmo(_ammoId, _count)
    if not consumeAmmoQueue[_ammoId] then
        consumeAmmoQueue[_ammoId] = 0
    end
    consumeAmmoQueue[_ammoId] = consumeAmmoQueue[_ammoId] + _count
end

function PlayerGunMgr:InitListeners()
    if localPlayer.C_Event == nil then
        world:CreateObject('FolderObject', 'C_Event', localPlayer)
    end
    for _, v in pairs(_CLIENT_EVENT_) do
        local event_C = localPlayer.C_Event[v]
        if event_C == nil then
            event_C = world:CreateObject('CustomEvent', v, localPlayer.C_Event)
        end
    end
    LinkConnects(localPlayer.C_Event, PlayerGunMgr, this)
end

function PlayerGunMgr:ModulesInit()
    for k, v in pairs(_G.Local) do
        if v ~= self and v.Init then
            v:Init()
        end
    end
end

function PlayerGunMgr:ModulesUpdate(_dt)
    for k, v in pairs(_G.Local) do
        if v ~= self and v.Update then
            v:Update(_dt)
        end
    end
end

function PlayerGunMgr:StartUpdate()
    if self.isRun then
        return
    end

    self.isRun = true
    world.OnRenderStepped:Connect(
        function(_dt)
            self:FixUpdate(_dt)
        end
    )
    local time = Timer.GetTimeMillisecond
    local prevTime, nowTime = time() / 1000, nil -- two timestamps
    while (self.isRun and wait()) do
        nowTime = time() / 1000
        self.dt = nowTime - prevTime
        self:Update(self.dt)
        prevTime = nowTime
    end
end

---Update函数
---@param dt number delta time 每帧时间
---@param tt number total time 总时间
function PlayerGunMgr:Update(dt, tt)
    if self.curGun and self.curGun.m_isDraw and self.canUpdateGun then
        self.curGun:Update(dt)
    end
    self:ModulesUpdate(dt)
end

---FixUpdate函数
function PlayerGunMgr:FixUpdate(_dt)
    if self.curGun and self.curGun.m_isDraw then
        self.curGun:FixUpdate(_dt)
    end
    CameraControl:FixUpdate(_dt)
    waitTime = waitTime - _dt
    if waitTime <= 0 then
        waitTime = 0.1
        if #damageQueue > 0 then
            world.S_Event.WeaponHitPlayerEvent:Fire(damageQueue)
        end
        damageQueue = {}
    --[[local isEmpty = true
        for k, v in pairs(consumeAmmoQueue) do
            isEmpty = false
        end
        if not isEmpty then
            world.S_Event.PlayerPickAmmoEvent:Fire(localPlayer, consumeAmmoQueue)
            consumeAmmoQueue = {}
        end]]
    end
    local fixDt = _dt
    BattleGUI:FixUpdate(_dt)
end

---玩家点击按钮拾取一个武器
function PlayerGunMgr:PickWeapon(_pickGun)
    if not _pickGun or _pickGun:IsNull() then
        return
    end
    if _pickGun.Player.Value then
        return
    end
    ---手动设置武器的父物体为玩家节点
    _pickGun:SetParentTo(localPlayer.Avatar[_pickGun.Bone], _pickGun.AttachPos, _pickGun.AttachRot)
    local tryPickGunPosition = GunConfig.GunConfig[_pickGun.ID.Value].CanBeEquipPosition
    local targetPosition
    local curIndex = self:GetCurGunIndex()
    if tryPickGunPosition == CanBeEquipPositionEnum.MainOrDeputy then
        ---当前尝试拾取的枪位置是左边两个
        if self.curGun then
            if self.curGun.m_isDraw then
                ---当前有枪并且是掏枪状态
                if self.curGun.canBeEquipPosition == CanBeEquipPositionEnum.MainOrDeputy then
                    if self.mainGun == self.curGun then
                        if not self.deputyGun then
                            targetPosition = 2
                        else
                            targetPosition = 1
                            self:DropWeapon()
                        end
                    else
                        if not self.mainGun then
                            targetPosition = 1
                        else
                            targetPosition = 2
                            self:DropWeapon()
                        end
                    end
                else
                    if self.mainGun and self.deputyGun then
                        targetPosition = 1
                        ---丢弃主枪
                        print('丢弃主枪')
                        self:DropWeapon(self.mainGun)
                    elseif self.mainGun and not self.deputyGun then
                        ---丢弃副枪
                        targetPosition = 2
                    else
                        ---丢弃主枪
                        targetPosition = 1
                    end
                end
            else
                ---收枪状态
                if self.mainGun and self.deputyGun then
                    if self.mainGun == self.curGun then
                        targetPosition = 1
                        print('装备的位置是主枪位置')
                    else
                        targetPosition = 2
                        print('装备的位置是副枪位置')
                    end
                    if self.curGun.canBeEquipPosition == CanBeEquipPositionEnum.MainOrDeputy then
                        self:DropWeapon()
                    end
                elseif self.mainGun and not self.deputyGun then
                    targetPosition = 2
                else
                    targetPosition = 1
                end
            end
        else
            targetPosition = 1
        end
    elseif tryPickGunPosition == CanBeEquipPositionEnum.Mini then
        ---当前尝试拾取手枪
        print('当前尝试拾取手枪')
        if self.curGun then
            if self.curGun == self.miniGun then
                self:DropWeapon()
            elseif self.curGun ~= self.miniGun and self.miniGun then
                self:DropWeapon(self.miniGun)
            end
        else
        end
        targetPosition = 3
    else
        ---当前尝试拾取道具位置
        print('当前尝试拾取道具')
        if self.prop1 then
            targetPosition = 5
        else
            targetPosition = 4
        end
    end

    ---实例化一个枪械类
    local usedClass = GunConfig.GunConfig[_pickGun.ID.Value].UsedClass
    if _G[usedClass] == nil then
        error(usedClass, 'not exist')
    end
    ---@type GunBase
    local gun = _G[usedClass]:new(self.player, self.player.Avatar.Bone_R_Hand, _pickGun)
    --, {Origin = GetOrigin, Target = GetTarget})
    if targetPosition == 1 then
        self.mainGun = gun
        self.mainGun.m_animationControl:SetLayer(4)
    elseif targetPosition == 2 then
        self.deputyGun = gun
        self.mainGun.m_animationControl:SetLayer(5)
    elseif targetPosition == 3 then
        self.miniGun = gun
        self.miniGun.m_animationControl:SetLayer(6)
    elseif targetPosition == 4 then
        self.prop1 = gun
        self.prop1.m_animationControl:SetLayer(7)
    elseif targetPosition == 5 then
        self.prop2 = gun
        self.prop2.m_animationControl:SetLayer(8)
    end
    if targetPosition == curIndex or curIndex == -1 then
        self.curGun = gun
        self.curGun:DrawGun()
    end

    ---绑定枪械自身自定义事件---
    ---开始装弹
    gun.magazineLoadStarted:Bind(StartReload)
    ---装满子弹时的回调
    gun.fullyLoaded:Bind(FullyLoaded)
    ---开始装弹时的回调
    gun.bulletLoadStarted:Bind(BulletLoadStarted)
    ---每发子弹上弹时的回调
    gun.bulletLoaded:Bind(BulletLoaded)
    gun.reloadFinished:Bind(
        function()
            --print('上弹完成')
        end
    )
    ---拉枪栓的回调
    gun.pumpStarted:Bind(
        function()
            --print('拉枪栓的回调')
        end
    )
    ---拉完枪栓的回调
    gun.pumped:Bind(
        function()
            --print('拉完枪栓的回调')
        end
    )
    gun.aimIn:Bind(
        function()
        end
    )
    ---开了一枪后的回调
    gun.fired:Bind(Fired)
    ---放空枪时候的回调
    gun.emptyFire:Bind(EmptyFire)
    ---开始开火回调
    gun.fireStarted:Bind(StartFire)
    ---停止开火的事件
    gun.fireStopped:Bind(StopFire)
    ---击中的回调
    gun.successfullyHit:Bind(SuccessfullyHit)
    ---击中靶子的回调
    gun.successfullyHitTarget:Bind(SuccessfullyHitTarget)
    ---调用玩家远离一把枪的事件
    world.Players:BroadcastEvent('PlayerFarWeaponEvent', _pickGun)
    invoke(
        function()
            localPlayer.C_Event.OnEquipWeaponEvent:Fire()
            BottomGUI:UpdateList(gun, targetPosition)
            BagGUI:EquipWeapon(targetPosition)
        end
    )
end

---将当前的枪脱下的事件
---@param _gun GunBase 枪实体
function PlayerGunMgr:OnUnEquipWeaponEvent(_gun)
    local unEquipGunIndex
    if _gun == self.mainGun then
        self.mainGun = nil
        unEquipGunIndex = 1
    elseif _gun == self.deputyGun then
        self.deputyGun = nil
        unEquipGunIndex = 2
    elseif _gun == self.miniGun then
        self.miniGun = nil
        unEquipGunIndex = 3
    elseif _gun == self.prop1 then
        self.prop1 = nil
        unEquipGunIndex = 4
    elseif _gun == self.prop2 then
        self.prop2 = nil
        unEquipGunIndex = 5
    end
    BottomGUI:UpdateList(nil, unEquipGunIndex)
    BagGUI:UnEquipWeapon(unEquipGunIndex)
    BattleGUI:OnUnEquipWeaponEvent()
    if _gun == self.curGun then
        if self.mainGun then
            self.curGun = self.mainGun
        elseif self.deputyGun then
            self.curGun = self.deputyGun
        elseif self.miniGun then
            self.curGun = self.miniGun
        elseif self.prop1 then
            self.curGun = self.prop1
        elseif self.prop2 then
            self.curGun = self.prop2
        else
            self.curGun = nil
        end
        _gun:WithdrawGun()
    end
    ---析构这个枪械类
    _gun:Destructor()
    _gun = nil
end

---将一把枪切换到另一把枪,不会析构切换的枪械类
---@param _targetIndex number 要切换的枪的索引,0表示收枪/掏枪
function PlayerGunMgr:SwitchWeapon(_targetIndex)
    if localPlayer.Health <= 0 then
        return
    end
    if _targetIndex < 0 then
        return
    end
    if _targetIndex == 0 then
        ---收枪/掏枪,此游戏中屏蔽收枪
        --self:WithdrawWeapon()
    else
        local targetGun = nil
        if _targetIndex == 1 then
            targetGun = self.mainGun
        elseif _targetIndex == 2 then
            targetGun = self.deputyGun
        elseif _targetIndex == 3 then
            targetGun = self.miniGun
        elseif _targetIndex == 4 then
            targetGun = self.prop1
        elseif _targetIndex == 5 then
            targetGun = self.prop2
        end

        if targetGun == nil then
            return
        elseif targetGun == self.curGun then
            ---切换到当前的枪,表示收枪,此游戏中屏蔽收枪
            --self:WithdrawWeapon()
        else
            ---切换到指定索引的枪
            if self.curGun and self.curGun.m_isDraw then
                self:TurnGun(self.curGun, targetGun)
            else
                self.curGun = targetGun
                self.curGun:DrawGun()
            end
            BagGUI:SwitchWeapon(_targetIndex)
        end
    end
    BattleGUI:WithDrawOrNot()
    DebugGUI:SwitchWeapon()
end

---换枪，绕行方案,避免渲染
function PlayerGunMgr:TurnGun(_curGun, _tarGun)
    local pitch = _curGun.m_cameraControl.m_theta
    local yaw = _curGun.m_cameraControl.m_phy
    self.curGun:WithdrawGun()
    self.curGun = _tarGun
    _tarGun:DrawGun({theta = pitch, phy = yaw})
end

---收枪/掏枪逻辑
function PlayerGunMgr:WithdrawWeapon()
    if not self.curGun then
        return
    end
    ---当前持有一把武器
    if (self.curGun.m_isDraw) then
        self.curGun:WithdrawGun()
    else
        self.curGun:DrawGun()
    end
end

---玩家被打中的事件  伤害的发起者  伤害来源的枪械  伤害的数值  伤害部位
function PlayerGunMgr:PlayerBeHitEventHandler(_msg)
    if PlayerOccLogic.invincible then
        return
    end
    for k, v in pairs(_msg) do
        if v[4] == HitPartEnum.Fort then
            ---伤害类型为炮台受到的伤害
            print('你的炮台受击', table.unpack(v))
            ---@type FortBase
            local fortIns = self.mainGun.m_fort or self.deputyGun.m_fort or self.miniGun.m_fort
            if fortIns.m_hp then
                fortIns:BitHit(v[1], v[2], v[3])
            end
        else
            if localPlayer.Health <= 0 then
                goto Continue
            end
            if v[1].Health <= 0 then
                ---伤害发起者已经死亡则不响应此次伤害
                goto Continue
            end
            ---print('玩家', v[1], '打中你了,你受到伤害为,', v[3])
            localPlayer.Health = localPlayer.Health - v[3]
            ---print(localPlayer.Health)
            if localPlayer.Health <= 0 then
                ---自己死亡
                ---print('广播自己死亡事件')
                --- v[1]击杀者 v[2]枪械ID v[4]击杀部位
                world.Players:BroadcastEvent('PlayerDieEvent', v[1], localPlayer, v[2], v[4])
                world.S_Event:BroadcastEvent('PlayerDieEvent', v[1], localPlayer, v[2], v[4])
            end
        end
        ::Continue::
    end
end

---玩家点击按钮尝试丢弃一个武器
---@param _gunCls GunBase
function PlayerGunMgr:DropWeapon(_gunCls)
    if _gunCls then
        _gunCls.gun:SetParentTo(world.Weapons, _gunCls.character.Position, EulerDegree(0, 0, 0))
        self:OnUnEquipWeaponEvent(_gunCls)
    elseif self.curGun then
        self.curGun.gun:SetParentTo(world.Weapons, self.curGun.character.Position, EulerDegree(0, 0, 0))
        self:OnUnEquipWeaponEvent(self.curGun)
    end
end

---玩家尝试更换射击模式
function PlayerGunMgr:ChangeShootMode()
    if self.curGun then
        ---尝试更改当前射击模式,成功则返回新的射击模式,失败nil
        return self.curGun:ChangeShootMode()
    end
end

---获取指定枪的索引
function PlayerGunMgr:GetIndexByWeapon(_weapon)
    if not _weapon then
        return -1
    end
    if _weapon == self.mainGun then
        return 1
    elseif _weapon == self.deputyGun then
        return 2
    elseif _weapon == self.miniGun then
        return 3
    elseif _weapon == self.prop1 then
        return 4
    elseif _weapon == self.prop2 then
        return 5
    end
end

---获取当前持有的枪的索引
function PlayerGunMgr:GetCurGunIndex()
    if not self.curGun then
        return -1
    end
    if self.curGun == self.mainGun then
        return 1
    elseif self.curGun == self.deputyGun then
        return 2
    elseif self.curGun == self.miniGun then
        return 3
    elseif self.curGun == self.prop1 then
        return 4
    elseif self.curGun == self.prop2 then
        return 5
    end
end

---玩家点击按钮尝试拾取一个配件
function PlayerGunMgr:PickAccessory(_pickAccessory)
    if _pickAccessory.Player.Value then
        return
    end
    ---手动设置配件的父节点为玩家节点并隐藏
    _pickAccessory:SetActive(false)
    _pickAccessory:SetParentTo(localPlayer, Vector3.Zero, EulerDegree(0, 0, 0))
    ---实例化一个配件类
    local accessoryObj = WeaponAccessoryBase:new(_pickAccessory)
    self.hadAccessoryList[_pickAccessory.UUID.Value] = accessoryObj
    world.Players:BroadcastEvent('PlayerFarWeaponAccessoryEvent', _pickAccessory)
    self:TryEquipAccessoryToWeapon(accessoryObj, self.curGun)
end

---玩家点击按钮丢弃一个配件
---@param _accessoryCls WeaponAccessoryBase
function PlayerGunMgr:DropAccessory(_accessoryCls)
    if _accessoryCls == nil then
        return
    end
    local uuid = _accessoryCls.uuid
    _accessoryCls.weaponAccessory:SetActive(true)
    _accessoryCls.weaponAccessory:SetParentTo(
        world.Accessories,
        localPlayer.Position,
        _accessoryCls.weaponAccessory.Rotation
    )
    local equipWeapon = self.hadAccessoryList[uuid].m_equippedWeapon
    if equipWeapon then
        ---配件当前装备在一个枪上,需要先从枪上脱下来
        equipWeapon:UnEquipAccessory(self.hadAccessoryList[uuid])
        BagGUI:UnEquipAccessory(self.hadAccessoryList[uuid], equipWeapon)
    end
    self.hadAccessoryList[uuid]:Destructor()
    self.hadAccessoryList[uuid] = nil
end

---玩家点击按钮拾取子弹
function PlayerGunMgr:PickAmmo(_ammo)
    if _ammo.Player.Value then
        return
    end
    local id = _ammo.ID.Value
    world.Players:BroadcastEvent('PlayerFarAmmoEvent', _ammo)
    if self.hadAmmoList[id] then
        ---这个子弹在玩家身上已经有了
        self.hadAmmoList[id]:PlayerPickAmmo(_ammo, _ammo.Count.Value)
    else
        ---这个子弹是玩家首次拾取的
        local ammoObj = WeaponAmmoBase:new(id, _ammo.Count.Value, localPlayer)
        self.hadAmmoList[id] = ammoObj
    end
    world.S_Event.PlayerPickAmmoEvent:Fire(localPlayer, {[id] = _ammo.Count.Value})
end

---玩家丢弃子弹
---@param _ammoCls WeaponAmmoBase
function PlayerGunMgr:DropAmmo(_ammoCls, _count)
    if _ammoCls then
        _ammoCls:PlayerDropAmmo(_count)
    end
end

---玩家尝试装备一个配件到武器上
---@param _accessoryCls WeaponAccessoryBase 尝试装备的配件
---@param _gunCls GunBase 目标的枪械
function PlayerGunMgr:TryEquipAccessoryToWeapon(_accessoryCls, _gunCls)
    if not (_accessoryCls and _gunCls) then
        return
    end
    ---@type GunBase 配件原本在的枪械
    local originWeapon = _accessoryCls.m_equippedWeapon
    ---检测目标枪械的目标位置是否可以装备此配件
    local canBeEquip, originAccessory = _gunCls:EquipAccessory(_accessoryCls)
    if canBeEquip then
        BagGUI:EquipAccessory(_accessoryCls, _gunCls)
        ---目标可以被装备(此时配件已经被装备到目标上了)
        if originWeapon then
            ---配件原本已经装备在一个武器上了.需要卸载
            originWeapon:UnEquipAccessory(_accessoryCls)
            BagGUI:UnEquipAccessory(_accessoryCls, originWeapon)
            if originAccessory then
                ---目标位置已经有一个配件了,尝试更换到原本的枪上
                if originWeapon:EquipAccessory(originAccessory) then
                    BagGUI:EquipAccessory(originAccessory, originWeapon)
                else
                    _gunCls:UnEquipAccessory(originAccessory)
                    BagGUI:UnEquipAccessory(originAccessory, _gunCls)
                end
            end
        else
            if originAccessory then
                ---目标位置已经有一个配件了,将这个配件卸下
                originAccessory:UnEquipFromWeapon()
            end
        end
    else
        ---目标不能被装备
        print('配件不能被装备到目标上')
        return false
    end
end

---玩家尝试将一个配件卸下
---@param _accessoryCls WeaponAccessoryBase 尝试装备的配件
---@param _gunCls GunBase 目标的枪械
function PlayerGunMgr:TryUnEquipAccessoryFromWeapon(_accessoryCls, _gunCls)
    if not (_accessoryCls and _gunCls) then
        return
    end
    _gunCls:UnEquipAccessory(_accessoryCls)
    BagGUI:UnEquipAccessory(_accessoryCls, _gunCls)
end

---主副枪交换
function PlayerGunMgr:Main_DeputyWeapon()
    self.mainGun, self.deputyGun = self.deputyGun, self.mainGun
    self.mainGun.m_animationControl:SetLayer(4)
    self.deputyGun.m_animationControl:SetLayer(5)
end

--- 玩家数据接收
--- 接收服务器同其向客户端同步数据的信息
function PlayerGunMgr:SyncDataEventHandler(_data)
    for k, v in pairs(_data) do
        self.myData[k] = v
        print(k, v)
    end
end

---其他玩家对象创建事件
function PlayerGunMgr:WeaponObjCreatedEventHandler(_obj, _infoList)
    if not _obj then
        return
    end
    for i, v in pairs(_infoList) do
        _obj[i] = v
    end
end

---其他玩家发送对象激活或者取消激活事件,根据本地的画质进行选择过滤
---@param _obj Object 操作的对象
---@param _active boolean 激活或取消
---@param _objType number 对象的类型枚举值
function PlayerGunMgr:WeaponObjActiveChangeEventHandler(_obj, _active, _objType, _posOrVolume)
    local isAllow = true
    if _objType then
        isAllow = GunBase.static.utility:GetActiveByQuality(_objType, self.quality)
    end
    isAllow = not _active and true or isAllow
    if not isAllow then
        return
    end
    if _obj and not _obj:IsNull() then
        if _objType == ObjectTypeEnum.Sound then
            if _active then
                local dis = _obj.Position - localPlayer.Position
                dis = dis.Magnitude
                local volume
                if _obj.MinDistance >= dis then
                    volume = _obj.Volume
                elseif _obj.MaxDistance <= dis then
                    volume = 0
                else
                    volume =
                        _posOrVolume - _posOrVolume * (dis - _obj.MinDistance) / (_obj.MaxDistance - _obj.MinDistance)
                end
                volume = math.floor(volume)
                --print(volume, _obj.MaxDistance, _obj.MinDistance, dis)
                NotReplicate(
                    function()
                        --_obj:SetActive(_active)
                        _obj.Volume = volume
                        _obj:Play()
                    end
                )
            else
                NotReplicate(
                    function()
                        --_obj:SetActive(false)
                        _obj:Stop()
                    end
                )
            end
        else
            local pos = _active and _posOrVolume or Vector3.One * 10000
            NotReplicate(
                function()
                    _obj.Position = pos
                end
            )
            wait()
            NotReplicate(
                function()
                    _obj:SetActive(true)
                end
            )
        end
    end
end

---画质改变
function PlayerGunMgr:QualityChange(_new)
    self.quality = _new
end

return PlayerGunMgr
