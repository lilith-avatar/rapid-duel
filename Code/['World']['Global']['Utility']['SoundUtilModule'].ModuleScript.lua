--- 音效播放模块
---@module SoundUtil
---@copyright Lilith Games, Avatar Team
---@author Sharif Ma
local SoundUtil = {}

function SoundUtil:Init()
    print('[SoundUtil] Init()')
    self.SoundPlaying = {}
    self.Table_Sound = Config.Sound
end

---创建一个新音效并播放
---@param _ID number 音效的ID
---@param  _SoundSourceObj Object 音效的挂载物体,不填则为2D音效,挂载在主摄像机上,填写则为世界音效
function SoundUtil:PlaySound(_ID, _SoundSourceObj)
    local Info, _Duration
    local pos = _SoundSourceObj and _SoundSourceObj.Position or nil
    local targetPlayer = _SoundSourceObj and world:FindPlayers() or { localPlayer }
    --_SoundSourceObj = _SoundSourceObj or world.CurrentCamera
    Info = self.Table_Sound[_ID]
    assert(Info, '[SoundUtil] 表中不存在该ID的音效')
    _Duration = Info.Duration
    local sameSoundPlayingNum = 0
    for k, v in pairs(self.SoundPlaying) do
        if v == _ID then
            sameSoundPlayingNum = sameSoundPlayingNum + 1
        end
    end
    if sameSoundPlayingNum > 0 and not Info.CoverPlay then
        print(string.format('[SoundUtil] %s音效CoverPlay字段为false，不能覆盖播放', _ID))
        return
    end
    local filePath = 'Audio/' .. Info.FileName
    for i, v in pairs(targetPlayer) do
        NetUtil.Fire_C('WorldSoundEvent', v, filePath, { Position = pos, Volume = Info.Volume, Loop = Info.IsLoop})
    end

--[[
    local Audio = world:CreateObject('AudioSource', 'Audio_' .. Info.FileName, _SoundSourceObj)
    Audio.LocalPosition = Vector3.Zero
    Audio.SoundClip = ResourceManager.GetSoundClip('Audio/' .. Info.FileName)
    print('[SoundUtil] Audio.SoundClip', Audio.SoundClip)
    Audio.Volume = Info.Volume
    Audio.MaxDistance = 10
    Audio.MinDistance = 10
    Audio.Loop = Info.IsLoop
    Audio:Play()
    table.insert(self.SoundPlaying, _ID)
    _Duration = _Duration or 1]]

    invoke(
        function()
            for k, v in pairs(self.SoundPlaying) do
                if v == _ID then
                    table.remove(self.SoundPlaying, k)
                end
            end
        end,
        _Duration
    )
end

---停止一个音效的播放
function SoundUtil:StopSound(_ID, _isLocal)
    local Info = self.Table_Sound[_ID]
    assert(Info, '[SoundUtil] 表中不存在该ID的音效')
    local filePath = 'Audio/' .. Info.FileName
    local targetPlayer = _isLocal and { localPlayer } or world:FindPlayers()
    for i, v in pairs(targetPlayer) do
        NetUtil.Fire_C('StopSoundEvent', v, filePath)
    end
end

return SoundUtil
