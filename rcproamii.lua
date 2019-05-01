-- fceux --loadlua /Users/vyacheslavmikushev/Work/rcproamii.lua /Users/vyacheslavmikushev/Downloads/R.C.\ Pro-Am\ 2/R.C.\ Pro-Am\ 2\ \(U\)\ \[\!p\].nes

emu.speedmode("normal")

local socket = require("socket")

host = "localhost"
port = 8084

function initSocket()
   c, err = socket.connect(host, port)
   while err do
      c, err = socket.connect(host, port)
   end
   print("Socket connected!")
end

initSocket()

buttonNames = {'A', 'up', 'left', 'B', 'select', 'right', 'down', 'start'}

-- joypad state table example
-- {A=true, up=false, left=false, B=false, select=false, right=false, down=false, start=false}
function interpretAnswer(str)
   a = {}
   for i = 1, #str do
    local c = str:sub(i,i)
    a[buttonNames[i]] = c == '1'
   end
   return a
end

-- a = {}
-- a['A'] = true
-- print(tostring(a))

-- FIXME: refactor this function
function joypadToString(j)
   local a = {}
   if (j.left)   then table.insert(a, "left")   end
   if (j.right)  then table.insert(a, "right")  end
   if (j.up)     then table.insert(a, "up")     end
   if (j.down)   then table.insert(a, "down")   end
   if (j.start)  then table.insert(a, "start")  end
   if (j.select) then table.insert(a, "select") end
   if (j.A)      then table.insert(a, "A")      end
   if (j.B)      then table.insert(a, "B")      end
   s = ""
   if (a ~= {}) then
      s = table.concat(a, ",")
   end

   return s
end

function send(message, state)
   -- print("Sending message")
   c:send(state .. message)
end

function receive()
   -- print("Receiving answer")
   v, e = c:receive()
   if e then
      print("Error: " .. e)
      return nil
   end
   local a = interpretAnswer(v)

   -- if (a.start) then
   --    a.start = false
   -- end
   -- a.B = true

   -- print("Answer recieved: " .. joypadToString(a))
   return a
end

-- 1092 (0x0444) - paused or not
-- 1883 (0x075B) - first part of money (least)
-- 1887 (0x075F) - second part of money (significant)
-- 1953 (0x07A1) - letters for car upgrade
-- 1905 (0x0771) - lives
-- 1765 (0x06E5) - moves
-- 1526 (0x05F6) - money, stars and other staff in race

states = {Playing      = "00",
	  Dead         = "01",
	  Paused       = "02",
	  Moving       = "03",
	  PickupLetter = "04",
	  PickupStaff  = "05"}

function isPaused()
   return memory.readbyte(1092) == 1
end

function isMoving()
   return memory.readbyte(1765) == 64
end

staffValue = 0
function isPickUpStaff()
   local curr = memory.readbyte(1526)
   local b = curr > staffValue
   staffValue = curr
   return b
end

function getState()
   if (isPickUpStaff()) then
      return states.PickupStaff
   elseif (isMoving()) then
      return states.Moving
   elseif (isPaused()) then
      return states.Paused
   else
      return states.Playing
   end
end

frame = 0

while true do
   if (frame == 0) then
      send(gui.gdscreenshot(), getState())
   end

   if (frame == 30) then
      a = receive()
      -- joypad.set(1, a)
      frame = -1
   end

   if (a) then
      joypad.set(1, a)
   end

   frame = frame + 1

   emu.frameadvance()
end