local args = {...}
local url = args[1] or "/tat.nbs"
local drone = component.proxy(component.list("drone")())
local internet = component.proxy(component.list("internet")())

function fetch(url)
	local request = internet.request(url)
	request:finishConnect()

	local data = ""
	repeat
		local s = request.read(1024)
		if s ~= nil then
			data = data .. s
		end
	until ( not s )
	return data		
end

drone.setStatusText("Loading\nParser")
drone.move(1,1,1)

local parser = fetch("http://nocf.rph.space/dronesong/parser.lua")

drone.setStatusText("Loading\nSong    ")
drone.move(1,-1,0)

local song = fetch("http://nocf.rph.space" .. url)

drone.setStatusText("Loading\nPlayer   ")
drone.move(0,0,-1)
local player = fetch("http://nocf.rph.space/dronesong/player.lua")

drone.setStatusText("Loading\nFreqTab   ")
drone.move(-1, 0, 0)
local freqtab = fetch("http://nocf.rph.space/dronesong/freqtab.lua")

drone.setStatusText("Exec    \nFreqTab")
drone.move(-1, 0, 0)

load(freqtab)()

drone.setStatusText("Exec\nParser")

local ticks, currenttick, tempo = load(parser)(song)

drone.setStatusText("Playing\n        ")
while true do
	load(player)(ticks, currenttick, tempo)
	drone.setStatusText("Replay")
	computer.pullSignal(2)
end