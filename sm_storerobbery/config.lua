Config = {}



Config.itemRequired = {
    'lockpick',             --- Items Required To break into till to begin robbery
    'advanced_lockpick'
}

Config.lockpickNormalIterations = 5
Config.lockpickNormalDifficulty = 70

Config.lockpickAdvancedIterations = 3 
Config.lockpickAdvancedDifficulty = 55

Config.SecurityIterations = 3
Config.SecurityNodes = 10
Config.SecurityDuration = 10000 

Config.StoreCooldown = 1000

Config.Chance = 100 -- Chance of Gaining Safe Password in Till (1 to 100)
--[[
In Config.DispatchType configure to what dispatch system you are using
if you want to use
Core Dispatch = "core"
Code Design Dispaatch = "cd"
PS Dispatch = "ps"
Wasabi Dispatch = "wasabi"
Custom Dispatch = "custom"
]]--

Config.DispatchType = "ps"


--[[
Store Location Config Stores have all been set to Stores around the city if you want to add custom ones will add template below

]]--
Config.Stores = {
    ["clinton24_1"] = {
        label = "Clinton Ave 24/7",

        till = {
            coords = vec3(374.320892, 328.325287, 103.553833),
            size = vec3(1, 1, 1),
            rotation = 0
        },
        smashCoords = {
            sCoords = vec3(373.134064, 328.707703, 102.553833),
            heading = 270.0
        },

        safe = {
            coords = vec3(378.065948, 333.402191, 103.553833),
            size = vec3(1, 1, 1),
            rotation = 0
        }
    },
        ["mirrorp24_2"] = {
        label = "Mirror Park 24/7",

        till = {
            coords = vec3(1163.512085, -322.971436, 69.197021),
            size = vec3(1, 1, 1),
            rotation = 0

        },

        smashCoords = {
            sCoords = vec3(1164.764893, -322.786804, 68.197021),
            heading = 99.212593
        },


        safe = {
            coords = vec3(1159.490112, -314.004395, 69.197021),
            size = vec3(1, 1, 1),
            rotation = 0,
            heading = 102.047249
        }
    },
        ["innocence24_3"] = {
        label = "Innocence Blvd 24/7",

        till = {
            coords = vec3(25.701101, -1345.041748, 29.482056),
            size = vec3(1, 1, 1),
            rotation = 0

        },

        smashCoords = {
            sCoords = vec3(24.474728, -1344.909912, 28.482056),
            heading = 272.12
        },


        safe = {
            coords = vec3(28.153849, -1339.147217, 29.482056),
            size = vec3(1, 1, 1),
            rotation = 0,
            heading = 0
        }
    },
        ["grove24_4"] = {
        label = "Grove Street 24/7",

        till = {
            coords = vec3(-47.657143, -1757.129639, 29.414673),
            size = vec3(1, 1, 1),
            rotation = 0

        },

        smashCoords = {
            sCoords = vec3(-46.707691, -1757.934082, 29.414673),
            heading = 48.18
        },


        safe = {
            coords = vec3(-43.384613, -1748.373657, 29.414673),
            size = vec3(1, 1, 1),
            rotation = 0,
            heading = 51.0
        }
    },
        ["lilsoul24_5"] = {
        label = "Little Seoul 24/7",

        till = {
            coords = vec3(-707.353821, -913.753845, 19.203613),
            size = vec3(1, 1, 1),
            rotation = 0

        },

        smashCoords = {
            sCoords = vec3(-706.114258, -913.569214, 19.203613),
            heading = 87.87
        },


        safe = {
            coords = vec3(-709.780212, -904.180237, 19.203613),
            size = vec3(1, 1, 1),
            rotation = 0,
            heading = 87.87
        }
    }  
    

}