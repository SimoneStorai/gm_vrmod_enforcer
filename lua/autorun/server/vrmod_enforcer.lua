local vrmod_force = CreateConVar("vrmod_enforcer_policy", "2", { FCVAR_NOTIFY }, "Current VRMod use enforcement policy.", 0, 2)
local vrmod_force_timer = CreateConVar("vrmod_enforcer_timer", "0", { FCVAR_NOTIFY }, "If VR mode is being enforced, players are required to enable it within this threshold (0 means disabled).")

local function setPlayerLock(player, enabled)
    local policy = vrmod_force:GetInt()
    if policy == 0 then return end

    -- Ignore if privileged.
    if player:IsAdmin() or ULib and ULib.ucl.query(player, "vrmod enforcer ignore") then return end

    -- Native Player:Lock() prevents some VR functionalities (e.g. IK) from working properly.
    -- Other setters like Player:CrosshairEnable/Disable() cause this issue as well.
    player:Freeze(enabled)

    if enabled then
        -- If enabled, create a new kick timer for this player.
        local timer = vrmod_force_timer:GetInt()
        if timer > 0 then
            timer.Create("VRMod_Enforcer_Kick_" .. player:UserID(), timer, 1, function()
                if not vrmod.IsPlayerInVR(player) then
                    player:Kick("VR mode must be enabled in order to play on this server.")
                end
            end)
        end

        if policy == 2 then
            -- Force player *back* into VR mode.
            -- Freeze measures will be disabled later, however they still need to be applied since Player:ConCommand can be intercepted.
            player:ConCommand("vrmod_start")
        else
            player:ChatPrint("Enable VR mode in order to play on this server.")
            if timer > 0 then
                player:ChatPrint("Refusing to do so will get you kicked in " .. timer .. " seconds.")
            end
        end
    else
        -- Remove any existing kick timer.
        timer.Remove("VRMod_Enforcer_Kick_" .. player:UserID())
    end
end

hook.Add("PlayerSpawn", "VRMod_Enforcer", function(player, transition)
    -- Always assert VR status on player spawn.
    if not vrmod.IsPlayerInVR(player) then
        setPlayerLock(player, true)
    end
end)

hook.Add("VRMod_Start", "VRMod_Enforcer", function(player)
    setPlayerLock(player, false)
end)
hook.Add("VRMod_Exit", "VRMod_Enforcer", function(player)
    setPlayerLock(player, true)
end)

if ULib then
    ULib.ucl.registerAccess("vrmod enforcer ignore", ULib.ACCESS_OPERATOR, "Ability to play without VR mode being enabled.", "Other")
end