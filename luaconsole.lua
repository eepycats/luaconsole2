local vconsole = require("./vconsole")
local readline = require('readline')

local vconsoleClient = vconsole.create()


local pink = { r=255,g=192,b=203}

local function cprint(c, str)
	io.write(string.format("\x1b[38;2;%i;%i;%im%s\n", c.r,c.g,c.b, str))
end

vconsoleClient:on("AINF", function (self, data)
    print(data.commandLine)
	cprint(pink, "lau console 2")
	local osBits
	if bit.band(data.platformFlags, 1) ~= 0 then
		osBits = "64-bit"
	else
		osBits = "32-bit"
	end
	local statusString = string.format("Running %s (%s) (%s) ", data.productName, data.gameDir, osBits)
	cprint(pink,statusString)
	cprint(pink, "Command Line: " .. data.commandLine)
	io.write("\x1b[38;2;255;255;255m")

end)

vconsoleClient:on("CHAN", function (self, data)
    self.channels = data
end)

vconsoleClient:on("CMND", function (self, str)
    print(str)
	if str == "vc_exit tools" then
		process:exit()
	end
end)

vconsoleClient:on("PRNT", function (self, data)
	local r,g,b,a
	if data.color ~= 0 then
		r,g,b,a = string.unpack("I1 I1 I1 I1",string.pack(">I" ,data.color))
	else
		if self.channels[data.channelCRC].defaultColor == 0 then
			r,g,b,a = 255, 255, 255, 255
			if data.messageVerbosity == 3 then
				r,g,b = 255, 255, 0
			end
		else
			r,g,b,a = string.unpack("I1 I1 I1 I1",string.pack(">I" ,self.channels[data.channelCRC].defaultColor))
		end
	end
	io.write(string.format("\x1b[38;2;%i;%i;%im[%s] %s", r,g,b, self.channels[data.channelCRC].channelName, data.printString))
	io.write("\x1b[38;2;255;255;255m")
end)

vconsoleClient:on("CVRB", function (self, data)
	--print(data.name)
	self.cvars = data
end)

vconsoleClient:connect("127.0.0.1", 29000)

local history = readline.History.new()
local editor = readline.Editor.new({stdin = process.stdin.handle, stdout = process.stdout.handle, history = history})

local function onLine(err, line, ...)
    if line then
        vconsoleClient:sendCommand(line)
        editor:readLine("", onLine)
    else
        process:exit()
    end
end

editor:readLine("", onLine)