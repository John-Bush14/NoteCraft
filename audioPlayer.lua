local instrumentsVanilla = {
   "harp",
   "bass",
   "basedrum",
   "snare",
   "hat",
   "guitar",
   "flute",
   "bell",
   "chime",
   "xylophone",
   "xylophone", -- iron_xylophone
   "harp", -- cow_bell
   "flute", -- didgeridoo
   "harp", -- bit,
   "harp", -- banjo
   "harp", -- pling
   "Tempo Changer"
}

require("tools").extend(table, math)

local gpu = require("gpu")

local speakers = {peripheral.find("speaker")}
local pause = keys.space
local nextK = keys.right
local previous = keys.left


local function parseSong(songFile)
   print(songFile)
    local song = require("nbsParser")(io.open(songFile, "rb"))

    if song == nil then error(songFile .. " is invalid or corrupted (check if it is of NBS version 5)") end

    local instruments = instrumentsVanilla
    for _, instrument in pairs(song.instruments) do if type(instrument) == "table" then table.insert(instruments, instrument.substitute) end end

    return song, instruments
end

local function getKeys()
   local events = {os.pullEvent()}
   local keys = {}
   local key = false

   for _, event in pairs(events) do
      if event == "key" then key = true
      elseif key and type(event) == "number" then
---@diagnostic disable-next-line: cast-local-type
          key = event
      elseif type(key) == "number" and type(event) == "boolean" then
          if not event then table.insert(keys, key) end
---@diagnostic disable-next-line: cast-local-type
          key = nil
      end
   end

   return keys
end

local songI = 1

function table.size(tbl)
    local x = 0
    for _,_ in pairs(tbl) do x = x + 1 end
    return x
end

local function handleInput(paused, songs)
   local songIChanged = false

   for _, key in pairs(getKeys()) do
      if key == pause then
            paused = not paused
      elseif key == nextK then
            songI = songI + 1
            if songI > #songs then songI = 1 end
            songIChanged = true
      elseif key == previous then
            songI = songI - 1
            if songI < 1 then songI = #songs end
            print(songI, songs[songI])
            songIChanged = true
      end
   end

   return paused, songIChanged
end

local function playTick(k, note, song, instruments, tempoChangers)
   local AVpitch = nil
   local AVvolume = nil

   local layerI = 0

   while type(note) == "table" do
      layerI = layerI + (note["jumps-layer"] or 0)
      local layer = {volume = 1.0}
      if song.layers ~= nil then layer = song.layers[layerI] or error(textutils.serialize(song.layers) .. " fuck: " .. layerI) end

      local pitch  = math.clamp((note.key-33)+((note.pitch or 0)/100), 0, 24)
      local volume = math.clamp(((note.velocity or 50)*(layer.volume/100))/(100/3), 0, 3)
      local instrument = instruments[note.instrument + 1] or error("Custom Instrument Not Supported!")

      AVpitch = (pitch  + (AVpitch or pitch))/2
      AVvolume = (volume + (AVvolume or volume))/2

      local i = 1

      if instrument == "Tempo Changer" then
         tempoChangers[note.key] = math.abs(note.pitch/15.0)
      else
         ---@diagnostic disable-next-line: need-check-nil
         while not speakers[i].playNote(instrument, volume*10, pitch) and i < #speakers do
            i = i + 1
         end
      end

      k, note = next(song.notes, k)
   end

   return AVpitch, AVvolume, k, note
end

local function playSong(songFile, songs, options)
   local song, instruments = parseSong(songFile)


   local ticks = 0

   local paused = options.paused == "true"


   local spt = (1/((tonumber(options.forceTps or "NaN") or song.header.tempo or 2000)/100))


   local secSinceTick = 0


   local k, note = nil, nil

   gpu.init_screen(song)


   local tempoChangers = {}

   print("start!")

   while true do
      local start = os.clock()

      local elapsedTime = 0


      os.startTimer(0)
      while elapsedTime <= 0 do
         local changeSong = false

         paused, changeSong = handleInput(paused, songs)

         if changeSong then return playSong(songs[songI], songs, options) end


         elapsedTime = os.clock() - start
      end


      if ticks == 0 then secSinceTick = spt end -- safegaurd


      secSinceTick = secSinceTick + elapsedTime*(tonumber(options.speed) or 1)


      while secSinceTick >= spt-0.001 do
         secSinceTick = secSinceTick-spt

         if not paused then -- if paused then continue end


         if type(note) ~= nil then ticks = ticks + 1 end


         if tempoChangers[ticks] ~= nil then spt = 1/tempoChangers[ticks] end


         k, note = next(song.notes, k)


         local AVvolume = nil
         local AVpitch = nil


         if type(note) == "table" then
            ticks = ticks-1

            AVpitch, AVvolume, k, note = playTick(k, note, song, instruments, tempoChangers)
         end


         gpu.processData(AVpitch, AVvolume)


         if note == nil then
            songI = songI + 1
            if songI > #songs then songI = 1 end
            return playSong(songs[songI], songs, options)
         end


         gpu.drawScreen(song, ticks)

         gpu.moveScreen(3)
      end end
   end
end

return playSong
