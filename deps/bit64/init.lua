
if math.maxinteger and math.maxinteger >= 0x7fffffffffffffff then
  return require('native.lua')
elseif pcall(require, 'ffi') then
  return require('ffi.lua')
else
  error('The bit module does not support Lua 5.1 or 5.2, or a Lua configuration with less than 64-bit integers')
end
