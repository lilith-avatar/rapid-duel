--- 网路工具/事件工具
--- @module NetUtil utilities
--- @copyright Lilith Games, Avatar Team
--- @author Sharif Ma, Yuancheng Zhang, Yen Yuan
local NetUtil = {}

-- 格式化事件参数, Table=>JSON
local FormatArgs

--! 事件参数校验, true:开启校验
local valid, ValidateArgs = true

--! 打印事件日志, true:开启打印
local showLog, PrintEventLog = false

local FireEnum = {
    SERVER = 1,
    CLIENT = 2,
    BROADCAST = 3
}

--! 外部接口

--- 向服务器发送消息
-- @param @string _eventName 事件的名字(严格对应)
-- @param ... 事件参数
function NetUtil.Fire_S(_eventName, ...)
    ValidateArgs(FireEnum.SERVER, _eventName)
    local args = {...}
    world.S_Event[_eventName]:Fire(table.unpack(args))
    PrintEventLog(FireEnum.SERVER, _eventName, nil, args)
end

--- 向指定的玩家发送消息
-- @param @string _eventName 事件的名字
-- @param _player 玩家对象
-- @param ... 事件参数
function NetUtil.Fire_C(_eventName, _player, ...)
	if(_player == nil) then
		return
	end
    ValidateArgs(FireEnum.CLIENT, _eventName, _player)
    local args = {...}
    if not _player.C_Event[_eventName] or _player.C_Event[_eventName]:IsNull() then
        return
    end
    _player.C_Event[_eventName]:Fire(table.unpack(args))
    PrintEventLog(FireEnum.CLIENT, _eventName, _player, args)
end

--- 客户端广播
-- @param @string _eventName 事件的名字(严格对应)
-- @param ... 事件参数
function NetUtil.Broadcast(_eventName, ...)
    ValidateArgs(FireEnum.BROADCAST, _eventName, ...)
    local args = {...}
    world.Players:BroadcastEvent(_eventName, table.unpack(args))
    PrintEventLog(FireEnum.BROADCAST, _eventName, nil, args)
end

--! 私有函数

--- 格式化事件参数
FormatArgs = function(...)
    local args = {...}
    for k, v in pairs(args) do
        if type(v) == 'table' then
            args[k] = string.format('JSON%sJSON', LuaJsonUtil:encode(v))
        end
    end
    return args
end

--! 辅助功能

--- 事件参数校验
ValidateArgs =
    valid and
    function(_fireEnum, _eventName, _player)
        if _fireEnum == FireEnum.SERVER then
            --! Fire_S 检查参数
            assert(not string.isnilorempty(_eventName), '[NetUtil][Fire_S] 事件名为空')
            assert(world.S_Event[_eventName], string.format('[NetUtil][Fire_S] 服务器不存在事件: %s', _eventName))
        elseif _fireEnum == FireEnum.CLIENT then
            --! Fire_C 检查参数
            assert(not string.isnilorempty(_eventName), '[NetUtil] 事件名为空')
            assert(
                _player and _player.ClassName == 'PlayerInstance',
                string.format('[NetUtil][Fire_C]第2个参数需要是玩家对象, 错误事件: %s', _eventName)
            )
            --[[assert(
                _player.C_Event[_eventName],
                string.format('[NetUtil][Fire_C] 客户端玩家不存在事件: %s, 玩家: %s', _player.Name, _eventName)
            )]]
        elseif _fireEnum == FireEnum.BROADCAST then
            --! Broadcase 检查参数
            assert(not string.isnilorempty(_eventName), '[NetUtil][Broadcast] 事件名为空')
        end
    end or
    function()
    end

--- 打印事件日志
PrintEventLog = showLog and function(_fireEnum, _eventName, _player, _args)
        if _fireEnum == FireEnum.SERVER then
            --* Fire_S 参数打印
            print(string.format('[NetUtil][服务器] %s, 参数 = %s, %s', _eventName, #_args, table.dump(_args)))
        elseif _fireEnum == FireEnum.CLIENT then
            --* Fire_C 参数打印
            print(
                string.format(
                    '[NetUtil][客户端] %s, 玩家=%s, 参数 = %s, %s',
                    _eventName,
                    _player.Name,
                    #_args,
                    table.dump(_args)
                )
            )
        elseif _fireEnum == FireEnum.BROADCAST then
            --* Broadcase 参数打印
            print(string.format('[NetUtil][客户端][广播] %s, 参数 = %s, %s', _eventName, #_args, table.dump(_args)))
        end
    end or function()
    end

return NetUtil
