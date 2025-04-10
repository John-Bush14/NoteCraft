local gpu = {}

function gpu.drawScreen(song, ticks)
    term.clear()

    for y, blitline in pairs(gpu.blitlines) do
       term.setCursorPos(-2, y)
       term.blit(blitline, blitline, blitline)
    end


   term.setCursorPos(1, 1)

    if song.header.name == "" then song.header.name = song.header["OG-filename"] end
    if song.header.author == "" then song.header.author = song.header["OG-author"] end

    print(" - " .. song.header.name .. " - from " .. song.header.author .. " playing for " .. math.floor(ticks or 0) .. "/" .. math.floor(song.header.length) .. " ticks")
end

local function calculateDimensions(song)
   local _, height = term.getSize()

   local dimensions = {
      maxX = math.floor(term.getSize()-6),
      height = height,
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

function gpu.init_screen(song)
   gpu.dimensions = calculateDimensions(song)

   gpu.blitlines = {}
   local emptyBlitline = ""

   for _ = 1-2,gpu.dimensions.maxX,1 do
      emptyBlitline = emptyBlitline .. "f"
   end

   for _=1,gpu.dimensions.height,1 do
      table.insert(gpu.blitlines, emptyBlitline)
   end
end

function gpu.processData(AVpitch, AVvolume)
   local pitchY = math.floor((gpu.dimensions.pitch.paddingY-((AVpitch or 0)*gpu.dimensions.pitch.width)))
   local volumeY = math.floor((gpu.dimensions.volume.paddingY-((AVvolume or 0)*gpu.dimensions.volume.width)))

   for y, blitline in pairs(gpu.blitlines) do
      if y == pitchY and AVpitch or 0 > 0 then gpu.blitlines[y] = blitline .. "fb"
      elseif y == volumeY and AVvolume or 0 > 0 then gpu.blitlines[y] = blitline .. "fd"
      else gpu.blitlines[y] = blitline .. "ff" end
   end
end

function gpu.moveScreen(x)
   for y, blitline in pairs(gpu.blitlines) do
      gpu.blitlines[y] = string.sub(blitline, x)
   end
end

return gpu
