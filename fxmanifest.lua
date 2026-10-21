fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
version '2.1.1'
shared_scripts {
	'@ox_lib/init.lua',
}
client_scripts {
	'client/compat/init.lua',
	'init.lua',
	'client/*.lua',
}
ui_page 'web/textui.html'
files {
	'init.lua',
	'web/**',
	'client/modules/*.lua',
	'client/framework/*.lua',
	'client/compat/resources/*.lua'
}
provides {
	'ox_target',
	-- 'interact',
	'qtarget',
	'qb-target'
}
dependency 'ox_lib'


