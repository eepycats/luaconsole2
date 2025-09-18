local lzss = {}

lzss.decompress = function(data)
    local nextByte = 1
    local magic, actualSize
	local cmdByte = 0
	local getCmdByte = 0
    local totalBytes = 0
    local output = {}
    magic, actualSize, nextByte= string.unpack("< c4 I4", data, nextByte)
    if actualSize == 0 or magic ~= "LZSS" then
        error("bad lzss payload")
    end

    while true do
        if getCmdByte == 0 then
            cmdByte, nextByte = string.unpack("I1", data, nextByte)
        end
        getCmdByte = bit.band((getCmdByte + 1), 0x07)
        
        if bit.band(cmdByte, 0x01) ~= 0 then
            local a,b
            a, nextByte = string.unpack("I1", data, nextByte)
            b = string.unpack("I1", data, nextByte)
            local position = bit.bor(bit.lshift(a,4),bit.rshift(b,4))
            local count 
            count,nextByte = string.unpack("I1", data, nextByte)
            count = (bit.band(count,0x0f)) + 1
            if count == 1 then break end
            source = #output - position - 1
            for i=1,count do
                local bytes
                table.insert(output, output[source + 1])
                source = source + 1
            end
            totalBytes = totalBytes + count
        else
            local byte
            byte, nextByte = string.unpack("c1", data, nextByte)
            table.insert(output,byte)
            totalBytes = totalBytes + 1
        end
        cmdByte = bit.rshift(cmdByte, 1)
    end

    if totalBytes ~= actualSize then
        error("what the fuck")
    end

    return table.concat(output)
end

return lzss