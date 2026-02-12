DEBUG_MODE = true
-- Load configuration options up front
ScriptHost:LoadScript("scripts/settings.lua")
ScriptHost:LoadScript("scripts/common.lua")
ScriptHost:LoadScript("scripts/class.lua")
ScriptHost:LoadScript("scripts/custom_item.lua")
ScriptHost:LoadScript("scripts/main.lua")
ScriptHost:LoadScript("scripts/AnyKeyCount.lua")
local anykeycount = AnyKeyCount()
ScriptHost:LoadScript("scripts/TriforceCount.lua")
local triforcecount = TriforceCount()
--ScriptHost:LoadScript("scripts/TriforceHunt.lua")
--local triforcehunt = TriforceHunt()


-- Are we using a keysanity variant?
--IS_KEYSANITY = string.find(Tracker.ActiveVariantUID, "keys") ~= nil

-- Are we using Z1 Entrance varient?
IS_Z1ENTRANCE = string.find(Tracker.ActiveVariantUID, "z1ent") ~= nil

-- Are we using Z3 Entance varient?
IS_Z3ENTRANCE = string.find(Tracker.ActiveVariantUID, "z3ent") ~= nil

--Both?
IS_Z1Z3ENTRANCE = string.find(Tracker.ActiveVariantUID, "z1z3ent") ~= nil

-- Items
Tracker:AddItems("items/common.json")
if IS_Z3ENTRANCE or IS_Z1Z3ENTRANCE then
    Tracker:AddItems("items/dungeon_items_keysanity.json")
    Tracker:AddItems("items/labels.json")
else
    Tracker:AddItems("items/dungeon_items_standard.json")
end
Tracker:AddItems("items/keys.json")
Tracker:AddItems("items/labels.json")
Tracker:AddItems("items/entrance_badges.json")






-- Maps
--if IS_KEYSANITY then
--    Tracker:AddMaps("maps/maps_keysanity.json")
--else
    Tracker:AddMaps("maps/maps.json")
--end

-- Locations (load SM cards first for portal logic)
--if IS_KEYSANITY then
--    Tracker:AddLocations("locations/sm/cards_keysanity.json")
--else
    Tracker:AddLocations("locations/sm/cards_standard.json")
--end
Tracker:AddLocations("locations/logic.json")
if IS_Z3ENTRANCE or IS_Z1Z3ENTRANCE then
    Tracker:AddLocations("locations/alttp/overworld_entrances.json")
    Tracker:AddLocations("locations/alttp/dungeons_entrance.json")
    ScriptHost:LoadScript("scripts/capturez3badge.lua") 
else
    Tracker:AddLocations("locations/alttp/lightworld.json")
    Tracker:AddLocations("locations/alttp/darkworld.json")
    Tracker:AddLocations("locations/alttp/bothworlds.json")
    Tracker:AddLocations("locations/alttp/dungeons_standard.json")
end
--if IS_KEYSANITY then
--    Tracker:AddLocations("locations/alttp/dungeons_keysanity.json")
--    Tracker:AddLocations("locations/sm/doors_keysanity.json")
--else
    Tracker:AddLocations("locations/sm/doors_standard.json")
--end
Tracker:AddLocations("locations/sm/wreckedship.json")
Tracker:AddLocations("locations/sm/crateria.json")
Tracker:AddLocations("locations/sm/brinstar.json")
Tracker:AddLocations("locations/sm/norfairupper.json")
Tracker:AddLocations("locations/sm/norfairlower.json")
Tracker:AddLocations("locations/sm/maridia.json")

if IS_Z1ENTRANCE or IS_Z1Z3ENTRANCE then
    Tracker:AddLocations("locations/loz/entrando/entrando.json")
    Tracker:AddLocations("locations/loz/entrando/level_1.json")
    Tracker:AddLocations("locations/loz/entrando/level_2.json")
    Tracker:AddLocations("locations/loz/entrando/level_3.json")
    Tracker:AddLocations("locations/loz/entrando/level_4.json")
    Tracker:AddLocations("locations/loz/entrando/level_5.json")
    Tracker:AddLocations("locations/loz/entrando/level_6.json")
    Tracker:AddLocations("locations/loz/entrando/level_7.json")
    Tracker:AddLocations("locations/loz/entrando/level_8.json")
    Tracker:AddLocations("locations/loz/entrando/level_9.json")
    ScriptHost:LoadScript("scripts/capturez1badge.lua") 
    --[[
        ScriptHost:LoadScript("scripts/accessibility_levels.lua")
        ScriptHost:LoadScript("scripts/access_data.lua")
        ScriptHost:LoadScript("scripts/access_building.lua")
        ScriptHost:LoadScript("scripts/add_section_objects.lua")
    ]]
else
    Tracker:AddLocations("locations/loz/overworld.json")
    Tracker:AddLocations("locations/loz/level_1.json")
    Tracker:AddLocations("locations/loz/level_2.json")
    Tracker:AddLocations("locations/loz/level_3.json")
    Tracker:AddLocations("locations/loz/level_4.json")
    Tracker:AddLocations("locations/loz/level_5.json")
    Tracker:AddLocations("locations/loz/level_6.json")
    Tracker:AddLocations("locations/loz/level_7.json")
    Tracker:AddLocations("locations/loz/level_8.json")
    Tracker:AddLocations("locations/loz/level_9.json")
end

Tracker:AddLocations("locations/metroid/zebes.json")


-- Layouts
Tracker:AddLayouts("layouts/common.json")
if IS_Z1Z3ENTRANCE then
    Tracker:AddLayouts("layouts/tracker_z1z3entrance.json")
    Tracker:AddLayouts("layouts/broadcast_z3entrance.json")  
    Tracker:AddLayouts("layouts/capture_grids.json")
elseif IS_Z3ENTRANCE then
    Tracker:AddLayouts("layouts/tracker_z3entrance.json")
    Tracker:AddLayouts("layouts/broadcast_z3entrance.json")  
    Tracker:AddLayouts("layouts/capture_grids.json")
elseif IS_Z1ENTRANCE then
    Tracker:AddLayouts("layouts/tracker_z1entrance.json")
    Tracker:AddLayouts("layouts/broadcast_standard.json")  
    Tracker:AddLayouts("layouts/capture_grids.json")
else
    Tracker:AddLayouts("layouts/tracker_standard.json")
    Tracker:AddLayouts("layouts/broadcast_standard.json")
end

function tracker_on_accessibility_updated()
    local anykey = Tracker:FindObjectForCode("z1magickey")
    if anykey.Active then
        anykeycount:SetAnyKey(true)
    else
        anykeycount:SetAnyKey(false)
    end
--[[
    local triforcehunt = Tracker:FindObjectForCode("hunt")
    if triforcehunt.Active then
        triforcehunt:SetTriforceHunt(true)
    else
        triforcehunt:SetTriforceHunt(false)
    end
]]
    if IS_Z1ENTRANCE or IS_Z1Z3ENTRANCE then
        for i,section in pairs(CaptureZ1BadgeSections) do
            local target = Tracker:FindObjectForCode(section)
            -- Has the captured item for this section changed since last update
            if not target then
                print("Failed to resolve " .. section)
            elseif target.CapturedItem ~= CaptureZ1BadgeCache[target] then
                -- Does the location that owns this section already have a badge, if so remove it
                if CaptureZ1BadgeCache[target.Owner] then
                    target.Owner:RemoveBadge(CaptureZ1BadgeCache[target.Owner])
                    CaptureZ1BadgeCache[target.Owner] = nil
                    CaptureZ1BadgeCache[target] = nil
                end
                -- Check if a captured item exists, add as badge to the sections owner if it does
                if target.CapturedItem then
                    CaptureZ1BadgeCache[target.Owner] = target.Owner:AddBadge(target.CapturedItem.PotentialIcon)
                    CaptureZ1BadgeCache[target] = target.CapturedItem
                end
            end
        end
    end

    if IS_Z3ENTRANCE or IS_Z1Z3ENTRANCE then
        for i,section in pairs(CaptureZ3BadgeSections) do
            local target = Tracker:FindObjectForCode(section)
            -- Has the captured item for this section changed since last update
            if not target then
                print("Failed to resolve " .. section)
            elseif target.CapturedItem ~= CaptureZ3BadgeCache[target] then
                -- Does the location that owns this section already have a badge, if so remove it
                if CaptureZ3BadgeCache[target.Owner] then
                    target.Owner:RemoveBadge(CaptureZ3BadgeCache[target.Owner])
                    CaptureZ3BadgeCache[target.Owner] = nil
                    CaptureZ3BadgeCache[target] = nil
                end
                -- Check if a captured item exists, add as badge to the sections owner if it does
                if target.CapturedItem then
                    CaptureZ3BadgeCache[target.Owner] = target.Owner:AddBadge(target.CapturedItem.PotentialIcon)
                    CaptureZ3BadgeCache[target] = target.CapturedItem
                end
            end
        end
    end

    local item_list = {
        "m1kraid",
        "m1ridley"
    }

    if INITIALIZED then
        for i = 1, #item_list do
            local item = Tracker:FindObjectForCode(item_list[i])
            local state = ITEM_STATE_LIST[item_list[i]]
            item_check(item,state)
        end
    end    
end

---- Autotracking if supported
-- if _VERSION == "Lua 5.3" then
--    ScriptHost:LoadScript("scripts/autotracking.lua")
--else
--    print("Autotracking is unsupported by your EmoTracker version, please update to the latest version!")
--end

init()