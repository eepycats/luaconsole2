local ffi = require 'ffi'
local uint64_t = ffi.typeof('uint64_t')
local int64_t = ffi.typeof('int64_t')

local bit = require 'bit'

local ZERO = int64_t(0)
local ONE = int64_t(1)

---@class bit64.ffi
local bit64 = {}

--- Returns the integer part of `x`.
--- @param x number
--- @return integer
function bit64.tointeger(x)
    if ffi.istype(uint64_t, x) or ffi.istype(int64_t, x) then
        return x * ONE
    end

    if type(x) == 'string' then
        local sign, num = x:match('^([+-]?)(%x+)$')
        if not num then
            error('invalid hex string')
        end

        local low = tonumber(num:sub(-8), 16)
        local high = tonumber(num:sub(-16, -9), 16) or 0

        local int = bit.lshift(high * ONE, 32) + low
        if sign == '-' then
            return -int
        end

        return int
    end

    return bit.tobit(x) * ONE
end

--- Returns the integer `x` as a normal number.
--- @param x number
--- @return number
function bit64.tonumber(x)
    --- @diagnostic disable-next-line: return-type-mismatch
    return tonumber(x)
end

--- Returns a string representing the hexadecimal value of `x`. With `n` being the number of hex nibbles to generate.
--- @param x number
--- @param n integer
--- @return string
function bit64.tohex(x, n)
    n = n or 16
    return bit.tohex(x * ONE, n)
end

--- Returns a string representing the byte value of `x`.
--- @param x number
--- @return string
function bit64.tobytes(x)
    assert(tonumber(x), 'number expected')
    return ffi.string(ffi.new('int64_t[1]', x), 8)
end

--- Returns the bitwise negation of `x`.
---comment
---@param x number
---@return integer
function bit64.bnot(x)
    return bit.bnot(x * ONE)
end

--- Returns the bitwise OR of 2 operands.  
---@param x number
---@param y number
---@return integer
function bit64.bor2(x, y)
    return bit.bor(x * ONE, y)
end

--- Returns the bitwise OR of 3 operands.
---@param x number
---@param y number
---@param z number
---@return integer
function bit64.bor3(x, y, z)
    return bit.bor(x * ONE, y, z)
end

--- Returns the bitwise OR of all operands.
---@param x number
---@param ... number
---@return integer
function bit64.bor(x, ...)
    return bit.bor(x * ONE, ...)
end

--- Returns the bitwise AND of 2 operands.
---@param x number
---@param y number
---@return integer
function bit64.band2(x, y)
    return bit.band(x * ONE, y)
end

--- Returns the bitwise AND of 3 operands.
---@param x number
---@param y number
---@param z number
---@return integer
function bit64.band3(x, y, z)
    return bit.band(x * ONE, y, z)
end

--- Returns the bitwise AND of all operands.
---@param x number
---@param ... number
---@return integer
function bit64.band(x, ...)
    return bit.band(x * ONE, ...)
end

--- Returns the bitwise XOR of 2 operands.
---@param x number
---@param y number
---@return integer
function bit64.bxor2(x, y)
    return bit.bxor(x * ONE, y)
end

--- Returns the bitwise XOR of 3 operands.
---@param x number
---@param y number
---@param z number
---@return integer
function bit64.bxor3(x, y, z)
    return bit.bxor(x * ONE, y, z)
end

--- Returns the bitwise XOR of all operands.
---@param x number
---@param ... number
---@return integer
function bit64.bxor(x, ...)
    return bit.bxor(x * ONE, ...)
end

--- Shift all bits of `x` to the left (low to high) by `n` positions.
--- All new bits are set to 0.
---@param x number
---@param n integer
---@return integer
function bit64.lshift(x, n)
    return bit.lshift(x * ONE, n)
end

--- Shift all bits of `x` to the right (high to low) by `n` positions.
--- All new bits are set to 0.
---@param x number
---@param n integer
---@return integer
function bit64.rshift(x, n)
    return bit.rshift(x * ONE, n)
end

--- Shift all bits of `x` to the right (high to low) by `n` positions.
--- All new bits are set to the highest bit of `x`.
---@param x number
---@param n integer
---@return integer
function bit64.arshift(x, n)
    return bit.arshift(x * ONE, n)
end

--- Rotate all bits of `x` to the left (low to high) by `n` positions.
--- Bits that are shifted out of the integer are rotated back to the other side.
---@param x number
---@param n integer
---@return integer
function bit64.rol(x, n)
    return bit.rol(x * ONE, n)
end

--- Rotate all bits of `x` to the right (high to low) by `n` positions.
--- Bits that are shifted out of the integer are rotated back to the other side.
---@param x number
---@param n integer
---@return integer
function bit64.ror(x, n)
    return bit.ror(x * ONE, n)
end

function bit64.bswap(x)
    return bit.bswap(x * ONE)
end

--- Returns the number of bits set to 1 in `x`.
---@param x number
---@return integer
function bit64.popcount(x)
    x = x * ONE

    local count = 0
    while x ~= 0 do
        x = bit.band(x, x - 1)
        count = count + 1
    end

    return count
end

local clz_table = {}
for i = 0, 255 do
    local n, j = 0, i
    if i <= 0x0F then
        n = n + 4
        i = bit.lshift(i, 4)
    end

    if i <= 0x3F then
        n = n + 2
        i = bit.lshift(i, 2)
    end

    if i <= 0x7F then
        n = n + 1
    end

    clz_table[j] = n
end

--- Returns the number of leading 0 bits in `x`.
---@param x number
---@return integer
function bit64.clz(x)
    if x == 0 then
        return 64
    end

    x = x * ONE

    local n = 0
    if bit.rshift(x, 32) == ZERO then
        n = n + 32
        x = bit.lshift(x, 32)
    end

    if bit.rshift(x, 48) == ZERO then
        n = n + 16
        x = bit.lshift(x, 16)
    end

    if bit.rshift(x, 56) == ZERO then
        n = n + 8
        x = bit.lshift(x, 8)
    end

    n = n + clz_table[tonumber(bit.rshift(x, 56))]

    return n
end

--- Returns the number of trailing 0 bits in `x`.
---@param x number
---@return integer
function bit64.ctz(x)
    if x == 0 then
        return 64
    end

    x = bit.band(x * ONE, -x)
    return 63 - bit64.clz(x)
end

return bit64
