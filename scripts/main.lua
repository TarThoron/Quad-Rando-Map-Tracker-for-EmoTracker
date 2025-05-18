function init()
    if INITIALIZED == nil then
        -- Used for automatically adding/removing consumable count when a toggle is enabled/disabled, or for updating other items based on a specific item's action.
        ITEM_STATE_LIST = {
            ["m1kraid"]   = false,
            ["m1ridley"] = false,
        }

        INITIALIZED = true
    end
end

function tracker_on_accessibility_updated()
    --[[    This is the table of item codes we care about making updates for.
            It should ideally contain the keys from ITEM_STATE_LIST
    ]]
    local item_list = {
        "m1kraid",
        "m1ridley",
    }

    if INITIALIZED then
        for i = 1, #item_list do
            local item = Tracker:FindObjectForCode(item_list[i])
            local state = ITEM_STATE_LIST[item_list[i]]
            item_check(item,state)
        end
    end
end

---This function is unique to a specific item as defined by the first local variable.
---The consumable in this function is updated by the toggle defined by the first parameter.
---The consumable to update is hard-coded here.
---@param item any -- The item object of the togglable item
function _update_m1missile_count(item)
    local consumable = Tracker:FindObjectForCode("m1missile") -- change this to change what consumable is being updated

    if item.Active then
        debug_log("callback", "add 75 count to m1missile")
        consumable:Increment(15)
    else
        debug_log("callback", "subtract 75 count from m1missile")
        consumable:Decrement(15)
    end
    ITEM_STATE_LIST["m1kraid"] = item.Active
end

---This function is unique to a specific item as defined by the first local variable.
---The consumable in this function is updated by the toggle defined by the first parameter.
---The consumable to update is hard-coded here.
---@param item any -- The item object of the togglable item
function _update_m1missile_count_2(item)
    local consumable = Tracker:FindObjectForCode("m1missile") -- change this to change what consumable is being updated

    if item.Active then
        debug_log("callback", "add 75 count to m1missile")
        consumable:Increment(15) -- Note: example_consumable_2 has increments of 5
    else
        debug_log("callback", "subtract 75 count from m1missile")
        consumable:Decrement(15)
    end
    ITEM_STATE_LIST["m1ridley"] = item.Active
end

---Checks items listed in `item_to_update_function`
---@param item any -- An Item object to
---@param prev_state any
function item_check(item, prev_state)
    -- Update item state table when registered items are toggled
    -- between active and inactive.

    if item.Active == prev_state then
        return
    elseif item.AcquiredCount == prev_state then
        return
    elseif item.CurrentStage == prev_state then
        return
    end

    --[[
        This list is formated as a table of "Item Name" = function()
        Item names are defined as the "name" property of an item as defined in
        your item json files.
        Functions are defined to be unique to each item.
        for example:
        {
            ["Item Name 1"] = _callback_to_update_1,
            ["Item Name 2"] = _callback_to_update_2,
        }
    ]]
    local item_to_update_function = {
        ["M1Kraid"]   = _update_m1missile_count,
        ["M1Ridley"] = _update_m1missile_count_2,
    }

    local callback = item_to_update_function[item.Name]

    if not callback then
        debug_log("item_check", string.format("item %s has no callback function", item.Name))
        return
    end

    callback(item)
end

---Used for outputting logs in developer console
---@param x string
---@param str string
function debug_log(x, str)
    if DEBUG_MODE == true then
        print("DEBUG: "..x..": "..tostring(str))
    end
end
