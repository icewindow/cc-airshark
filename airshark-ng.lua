-- Settings

-- Program variables
local modem = peripheral.find("modem")
local bCaptureRunning = false
local bShowLive = false
local bShowCaptured = false
local tCapture = {}
local nCaptureIndex = 0
local nDisplayOffset = 0
local nExitCounter = 0
local sChannels = ""
local tLogWindow
local tLines = {}
local nIndexCache = -1
local sPacketFilter = "true"
local fPacketFilter = function() return true end

-- Functions
--[[
 Parses the string sChannels and opens the channels denoted within it
--]]
function openChannels()
  local subset = {}
  local channels = {}
  for v in sChannels:gmatch("[%w-]+") do
    table.insert(subset, v)
  end
  for i=1, #subset do
    if subset[i]:match("^%-?[%xx]+%-[%xx]+") then
      local from = tonumber(subset[i]:match("[%xx]+"))
      local to = tonumber(subset[i]:match("[%xx]+$"))
      if from > to then
        local tmp = from
        from = to
        to = tmp
      end
      local target
      if subset[i]:sub(1,1) == "-" then
        target = nil
      else
        target = true
      end
      for j=from, to do
        channels[j] = target
      end
    elseif subset[i]:match("^%-[%xx]+") then
      channels[tonumber(subset[i]:sub(2))] = nil
    elseif subset[i]:match("^[%xx]+") then
      channels[tonumber(subset[i])] = true
    end
  end
  for channel in pairs(channels) do
    local s = pcall(modem.open, channel)
    if not s then return false end
  end
end

--[[
 Clears the terminal
--]]
function clear()
  term.clear()
  term.setCursorPos(1,1)
end

--[[
Prints the menu
--]]
function printMenu()
  clear()
  print("     -= AirShark NG =-")
  print("")
  print("1. Set channel filter")
  print("2. View channel filter")
  print("3. Start capture")
  print("4. Stop capture")
  print("5. Show live capture")
  print("6. View captured packets")
  print("7. Save captured packets")
  print("8. Delete captured packets")
  print("9. Change modem")
  print("A. Set packet filter")
  print("B. View packet filter")
  print("C. View packet filter help")
  print("0. Exit AirShark NG")
  print("")
end

--[[
 Prints packet information to the default terminal and
 the serialized packet content to tLogWindow
--]]
function printPacket()
  clear()
  if #tCapture == 0 then
    print("Showing 0/0")
    return
  end
  print("Showing ", nCaptureIndex, "/", #tCapture)
  if nIndexCache ~= nCaptureIndex then
    local packet = tCapture[nCaptureIndex]
    tLines = {
      "Side: " .. packet.side,
      "Distance: " .. packet.distance,
      "Sender channel: " .. packet.sender,
      "Reply channel: " .. packet.reply,
      "Time: " .. packet.time .. ", Day: " .. packet.day
    }
    for sLine in textutils.serialize(packet.message):gmatch("[^\r\n]+") do
      table.insert(tLines, sLine)
    end
    nIndexCache = nCaptureIndex
  end
  local prev = term.redirect(tLogWindow)
  clear()
  local w,h = term.getSize()
  for i=1 + nDisplayOffset, #tLines do
    local x,y = term.getCursorPos()
    if y >= h then
      break
    end
    print(tLines[i])
  end
  term.redirect(prev)
end

-- Main program logic
if not modem then
  print("Error: No modem found!")
  print("AirShark is useless without a modem and will now exit")
  return
end

local tArgs = {...}
if #tArgs == 1 then
  -- First parameter: Channel filter
  sChannels = tArgs[1]:match("^[%x%-x,]+")
  os.queueEvent("char", "3")
elseif #tArgs >= 2 then
  -- Second parameter: Packet filter
  sChannels = tArgs[1]:match("^[%x%-x,]+")
  local sFilter = tArgs[2]
  for i=3, #tArgs do
    -- Packet filter is probably longer than one word, concatenate
    -- all parameters to one filter string
    sFilter = sFilter .. " " .. tArgs[i]
  end
  local func = loadstring("return " .. sFilter)
  if func then
    sPacketFilter = sFilter
    fPacketFilter = func
  end
  os.queueEvent("char", "3")
end

local w,h = term.getSize()
tLogWindow = window.create(term.current(), 1, 2, w, h, false)

if multishell then
  multishell.setTitle(multishell.getCurrent(), "AirShark NG")
end

printMenu()
while true do
  local e,p1,p2,p3,p4,p5 = os.pullEvent()
  if e == "char" then
    nExitCounter = nExitCounter - 1
    if bShowCaptured or bShowLive then
      if p1 == "0" then
        if bShowCaptured then
          bShowCaptured = false
          tLogWindow.setVisible(false)
        elseif bShowLive then
          bShowLive = false
        end
        printMenu()
      end
    else
      if p1 == "1" then
        -- Set channel filter
        printMenu()
        if bCaptureRunning then
          print("Unavailable during capture")
        else
          print("Channel filter:")
          term.setCursorBlink(true)
          local filter = io.read()
          if filter ~= "" then
            sChannels = filter
            print("Filter set!")
          else
            print("Aborted")
          end
        end
      elseif p1 == "2" then
        -- Print channel filter
        printMenu()
        print("Current channel filter:")
        print(sChannels ~= "" and sChannels or "Filter not set")
      elseif p1 == "3" then
        -- Open channels and start capture
        printMenu()
        if bCaptureRunning then
          print("Capture already running!")
        elseif sChannels == "" then
          print("No channel filter set")
        else
          print("Opening channels")
          openChannels()
          bCaptureRunning = true
          print("Capture started")
        end
      elseif p1 == "4" then
        -- Stop running capture
        printMenu()
        if bCaptureRunning then
          modem.closeAll()
          bCaptureRunning = false
          print("Capture stopped")
        else
          print("Capture not running!")
        end
      elseif p1 == "5" then
        -- Live packet view
        printMenu()
        bShowLive = true
        print("Press 0 to stop live view")
        print("")
      elseif p1 == "6" then
        -- Show captured packets
        bShowCaptured = true
        nCaptureIndex = 1
        nOffset = 0
        tLogWindow.setVisible(true)
        printPacket(nCaptureIndex, nOffset)
      elseif p1 == "7" then
        -- Save captured packets
        printMenu()
        if bCaptureRunning then
          print("Unavailable during capture")
        else
          print("Enter filename:")
          term.setCursorBlink(true)
          local filename = io.read()
          if filename ~= "" then
            local handle = fs.open(filename, "w")
            handle.write(textutils.serialize(tCapture))
            handle.close()
            print("Captured packets saved!")
          else
            print("Filename may not be empty!")
          end
        end
      elseif p1 == "8" then
        -- Delete captured packets
        if bCaptureRunning then
          printMenu()
          print("Unavailable during capture")
        else
          while true do
            printMenu()
            print("Delete captured packets up to this point (Y/N)?")
            term.setCursorBlink(true)
            local answer = io.read():lower()
            if answer == "y" then
              tCapture = {}
              print("Captured packets cleared")
              break
            elseif answer == "n" then
              print("Aborted")
              break
            end
          end
        end
      elseif p1 == "9" then
        -- Use another modem
        printMenu()
        if bCaptureRunning then
          print("Unavailabe during capture")
        else
          print("Enter new modem side:")
          term.setCursorBlink(true)
          local answer = io.read():lower()
          if answer == "" then
            print("Aborted")
          elseif answer == "any" then
            modem = peripheral.find("modem")
            print("Modem set to first modem")
          else
            if peripheral.getType(answer) ~= "modem" then
              print("No modem or invalid side ")
            else
              modem = peripheral.wrap(answer)
              print("Using modem ", answer)
            end
          end
        end
      elseif p1 == "a" then
        -- Set packet filter expression
        printMenu()
        if bCaptureRunning then
          print("Unavailabe during capture")
        else
          print("Enter filter expression:")
          local sFilter = io.read()
          if sFilter == "" then
            print("Aborted")
          else
            local func, err = loadstring("return " .. sFilter)
            if not func then
              print("Error evaluating expression:")
              print(err)
            else
              fPacketFilter = func
              sPacketFilter = sFilter
              print("Packet filter set")
            end
          end
        end
      elseif p1 == "b" then
        -- Display packet filter expression
        printMenu()
        print("Current filter expression:")
        print(sPacketFilter)
      elseif p1 == "c" then
        -- Print packet filter help
        clear()
        print("Packet filter help\n")
        print("Packet filters must be a valid lua expression evaluating to either true/not nil or false/nil.\n")
        print("Usable variables in expressions:\n")
        print("side: modem side, p1")
        print("sender: sender channel, p2")
        print("reply: reply channel, p3")
        print("message: message, p4")
        print("distance: distance, p5")
        print("time: time of recording")
        print("day: day of recording")
        print("\nPress any key to continue")
        os.pullEvent("key")
        printMenu()
      elseif p1 == "0" then
        -- Exit
        if nExitCounter < 1 then
          nExitCounter = 2
          printMenu()
          print("Press again to exit")
        elseif nExitCounter == 1 then
          break
        end
      end
    end
  elseif e == "key" then
    if bShowCaptured then
      -- Keys to navigate packet view
      if p1 == keys.left then
        nCaptureIndex = nCaptureIndex > 1 and nCaptureIndex - 1 or 1
        nDisplayOffset = 0
      elseif p1 == keys.right then
        nCaptureIndex = nCaptureIndex < #tCapture and nCaptureIndex + 1 or #tCapture
        nDisplayOffset = 0
      elseif p1 == keys.up then
        nDisplayOffset = nDisplayOffset > 0 and nDisplayOffset - 1 or 0
      elseif p1 == keys.down then
        local _,h = tLogWindow.getSize()
        nDisplayOffset = nDisplayOffset + #tLines > h and nDisplayOffset + 1 or nDisplayOffset 
      elseif p1 == keys.home then
        nCaptureIndex = 1
      elseif p1 == keys["end"] then
        nCaptureIndex = #tCapture
      end
      printPacket()
    end
  elseif e == "modem_message" then
    local packet = {
      side = p1,
      sender = p2,
      reply = p3,
      message = p4,
      distance = p5,
      time = os.time(),
      day = os.day()
    }
    -- Make packet information available to filter
    setfenv(fPacketFilter, packet)
    local ok,result = pcall(fPacketFilter)
    if not ok then
      -- If packet filter errored, show error trimmed error message
      if not bShowCaptured and not bShowLive then
        -- But only if we're not already displaying other information
        print("Packet filter error:")
        print(result:sub(11))
      end
    else
      if result then
        -- Packet filter matched
        table.insert(tCapture, packet)
        if bShowCaptured then
          -- Update number of captured packets in packet view mode
          term.setCursorPos(1,1)
          term.clearLine()
          print("Showing ", nCaptureIndex, "/", #tCapture)
        elseif bShowLive then
          -- Print packet information if in live view mode
          print("Side: ", p1)
          print("Distance: ", p5)
          print("Sender channel: ", p2)
          print("Reply channel: ", p3)
          print(textutils.serialize(p4))
          print()
        end
      end
    end
  end
end
modem.closeAll()
clear()