fx_version 'cerulean'
game 'gta5'

name "Used Car Dealer"
author "Made with love by Samuel#0008"
version "1.0.0"
description "Advanced used car dealer system with bridge support"

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/shared.lua',
    'bridge/init.lua',
    'config.lua'
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/*.lua'
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_target'
}