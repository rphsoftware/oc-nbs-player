--local drone = component.proxy(component.list("drone")())
local args = {...}

local function trim(n)
	return n & 0xFFFFFFFF
end

local bit32 = {}

function bit32.lshift(x, disp)
	return trim(x << disp)
end

local song = args[1]
local readOffset = 1

function readInteger()
    local buffer = song:sub(readOffset, readOffset + 3)
    readOffset = readOffset + 4
 
    -- We dont deal with garbage
    if buffer == nil or #buffer < 4 then
        return nil
    end
 
    local bytes = {}
    bytes[1] = string.byte(buffer, 1)
    bytes[2] = string.byte(buffer, 2)
    bytes[3] = string.byte(buffer, 3)
    bytes[4] = string.byte(buffer, 4)
 
    local num = bytes[1] + bit32.lshift(bytes[2], 8) + bit32.lshift(bytes[3], 16) + bit32.lshift(bytes[4], 24)
    return num
end

function readShort()
    local buffer = song:sub(readOffset, readOffset + 1)
    readOffset = readOffset + 2
 
    if buffer == nil or #buffer < 2 then
        return nil
    end
 
    local bytes = {}
    bytes[1] = string.byte(buffer, 1)
    bytes[2] = string.byte(buffer, 2)
 
    local num = bytes[1] + bit32.lshift(bytes[2], 8)
    return num
end

function readByte()
	local buffer = song:sub(readOffset, readOffset)
	readOffset = readOffset + 1

	return string.byte(buffer, 1)
end

function readString()
	local length = readInteger()
--	drone.setStatusText(tostring(length))
	local txt = song:sub(readOffset, length)
	readOffset = readOffset + length

	return txt
end

for i=1,2 do readShort() end
for i=1,4 do readString() end

local tempo = readShort()

for i=1,3 do readByte() end
for i=1,5 do readInteger() end
readString()

local ticks = {}
local currenttick = -1
local sound = component.proxy(component.list("sound")())
local instruments = {
    {sound.modes.square, 1},
    {sound.modes.triangle, 0.6},
    {sound.modes.noise, 0.6},
    {sound.modes.noise, 0.6},
    {sound.modes.noise, 0.6},
    {sound.modes.triangle, 0.6},
    {sound.modes.sine, 0.6},
    {sound.modes.sine, 0.6},
    {sound.modes.square, 0.6},
    {sound.modes.noise, 0.6}
}

while true do
	local step = readShort()

	if step == 0 then
		break
	end

	currenttick = currenttick + step

	local lpos = 1

	ticks[currenttick] = {}

	while true do
		local jump = readShort()

		if jump == 0 then
			break
		end

		local inst = readByte()
		local note = readByte()

		ticks[currenttick][lpos] = {}
		ticks[currenttick][lpos]["inst"] = instruments[inst + 1]
		ticks[currenttick][lpos]["note"] = freq[note + 1]
		lpos = lpos + 1
	end
	if currenttick % 100 == 0 then
		computer.pullSignal(0)
	end
end

return ticks, currenttick, tempo