access_per_region = {}
location_access = {}

function set_region_access(to_region, new_access, from_access)
    if ACCESS_LEVEL[from_access] < ACCESS_LEVEL[new_access] then
      new_access = from_access
    end
    local old_access = access_per_region[to_region]
    if ACCESS_LEVEL[old_access] < ACCESS_LEVEL[new_access] then
      changed_access = true
      access_per_region[to_region] = new_access
    end
end
  
function set_location_access(location, new_access, from_access)
    if ACCESS_LEVEL[from_access] < ACCESS_LEVEL[new_access] then
      new_access = from_access
    end
    local old_access = location_access[location] or AccessibilityLevel.None
    if ACCESS_LEVEL[old_access] < ACCESS_LEVEL[new_access] then
      changed_access = true
      location_access[location] = new_access
    end
end

function update_region_connections()
    invalidate_regions()
    invalidate_locations()
  
    access_per_region["Z1 Overworld"] = AccessibilityLevel.Normal
  
    changed_access = true
    while changed_access do
        changed_access = false
        for region, access in pairs(access_per_region) do
            if access ~= AccessibilityLevel.None then
                local region_data = data_per_region[region]
  
                if type(region_data.Entrances) == "table" then
                    for location, location_data in pairs(region_data.Entrances) do
                        local new_access = location_data()
        
                        set_location_access(location, new_access, access)
                    end
                end

                if type(region_data.Entrances) == "table" then
                    for entrance, entrance_data in pairs(region_data.Entrances) do
                      local new_access = entrance_data()
        
                      local is_same_scene = data_per_region[location].scene == region_data.scene
        
                        if is_same_scene then
                          set_region_access(location, new_access, access)
                        elseif not is_same_scene then
                            if location_data.capture and data_per_region[location_data.capture] then
                                set_region_access(location_data.capture, new_access, access)
                            end
                        end
                    end
                end
            end
        end
    end
end

function access_region(region)
    region = region or ""
    return AccessibilityLevel.None
end

function access_location(location)
    if not location then
      return 0, AccessibilityLevel.None
    end
    local access = AccessibilityLevel.None
  
    local level = ACCESS_LEVEL[access]
    if level > 0 then
      return 1, access
    end
    return 0, AccessibilityLevel.None
  end