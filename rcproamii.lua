-- fceux --loadlua /Users/vyacheslavmikushev/Work/NesML/rcproamii.lua /Users/vyacheslavmikushev/Downloads/R.C.\ Pro-Am\ 2/R.C.\ Pro-Am\ 2\ \(U\)\ \[\!p\].nes

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
-- 1364 (0x0554) - total position
-- 1872 (0x0750) - level
-- 1526 (0x05F6) - money, stars and other staff in race

states = {Playing        = "00",
	  Dead           = "01",
	  Paused         = "02",
	  MovingForward  = "03",
	  MovingBackward = "04",
	  PickupLive     = "05",
	  PickupLetter   = "06",
	  PickupStaff    = "07",
	  NextLevel      = "08",
	  GameOver       = "09"}

previous = {}
current  = {}
function readCurrent()
   current = {}
   current.IsPaused = memory.readbyte(1092) == 1
   current.Money1   = memory.readbyte(1883)
   current.Money2   = memory.readbyte(1887)
   current.Letter   = memory.readbyte(1953)
   current.Lives    = memory.readbyte(1905)
   current.Position = memory.readbyte(1364)
   current.Level    = memory.readbyte(1827)
   current.Staff    = memory.readbyte(1526)
end

function getState()
   readCurrent()
   state = states.Playing
   if (previous.IsPaused ~= nil) then
      if (current.IsPaused) then
	 state = states.Paused
      elseif (current.Level > previous.Level) then
	 current.Position = 0
	 current.Staff = 0
	 state = states.NextLevel
      elseif (current.Lives < previous.Lives) then
	 state = states.Dead
      elseif (current.Lives > previous.Lives) then
	 state = states.PickupLive
      elseif (current.Staff > previous.Staff) then
	 state = states.PickupStaff
      elseif (current.Position > previous.Position) then
	 state = states.MovingForward
      elseif (current.Position < previous.Position) then
	 state = states.MovingBackward
      elseif (current.Money1 == 0 and current.Money2 == 0 and current.Lives == 0) then
	 state = states.GameOver
      end
   end

   previous = current
   return state
end

frame = 0
started = false

while true do
   if (started) then
      if (frame == 0) then
	 send(gui.gdscreenshot(), getState())
      end

      if (frame == 20) then
	 a = receive()
	 frame = -1
      end

      if (a) then
	 joypad.set(1, a)
      end

      frame = frame + 1
   else
      a = joypad.get(1)
      if (a.select) then
	 started = true
      end
   end

   emu.frameadvance()
end