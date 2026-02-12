for region, region_data in pairs(data_per_region) do
  if type(region_data.locations) == "table" then
    for location, location_data in pairs(region_data.locations) do
      local is_same_scene = data_per_region[location].scene == region_data.scene
      if not is_same_scene then
        local location = string.format("@%s -> %s", region, location)
        location_data.location_object = get_object(location)
        local section = string.format("%s/Capture", location)
        location_data.section_object = get_object(section)
      end
    end
  end
end
