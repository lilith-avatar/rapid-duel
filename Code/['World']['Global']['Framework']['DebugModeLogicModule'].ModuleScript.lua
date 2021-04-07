--- @module DebugModeLogic
--- @copyright Lilith Games, Avatar Team
--- @author Sharif Ma
local DebugModeLogic = {}

--- 初始化
function DebugModeLogic.InitHook()
    HookFunc()
end

function DebugModeLogic.InitClient()
    InitClientLogic()
end

--- 显示报错信息
---@param _location number 报错位置
---@param _content string 报错信息
function ErrorShow(_location, _content)
    local self = DebugModeLogic
    if self.root.Bg.ActiveSelf then
        return
    end
    local locationStr = ''
    if _location == Const.ErrorLocationEnum.Client then
        locationStr = 'Client'
    elseif _location == Const.ErrorLocationEnum.Server then
        locationStr = 'Server'
    end
    self.locationTxt.Text = locationStr
    self.contentTxt.Text = _content
    self.root.Bg:SetActive(true)
end

---显示当前游戏未结束
function StillInGameShow()
    local self = DebugModeLogic
    self.stillInGameRoot:SetActive(true)
end

function InitEvent()
    if localPlayer.C_Event == nil then
        world:CreateObject('FolderObject', 'C_Event', localPlayer)
    end
    local event = world:CreateObject('CustomEvent', 'ErrorShowEvent', localPlayer.C_Event)
    event:Connect(ErrorShow)
    event = world:CreateObject('CustomEvent', 'StillInGameEvent', localPlayer.C_Event)
    event:Connect(StillInGameShow)
end

function InitUI()
    local self = DebugModeLogic
    self.root = world:CreateInstance('ErrorGUI', 'ErrorGUI', localPlayer.Local)
    self.root.Order = 950
    self.stillInGameRoot = world:CreateInstance('SetRoomGUI', 'SetRoomGUI', localPlayer.Local)
    self.stillInGameRoot.Order = 950
    self.contentTxt = self.root.Bg.Content
    self.locationTxt = self.root.Bg.Location
    self.okBtn = self.root.Bg.OK

    self.root.Bg:SetActive(false)
    self.stillInGameRoot:SetActive(false)

    self.okBtn.OnClick:Connect(
        function()
            self.root.Bg:SetActive(false)
        end
    )
    self.root.BakeBtn.OnClick:Connect(
        function()
            BakeNav()
        end
    )
    ---仍在游戏中的提示框
    self.stillInGameRoot.Bg.WAIT.OnClick:Connect(
        function()
            self.stillInGameRoot:SetActive(false)
        end
    )
    self.stillInGameRoot.Bg.QUIT.OnClick:Connect(
        function()
            Game.Quit()
        end
    )
end

function HookFunc()
    if FrameworkConfig.DebugMode then
        for _, module in pairs(_G) do
            if type(module) == 'table' then
                local funcTable = {}
                if module.__declaredMethods then
                    ---类模块
                    funcTable = module.__declaredMethods
                else
                    ---正常模块
                    funcTable = module
                end
                for funcName, func in pairs(funcTable) do
                    if type(func) == 'function' and funcName ~= 'Update' and funcName ~= 'FixUpdate' then
                        local hookedFunc = function(...)
                            local res = {pcall(func, ...)}
                            local success = res[1]
                            table.remove(res, 1)
                            if success then
                                return table.unpack(res)
                            else
                                if localPlayer then
                                    ---客户端报错
                                    NetUtil.Fire_C(
                                        'ErrorShowEvent',
                                        localPlayer,
                                        Const.ErrorLocationEnum.Client,
                                        res[1]
                                    )
                                else
                                    ---服务端报错
                                    NetUtil.Broadcast('ErrorShowEvent', Const.ErrorLocationEnum.Server, res[1])
                                end
                            end
                        end
                        module[funcName] = hookedFunc
                    end
                end
            end
        end
    end
end

function InitClientLogic()
    InitEvent()
    InitUI()
    InitBakeNav()
end

function InitBakeNav()
    local self = DebugModeLogic
    if FrameworkConfig.DebugMode then
        Input.OnKeyDown:Connect(
            function()
                if Input.GetPressKeyData(Enum.KeyCode.F1) == Enum.KeyState.KeyStatePress then
                    if self.root.BakeBtn.ActiveSelf then
                        self.root.BakeBtn:SetActive(false)
                    else
                        self.root.BakeBtn:SetActive(true)
                    end
                end
            end
        )
    end
end

function BakeNav()
    BakeNavMesh.CreateData()
end

return DebugModeLogic
