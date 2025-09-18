-- Implementation of luabitop-like behavior for Lua 5.3+
local MAX_INT = -1
local MAX_SHIFT = math.log(math.maxinteger, 2) | 0
local INT_BITS = MAX_SHIFT + 1

local INT_FLOATING_MOD = 2 ^ 32 | 0 -- Always truncate floating point numbers to 32 bits.
local INT_FLOATING_NEG = INT_FLOATING_MOD // 2 -- A single bit set at the most significant position
local INT_FLOATING_SEXT = ~(INT_FLOATING_MOD - 1) -- A mask of all bits set above the negative bit, used for sign extension

if INT_BITS < 32 then
    error('The bit module does not support a Lua configuration with less than 32-bit integers')
end

---@class bit64.native
local bit64 = {}

-- Match the behavior of Luajit's bit library, integer types are kept at their original size.
local function normalize(x, sign_extend)
    if math.type(x) == 'integer' then
        return x
    end

    local y = math.tointeger(x % INT_FLOATING_MOD)
    y = (x < 0 or (sign_extend and y & INT_FLOATING_NEG ~= 0)) and y | INT_FLOATING_SEXT or y
    return y
end

--- Returns the integer part of `x`.
--- @param x number | string
--- @return integer
function bit64.tointeger(x)
    if type(x) == 'string' then
        return tonumber(x, 16) or error('invalid hex string')
    end

    return normalize(x, true)
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
--- @param n? integer
--- @return string
function bit64.tohex(x, n)
    x = normalize(x)
    n = n or (INT_BITS // 4)

    local fmt, mask
    if n < 0 then
        fmt = '%0' .. -n .. 'X'
        mask = (1 << -n * 4) - 1
    elseif n > 0 then
        fmt = '%0' .. n .. 'x'
        mask = (1 << n * 4) - 1
    else
        return ''
    end

    return string.format(fmt, x & mask)
end

--- Returns a string representing the byte value of `x`.
--- @param x number
--- @return string
function bit64.tobytes(x)
    x = normalize(x)

    local a = x & 0xff
    local b = (x >> 8) & 0xff
    local c = (x >> 16) & 0xff
    local d = (x >> 24) & 0xff
    local e = (x >> 32) & 0xff
    local f = (x >> 40) & 0xff
    local g = (x >> 48) & 0xff
    local h = (x >> 56) & 0xff

    return string.char(a, b, c, d, e, f, g, h)
end

--- Returns the bitwise negation of `x`.
---@param x number
---@return integer
function bit64.bnot(x)
    x = normalize(x)
    return ~x
end

--- Returns the bitwise OR of 2 operands.  
---@param x number
---@param y number
---@return integer
function bit64.bor2(x, y)
    return normalize(x) | normalize(y)
end

--- Returns the bitwise OR of 3 operands.
---@param x number
---@param y number
---@param z number
---@return integer
function bit64.bor3(x, y, z)
    return normalize(x) | normalize(y) | normalize(z)
end

--- Returns the bitwise OR of all operands.
---@param x number
---@param ... number
---@return integer
function bit64.bor(x, ...)
    x = normalize(x)
    for i = 1, select('#', ...) do
        x = x | normalize(select(i, ...), false)
    end
    return x
end

--- Returns the bitwise AND of 2 operands.
---@param x number
---@param y number
---@return integer
function bit64.band2(x, y)
    return normalize(x) & normalize(y)
end

--- Returns the bitwise AND of 3 operands.
---@param x number
---@param y number
---@param z number
---@return integer
function bit64.band3(x, y, z)
    return normalize(x) & normalize(y) & normalize(z)
end

--- Returns the bitwise AND of all operands.
---@param x number
---@param ... number
---@return integer
function bit64.band(x, ...)
    x = normalize(x)
    for i = 1, select('#', ...) do
        x = x & normalize(select(i, ...), false)
    end
    return x
end

--- Returns the bitwise XOR of 2 operands.
---@param x number
---@param y number
---@return integer
function bit64.bxor2(x, y)
    return normalize(x) ~ normalize(y)
end

--- Returns the bitwise XOR of 3 operands.
---@param x number
---@param y number
---@param z number
---@return integer
function bit64.bxor3(x, y, z)
    return normalize(x) ~ normalize(y) ~ normalize(z)
end

--- Returns the bitwise XOR of all operands.
---@param x number
---@param ... number
---@return integer
function bit64.bxor(x, ...)
    x = normalize(x)
    for i = 1, select('#', ...) do
        x = x ~ normalize(select(i, ...), false)
    end
    return x
end

--- Shift all bits of `x` to the left (low to high) by `n` positions.
--- All new bits are set to 0.
---@param x number
---@param n integer
---@return integer
function bit64.lshift(x, n)
    x = normalize(x)
    n = n & MAX_SHIFT
    return x << n
end

--- Shift all bits of `x` to the right (high to low) by `n` positions.
--- All new bits are set to 0.
---@param x number
---@param n integer
---@return integer
function bit64.rshift(x, n)
    x = normalize(x)
    n = n & MAX_SHIFT
    return x >> n
end

--- Shift all bits of `x` to the right (high to low) by `n` positions.
--- All new bits are set to the highest bit of `x`.
---@param x number
---@param n integer
---@return integer
function bit64.arshift(x, n)
    x = normalize(x)
    n = n & MAX_SHIFT
    if x < 0 then
        local fill_mask = MAX_INT << (INT_BITS - n)

        return x >> n | fill_mask
    else
        return x >> n
    end
end

--- Rotate all bits of `x` to the left (low to high) by `n` positions.
--- Bits that are shifted out of the integer are rotated back to the other side.
---@param x number
---@param n integer
---@return integer
function bit64.rol(x, n)
    x = normalize(x)
    n = n & MAX_SHIFT
    return (x << n) | (x >> (INT_BITS - n))
end

--- Rotate all bits of `x` to the right (high to low) by `n` positions.
--- Bits that are shifted out of the integer are rotated back to the other side.
---@param x number
---@param n integer
---@return integer
function bit64.ror(x, n)
    x = normalize(x)
    n = n & MAX_SHIFT
    return (x >> n) | (x << (INT_BITS - n))
end

--- Swap the byte order of a 64-bit integer.
---@param x number
---@return integer
function bit64.bswap(x)
    x = normalize(x)

    local a = x & 0xff
    local b = (x >> 8) & 0xff
    local c = (x >> 16) & 0xff
    local d = (x >> 24) & 0xff
    local e = (x >> 32) & 0xff
    local f = (x >> 40) & 0xff
    local g = (x >> 48) & 0xff
    local h = (x >> 56) & 0xff

    return a << 56 | b << 48 | c << 40 | d << 32 | e << 24 | f << 16 | g << 8 | h
end

--- Returns the number of bits set to 1 in `x`.
---@param x number
---@return integer
function bit64.popcount(x)
    x = normalize(x)

    local count = 0
    while x ~= 0 do
        x = x & (x - 1)
        count = count + 1
    end

    return count
end

local clz_table = {}
for i = 0, 255 do
    local n, j = 0, i
    if i <= 0x0F then
        n = n + 4
        i = i << 4
    end

    if i <= 0x3F then
        n = n + 2
        i = i << 2
    end

    if i <= 0x7F then
        n = n + 1
    end

    clz_table[j] = n
end

--- Returns the number of leading zeros in `x`.
--- @param x number
--- @return integer
function bit64.clz(x)
    x = normalize(x)

    if x == 0 then
        return INT_BITS
    end

    local n = 0
    if x >> 32 == 0 then
        n = n + 32
        x = x << 32
    end

    if x >> 48 == 0 then
        n = n + 16
        x = x << 16
    end

    if x >> 56 == 0 then
        n = n + 8
        x = x << 8
    end

    n = n + clz_table[x >> 56]

    return n
end

--- Returns the number of trailing
--- @return integer
function bit64.ctz(x)
    x = normalize(x)
    if x == 0 then
        return INT_BITS
    end

    x = x & -x
    return (INT_BITS - 1) - bit64.clz(x)
end

return bit64
