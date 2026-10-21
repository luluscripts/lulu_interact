local config = {}

-- this is the maximum distance that interacts will render the indicator sprite (little cirlce)
-- recommend keeping this pretty low for optimization
config.maxInteractDistance = 4.0

config.themeColor = { 0, 122, 255, 255 } --- r, g, b, a

--- texture dictionary and texture name for the sprite used to show non active interactions.
config.IndicatorSprite = { dict = 'shared', txt = 'emptydot_32' }

return config