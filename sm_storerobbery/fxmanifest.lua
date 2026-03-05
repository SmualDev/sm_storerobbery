fx_version 'cerulean'
game 'gta5'

lua54 'yes'

description 'Store Robbery - Smual'

shared_script 'config.lua'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'ox_target',
    'ox_inventory',
    'ox_lib'
}