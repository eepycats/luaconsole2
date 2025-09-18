local net = require('net')
local lzss = require("./lzss")
local bit64 = require('bit64')

--[[
commands:
_CST
_PRT
_CHN
RCSI
AINF - game info
ADON
CHAN - channels
PRNT
CVRB - cvar blob
ACTV
ANOF
EXIT
MODM
SVME
SVMI

]]


--[[
verbosity
enum LoggingSeverity_t
{
	//-----------------------------------------------------------------------------
	// An informative logging message.
	//-----------------------------------------------------------------------------
	LS_MESSAGE = 0,

	//-----------------------------------------------------------------------------
	// A warning, typically non-fatal
	//-----------------------------------------------------------------------------
	LS_WARNING = 1,

	//-----------------------------------------------------------------------------
	// A message caused by an Assert**() operation.
	//-----------------------------------------------------------------------------
	LS_ASSERT = 2,

	//-----------------------------------------------------------------------------
	// An error, typically fatal/unrecoverable.
	//-----------------------------------------------------------------------------
	LS_ERROR = 3,

	//-----------------------------------------------------------------------------
	// A placeholder level, higher than any legal value.
	// Not a real severity value!
	//-----------------------------------------------------------------------------
	LS_HIGHEST_SEVERITY = 4,
};
flags
enum LoggingChannelFlags_t
{
	//-----------------------------------------------------------------------------
	// Indicates that the spew is only relevant to interactive consoles.
	//-----------------------------------------------------------------------------
	LCF_CONSOLE_ONLY = 0x00000001,

	//-----------------------------------------------------------------------------
	// Indicates that spew should not be echoed to any output devices.
	// A suitable logging listener must be registered which respects this flag 
	// (e.g. a file logger).
	//-----------------------------------------------------------------------------
	LCF_DO_NOT_ECHO = 0x00000002,
};
]]



local vconsole = {}

local function parseAINF(messageData)
    --messageData unk64 32bf 32bf cmdline_len cmdline
    -- platformFlags
    -- & 1 - 64-bit
    -- & 2 - unk
    -- & 4 - unk
    -- & 8 - unk
    -- & 0x10 - unk
    -- & 0x20 - unk

    local productCRC32, unknown64, productName, gameDir, unk32, lengthCommandLine, platformFlags, commandLine = string.unpack("> I4 I8 c32 c32 I4 I4 I1 z", messageData)
    return {productCRC32 = productCRC32, productName = string.unpack("z", productName), gameDir = string.unpack("z", gameDir), platformFlags = platformFlags, commandLine = commandLine}
end

local function parseCHAN(messageData)
    local nextCharacter = 1
    local channelCount
    local channels = {}
    channelCount, nextCharacter = string.unpack("> I2", messageData)
    for i = 1, channelCount do
        -- channelHash == crc32(channelName .. "\x00")
        local channelHash, defaultFlags, currentFlags, defaultVerbosity, currentVerbosity, defaultColor, channelName, unknown16, nextCharacter_ = string.unpack("> I4 I4 I4 I4 I4 I4 c32 I2", messageData, nextCharacter)
        nextCharacter = nextCharacter_
        channelName = string.unpack("z", channelName)

        channels[channelHash] = {defaultFlags=defaultFlags,currentFlags=currentFlags,defaultVerbosity=defaultVerbosity,currentVerbosity=currentVerbosity,defaultColor=defaultColor,channelName=channelName}
    end
    return channels
end
	
local function parseADON(messageData)
    if #messageData ~= 4 then
        error("please message me abt this")
    end
    -- guessing
    local totalAddons, enabledAddons = string.unpack("> I2 I2", messageData)
    return {totalAddons, enabledAddons}
    -- todo parse strings here
end

local function parseCMND(messageData)
    local str = string.unpack("z", messageData)
    return str
end

local function byteStringToHex(str)
    return (str:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

local function parseCVRB(messageData)
    local cvarCount, countedStringPoolLength, compressedBlobSize = string.unpack("< I4 I4 I4",messageData)
    local decompressedBuffer = lzss.decompress(string.sub(messageData,13))
    local countedStringPoolData = string.sub(decompressedBuffer,1,countedStringPoolLength)

    local poolMagic, poolFreeListStart, poolHashCount, nextByte
    poolMagic, poolFreeListStart, poolHashCount, nextByte = string.unpack("< I4 I2 I4", countedStringPoolData)
    local hashTable = {}
    for i=1,poolHashCount do
        local hash, nextByte_ = string.unpack("< I2", countedStringPoolData, nextByte)
        table.insert(hashTable, hash)
        nextByte = nextByte_
    end

    local stringTable = {}

    local tableCount
    tableCount, nextByte = string.unpack("< I4", countedStringPoolData, nextByte)
    --print(tableCount)
    --error("hi")
    -- off by one apparently what the hellyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
    stringTable[1] = {nextElement = 0, referenceCount = 0, bufferString = ""}
    for i=2, tableCount do
        local nextElement, referenceCount, bufferString, nextByte_ = string.unpack("< I2 I1 z", countedStringPoolData, nextByte)
        --print(bufferString)
        table.insert(stringTable, {nextElement = nextElement, referenceCount = referenceCount, bufferString = bufferString})
        --error("hi")
        nextByte = nextByte_
    end

    local cvars = {

    }

    for i=1,cvarCount do
        local flags, cvarNameHandle, currentValueHandle, defaultValueHandle, minValueHandle, maxValueHandle, unk8, nextByte_ = string.unpack("< c8 I2 I2 I2 I2 I2 I1", countedStringPoolData, nextByte)
        table.insert(cvars, {
            flags = bit64.tointeger(byteStringToHex(flags)),
            name = stringTable[cvarNameHandle+1].bufferString,
            currentValue = stringTable[currentValueHandle+1].bufferString,
            defaultValue = stringTable[defaultValueHandle+1].bufferString,
            minValue = stringTable[minValueHandle+1].bufferString,
            maxValue = stringTable[maxValueHandle+1].bufferString,
        })
        
        nextByte = nextByte_
    end

    return cvars
end

local function parsePRNT(messageData)
    local channelCRC, loggingChannelId, messageVerbosity, color, millisecondTime, probablyColorThing, dunno2, printString = string.unpack("> I4 I4 I4 I4 I4 I4 I4 z", messageData)
    --print(printString)
    -- most probably wrong here
    return {channelCRC = channelCRC, loggingChannelId = loggingChannelId, messageVerbosity = messageVerbosity, color = color, millisecondTime = millisecondTime, dunno1 = dunno1, dunno2 = dunno2, printString = printString}
end


local function parseEFUL(messageData)
	return
end

function vconsole.create()
    local cl = {
        client = nil,
        messageHandlers = {},
        buffer = "",
        parsers = {
            AINF = parseAINF,
            CHAN = parseCHAN,
            ADON = parseADON,
            CVRB = parseCVRB,
            PRNT = parsePRNT,
            CMND = parseCMND,
			EFUL = parseEFUL -- bug that occurs sometimes, not a real message (libvconcomm nor vconsole2 has any writing/parsing code for this, probably uninitialized stack mem)
        }
    }
    function cl:on(event, handler)
        if self.messageHandlers[event] == nil then
            self.messageHandlers[event] = {}
        end
        table.insert(self.messageHandlers[event], handler)
    end

	function cl:parseMessage(messageType, protocolNumber, messageData)
		messageData = string.sub(messageData, 12 + 1)
        --print(messageType)
		--[[if messageType ~= "PRNT" then
			print("got message type", protocolNumber, messageType)

			local file = io.open(messageType..".bin", "w")
			print(file)
			if file then
				
				file:write(messageData)
				file:close()
			end
		end]]
		--[[if messageType == "CVRB" then
			blob = string.sub(messageData, 13)
			--print(string.sub(blob,1,4))
			local decompressedBlob = lzss.decompress(blob)
			file = io.open("cvarblob.bin", "w")
			file:write(decompressedBlob)
			file:close()
		end]]
        if self.parsers[messageType] == nil then
            error("no parser for ".. messageType)
        end
		if self.parsers[messageType] ~= nil and self.messageHandlers[messageType] ~= nil then
			local result = self.parsers[messageType](messageData)
            for _,handler in pairs(self.messageHandlers[messageType]) do
                handler(self, result)
            end
		end

	end

    function cl:checkFrame(data)
		if #data < 12 then return 0 end
		local parsedBytes = 0
		local keepParsing = true
		while keepParsing do
			if #data < 12 then
				keepParsing = false
				break
			end
			local messageType, protocolNumber, frameBytes, alwaysZero = string.unpack(">c4 I2 I4 I2",data)
			if #data >= frameBytes then
				local messageBuffer = string.sub(data, 1, frameBytes)
				self:parseMessage(messageType, protocolNumber, messageBuffer)
				parsedBytes = parsedBytes + frameBytes
				data = string.sub(data, frameBytes + 1)
			else
				keepParsing = false
			end
		end

		return parsedBytes
	end

    function cl:connect(ip, port)
        self.client = net.createConnection(port, ip, function (err)

        self.client:on("data",function(data)
            self.buffer = self.buffer .. data
            local parsedBytes = self:checkFrame(self.buffer)
            if parsedBytes > 0 then
                self.buffer = string.sub(self.buffer, parsedBytes + 1)
            end
        end)

        end)
    end

	function cl:sendCommand(str)
		self.client:write(string.pack("> c4 I2 I4 I2 z", "CMND", 212, 12 + #str + 1, 0, str))
	end

    return cl
end

return vconsole