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

require("tools")(table, math)

local speakers = {peripheral.find("speaker")}
local pause = keys.space
local nextK = keys.right
local previous = keys.left
local volumeUp = keys.up
local volumeDown = keys.down


local function drawScreen(blitlines, song, ticks)
    term.clear()


    for y, blitline in pairs(blitlines) do
       term.setCursorPos(-2, y)
       term.blit(blitline, blitline, blitline)
    end


   term.setCursorPos(1, 1)

    if song.header.name == "" then song.header.name = song.header["OG-filename"] end
    if song.header.author == "" then song.header.author = song.header["OG-author"] end

    print(" - " .. song.header.name .. " - from " .. song.header.author .. " playing for " .. math.floor(ticks or 0) .. "/" .. math.floor(song.header.length) .. " ticks")
end

local function calculateDimensions(song)
   local dimensions = {
      maxX = math.floor(term.getSize()-6)
   }

   local layerI = 0

   local AVpitch = 0
   local AVvolume = 0

   local volumeExtremes = {99999, -99999}
   local pitchExtremes = {999999, -99999}

   for _, note in pairs(song.notes) do
      if type(note) == "table" then
         layerI = layerI + (note["jumps-layer"] or 0)
         local layer = {volume = 1.0}
         if song.layers ~= nil then layer = song.layers[layerI] or layer end

         local pitch  = math.clamp((note.key-33)+((note.pitch or 0)/100), 0, 24)
         local volume = math.clamp(((note.velocity or 50)*(layer.volume/100))/(100/3), 0, 3)

         AVpitch = (pitch  + (AVpitch or pitch))/2
         AVvolume = (volume + (AVvolume or volume))/2
      elseif AVpitch ~= 0 and AVpitch ~= 0 then
         layerI = 1

         volumeExtremes = {math.min(volumeExtremes[1], AVvolume), math.max(volumeExtremes[2], AVvolume)}
         pitchExtremes = {math.min(pitchExtremes[1], AVpitch), math.max(pitchExtremes[2], AVpitch)}

         AVpitch = 0
         AVvolume = 0
      end
   end

   local _, height = term.getSize()

   dimensions.pitch = {
      width = (height-5)/(pitchExtremes[2]-pitchExtremes[1])
   }
   dimensions.pitch.paddingY = height + pitchExtremes[1]*dimensions.pitch.width

   dimensions.volume = {
      width = (height-5)/(volumeExtremes[2]-volumeExtremes[1])
   }
   dimensions.volume.paddingY = height + volumeExtremes[1]*dimensions.volume.width

   return dimensions
end

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
      elseif key == volumeUp then
            volumeMod = volumeMod*1.01
      elseif key == volumeDown then
            volumeMod = volumeMod/1.01
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

   local paused = options.paused


   local dimensions = calculateDimensions(song)


   local spt = options.forceSpt or (1/((song.header.tempo or 2000)/100))


   local secSinceTick = 0


   local k, note = nil, nil


   local blitlines = {}

   local emptyBlitline = ""

   for _ = 1-2,dimensions.maxX,1 do
      emptyBlitline = emptyBlitline .. "f"
   end

   local _, height = term.getSize()

   for _=1,height,1 do
      table.insert(blitlines, emptyBlitline)
   end


   local tempoChangers = {}


   while true do
      local start = os.clock()

      local elapsedTime = 0


      os.startTimer(0)
      while elapsedTime <= 0 do
         local changeSong = false

         paused, changeSong = handleInput(paused, songs)

         if changeSong then return playSong(songs[songI], songs) end


         elapsedTime = os.clock() - start
      end


      if ticks == 0 then secSinceTick = 0.05 end -- safegaurd


      secSinceTick = secSinceTick + elapsedTime*(options.speed or 1)


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


         local pitchY = math.floor((dimensions.pitch.paddingY-((AVpitch or 0)*dimensions.pitch.width)))
         local volumeY = math.floor((dimensions.volume.paddingY-((AVvolume or 0)*dimensions.volume.width)))


         for y, blitline in pairs(blitlines) do
            if y == pitchY and AVpitch or 0 > 0 then blitlines[y] = blitline .. "fb"
            elseif y == volumeY and AVvolume or 0 > 0 then blitlines[y] = blitline .. "fd"
            else blitlines[y] = blitline .. "ff" end
         end


         if note == nil then
            songI = songI + 1
            if songI > #songs then songI = 1 end
            return playSong(songs[songI], songs)
         end

         drawScreen(blitlines, song, ticks)


         for y, blitline in pairs(blitlines) do
            blitlines[y] = string.sub(blitline, 3)
         end
      end end
   end
end

return playSong
