data_per_region = {
    ["Z1 Overworld"] = {
        ["scene"] = "Z1Overworld"
        ["Entrances"] = {
            ["Open Caves"] = function()
                return AccessibilityLevel.Normal
            end
            ["Burn Bushes"] = function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Bomb Walls"] = function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Raft Spot"] = function()
                if has("z1raft") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Recorder Spot"] = function()
                if has("z1recorder") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Warp Zone"] = function()
                if has("z1bracelet") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
        }
    },
    ["Open Caves"] = {
        ["scene"] = "Z1Overworld"
        ["locations"] = {
            ["Map 04 - Open Cave"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 0A - Cave 12 - White Sword"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 0B - Level 5 Entrance"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 0C - Lost Hills Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 0E - Cave 18 - Letter Cave"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 0F - Corner Secret"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 1A - Waterfall"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 1C - Lost Hills Armos"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 1F - Coast Gamble"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 21 - Cave 13 - Magic Sword"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 22 - Level 6 Entrance"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 25 - Graveyard Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 34 - Armos Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 37 - Level 1 Entrance"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 3C - Level 2 Entrance"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 3D - Upper Forest Armos"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 44 - Lake Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 4A - Desert Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 4E - Lower Forest Armos"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 5E - Forest Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 64 - Dead Woods Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 6F - Coast Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 70 - Hint Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 74 - Level 3 Entrance"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 75 - Hint Shop"] function()
                return AccessibilityLevel.Normal
            end
            ["Map 77 - Cave 10 - Wood Sword"] function()
                return AccessibilityLevel.Normal
            end
        }
    },
    ["Burn Bushes"] = {
        ["scene"] = "Z1Overworld"
        ["locations"] = {
            ["Map 28 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 46 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 47 - Burn Bush Take Any"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 48 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 4B - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 4D - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 51 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 56 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 5B - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 62 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 63 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 68 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 6A - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 6B - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 6C - Level 8 Entrance"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 78 - Burn Bush"] function()
                if has("z1candle") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
        }
    },
    ["Bomb Walls"] = {
        ["scene"] = "Z1Overworld"
        ["locations"] = {
            ["Map 01 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 03 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 05 - Spectacle Rock Entrance"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end        
            ["Map 07 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            
            ["Map 0D - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 10 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 12 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end        
            ["Map 13 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 14 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 16 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 1E - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 26 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 27 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 2C - Monocle Rock Take Any"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 2D - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 33 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 67 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 71 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 76 - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 7B - South Shore Take Any"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 7C - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 7D - Bomb Wall"] function()
                if has("z1bomb") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
        }
    },
    ["Raft Spot"] = {
        ["scene"] = "Z1Overworld"
        ["locations"] = {
            ["Map 2F - Raft Spot Take Any"] function()
                if has("z1raft") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 45 - Level 4 Entrance"] function()
                if has("z1raft") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
        }
    },
    ["Recorder Spot"] = {
        ["scene"] = "Z1Overworld"
        ["locations"] = {
            ["Map 42 - Level 7 Entrance"]function()
                if has("z1recorder") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
        }
    },
    ["Warp Zone"] = {
        ["scene"] = "Z1Overworld"
        ["locations"] = {
            ["Map 1D - Lost Hills Warp"] function()
                if has("z1bracelet") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 23 - Graveyard Warp"] function()
                if has("z1bracelet") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            ["Map 49 - Desert Warp"] function()
                if has("z1bracelet") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
            
            ["Map 79 - South Warp"] function()
                if has("z1bracelet") then
                    return AccessibilityLevel.Normal
                end
                return AccessibilityLevel.None
            end
        }                                                                                                                                                                
    }
}