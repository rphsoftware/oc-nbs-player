local args = {...}
local ticks = args[1]
local currenttick = args[2]
local tempo = args[3]
local frame = math.floor(1000 / (tempo / 100))
local framebit = frame / 32
local stime = frame / 1000 - 0.02
local sound = component.proxy(component.list("sound")())
local drone = component.proxy(component.list("drone")())

drone.setStatusText("Playing\nWait...")

function soundReset()
    sound.setTotalVolume(1)
    for i=1, 8 do
        sound.setWave(i, sound.modes.sine)
        sound.setFrequency(i, 0)
        sound.setVolume(i, 0)
        sound.resetFM(i)
        sound.resetAM(i)
        sound.resetEnvelope(i)
        sound.open(i)
    end
    sound.process()
end

function sleep(timeout)
	local deadline = computer.uptime() + (timeout or 0)
	repeat
		computer.pullSignal(deadline - computer.uptime())
	until computer.uptime() >= deadline
end

soundReset()

sleep(1)

soundReset()
drone.setStatusText("1")
for i=0, currenttick do
	local unused = 1

	if ticks[i] then
		local tick = ticks[i]

		for aaa = 1, #tick do
			local instrument = tick[aaa]["inst"]
			local f = tick[aaa]["note"]
			
			sound.setWave(aaa, instrument[1])
			sound.setVolume(aaa, instrument[2])
			sound.setFrequency(aaa, f)

			sound.setADSR(aaa, framebit * 4, framebit * 8, instrument[2] - 0.1, framebit * 4)

			unused = aaa + 1
		end
	end

	for aaa = unused, 8 do
		sound.setVolume(aaa, 0)
		sound.setFrequency(aaa, 0)
	end

	sound.delay(frame)
	sound.process()
	
	sleep(stime)
	--[[
	if i % 20 == 0 then
		drone.setStatusText(i .. "/" .. currenttick)
		drone.move(math.random(-1, 1), math.random(1, -1), math.random(1, -1))
	end
	]]--
	if i % 500 == 0 then
		soundReset()
	end
end