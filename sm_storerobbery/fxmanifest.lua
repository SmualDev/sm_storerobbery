fx_version 'cerulean'
game 'gta5'

author 'Smual'
description 'A robbery script for FiveM servers, allowing players to rob various locations and earn rewards.'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'bl_ui'
}
