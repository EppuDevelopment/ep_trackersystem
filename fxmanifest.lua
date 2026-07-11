fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'EP Development'
description 'Shared emergency service tracker blips'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

files {
    'locales/*.json'
}

client_scripts {
    'client/modules/framework.lua',
    'client/main.lua'
}

server_scripts {
    'server/modules/framework.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib'
}
