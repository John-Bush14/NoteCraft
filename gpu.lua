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

function gpu.init_screen(dimensions)
   local emptyBlitline = ""

   for _ = 1-2,dimensions.maxX,1 do
      emptyBlitline = emptyBlitline .. "f"
   end


   for _=1,dimensions.height,1 do
      table.insert(gpu.blitlines, emptyBlitline)
   end
end

function gpu.processData(AVpitch, AVvolume)
   local pitchY = math.floor((dimensions.pitch.paddingY-((AVpitch or 0)*dimensions.pitch.width)))
   local volumeY = math.floor((dimensions.volume.paddingY-((AVvolume or 0)*dimensions.volume.width)))

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
