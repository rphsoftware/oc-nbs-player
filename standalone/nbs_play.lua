--[[
  NBS PARSE
  Read a .nbs file and play it using a computronics sound card
--]]
local bit32 = require('bit32')
local component = require('component')
local shell = require('shell')
local fs = require('filesystem')
local sound = component.sound
local notelib = require('note')
local serialization

local args,options = shell.parse(...)
local nogpu = false
if options.nogpu == true then
    nogpu = true
end
local db = false
if options.db == true and options.nogpu == true then
    serialization = require('serialization')
    db = true
end
if #args == 0 then
    io.write("Usage: nbs_parse <filename>")
    return
end

local filename = shell.resolve(args[1])

if not fs.exists(filename) then
    io.stderr:write("No such file!")
    return 1
end

-- Load EVERYTING! into memory
local handle = io.open(filename, "rb")
local w, h
local gpu = component.list("gpu", true)()
local screen = component.list("screen", true)()
if nogpu == false then
    gpu = component.proxy(gpu)
    gpu.bind(screen)
    if gpu and screen then
        w, h = gpu.maxResolution()
        gpu.setResolution(w, h)
        gpu.setBackground(0x333333)
        gpu.setForeground(0xD2D2D2)
        gpu.fill(1, 1, w, h, " ")
    end
end
-- A set of helper functions
local function title ( msg )
    if gpu and screen and nogpu == false then
        gpu.fill(1, h/2 - 1, w, 1, " ")
        local len = #msg
        local pos = math.floor((w - len)/2)
        gpu.set(pos, h/2 - 1, msg)
    end
end
local function status( msg )
    --[[
      if gpu and screen then
        gpu.fill(w/2, h/2, 100, 2, " ")
      end
      local _, lines = msg:gsub("\n", "\n")
      for ln, i in pairs(_) do
        gpu.set(((w-string.len(ln))/2),(h/2)-i, ln)
      end
    ]]--
    if gpu and screen and nogpu ==false then
        gpu.fill(1, h/2, w, 1, " ")
        local len = #msg
        local pos = math.floor((w - len)/2)
        gpu.set(pos, h/2, msg)
    end
end
function readInteger(handle)
    local buffer = handle:read(4)

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

function readShort(handle)
    local buffer = handle:read(2)

    if buffer == nil or #buffer < 2 then
        return nil
    end

    local bytes = {}
    bytes[1] = string.byte(buffer, 1)
    bytes[2] = string.byte(buffer, 2)

    local num = bytes[1] + bit32.lshift(bytes[2], 8)
    return num
end

function readByte(handle)
    local buffer = handle:read(1)

    if buffer == nil then
        return nil
    end

    return string.byte(buffer, 1)
end

function readString(handle)
    local length = readInteger(handle)
    local txt = handle:read(length)
    return txt
end

-- Begin loading the song
-- Metadata
local song = {}
song["length"] = readShort(handle)
song["height"] = readShort(handle)
song["name"] = readString(handle)
song["author"] = readString(handle)
song["ogauthor"] = readString(handle)
song["desc"] = readString(handle)
song["tempo"] = readShort(handle)

-- Throw out a few values (Noteblock studio keeps them for no fucking reason)
for i=1,3 do readByte(handle) end
for i=1,5 do readInteger(handle) end
readString(handle)

-- This stuff is here to take some math out of playback routine
-- Calculate the frame in miliseconds based on the conception that tempo is ticks count is 100 times the amount of them in a second
-- Each frame is a length of the tick
local frame = math.floor(1000 / (song["tempo"] / 100))
local sleep = frame / 1000 - 0.02

-- Make an array of notes from A0 to B8 as that is the range NBS uses
local tempNotes = {
    "c",
    "c#",
    "d",
    "d#",
    "e",
    "f",
    "f#",
    "g",
    "g#",
    "a",
    "a#",
    "b"
}

local assoc = {}

-- We insert those manually as we ignore any "0"s prior to A0
table.insert(assoc, "a0")
table.insert(assoc,"a#0")
table.insert(assoc,"b0")

-- And go from C1 to B8
for i = 1, 8 do
    for _,v in ipairs(tempNotes) do
        table.insert(assoc, v..tostring(i))
    end
end

-- Define instruments (waveform, relative volume)
-- I should probably move it to some file in /etc
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
--end optimizat

local ticks = {}
local currenttick = -1

title("Reading file")
status("Preparing to read notes")

while true do
    -- We skip by step layers ahead
    local step = readShort(handle)

    -- A zero step means we go to the next part (which we don't need so we just ignore that)
    if step == 0 then
        break
    end

    currenttick = currenttick + step

    -- lpos is the current layer (in the internal structure, we ignore NBS's editor layers for convenience)
    local lpos = 1
    ticks[currenttick] = {}

    while true do
        -- Check how big the jump from this note to the next one is
        local jump = readShort(handle)

        -- If its zero, we should go to the next tick
        if jump == 0 then
            break
        end

        -- But if its not, we read the instrument and note number
        local inst = readByte(handle)
        local note = readByte(handle)

        -- And add them to the internal structure
        ticks[currenttick][lpos] = {}
        ticks[currenttick][lpos]["inst"] = instruments[inst + 1]
        ticks[currenttick][lpos]["note"] = notelib.freq(assoc[note + 1])
        lpos = lpos + 1
    end

    if currenttick % 20 == 0 then status("" .. currenttick .. " of " .. song.length .. " ticks") end
end

-- We do not need any more of the file, goodbye!
handle:close()

status("Blasting data to soundcard..")


-- This function resets the state of the sound card (well, mostly, but enough for our needs)
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

-- Play a quick test sequence
status("Testing sound card..")
soundReset()

for i=1, 8 do
    sound.setFrequency(i, i * 200)
    sound.setVolume(i, 1)
    sound.delay(frame)
    sound.process()
    os.sleep(frame / 1000)
end
status("Testing sound card... OK!")
os.sleep(0.5)
soundReset()

-- fb stands for frame bit
local fb = frame / 32

title("Currently playing:")
-- Hey, we have currenttick from before; Why don't we use it for good?
for i=0, currenttick do
    -- Unused is a channel number from which start unused channels
    local unused = 1

    -- We may not even have data for this tick (like when it is blank), why waste time even processing it?
    if ticks[i] then
        -- The following line is used here mostly to reduce code clutter
        local tick = ticks[i]


        -- That can cause some confusion, tho. aaa is note id in this tick
        for aaa = 1, #tick do
            -- So we do some quick lookups. ( + 1 used because lua is retarded and has arrays start at 1, NBS indexes from 0)
            -- I suppose we could save CPU time here by incrementing the values on file read
            local instrument = tick[aaa]["inst"]
            local freq = tick[aaa]["note"]

            -- Send this stuff to the sound card
            sound.setWave(aaa, instrument[1])
            sound.setVolume(aaa, instrument[2])
            sound.setFrequency(aaa, freq)

            -- Make the sound less jagged and more nice to the ear
            sound.setADSR(aaa, fb * 4, fb * 8, instrument[2] - 0.1, fb * 4)

            -- The unused channel is now 1 higher
            unused = aaa + 1
        end
    end

    -- For all unused ticks, we kind of reset the sound card state to reduce sound glitchiness
    for aaa = unused, 8 do
        sound.setVolume(aaa, 0)
        sound.setFrequency(aaa, 0)
    end

    -- And blast all the data we set to the sound card, as promised
    sound.delay(frame)
    sound.process()
    status("Note " .. i .. " of " .. song.length)
    if db then
        print(serialization.serialize(ticks[i]))
    end
    -- Since sound.delay doesnt actually delay the OC's CPU, we have to do that as well (sync bullshit, mostly)
    os.sleep(sleep)
    if i % 500 == 0 then
        soundReset()
    end
end
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
require("tty").clear()
