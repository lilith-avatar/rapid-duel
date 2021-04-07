--- 游戏客户端主逻辑
--- @module Client Manager, Client-side
--- @copyright Lilith Games, Avatar Team
--- @author Yuancheng Zhang
local Client = {}

-- Localize global vars
local CsvUtil, XslUitl, ModuleUtil = CsvUtil, XslUitl, ModuleUtil
local Config = FrameworkConfig.Client

-- 已经初始化，正在运行
local initialized, running = false, false

-- 含有InitDefault(),Init(),Update()的模块列表
local initDefaultList, initList, updateList, fixUpdateList = {}, {}, {}, {}

--- 运行客户端
function Client:Run()
    print('[Client] Run()')
    InitClient()
    StartFixUpdate()
    StartUpdate()
end

--- 停止Update
function Client:Stop()
    print('[Client] Stop()')
    running = false
    ClientHeartbeat.Stop()
    QualityBalance.StopUpdate()
end

--- 初始化
function InitClient()
    if initialized then
        return
    end
    print('[Client] InitClient()')
    InitDebugUI()
    InitCamera()
    InitRandomSeed()
    InitHeartbeat()
    InitPlugin()
    InitClientCustomEvents()
    PreloadCsv()
    GenInitAndUpdateList()
    RunInitDefault()
    InitOtherModules()
    InitQualityBalance()
    initialized = true
end

---初始化调试UI
function InitDebugUI()
    DebugModeLogic.InitClient()
end

---初始化画质控制
function InitQualityBalance()
    QualityBalance.Init()
end

---初始化相机
function InitCamera()
    world.CurrentCamera = localPlayer.Local.Independent.CamGame
end

---初始化插件
function InitPlugin()
    PlayerGunMgr:Init()
end

--- 初始化心跳包
function InitHeartbeat()
    assert(ClientHeartbeat, '[Client][Heartbeat] 找不到ClientHeartbeat,请联系张远程')
    ClientHeartbeat.Init()
end

--- 初始化客户端的CustomEvent
function InitClientCustomEvents()
    if localPlayer.C_Event == nil then
        world:CreateObject('FolderObject', 'C_Event', localPlayer)
    end

    -- 将插件中的CustomEvent放入Events.ClientEvents中
    for _, m in pairs(Config.PluginEvents) do
        local evts = _G[m].ClientEvents
        assert(evts, string.format('[Client] %s 中不存在ClientEvents，请检查模块，或从FrameworkConfig删除此配置', m))
        for __, evt in pairs(evts) do
            if not table.exists(Events.ClientEvents, evt) then
                table.insert(Events.ClientEvents, evt)
            end
        end
    end

    -- 生成CustomEvent节点
    for _, evt in pairs(Events.ClientEvents) do
        if localPlayer.C_Event[evt] == nil then
            world:CreateObject('CustomEvent', evt, localPlayer.C_Event)
        end
    end
end

--- 生成需要Init和Update的模块列表
function GenInitAndUpdateList()
    ModuleUtil.GetModuleListWithFunc(Module.C_Module, 'InitDefault', initDefaultList)
    ModuleUtil.GetModuleListWithFunc(Module.C_Module, 'Init', initList)
    ModuleUtil.GetModuleListWithFunc(Module.C_Module, 'Update', updateList)
    ModuleUtil.GetModuleListWithFunc(Module.C_Module, 'FixUpdate', fixUpdateList)
    for _, m in pairs(Config.PluginModules) do
        ModuleUtil.GetModuleListWithFunc(m, 'InitDefault', initDefaultList)
        ModuleUtil.GetModuleListWithFunc(m, 'Init', initList)
        ModuleUtil.GetModuleListWithFunc(m, 'Update', updateList)
    end
end

--- 执行默认的Init方法
function RunInitDefault()
    for _, m in ipairs(initDefaultList) do
        m:InitDefault(m)
    end
end

--- 初始化客户端随机种子
function InitRandomSeed()
    math.randomseed(os.time())
end

--- 预加载所有的CSV表格
function PreloadCsv()
    print('[Client] PreloadCsv()')
    if Config.ClientPreload and #Config.ClientPreload > 0 then
        CsvUtil.PreloadCsv(Config.ClientPreload, Csv, Config)
    end
end

--- 初始化包含Init()方法的模块
function InitOtherModules()
    SoundUtil:Init()
    for _, m in ipairs(initList) do
        m:Init()
    end
    AnimationMain:Init()
end

function StartFixUpdate()
    world.OnRenderStepped:Connect(Client.FixUpdateClient)
end

--- 开始Update
function StartUpdate()
    print('[Client] StartUpdate()')
    assert(not running, '[Client] StartUpdate() 正在运行')

    running = true

    -- 开启心跳
    if FrameworkConfig.HeartbeatStart then
        invoke(ClientHeartbeat.Start)
    end

    QualityBalance.StartUpdate()

    local dt = 0 -- delta time 每帧时间
    local tt = 0 -- total time 游戏总时间
    local now = Timer.GetTimeMillisecond --时间函数缓存
    local prev, curr = now() / 1000, nil -- two timestamps

    while (running and wait()) do
        curr = now() / 1000
        dt = curr - prev
        tt = tt + dt
        prev = curr
        UpdateClient(dt, tt)
    end
end

--- Update函数
-- @param dt delta time 每帧时间
function UpdateClient(_dt, _tt)
    for _, m in ipairs(updateList) do
        m:Update(_dt, _tt)
    end
end

---FixUpdate函数
function Client.FixUpdateClient(_dt)
    AnimationMain:FixUpdate(_dt)
    for _, m in ipairs(fixUpdateList) do
        m:FixUpdate(_dt)
    end
    for i, v in pairs(UIBase.uiList) do
        if v.Update then
            v:Update(_dt)
        end
    end
end

return Client
