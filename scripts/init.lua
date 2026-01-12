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

-- Items
Tracker:AddItems("items/common.json")
--if IS_KEYSANITY then
--    Tracker:AddItems("items/dungeon_items_keysanity.json")
--else
    Tracker:AddItems("items/dungeon_items_standard.json")
--end
Tracker:AddItems("items/keys.json")
Tracker:AddItems("items/labels.json")






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
Tracker:AddLocations("locations/alttp/lightworld.json")
Tracker:AddLocations("locations/alttp/darkworld.json")
Tracker:AddLocations("locations/alttp/bothworlds.json")
--if IS_KEYSANITY then
--    Tracker:AddLocations("locations/alttp/dungeons_keysanity.json")
--    Tracker:AddLocations("locations/sm/doors_keysanity.json")
--else
    Tracker:AddLocations("locations/alttp/dungeons_standard.json")
    Tracker:AddLocations("locations/sm/doors_standard.json")
--end
Tracker:AddLocations("locations/sm/wreckedship.json")
Tracker:AddLocations("locations/sm/crateria.json")
Tracker:AddLocations("locations/sm/brinstar.json")
Tracker:AddLocations("locations/sm/norfairupper.json")
Tracker:AddLocations("locations/sm/norfairlower.json")
Tracker:AddLocations("locations/sm/maridia.json")

if IS_Z1ENTRANCE then
    Tracker:AddItems("items/entrance_badges.json")
    Tracker:AddLocations("locations/loz/entrando.json")
    ScriptHost:LoadScript("scripts/capturebadge.lua")
else
    Tracker:AddLocations("locations/loz/overworld.json")
end
Tracker:AddLocations("locations/loz/level_1.json")
Tracker:AddLocations("locations/loz/level_2.json")
Tracker:AddLocations("locations/loz/level_3.json")
Tracker:AddLocations("locations/loz/level_4.json")
Tracker:AddLocations("locations/loz/level_5.json")
Tracker:AddLocations("locations/loz/level_6.json")
Tracker:AddLocations("locations/loz/level_7.json")
Tracker:AddLocations("locations/loz/level_8.json")
Tracker:AddLocations("locations/loz/level_9.json")
Tracker:AddLocations("locations/metroid/zebes.json")


-- Layouts
Tracker:AddLayouts("layouts/common.json")
--if IS_KEYSANITY then
--    Tracker:AddLayouts("layouts/tracker_keysanity.json")
--    Tracker:AddLayouts("layouts/broadcast_keysanity.json")
--else
    Tracker:AddLayouts("layouts/tracker_standard.json")
    Tracker:AddLayouts("layouts/broadcast_standard.json")
--end

--function tracker_on_accessibility_updated()
--    local anykey = Tracker:FindObjectForCode("z1magickey")

--    if anykey.Active then
--        anykeycount:SetAnyKey(true)
--   else
--        anykeycount:SetAnyKey(false)
--    end
--end

--function tracker_on_accessibility_updated()
--    local triforcehunt = Tracker:FindObjectForCode("hunt")
--
--    if triforcehunt.Active then
--        triforcehunt:SetTriforceHunt(true)
--    else
--        triforcehunt:SetTriforceHunt(false)
--    end
--end

---- Autotracking if supported
-- if _VERSION == "Lua 5.3" then
--    ScriptHost:LoadScript("scripts/autotracking.lua")
--else
--    print("Autotracking is unsupported by your EmoTracker version, please update to the latest version!")
--end

init()