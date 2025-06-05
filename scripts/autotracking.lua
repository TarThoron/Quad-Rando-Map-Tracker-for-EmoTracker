-- Configuration --------------------------------------
AUTOTRACKER_ENABLE_DEBUG_LOGGING = false
AUTOTRACKER_ENABLE_DEBUG_DUNGEON_LOGGING = false
AUTOTRACKER_ENABLE_DEBUG_ERROR_LOGGING = false
SHOW_DUNGEON_DEBUG_LOGGING = AUTOTRACKER_ENABLE_DEBUG_LOGGING or AUTOTRACKER_ENABLE_DEBUG_DUNGEON_LOGGING
SHOW_ERROR_DEBUG_LOGGING = AUTOTRACKER_ENABLE_DEBUG_LOGGING or AUTOTRACKER_ENABLE_DEBUG_ERROR_LOGGING

-- Are we using a Bizhawk-specific variant?  This matters for memory addressing, until we get a new connectorlib.
BIZHAWK_MODE = string.find(Tracker.ActiveVariantUID, "bizhawk") ~= nil
-------------------------------------------------------

-- Some useful stuff for reference from Z3SM ASM GitHub repo: https://github.com/tewtal/alttp_sm_combo_randomizer_rom
-- !SRAM_ALTTP_START = $a06000
-- !SRAM_SM_START = $a16010
--
-- LTTP SRAM in bank 0xa06000
-- SM SRAM in bank 0xa16000, file 1 starts $10 bytes after the beginning!
--
-- For mapping the SRAM address for SD2SNES, the usb2snes protocol works differently!
-- See: https://github.com/Skarsnik/QUsb2snes/blob/master/docs/Procotol.md#usb2snes-address
-- ROM starts at 0x000000
-- WRAM starts at 0xF50000
-- SRAM starts at 0xE00000
--
-- For WRAM, we can address banks 0x7e and 0x7f directly with connectorlib currently.  In a future update, we *should*
-- be able to directly address the SRAM banks but currently we have to use the bank 0xe0 mapping instead.
-- See the getSRAMAddressLTTP() and getSRAMAddressSM() functions below for the mapping math.

print("")
print("Active Auto-Tracker Configuration")
print("---------------------------------------------------------------------")
if IS_KEYSANITY then
    print("Keysanity Mode enabled")
end
if BIZHAWK_MODE then
    print("Bizhawk Mode enabled")
end
if AUTOTRACKER_ENABLE_ITEM_TRACKING then
    print("Item Tracking enabled")
end
if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
    print("Location Tracking enabled")
end
if AUTOTRACKER_ENABLE_DUNGEON_TRACKING then
    print("Dungeon Tracking enabled")
end
if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print("Debug Logging enabled")
end
if AUTOTRACKER_ENABLE_DEBUG_DUNGEON_LOGGING then
    print("Debug Dungeon Logging enabled")
end
if AUTOTRACKER_ENABLE_DEBUG_ERROR_LOGGING then
    print("Debug Error Logging enabled")
end
print("---------------------------------------------------------------------")
print("")

CONNECTOR_NAME_SD2SNES = "SD2SNES"

AUTOTRACKER_IS_IN_LTTP = false
AUTOTRACKER_IS_IN_SM = false

-- Constants
LTTP = "LTTP"
SM = "SM"

U8_READ_CACHE = 0
U8_READ_CACHE_ADDRESS = 0

U16_READ_CACHE = 0
U16_READ_CACHE_ADDRESS = 0

-- Save memory watch segments in table so we can clear them when switching games.
GAME_WATCH = nil
MEMORY_WATCHES = {}

-- Track total hearts for changes.
TOTAL_HEARTS = 0

-- Caches for dungeon item tracking.
DUNGEON_LOCATIONS_CHECKED = {}
DUNGEON_ITEMS_FOUND = {}
CHEST_SMALL_KEYS = {}

-- ************************** Table helper functions for debug printing

function table.val_to_str ( v )
    if "string" == type( v ) then
        v = string.gsub( v, "\n", "\\n" )
        if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
    else
        return "table" == type( v ) and table.tostring( v ) or
                tostring( v )
    end
end

function table.key_to_str ( k )
    if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
        return k
    else
        return "[" .. table.val_to_str( k ) .. "]"
    end
end

function table.tostring( tbl )
    local result, done = {}, {}
    for k, v in ipairs( tbl ) do
        table.insert( result, table.val_to_str( v ) )
        done[ k ] = true
    end
    for k, v in pairs( tbl ) do
        if not done[ k ] then
            table.insert( result,
                    table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
        end
    end
    return "{" .. table.concat( result, "," ) .. "}"
end

function table.has_value(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- ************************** Memory reading helper functions

function InvalidateReadCaches()
    U8_READ_CACHE_ADDRESS = 0
    U16_READ_CACHE_ADDRESS = 0
end

function ReadU8(segment, address)
    if U8_READ_CACHE_ADDRESS ~= address then
        -- Convert read value to integer.
        U8_READ_CACHE = math.floor(segment:ReadUInt8(address))
        U8_READ_CACHE_ADDRESS = address
    end

    return U8_READ_CACHE
end

function ReadU16(segment, address)
    if U16_READ_CACHE_ADDRESS ~= address then
        -- Convert read value to integer.
        U16_READ_CACHE = math.floor(segment:ReadUInt16(address))
        U16_READ_CACHE_ADDRESS = address
    end

    return U16_READ_CACHE
end

function clearMemoryWatches()
    for _, watch in ipairs(MEMORY_WATCHES) do
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("Removing previous memory watch:", watch)
        end
        ScriptHost:RemoveMemoryWatch(watch)
    end
    -- Remove all elements from the table to clear it.
    for k in pairs(MEMORY_WATCHES) do
        MEMORY_WATCHES[k] = nil
    end
end

function getSRAMOffset(address)
    -- Compute SRAM offset based on raw ExHiROM address (used for usb2snes and Bizhawk Lua addressing).
    -- For HiROM in general, SRAM is mapped to banks $A0-$BF for addresses $6000–$7FFF within each bank.  For example:
    --   $A06000 = offset 0x0
    --   $A07000 = offset 0x1000
    --   $A16000 = offset 0x2000
    --   $A17000 = offset 0x3000
    --   and so on...
    -- Start by subtracting 0xa06000 as the base, then offset 0x2000 for each additional bank.
    local offset = 0x0
    local remaining_addr = address - 0xa06000
    while remaining_addr >= 0x2000 do
        remaining_addr = remaining_addr - 0x10000
        offset = offset + 0x2000
    end
    return offset + remaining_addr
end

function mapSRAMAddress(address)
    -- Map SRAM address to the location needed based on the connector being used.
    -- Bizhawk (Lua): SRAM starts at 0x700000 in the system bus for whatever reason.
    -- SD2SNES: SRAM starts at 0xe00000 in the usb2snes protocol.
    -- snes9x (Lua): Uses the raw address.
    if BIZHAWK_MODE then
        return 0x700000 + getSRAMOffset(address)
    elseif AutoTracker.SelectedConnectorType.Name == CONNECTOR_NAME_SD2SNES then
        return 0xe00000 + getSRAMOffset(address)
    else
        return address
    end
end

function getSRAMAddressLTTP(offset)
    -- Map SRAM offset to address for LTTP based on which connector we're using.
    -- LTTP SRAM is in bank 0xa06000
    return mapSRAMAddress(0xa06000 + offset)
end

function getSRAMAddressSM(offset)
    -- Map SRAM offset to address for SM based on which connector we're using.
    -- SM SRAM is in bank 0xa16000, and file 1 starts 0x10 bytes after the beginning.
    return mapSRAMAddress(0xa16010 + offset)
end

-- *************************** Game status and memory watches

function updateGame()
    -- Figure out which game we're in.
    InvalidateReadCaches()

    local game = whichGameAreWeIn()
    local changingGame = false
    if (game == SM) then
        changingGame = not AUTOTRACKER_IS_IN_SM
        AUTOTRACKER_IS_IN_LTTP = false
        AUTOTRACKER_IS_IN_SM = true
    elseif (game == LTTP) then
        changingGame = not AUTOTRACKER_IS_IN_LTTP
        AUTOTRACKER_IS_IN_LTTP = true
        AUTOTRACKER_IS_IN_SM = false
    else
        -- If we got a bad game value, assume we reset or something and clear all the watches.
        changingGame = true
        AUTOTRACKER_IS_IN_LTTP = false
        AUTOTRACKER_IS_IN_SM = false
    end

    -- If we're changing games, update the memory watches accordingly.  This forces all the data to be refreshed.
    if changingGame then
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("**** Game change detected: ", game)
        end

        clearMemoryWatches()

        CURRENT_ROOM_ID = nil
        CURRENT_ROOM_DATA = 0x0

        -- Link to the Past
        if AUTOTRACKER_IS_IN_LTTP then
            -- WRAM watches
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Item Data", 0x7ef340, 0x90, updateItemsActiveLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Heart Piece Data", 0x7ef448, 0x1, updateHeartPiecesActiveLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP NPC Item Data", 0x7ef410, 0x2, updateNPCItemFlagsActiveLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Room Data", 0x7ef000, 0x250, updateRoomsActiveLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Overworld Event Data", 0x7ef280, 0x82, updateOverworldEventsActiveLTTP))

            -- Dungeon tracking watches, depending on whether we're in keysanity or not.
            if IS_KEYSANITY then
                table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Small Keys", 0x7ef4e0, 0x10,
                        updateSmallKeysActiveLTTP))
            else
                table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Dungeon Item Checks", 0x7ef434, 0x6,
                        updateDungeonChecksActiveLTTP))
            end

            -- Extra cross-game RAM watches specifically for items.
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Item Data In LTTP", mapSRAMAddress(0xa17900), 0x10,
                    updateItemsInactiveSM))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Ammo Data In LTTP", mapSRAMAddress(0xa17920), 0x16,
                    updateAmmoInactiveSM))
            if IS_KEYSANITY then
                table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Key Data In LTTP", mapSRAMAddress(0xa17970), 0x02,
                        updateKeycardsInactiveSM))
            end

            -- SRAM watches for things that aren't in cross-game extra RAM.
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Boss Data In LTTP", getSRAMAddressSM(0x68), 0x08, updateSMBossesInactive))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Room Data In LTTP", getSRAMAddressSM(0xb0), 0x20, updateRoomsInactiveSM))

            -- Game completion checks
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP DONE", mapSRAMAddress(0xa17506), 0x01,
                    updateLTTPcompletionInLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM DONE", mapSRAMAddress(0xa17402), 0x01,
                    updateSMcompletionInLTTP))

        -- Super Metroid
        elseif AUTOTRACKER_IS_IN_SM then
            -- WRAM watches
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Item Data", 0x7e09a0, 0x10, updateItemsActiveSM))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Ammo Data", 0x7e09c2, 0x16, updateAmmoActiveSM))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Boss Data", 0x7ed828, 0x08, updateSMBossesActive))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Room Data", 0x7ed870, 0x20, updateRoomsActiveSM))
            if IS_KEYSANITY then
                table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM Key Data In LTTP", 0x7ed830, 0x02, updateKeycardsActiveSM))
            end

            -- Extra cross-game RAM watches specifically for items.
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Item Data In SM", mapSRAMAddress(0xa17b40), 0x90,
                    updateItemsInactiveLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Heart Piece Data In SM", mapSRAMAddress(0xa17f28), 0x1,
                    updateHeartPiecesInactiveLTTP))

            -- Dungeon tracking watches, depending on whether we're in keysanity or not.
            if IS_KEYSANITY then
                table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Small Keys In SM", mapSRAMAddress(0xa17f50), 0x10,
                        updateSmallKeysInactiveLTTP))
            else
                table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Dungeon Item Checks In SM", mapSRAMAddress(0xa17f14), 0x6,
                        updateDungeonChecksInactiveLTTP))
            end

            -- SRAM watches for things that aren't in cross-game extra RAM.
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP NPC Item Data In SM", getSRAMAddressLTTP(0x410), 0x2,
                    updateNPCItemFlagsInactiveLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Room In SM", getSRAMAddressLTTP(0x0), 0x250,
                    updateRoomsInactiveLTTP))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP Overworld Event Data In SM", getSRAMAddressLTTP(0x280), 0x82,
                    updateOverworldEventsInactiveLTTP))

            -- Game completion checks
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("LTTP DONE", mapSRAMAddress(0xa17506), 0x01,
                    updateLTTPcompletionInSM))
            table.insert(MEMORY_WATCHES, ScriptHost:AddMemoryWatch("SM DONE", mapSRAMAddress(0xa17402), 0x01,
                    updateSMcompletionInSM))

        end
    end

    return true
end

function whichGameAreWeIn()
    local value = AutoTracker:ReadU8(mapSRAMAddress(0xa173fe), 0)
    if (value == 0xFF) then
        return SM
    elseif (value == 0x00) then
        return LTTP
    else
        return nil
    end
end

function isInLTTP()
    return whichGameAreWeIn() == LTTP
end

function isInGameLTTP()
    if not AUTOTRACKER_IS_IN_LTTP then
        return false
    else
        local mainModuleIdx = AutoTracker:ReadU8(0x7e0010, 0)

        local isInGame = (mainModuleIdx > 0x05 and mainModuleIdx < 0x1b and mainModuleIdx ~= 0x14 and mainModuleIdx ~= 0x17)
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("** LTTP Status:", "0x7e0010", string.format('0x%x', mainModuleIdx), isInGame)
        end
        return isInGame
    end
end

function isInSM()
    return whichGameAreWeIn() == SM
end

function isInGameSM()
    if not AUTOTRACKER_IS_IN_SM then
        return false
    else
        local mainModuleIdx = AutoTracker:ReadU8(0x7e0998, 0)

        local isInGame = (mainModuleIdx >= 0x07 and mainModuleIdx <= 0x12)
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("** SM status:", '0x7e0998', string.format('0x%x', mainModuleIdx), isInGame)
        end
        return isInGame
    end
end

function updateLTTPcompletionInLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    updateLTTPcompletion(segment)
    return true
end

function updateLTTPcompletionInSM(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    updateLTTPcompletion(segment)
    return true
end

function updateLTTPcompletion(segment)
    InvalidateReadCaches()
    updateToggleItemFromByte(segment, "ganon", mapSRAMAddress(0xa17506))
end

function updateSMcompletionInLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    updateSMcompletion(segment)
    return true
end

function updateSMcompletionInSM(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    updateSMcompletion(segment)
    return true
end

function updateSMcompletion(segment)
    InvalidateReadCaches()
    updateToggleItemFromByte(segment, "brain", mapSRAMAddress(0xa17402))
end

-- ******************** Helper functions for updating items and locations

function updateToggleFromRoomSlot(segment, address, code, slot)
    local item = Tracker:FindObjectForCode(code)
    if item then
        local roomData = ReadU16(segment, address + (slot[1] * 2))
        local value = 1 << slot[2]
        local check = roomData & value

        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("Room data:", code, slot[1], string.format('0x%x', roomData),
                    string.format('0x%x', value), check ~= 0)
        end

        item.Active = check ~= 0
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find item: ", code)
    end
end

function updateSectionChestCountFromRoomSlotList(segment, address, locationRef, roomSlots, callback)
    local location = Tracker:FindObjectForCode(locationRef)
    if location then
        -- Do not auto-track this if the user has manually modified it
        if location.Owner.ModifiedByUser then
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
                print("* Skipping user modified location: ", locationRef)
            end
            return
        end

        local clearedCount = 0
        for _, slot in ipairs(roomSlots) do
            local roomData = ReadU16(segment, address + (slot[1] * 2))
            local flag = 1 << slot[2]
            local check = roomData & flag

            if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
                print("Updating chest count: ", locationRef, slot[1], string.format('0x%x', roomData),
                        string.format('0x%x', flag), check ~= 0)
            end

            if check ~= 0 then
                clearedCount = clearedCount + 1
            end
        end

        location.AvailableChestCount = location.ChestCount - clearedCount
        if callback then
            callback(clearedCount > 0)
        end
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find location: ", locationRef)
    end
end

function updateProgressiveItemFromByte(segment, code, address, offset)
    local item = Tracker:FindObjectForCode(code)
    if item then
        local value = ReadU8(segment, address)
        local newStage = value + (offset or 0)

        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("Progressive item: ", code, string.format('0x%x', address),
                    string.format('0x%x', value), newStage)
        end

        item.CurrentStage = newStage
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find item: ", code)
    end
end

function updateSectionChestCountFromByteAndFlag(segment, locationRef, address, flag, callback)
    local location = Tracker:FindObjectForCode(locationRef)
    if location then
        -- Do not auto-track this if the user has manually modified it
        if location.Owner.ModifiedByUser then
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
                print("* Skipping user modified location: ", locationRef)
            end
            return
        end

        local value = ReadU8(segment, address)
        local check = value & flag

        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("Updating chest count:", locationRef, string.format('0x%x', address),
                    string.format('0x%x', value), string.format('0x%x', flag), check ~= 0)
        end

        if check ~= 0 then
            location.AvailableChestCount = 0
            if callback then
                callback(true)
            end
        else
            location.AvailableChestCount = location.ChestCount
            if callback then
                callback(false)
            end
        end
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find location:", locationRef)
    end
end

function updateToggleItemFromByte(segment, code, address)
    local item = Tracker:FindObjectForCode(code)
    if item then
        local value = ReadU8(segment, address)

        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("Item: ", code, string.format('0x%x', address), string.format('0x%x', value), value >= 1)
        end

        if value >= 1 then
            item.Active = true
        elseif value == 0 then
            item.Active = false
        end
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find item: ", code)
    end
end

function updateAmmoFrom2Bytes(segment, code, address)
    local item = Tracker:FindObjectForCode(code)
    local value = ReadU8(segment, address+1)*256 + ReadU8(segment, address)

    if item then
        if code == "etank" then
            if value > 1499 then
                item.AcquiredCount = 14
            else
                item.AcquiredCount = value/100
            end
        elseif code == "reservetank" then
            if value > 400 then
                item.AcquiredCount = 4
            else
                item.AcquiredCount = value/100
            end
        else
            item.AcquiredCount = value
        end

        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("Ammo:", item.Name, string.format("0x%x", address), value, item.AcquiredCount)
        end
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find item: ", code)
    end
end

function updateToggleItemFromByteAndFlag(segment, code, address, flag)
    local item = Tracker:FindObjectForCode(code)
    if item then
        local value = ReadU8(segment, address)

        local flagTest = value & flag

        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("Item:", item.Name, string.format("0x%x", address), string.format("0x%x", value),
                    string.format("0x%x", flag), flagTest ~= 0)
        end

        if flagTest ~= 0 then
            item.Active = true
        else
            item.Active = false
        end
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find item: ", code)
    end
end

-- ************************* LTTP functions

function updateAga1(segment, address)
    InvalidateReadCaches()
    local item = Tracker:FindObjectForCode("aga1")
    local value = ReadU8(segment, address)

    if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
        print("Aga1:", string.format('0x%x', address), string.format('0x%x', value), value >= 3)
    end

    if value >= 3 then
        item.Active = true
    else
        item.Active = false
    end
end

function updateBottles(segment, address)
    local item = Tracker:FindObjectForCode("bottle")
    local count = 0
    for i = 0, 3, 1 do
        if ReadU8(segment, address + i) > 0 then
            count = count + 1
        end
    end
    item.CurrentStage = count
end

function updateFlute(segment, address)
    local item = Tracker:FindObjectForCode("flute")
    local value = ReadU8(segment, address)

    local fluteAcquired = value & 0x02
    local gooseLoose = value & 0x01

    if gooseLoose ~= 0 then
        item.CurrentStage = 2
    elseif fluteAcquired ~= 0 then
        item.CurrentStage = 1
    else
        item.CurrentStage = 0
    end
end

function updateMirror(segment, address)
    local item = Tracker:FindObjectForCode("mirror")
    if item then
        local value = ReadU8(segment, address)
        if value == 1 or value == 2 then
            item.Active = true
        elseif value == 0 then
            item.Active = false
        end
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find item: ", code)
    end
end

-- ****************************************** Dungeon Room Checks
function checkDungeonCacheTableChanged(cacheTable, newTable, label)
    -- Check if the cached dungeon data has changed for debug logging.
    local changed = {}
    for key, count in pairs(newTable) do
        if cacheTable[key] ~= count then
            if SHOW_DUNGEON_DEBUG_LOGGING then
                print(label .. " changed for: ", key, "Old: ", tostring(cacheTable[key]), "New: ", count)
            end
            cacheTable[key] = count
            table.insert(changed, key)
        end
    end

    if next(changed) ~= nil then
        if SHOW_DUNGEON_DEBUG_LOGGING then
            print(label .. ": ", table.tostring(cacheTable))
        end
    end

    return changed
end

function updateDungeonLocationFromCache(locationRef, code)
    local location = Tracker:FindObjectForCode(locationRef)
    if location then
        -- Do not auto-track this if the user has manually modified it
        if location.Owner.ModifiedByUser then
            if SHOW_DUNGEON_DEBUG_LOGGING then
                print("* Skipping user modified location: ", locationRef)
            end
            return
        end

        -- Get variables.
        local openedChests = DUNGEON_LOCATIONS_CHECKED[code] or 0
        local dungeonItems = DUNGEON_ITEMS_FOUND[code] or 0
        local keysFromChests = CHEST_SMALL_KEYS[code] or 0

        -- Subtract dungeon items and small keys.
        local itemsFound = math.floor(math.min(location.ChestCount, math.max(0, openedChests - dungeonItems - keysFromChests)))

        local newCount = location.ChestCount - itemsFound
        local changed = location.AvailableChestCount ~= newCount
        if changed and SHOW_DUNGEON_DEBUG_LOGGING then
            print("Dungeon item count: ", locationRef,
                    "Opened chests: " .. openedChests, "Dungeon items: " .. dungeonItems,
                    "Keys from chests: " .. keysFromChests, "Items found: " .. itemsFound)
        end
        location.AvailableChestCount = newCount

    elseif SHOW_DUNGEON_DEBUG_LOGGING or SHOW_ERROR_DEBUG_LOGGING then
        print("***ERROR*** Couldn't find location:", locationRef)
    end
end

function updateAllDungeonLocationsFromCache()
    -- Update standard dungeon locations in the tracker based on the inventory caches.

    -- Light World
    updateDungeonLocationFromCache("@Hyrule Castle/Escape", "hc")
    updateDungeonLocationFromCache("@Eastern Palace/Dungeon", "ep")
    updateDungeonLocationFromCache("@Desert Palace/Dungeon", "dp")
    updateDungeonLocationFromCache("@Tower of Hera/Dungeon", "toh")

    -- Dark World
    updateDungeonLocationFromCache("@Palace of Darkness/Dungeon", "pod")
    updateDungeonLocationFromCache("@Swamp Palace/Dungeon", "sp")
    updateDungeonLocationFromCache("@Skull Woods/Dungeon", "sw")
    updateDungeonLocationFromCache("@Thieves' Town/Dungeon", "tt")
    updateDungeonLocationFromCache("@Ice Palace/Dungeon", "ip")
    updateDungeonLocationFromCache("@Misery Mire/Dungeon", "mm")
    updateDungeonLocationFromCache("@Turtle Rock/Dungeon", "tr")
end


-- ****************************************** Items
function updateItemsActiveLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateItemsLTTP(segment, 0x7ef300, true)
    end
    return true
end

function updateItemsInactiveLTTP(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end

    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateItemsLTTP(segment, mapSRAMAddress(0xa17b00), false)
    end
    return true
end

function updateItemsLTTP(segment, address, inLTTP)
    InvalidateReadCaches()

    updateProgressiveItemFromByte(segment, "owsword",  address + 0x59)
    updateProgressiveItemFromByte(segment, "shield",  address + 0x5A)
    updateProgressiveItemFromByte(segment, "armor",  address + 0x5B)
    updateProgressiveItemFromByte(segment, "gloves", address + 0x54)

    updateToggleItemFromByte(segment, "hookshot",  address + 0x42)
    updateToggleItemFromByte(segment, "bombs",     address + 0x43)
    updateToggleItemFromByte(segment, "firerod",   address + 0x45)
    updateToggleItemFromByte(segment, "icerod",    address + 0x46)
    updateToggleItemFromByte(segment, "bombos",    address + 0x47)
    updateToggleItemFromByte(segment, "ether",     address + 0x48)
    updateToggleItemFromByte(segment, "quake",     address + 0x49)
    updateToggleItemFromByte(segment, "lamp",      address + 0x4a)
    updateToggleItemFromByte(segment, "hammer",    address + 0x4b)
    updateToggleItemFromByte(segment, "net",       address + 0x4d)
    updateToggleItemFromByte(segment, "book",      address + 0x4e)
    updateToggleItemFromByte(segment, "somaria",   address + 0x50)
    updateToggleItemFromByte(segment, "byrna",     address + 0x51)
    updateToggleItemFromByte(segment, "cape",      address + 0x52)
    updateToggleItemFromByte(segment, "boots",     address + 0x55)
    updateToggleItemFromByte(segment, "flippers",  address + 0x56)
    updateToggleItemFromByte(segment, "pearl",     address + 0x57)
    updateToggleItemFromByte(segment, "halfmagic", address + 0x7b)

    updateToggleItemFromByteAndFlag(segment, "blueboomerang", address + 0x8c, 0x80)
    updateToggleItemFromByteAndFlag(segment, "redboomerang",  address + 0x8c, 0x40)
    updateToggleItemFromByteAndFlag(segment, "shovel", address + 0x8c, 0x04)
    updateToggleItemFromByteAndFlag(segment, "powder", address + 0x8c, 0x10)
    updateToggleItemFromByteAndFlag(segment, "mushroom", address + 0x8c, 0x20)
    updateToggleItemFromByte(segment, "bow", address + 0x40)
    updateToggleItemFromByteAndFlag(segment, "silvers", address + 0x8e, 0x40)

    updateBottles(segment, address + 0x5c)
    updateFlute(segment, address + 0x8c)
    updateMirror(segment, address + 0x53)
    updateAga1(segment, address + 0xc5)

    -- Big keys for keysanity.
    updateToggleItemFromByteAndFlag(segment, "gt_bigkey",  address + 0x66, 0x04)
    updateToggleItemFromByteAndFlag(segment, "tr_bigkey",  address + 0x66, 0x08)
    updateToggleItemFromByteAndFlag(segment, "tt_bigkey",  address + 0x66, 0x10)
    updateToggleItemFromByteAndFlag(segment, "toh_bigkey", address + 0x66, 0x20)
    updateToggleItemFromByteAndFlag(segment, "ip_bigkey",  address + 0x66, 0x40)
    updateToggleItemFromByteAndFlag(segment, "sw_bigkey",  address + 0x66, 0x80)
    updateToggleItemFromByteAndFlag(segment, "mm_bigkey",  address + 0x67, 0x01)
    updateToggleItemFromByteAndFlag(segment, "pod_bigkey", address + 0x67, 0x02)
    updateToggleItemFromByteAndFlag(segment, "sp_bigkey",  address + 0x67, 0x04)
    updateToggleItemFromByteAndFlag(segment, "dp_bigkey",  address + 0x67, 0x10)
    updateToggleItemFromByteAndFlag(segment, "ep_bigkey",  address + 0x67, 0x20)

    --  It may seem unintuitive, but these locations are controlled by flags stored adjacent to the item data,
    --  which makes it more efficient to update them here.
    updateSectionChestCountFromByteAndFlag(segment, "@Secret Passage/Link's Uncle", address + 0xc6, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Hobo/Under The Bridge", address + 0xc9, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Bottle Merchant/Bottle Merchant", address + 0xc9, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Purple Chest/Purple Chest", address + 0xc9, 0x10)

    -- Get total number of hearts to track heart pieces and containers.
    local containers = Tracker:FindObjectForCode("heartcontainer")
    if containers then
        local maxHealth = ReadU8(segment, address + 0x6c)
        local total_hearts = maxHealth // 8

        local changed = total_hearts ~= TOTAL_HEARTS
        TOTAL_HEARTS = total_hearts

        if changed then
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
                print("LTTP current max health: ", string.format("0x%x", address + 0x6c),
                        string.format("0x%x", maxHealth), total_hearts, "total hearts")
            end

            -- Need current heart pieces to compute containers.
            local heart_pieces
            if inLTTP then
                heart_pieces = math.floor(AutoTracker:ReadU8(0x7ef448, 0))
            else
                heart_pieces = math.floor(AutoTracker:ReadU8(mapSRAMAddress(0xa17f28), 0))
            end

            containers.AcquiredCount = (total_hearts - 3) - (heart_pieces // 4)
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
                print("Heart pieces: ", heart_pieces, "Heart containers: ", containers.AcquiredCount)
            end
        end
    end
end

-- ****************************************** Dungeon item checks
function updateDungeonChecksActiveLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    updateDungeonChecks(segment, 0x7ef434, true)
    return true
end

function updateDungeonChecksInactiveLTTP(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    updateDungeonChecks(segment, mapSRAMAddress(0xa17f14), false)
    return true
end

function updateDungeonChecks(segment, address, inLTTP)
    -- Update total dungeon item location checks.
    InvalidateReadCaches()

    local newLocationsChecked = {}

    -- $7EF434 - hhhhdddd
    -- h - hyrule castle
    -- d - palace of darkness
    local val = ReadU8(segment, address)
    newLocationsChecked['hc'] = (val & 0xf0) >> 4
    newLocationsChecked['pod'] = val & 0x0f

    -- $7EF435 - dddhhhaa
    -- d - desert palace
    -- h - tower of hera
    -- a - agahnim's tower (not needed)
    val = ReadU8(segment, address + 1)
    newLocationsChecked['dp'] = (val & 0xe0) >> 5
    newLocationsChecked['toh'] = (val & 0x1c) >> 2

    -- $7EF436 - gggggeee
    -- g - ganon's tower (not needed)
    -- e - eastern palace
    val = ReadU8(segment, address + 2)
    newLocationsChecked['ep'] = val & 0x07

    -- $7EF437 - sssstttt
    -- s - skull woods
    -- t - thieves town
    val = ReadU8(segment, address + 3)
    newLocationsChecked['sw'] = (val & 0xf0) >> 4
    newLocationsChecked['tt'] = val & 0x0f

    -- $7EF438 - iiiimmmm
    -- i - ice palace
    -- m - misery mire
    val = ReadU8(segment, address + 4)
    newLocationsChecked['ip'] = (val & 0xf0) >> 4
    newLocationsChecked['mm'] = val & 0x0f

    -- $7EF439 - ttttssss
    -- t - turtle rock
    -- s - swamp palace
    val = ReadU8(segment, address + 5)
    newLocationsChecked['tr'] = (val & 0xf0) >> 4
    newLocationsChecked['sp'] = val & 0x0f

    local changed = checkDungeonCacheTableChanged(DUNGEON_LOCATIONS_CHECKED, newLocationsChecked, 'Dungeon locations checked')

    -- Get chest small keys and map/compass/BK from memory or SRAM so we get up to date data after location increment.
    local compasses, bigKeys, maps, smallKeyAddress = 0x0
    if inLTTP then
        compasses = math.floor(AutoTracker:ReadU16(0x7ef364))
        bigKeys = math.floor(AutoTracker:ReadU16(0x7ef366))
        maps = math.floor(AutoTracker:ReadU16(0x7ef368))
        smallKeyAddress = 0x7ef4e0
    else
        compasses = math.floor(AutoTracker:ReadU16(getSRAMAddressLTTP(0x364)))
        bigKeys = math.floor(AutoTracker:ReadU16(getSRAMAddressLTTP(0x366)))
        maps = math.floor(AutoTracker:ReadU16(getSRAMAddressLTTP(0x368)))
        smallKeyAddress = mapSRAMAddress(0xa17f50)
    end

    local newDungeonItems = {}
    local newSmallKeys = {}

    function updateNewDungeonItems(key, dungeonItemMask, smallKeyIndex)
        -- Get small keys from chest cache in memory.
        newSmallKeys[key] = math.floor(AutoTracker:ReadU8(smallKeyAddress + smallKeyIndex))

        -- For Hyrule Castle, the first index is Sewers but this gets put in Hyrule Castle instead sometimes.
        -- Check both to be sure, there's only a single key for this dungeon.
        if key == 'hc' then
            newSmallKeys[key] = newSmallKeys[key] + math.floor(AutoTracker:ReadU8(smallKeyAddress + smallKeyIndex + 1))
            newSmallKeys[key] = math.min(1, newSmallKeys[key])
        end

        -- Get total dungeon items.
        newDungeonItems[key] = 0
        if (maps & dungeonItemMask) > 0 then
            newDungeonItems[key] = newDungeonItems[key] + 1
        end

        -- Hyrule Castle has map only for tracking.
        if key ~= 'hc' then
            if (bigKeys & dungeonItemMask) > 0 then
                newDungeonItems[key] = newDungeonItems[key] + 1
            end
            if (compasses & dungeonItemMask) > 0 then
                newDungeonItems[key] = newDungeonItems[key] + 1
            end
        end
    end

    for _, key in ipairs(changed) do
        if key == 'hc' then
            updateNewDungeonItems(key, 0xc000, 0)
        elseif key == 'ep' then
            updateNewDungeonItems(key, 0x2000, 2)
        elseif key == 'dp' then
            updateNewDungeonItems(key, 0x1000, 3)
        elseif key == 'toh' then
            updateNewDungeonItems(key, 0x0020, 10)
        elseif key == 'pod' then
            updateNewDungeonItems(key, 0x0200, 6)
        elseif key == 'sp' then
            updateNewDungeonItems(key, 0x0400, 5)
        elseif key == 'sw' then
            updateNewDungeonItems(key, 0x0080, 8)
        elseif key == 'tt' then
            updateNewDungeonItems(key, 0x0010, 11)
        elseif key == 'ip' then
            updateNewDungeonItems(key, 0x0040, 9)
        elseif key == 'mm' then
            updateNewDungeonItems(key, 0x0100, 7)
        elseif key == 'tr' then
            updateNewDungeonItems(key, 0x0008, 12)
        end
    end

    -- Check if any of the dungeon item counts actually changed.
    checkDungeonCacheTableChanged(DUNGEON_ITEMS_FOUND, newDungeonItems, "Dungeon item count")
    checkDungeonCacheTableChanged(CHEST_SMALL_KEYS, newSmallKeys, 'Chest small keys')

    updateAllDungeonLocationsFromCache()
end


-- ****************************************** Small key checks for keysanity
function updateSmallKeysActiveLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    updateSmallKeys(segment, 0x7ef4e0)
    return true
end

function updateSmallKeysInactiveLTTP(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    updateSmallKeys(segment, mapSRAMAddress(0xa17f50))
    return true
end

function updateSmallKeys(segment, address)
    -- Update chest small key counts.
    InvalidateReadCaches()

    local newSmallKeys = {}

    -- For Hyrule Castle, the first index is Sewers but this gets put in Hyrule Castle instead sometimes.
    -- Check both to be sure, there's only a single key for this dungeon.
    newSmallKeys['hc'] = math.min(1, ReadU8(segment, address) + ReadU8(segment, address + 1))

    newSmallKeys['ep'] = ReadU8(segment, address + 2)
    newSmallKeys['dp'] = ReadU8(segment, address + 3)
    newSmallKeys['at'] = ReadU8(segment, address + 4)
    newSmallKeys['sp'] = ReadU8(segment, address + 5)
    newSmallKeys['pod'] = ReadU8(segment, address + 6)
    newSmallKeys['mm'] = ReadU8(segment, address + 7)
    newSmallKeys['sw'] = ReadU8(segment, address + 8)
    newSmallKeys['ip'] = ReadU8(segment, address + 9)
    newSmallKeys['toh'] = ReadU8(segment, address + 10)
    newSmallKeys['tt'] = ReadU8(segment, address + 11)
    newSmallKeys['tr'] = ReadU8(segment, address + 12)
    newSmallKeys['gt'] = ReadU8(segment, address + 13)

    -- Update small key item counts.
    local item
    for code, val in pairs(newSmallKeys) do
        item = Tracker:FindObjectForCode(code .. "_smallkey")
        if item then
            item.AcquiredCount = val
        end
    end
end


-- ****************************************** Heart pieces
function updateHeartPiecesActiveLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    updateHeartPiecesLTTP(segment, 0x7ef448)
    return true
end

function updateHeartPiecesInactiveLTTP(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    updateHeartPiecesLTTP(segment, mapSRAMAddress(0xa17f28))
    return true
end

function updateHeartPiecesLTTP(segment, address)
    local pieces = Tracker:FindObjectForCode("heartpiece")
    if pieces then
        pieces.AcquiredCount = ReadU8(segment, address)
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print("LTTP current heart piece count: ", string.format("0x%x", address), pieces.AcquiredCount)
        end
    end
end


-- ****************************************** Rooms
function updateRoomsActiveLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    updateRoomsLTTP(segment, 0x7ef000)
    return true
end

function updateRoomsInactiveLTTP(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    updateRoomsLTTP(segment, getSRAMAddressLTTP(0x0))
    return true
end

function updateRoomsLTTP(segment, address)
    InvalidateReadCaches()

    -- Update dungeon clear markers.
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateToggleFromRoomSlot(segment, address, "ep", { 200, 11 })
        updateToggleFromRoomSlot(segment, address, "dp", { 51, 11 })
        updateToggleFromRoomSlot(segment, address, "toh", { 7, 11 })
        updateToggleFromRoomSlot(segment, address, "pod", { 90, 11 })
        updateToggleFromRoomSlot(segment, address, "sp", { 6, 11 })
        updateToggleFromRoomSlot(segment, address, "sw", { 41, 11 })
        updateToggleFromRoomSlot(segment, address, "tt", { 172, 11 })
        updateToggleFromRoomSlot(segment, address, "ip", { 222, 11 })
        updateToggleFromRoomSlot(segment, address, "mm", { 144, 11 })
        updateToggleFromRoomSlot(segment, address, "tr", { 164, 11 })
        updateToggleFromRoomSlot(segment, address, "aga2", { 13, 11 })
    end

    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateSectionChestCountFromRoomSlotList(segment, address, "@Kakariko Well/Cave",
                { { 47, 5 }, { 47, 6 }, { 47, 7 }, { 47, 8 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Kakariko Well/Bombable Wall", { { 47, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Hookshot Cave/Bonkable Chest", { { 60, 7 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Hookshot Cave/Back", { { 60, 4 }, { 60, 5 }, { 60, 6 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Secret Passage/Hallway", { { 85, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Lost Woods Hideout/Lost Woods Hideout", { { 225, 9 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Lumberjack Tree/Lumberjack Tree", { { 226, 9 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Spectacle Rock Cave/Cave", { { 234, 10 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Paradox Cave/Top",
                { { 239, 4 }, { 239, 5 }, { 239, 6 }, { 239, 7 }, { 239, 8 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Super-Bunny Cave/Cave", { { 248, 4 }, { 248, 5 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Spiral Cave/Spiral Cave", { { 254, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Paradox Cave/Bottom", { { 255, 4 }, { 255, 5 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Kakariko Tavern/Back Room", { { 259, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Link's House/Link's House", { { 260, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Sahasrahla's Hut/Back Room",
                { { 261, 4 }, { 261, 5 }, { 261, 6 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Brewery/Brewery", { { 262, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Chest Game/Chest Game", { { 262, 10 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Chicken House/Bombable Wall", { { 264, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Aginah's Cave/Aginah's Cave", { { 266, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@The Dam/Floodgate Chest", { { 267, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Mimic Cave/Mimic Cave", { { 268, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Mire Shed/Shack", { { 269, 4 }, { 269, 5 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@King's Tomb/The Crypt", { { 275, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Waterfall Fairy/Waterfall Fairy", { { 276, 4 }, { 276, 5 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Pyramid Fairy/Big Bomb Spot",
                { { 278, 4 }, { 278, 5 } }, updateBombIndicatorStatus)
        updateSectionChestCountFromRoomSlotList(segment, address, "@Spike Cave/Spike Cave", { { 279, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Graveyard Ledge/Cave", { { 283, 9 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@South of Grove/Cave", { { 283, 10 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@C-Shaped House/House", { { 284, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Blind's Hideout/Basement",
                { { 285, 5 }, { 285, 6 }, { 285, 7 }, { 285, 8 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Blind's Hideout/Bombable Wall", { { 285, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Hype Cave/Cave",
                { { 286, 4 }, { 286, 5 }, { 286, 6 }, { 286, 7 }, { 286, 10 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Ice Rod Cave/Ice Rod Cave", { { 288, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Mini Moldorm Cave/Mini Moldorm Cave",
                { { 291, 4 }, { 291, 5 }, { 291, 6 }, { 291, 7 }, { 291, 10 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Pegasus Rocks/Pegasus Rocks", { { 292, 4 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Checkerboard Cave/Checkerboard Cave", { { 294, 9 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Hammer Pegs/Cave", { { 295, 10 } })
    end

    if AUTOTRACKER_ENABLE_DUNGEON_TRACKING then
        -- For keysanity, update dungeon chest counts directly from the room data since they're all counted.
        if IS_KEYSANITY then
            -- *** Hyrule Castle
            updateSectionChestCountFromRoomSlotList(segment, address, "@Hyrule Castle/Dungeon",
                    { { 114, 4 }, { 113, 4 }, { 128, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Hyrule Castle/Dark Cross",
                    { { 50, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Hyrule Castle/Back of Escape",
                    { { 17, 4 }, { 17, 5 }, { 17, 6 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Hyrule Castle/Sanctuary",
                    { { 18, 4 } })

            -- *** Eastern Palace
            updateSectionChestCountFromRoomSlotList(segment, address, "@Eastern Palace/Front",
                    { { 185, 4 }, { 170, 4 }, { 168, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Eastern Palace/Big Key Chest",
                    { { 184, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Eastern Palace/Big Chest",
                    { { 169, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Eastern Palace/Armos Knights",
                    { { 200, 11 } })

            -- *** Desert Palace
            updateSectionChestCountFromRoomSlotList(segment, address, "@Desert Palace/Map Chest",
                    { { 116, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Desert Palace/Torch",
                    { { 115, 10 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Desert Palace/Big Chest",
                    { { 115, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Desert Palace/Right Side",
                    { { 117, 4 }, { 133, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Desert Palace/Lanmolas",
                    { { 51, 11 } })

            -- *** Tower of Hera
            updateSectionChestCountFromRoomSlotList(segment, address, "@Tower of Hera/Entrance",
                    { { 119, 4 }, { 135, 10 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Tower of Hera/Basement",
                    { { 135, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Tower of Hera/Upper",
                    { { 39, 4 }, { 39, 5 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Tower of Hera/Moldorm",
                    { { 7, 11 } })

            -- *** Agahnim's Tower
            updateSectionChestCountFromRoomSlotList(segment, address, "@Castle Tower/Foyer",
                    { { 224, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Castle Tower/Dark Maze",
                    { { 208, 4 } })

            -- *** Palace of Darkness
            updateSectionChestCountFromRoomSlotList(segment, address, "@Palace of Darkness/Entrance",
                    { { 9, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Palace of Darkness/Big Key Chest",
                    { { 58, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Palace of Darkness/Front",
                    { { 10, 4 }, { 42, 5 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Palace of Darkness/Right Side",
                    { { 42, 4 }, { 43, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Palace of Darkness/Back",
                    { { 106, 4 }, { 106, 5 }, { 25, 4 }, { 25, 5 }, { 26, 5 }, { 26, 6 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Palace of Darkness/Big Chest",
                    { { 26, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Palace of Darkness/Helmasaur King",
                    { { 90, 11 } })

            -- *** Swamp Palace
            updateSectionChestCountFromRoomSlotList(segment, address, "@Swamp Palace/Entrance",
                    { { 40, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Swamp Palace/Bomb Wall",
                    { { 55, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Swamp Palace/Front",
                    { { 70, 4 }, { 53, 4 }, { 52, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Swamp Palace/Big Chest",
                    { { 54, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Swamp Palace/Back",
                    { { 118, 4 }, { 118, 5 }, { 102, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Swamp Palace/Arrgus",
                    { { 6, 11 } })

            -- *** Skull Woods
            updateSectionChestCountFromRoomSlotList(segment, address, "@Skull Woods/Front",
                    { { 103, 4 }, { 87, 4 }, { 87, 5 }, { 104, 4 }, { 88, 5 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Skull Woods/Big Chest",
                    { { 88, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Skull Woods/Back",
                    { { 89, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Skull Woods/Mothula",
                    { { 41, 11 } })

            -- *** Thieves Town
            updateSectionChestCountFromRoomSlotList(segment, address, "@Thieves' Town/Front",
                    { { 219, 4 }, { 219, 5 }, { 203, 4 }, { 220, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Thieves' Town/Attic",
                    { { 101, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Thieves' Town/Blind's Cell",
                    { { 69, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Thieves' Town/Big Chest",
                    { { 68, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Thieves' Town/Blind",
                    { { 172, 11 } })

            -- *** Ice Palace
            updateSectionChestCountFromRoomSlotList(segment, address, "@Ice Palace/Left Side",
                    { { 46, 4 }, { 126, 4 }, { 174, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Ice Palace/Big Chest",
                    { { 158, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Ice Palace/Right Side",
                    { { 95, 4 }, { 63, 4 }, { 31, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Ice Palace/Kholdstare",
                    { { 222, 11 } })

            -- *** Misery Mire
            updateSectionChestCountFromRoomSlotList(segment, address, "@Misery Mire/Right Side",
                    { { 162, 4 }, { 179, 4 }, { 194, 4 }, { 195, 5 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Misery Mire/Big Chest",
                    { { 195, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Misery Mire/Left Side",
                    { { 193, 4 }, { 209, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Misery Mire/Vitreous",
                    { { 144, 11 } })

            -- *** Turtle Rock
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Entrance",
                    { { 214, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Roller Room",
                    { { 183, 4 }, { 183, 5 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Chain Chomps",
                    { { 182, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Big Key Chest",
                    { { 20, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Big Chest",
                    { { 36, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Crystaroller Room",
                    { { 4, 4 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Laser Bridge",
                    { { 213, 4 }, { 213, 5 }, { 213, 6 }, { 213, 7 } })
            updateSectionChestCountFromRoomSlotList(segment, address, "@Turtle Rock/Trinexx",
                    { { 164, 11 } })
        end

        -- GT chests are tracked the same for standard and keysanity, single section for basement and tower each.
        updateSectionChestCountFromRoomSlotList(segment, address, "@Ganon's Tower/Dungeon",
                { { 140, 4 }, { 140, 5 }, { 140, 6 }, { 140, 7 }, { 140, 10 }, { 139, 4 }, { 125, 4 },
                  { 123, 4 }, { 123, 5 }, { 123, 6 }, { 123, 7 }, { 124, 4 }, { 124, 5 }, { 124, 6 }, { 124, 7 },
                  { 28, 4 }, { 28, 5 }, { 28, 6 }, { 141, 4 }, { 157, 4 }, { 157, 5 }, { 157, 6 }, { 157, 7 } })
        updateSectionChestCountFromRoomSlotList(segment, address, "@Ganon's Tower/Tower",
                { { 61, 4 }, { 61, 5 }, { 61, 6 }, { 77, 4 } })
    end
end


-- ****************************************** Item indicators
function updateItemIndicatorStatus(code, status)
    local item = Tracker:FindObjectForCode(code)
    if item then
        if status then
            item.CurrentStage = 1
        else
            item.CurrentStage = 0
        end
    elseif SHOW_ERROR_DEBUG_LOGGING then
        print(string.format("***ERROR*** Couldn't find %s for status update", code))
    end
end

function updateBombIndicatorStatus(status)
    updateItemIndicatorStatus("bombs", status)
end

function updateBatIndicatorStatus(status)
    updateItemIndicatorStatus("powder", status)
end

function updateShovelIndicatorStatus(status)
    updateItemIndicatorStatus("shovel", status)
end

function updateMushroomStatus(status)
    updateItemIndicatorStatus("mushroom", status)
end

function updateNPCItemFlagsActiveLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateNPCItemFlagsLTTP(segment, 0x7ef410)
    end
    return true
end

function updateNPCItemFlagsInactiveLTTP(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateNPCItemFlagsLTTP(segment, getSRAMAddressLTTP(0x410))
    end
    return true
end

function updateNPCItemFlagsLTTP(segment, address)
    InvalidateReadCaches()

    updateSectionChestCountFromByteAndFlag(segment, "@Old Man/Old Man", address, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Zora Area/King Zora", address, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Sick Kid/By The Bed", address, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Stumpy/Stumpy", address, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Sahasrahla's Hut/Sahasrahla", address, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Catfish/Catfish", address, 0x20)
    -- 0x40 is unused
    updateSectionChestCountFromByteAndFlag(segment, "@Library/On The Shelf", address, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Ether Tablet/Tablet", address + 0x1, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Bombos Tablet/Tablet", address + 0x1, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Blacksmith/Bring Him Home", address + 0x1, 0x04)
    -- 0x08 is no longer relevant
    updateSectionChestCountFromByteAndFlag(segment, "@Mushroom/Mushroom", address + 0x1, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Potion Shop/Potion Shop", address + 0x1, 0x20, updateMushroomStatus)
    -- 0x40 is unused
    updateSectionChestCountFromByteAndFlag(segment, "@Magic Bat/Magic Bowl", address + 0x1, 0x80, updateBatIndicatorStatus)
end


-- ****************************************** Overworld checks
function updateSectionChestCountFromOverworldIndexAndFlag(segment, locationRef, address, index, callback)
    updateSectionChestCountFromByteAndFlag(segment, locationRef, address + index, 0x40, callback)
end

function updateOverworldEventsActiveLTTP(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateOverworldEventsLTTP(segment, 0x7ef280)
    end
    return true
end

function updateOverworldEventsInactiveLTTP(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateOverworldEventsLTTP(segment, getSRAMAddressLTTP(0x280))
    end
    return true
end

function updateOverworldEventsLTTP(segment, address)
    InvalidateReadCaches()

    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Spectacle Rock/Spectacle Rock", address, 3)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Floating Island/Island", address, 5)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Maze Race/Maze Race", address, 40)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Flute Spot/Flute Spot", address, 42, updateShovelIndicatorStatus)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Desert Ledge/Desert Ledge", address, 48)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Lake Hylia Island/Lake Hylia Island", address, 53)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@The Dam/Sunken Treasure", address, 59)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Bumper Cave/Ledge", address, 74)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Pyramid/Ledge", address, 91)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Digging Game/Dig For Treasure", address, 104)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Master Sword Pedestal/Pedestal", address, 128)
    updateSectionChestCountFromOverworldIndexAndFlag(segment, "@Zora Area/Zora's Ledge", address, 129)
end


-- ************************* SM functions

-- ****************************************** Items
function updateItemsActiveSM(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateItemsSM(segment, 0x7e09a2)
    end
    return true
end

function updateItemsInactiveSM(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end

    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateItemsSM(segment, mapSRAMAddress(0xa17900))
    end
    return true
end

function updateItemsSM(segment, address)
    InvalidateReadCaches()

    updateToggleItemFromByteAndFlag(segment, "varia", address + 0x02, 0x01)
    updateToggleItemFromByteAndFlag(segment, "spring", address + 0x02, 0x02)
    updateToggleItemFromByteAndFlag(segment, "morph", address + 0x02, 0x04)
    updateToggleItemFromByteAndFlag(segment, "screw", address + 0x02, 0x08)
    updateToggleItemFromByteAndFlag(segment, "gravity", address + 0x02, 0x20)

    updateToggleItemFromByteAndFlag(segment, "hijump", address + 0x03, 0x01)
    updateToggleItemFromByteAndFlag(segment, "space", address + 0x03, 0x02)
    updateToggleItemFromByteAndFlag(segment, "bomb", address + 0x03, 0x10)
    updateToggleItemFromByteAndFlag(segment, "speed", address + 0x03, 0x20)
    updateToggleItemFromByteAndFlag(segment, "grapple", address + 0x03, 0x40)
    updateToggleItemFromByteAndFlag(segment, "xray", address + 0x03, 0x80)

    updateToggleItemFromByteAndFlag(segment, "wave", address + 0x06, 0x01)
    updateToggleItemFromByteAndFlag(segment, "ice", address + 0x06, 0x02)
    updateToggleItemFromByteAndFlag(segment, "spazer", address + 0x06, 0x04)
    updateToggleItemFromByteAndFlag(segment, "plasma", address + 0x06, 0x08)
    updateToggleItemFromByteAndFlag(segment, "charge", address + 0x07, 0x10)
end

-- ****************************************** Keycards
function updateKeycardsActiveSM(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateKeycardsSM(segment, 0x7ed830)
    end
    return true
end

function updateKeycardsInactiveSM(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end

    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateKeycardsSM(segment, mapSRAMAddress(0xa17970))
    end
    return true
end

function updateKeycardsSM(segment, address)
    InvalidateReadCaches()

    updateToggleItemFromByteAndFlag(segment, "crateria_key1", address + 0x00, 0x01)
    updateToggleItemFromByteAndFlag(segment, "crateria_key2", address + 0x00, 0x02)
    updateToggleItemFromByteAndFlag(segment, "crateria_bosskey", address + 0x00, 0x04)
    updateToggleItemFromByteAndFlag(segment, "brinstar_key1", address + 0x00, 0x08)
    updateToggleItemFromByteAndFlag(segment, "brinstar_key2", address + 0x00, 0x10)
    updateToggleItemFromByteAndFlag(segment, "brinstar_bosskey", address + 0x00, 0x20)
    updateToggleItemFromByteAndFlag(segment, "un_key1", address + 0x00, 0x40)
    updateToggleItemFromByteAndFlag(segment, "un_key2", address + 0x00, 0x80)

    updateToggleItemFromByteAndFlag(segment, "un_bosskey", address + 0x01, 0x01)
    updateToggleItemFromByteAndFlag(segment, "maridia_key1", address + 0x01, 0x02)
    updateToggleItemFromByteAndFlag(segment, "maridia_key2", address + 0x01, 0x04)
    updateToggleItemFromByteAndFlag(segment, "maridia_bosskey", address + 0x01, 0x08)
    updateToggleItemFromByteAndFlag(segment, "ws_key1", address + 0x01, 0x10)
    updateToggleItemFromByteAndFlag(segment, "ws_bosskey", address + 0x01, 0x20)
    updateToggleItemFromByteAndFlag(segment, "ln_key1", address + 0x01, 0x40)
    updateToggleItemFromByteAndFlag(segment, "ln_bosskey", address + 0x01, 0x80)

end

-- ****************************************** Ammo
function updateAmmoActiveSM(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateAmmoSM(segment, 0x7e09c2)
    end
    return true
end

function updateAmmoInactiveSM(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end

    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateAmmoSM(segment, mapSRAMAddress(0xa17920))
    end
    return true
end

function updateAmmoSM(segment, address)
    InvalidateReadCaches()

    updateAmmoFrom2Bytes(segment, "etank", address + 0x02)
    updateAmmoFrom2Bytes(segment, "missile", address + 0x06)
    updateAmmoFrom2Bytes(segment, "super", address + 0x0a)
    updateAmmoFrom2Bytes(segment, "pb", address + 0x0e)
    updateAmmoFrom2Bytes(segment, "reservetank", address + 0x12)
end

-- ****************************************** Bosses
function updateSMBossesActive(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateSMBosses(segment, 0x7ed828)
    end
    return true
end

function updateSMBossesInactive(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateSMBosses(segment, getSRAMAddressSM(0x68))
    end
    return true
end

function updateSMBosses(segment, address)
    InvalidateReadCaches()

    updateToggleItemFromByteAndFlag(segment, "kraid", address + 0x1, 0x01)
    updateToggleItemFromByteAndFlag(segment, "ridley", address + 0x2, 0x01)
    updateToggleItemFromByteAndFlag(segment, "phantoon", address + 0x3, 0x01)
    updateToggleItemFromByteAndFlag(segment, "draygon", address + 0x4, 0x01)
end

-- ****************************************** Rooms
function updateRoomsActiveSM(segment)
    if not (isInSM() and isInGameSM()) then
        return false
    end
    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateRoomsSM(segment, 0x7ed870)
    end
    return true
end

function updateRoomsInactiveSM(segment)
    if not (isInLTTP() and isInGameLTTP()) then
        return false
    end
    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateRoomsSM(segment, getSRAMAddressSM(0xb0))
    end
    return true
end

function updateRoomsSM(segment, address)
    InvalidateReadCaches()

    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (Crateria surface)/Power Bomb (Crateria surface)", address + 0x0, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (outside Wrecked Ship bottom)/Missile (outside Wrecked Ship bottom)", address + 0x0, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (outside Wrecked Ship top)/Missile (outside Wrecked Ship top)", address + 0x0, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (outside Wrecked Ship middle)/Missile (outside Wrecked Ship middle)", address + 0x0, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Crateria moat)/Missile (Crateria moat)", address + 0x0, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Gauntlet/Energy Tank, Gauntlet", address + 0x0, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Crateria bottom)/Missile (Crateria bottom)", address + 0x0, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Bombs/Bombs", address + 0x0, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Terminator/Energy Tank, Terminator", address + 0x1, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@After Gauntlet/Missile (Crateria gauntlet right)", address + 0x1, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@After Gauntlet/Missile (Crateria gauntlet left)", address + 0x1, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (Crateria)/Super Missile (Crateria)", address + 0x1, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Crateria middle)/Missile (Crateria middle)", address + 0x1, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (green Brinstar bottom)/Power Bomb (green Brinstar bottom)", address + 0x1, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (Pink Brinstar)/Super Missile (Pink Brinstar)", address + 0x1, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (green Brinstar below super missile)/Missile (green Brinstar below super missile)", address + 0x1, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (green Brinstar top)/Super Missile (green Brinstar top)", address + 0x2, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Reserve Tank, Brinstar/Reserve Tank, Brinstar", address + 0x2, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Missiles (green Brinstar behind reserve tank)/Missile (green Brinstar behind missile)", address + 0x2, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Missiles (green Brinstar behind reserve tank)/Missile (green Brinstar behind reserve tank)", address + 0x2, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (pink Brinstar top)/Missile (pink Brinstar top)", address + 0x2, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (pink Brinstar bottom)/Missile (pink Brinstar bottom)", address + 0x2, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Charge Beam/Charge Beam", address + 0x2, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (pink Brinstar)/Power Bomb (pink Brinstar)", address + 0x3, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (green Brinstar pipe)/Missile (green Brinstar pipe)", address + 0x3, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Morphing Ball/Morphing Ball", address + 0x3, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (blue Brinstar)/Power Bomb (blue Brinstar)", address + 0x3, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (blue Brinstar middle)/Missile (blue Brinstar middle)", address + 0x3, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Brinstar Ceiling/Energy Tank, Brinstar Ceiling", address + 0x3, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Etecoons/Energy Tank, Etecoons", address + 0x3, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (green Brinstar bottom)/Super Missile (green Brinstar bottom)", address + 0x3, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Waterway/Energy Tank, Waterway", address + 0x4, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (blue Brinstar bottom)/Missile (blue Brinstar bottom)", address + 0x4, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Brinstar Gate/Energy Tank, Brinstar Gate", address + 0x4, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Billy Mays Room/Missile (blue Brinstar top)", address + 0x4, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Billy Mays Room/Missile (blue Brinstar behind missile)", address + 0x4, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@X-Ray Scope/X-Ray Scope", address + 0x4, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (red Brinstar sidehopper room)/Power Bomb (red Brinstar sidehopper room)", address + 0x4, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (red Brinstar spike room)/Power Bomb (red Brinstar spike room)", address + 0x5, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (red Brinstar spike room)/Missile (red Brinstar spike room)", address + 0x5, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Spazer/Spazer", address + 0x5, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Kraid/Energy Tank, Kraid", address + 0x5, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Kraid)/Missile (Kraid)", address + 0x5, 0x10)

    updateSectionChestCountFromByteAndFlag(segment, "@Varia Suit/Varia Suit", address + 0x6, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (lava room)/Missile (lava room)", address + 0x6, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Ice Beam/Ice Beam", address + 0x6, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (below Ice Beam)/Missile (below Ice Beam)", address + 0x6, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Crocomire/Energy Tank, Crocomire", address + 0x6, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Hi-Jump Boots/Hi-Jump Boots", address + 0x6, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (above Crocomire)/Missile (above Crocomire)", address + 0x6, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Hi-Jump Boots)/Missile (Hi-Jump Boots)", address + 0x6, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank (Hi-Jump Boots)/Energy Tank (Hi-Jump Boots)", address + 0x7, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (Crocomire)/Power Bomb (Crocomire)", address + 0x7, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (below Crocomire)/Missile (below Crocomire)", address + 0x7, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Grappling Beam)/Missile (Grappling Beam)", address + 0x7, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Grappling Beam/Grappling Beam", address + 0x7, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Norfair Reserve Tank Room/Reserve Tank, Norfair", address + 0x7, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Norfair Reserve Tank Room/Missile (Norfair Reserve Tank)", address + 0x7, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (bubble Norfair green door)/Missile (bubble Norfair green door)", address + 0x7, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Missile (bubble Norfair)/Missile (bubble Norfair)", address + 0x8, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Speed Booster)/Missile (Speed Booster)", address + 0x8, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Speed Booster/Speed Booster", address + 0x8, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Wave Beam)/Missile (Wave Beam)", address + 0x8, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Wave Beam/Wave Beam", address + 0x8, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Gold Torizo)/Missile (Gold Torizo)", address + 0x8, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (Gold Torizo)/Super Missile (Gold Torizo)", address + 0x8, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Mickey Mouse room)/Missile (Mickey Mouse room)", address + 0x9, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (lower Norfair above fire flea room)/Missile (lower Norfair above fire flea room)", address + 0x9, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (lower Norfair above fire flea room)/Power Bomb (lower Norfair above fire flea room)", address + 0x9, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (Power Bombs of shame)/Power Bomb (Power Bombs of shame)", address + 0x9, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (lower Norfair near Wave Beam)/Missile (lower Norfair near Wave Beam)", address + 0x9, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Ridley/Energy Tank, Ridley", address + 0x9, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Screw Attack/Screw Attack", address + 0x9, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Firefleas/Energy Tank, Firefleas", address + 0xa, 0x01)

    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Wrecked Ship middle)/Missile (Wrecked Ship middle)", address + 0x10, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Reserve Tank, Wrecked Ship/Reserve Tank, Wrecked Ship", address + 0x10, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Gravity Suit)/Missile (Gravity Suit)", address + 0x10, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Wrecked Ship top)/Missile (Wrecked Ship top)", address + 0x10, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Wrecked Ship/Energy Tank, Wrecked Ship", address + 0x10, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (Wrecked Ship left)/Super Missile (Wrecked Ship left)", address + 0x10, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Right Super, Wrecked Ship/Right Super, Wrecked Ship", address + 0x10, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Gravity Suit/Gravity Suit", address + 0x10, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Missile (green Maridia shinespark)/Missile (green Maridia shinespark)", address + 0x11, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (green Maridia)/Super Missile (green Maridia)", address + 0x11, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Mama turtle/Energy Tank, Mama turtle", address + 0x11, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (green Maridia tatori)/Missile (green Maridia tatori)", address + 0x11, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Watering Hole/Super Missile (yellow Maridia)", address + 0x11, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Watering Hole/Missile (yellow Maridia super missile)", address + 0x11, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (yellow Maridia false wall)/Missile (yellow Maridia false wall)", address + 0x11, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Plasma Beam/Plasma Beam", address + 0x11, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@West Sand Hole/Missile (left Maridia sand pit room)", address + 0x12, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@West Sand Hole/Reserve Tank, Maridia", address + 0x12, 0x02)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (right Maridia sand pit room)/Missile (right Maridia sand pit room)", address + 0x12, 0x04)
    updateSectionChestCountFromByteAndFlag(segment, "@Power Bomb (right Maridia sand pit room)/Power Bomb (right Maridia sand pit room)", address + 0x12, 0x08)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (pink Maridia)/Missile (pink Maridia)", address + 0x12, 0x10)
    updateSectionChestCountFromByteAndFlag(segment, "@Super Missile (pink Maridia)/Super Missile (pink Maridia)", address + 0x12, 0x20)
    updateSectionChestCountFromByteAndFlag(segment, "@Spring Ball/Spring Ball", address + 0x12, 0x40)
    updateSectionChestCountFromByteAndFlag(segment, "@Missile (Draygon)/Missile (Draygon)", address + 0x12, 0x80)

    updateSectionChestCountFromByteAndFlag(segment, "@Energy Tank, Botwoon/Energy Tank, Botwoon", address + 0x13, 0x01)
    updateSectionChestCountFromByteAndFlag(segment, "@Space Jump/Space Jump", address + 0x13, 0x04)
end

-- *************************** Setup/startup stuff

function cleanup()
    -- Clean up existing memory watches and cache data.
    if GAME_WATCH then
        ScriptHost:RemoveMemoryWatch(GAME_WATCH)
    end
    GAME_WATCH = nil

    clearMemoryWatches()

    AUTOTRACKER_IS_IN_LTTP = false
    AUTOTRACKER_IS_IN_SM = false

    OPENED_DOORS = {}
    OPENED_CHESTS = {}
    DUNGEON_ITEMS = {}
    REMAINING_KEYS = {}
    FLOOR_KEYS = {}
end

-- Invoked when the auto-tracker is activated/connected
function autotracker_started()
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
        print("**** Auto-Tracker started ****")
    end
    cleanup()

    -- Initialize watch for when the game changes.  Everything else happens in there.
    GAME_WATCH = ScriptHost:AddMemoryWatch("Which Game Is It Anyways", mapSRAMAddress(0xa173fe), 0x02, updateGame, 250)
end

--Invoked when the auto-tracker is stopped.
function autotracker_stopped()
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
        print("**** Auto-Tracker stopped ****")
    end
    cleanup()
end

-- This is kind of hacky, but the tracker needs at least one memory watch set up in order to detect that the package
-- uses auto-tracking.  The only one that is active all the time is the "Which Game Is It Anyways" watch, but until we
-- get proper native addressing we can't initialize it until we know what connector is selected.
-- This is a dummy entry that will do nothing, the actual watches will be set when it starts above.
-- Set this watch interval to 60 seconds so it fires infrequently.
function noop()
    return true
end

ScriptHost:AddMemoryWatch("Dummy Auto-Tracking Marker", 0x7e0000, 0x01, noop, 60 * 1000)
