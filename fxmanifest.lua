fx_version 'cerulean'
game 'gta5'

name 'berkie_states'
author 'BerkieB'
description 'Server-side state manager for FiveM'
version '1.1.4'
repository 'https://github.com/BerkieBb/berkie_states'
license 'GPL v3'

server_scripts {
    'config.lua',
    'server.lua'
}

dependencies {
    '/onesync',
    '/server:6129'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'