-- Two bindings input.conf cannot express on its own. Keys are bound in
-- mpv.nix; this only names the actions.
local held

-- Hold for 5x, release to restore. Only `script-binding` targets get key-up
-- events, so a plain input.conf line cannot do this.
mp.add_key_binding(nil, "hold-speed", function(e)
	if e.event == "down" and not held then
		held = mp.get_property_number("speed", 1)
		mp.set_property_number("speed", 6)
	elseif e.event == "up" and held then
		mp.set_property_number("speed", held)
		held = nil
	end
end, { complex = true })

-- Undo a fumbled key: every property a stray keypress changes for one file.
-- mpv has no built-in reset, and these are global properties, so reloading
-- the file does not clear them either.
local defaults = {
	speed = 1,
	["video-zoom"] = 0,
	["video-pan-x"] = 0,
	["video-pan-y"] = 0,
	["video-rotate"] = 0,
	["video-aspect-override"] = -1,
	panscan = 0,
	brightness = 0,
	contrast = 0,
	gamma = 0,
	saturation = 0,
	hue = 0,
	["audio-delay"] = 0,
	["sub-delay"] = 0,
	["sub-pos"] = 100,
	["sub-scale"] = 1,
}
mp.add_key_binding(nil, "reset-settings", function()
	for name, value in pairs(defaults) do
		mp.set_property_number(name, value)
	end
	mp.osd_message("settings reset")
end)
