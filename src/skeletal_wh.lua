script_name("Skeletal WallHack")
script_version_number(1)
script_description("thx to Valdan666 and FYP")
script_author("AppleThe & hnnssy")

local ffi = require "ffi"
local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
require "lib.moonloader"
local mem = require "memory"

--// *** // *** //--
whVisible = "all" -- Мод ВХ по умолчанию. Моды написаны в комментарии ниже
optionsCommand = "skeletal" -- Моды ВХ: bones - только кости / names - только ники, all - всё сразу
KEY = VK_F5 -- Кнопка активации ВХ
defaultState = false -- Запуск ВХ при старте игры
--// *** // *** //--

function main()
	if not isSampLoaded() or not isCleoLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
	sampRegisterChatCommand(optionsCommand, function(param)
		if param == "bones" then whVisible = param; nameTagOff()
		elseif param == "names" or param == "all" then whVisible = param if not nameTag then nameTagOn() end
		else sampAddChatMessage("Введите корректный режим: {CCCCFF}names{4444FF}/{CCCCFF}bones{4444FF}/{CCCCFF}all", 0xFF4444FF) end
	end)
	while not sampIsLocalPlayerSpawned() do wait(100) end
	if defaultState and not nameTag then nameTagOn() end
	while true do
		wait(0)
		if wasKeyPressed(KEY) then;
			if defaultState then
				defaultState = false;
				nameTagOff();
				while isKeyDown(KEY) do wait(100) end
			else
				defaultState = true;
				if whVisible ~= "bones" and not nameTag then nameTagOn() end
				while isKeyDown(KEY) do wait(100) end
			end
		end
		if defaultState and whVisible ~= "names" then
			if not isPauseMenuActive() and not isKeyDown(VK_F8) then
				for i = 0, sampGetMaxPlayerId() do
				if sampIsPlayerConnected(i) then
					local result, cped = sampGetCharHandleBySampPlayerId(i)
					local color = sampGetPlayerColor(i)
					local aa, rr, gg, bb = explode_argb(color)
					local color = join_argb(255, rr, gg, bb)
					if result then
						if doesCharExist(cped) and isCharOnScreen(cped) then
							local t = {3, 4, 5, 51, 52, 41, 42, 31, 32, 33, 21, 22, 23, 2}
							for v = 1, #t do
								pos1X, pos1Y, pos1Z = getBodyPartCoordinates(t[v], cped)
								pos2X, pos2Y, pos2Z = getBodyPartCoordinates(t[v] + 1, cped)
								pos1, pos2 = convert3DCoordsToScreen(pos1X, pos1Y, pos1Z)
								pos3, pos4 = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
								renderDrawLine(pos1, pos2, pos3, pos4, 1, color)
							end
							for v = 4, 5 do
								pos2X, pos2Y, pos2Z = getBodyPartCoordinates(v * 10 + 1, cped)
								pos3, pos4 = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
								renderDrawLine(pos1, pos2, pos3, pos4, 1, color)
							end
							local t = {53, 43, 24, 34, 6}
							for v = 1, #t do
								posX, posY, posZ = getBodyPartCoordinates(t[v], cped)
								pos1, pos2 = convert3DCoordsToScreen(posX, posY, posZ)
							end
						end
					end
				end
			end
			else
				nameTagOff()
				while isPauseMenuActive() or isKeyDown(VK_F8) do wait(0) end
				nameTagOn()
			end
		end
	end
end

function getBodyPartCoordinates(id, handle)
  local pedptr = getCharPointer(handle)
  local vec = ffi.new("float[3]")
  getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
  return vec[0], vec[1], vec[2]
end

function nameTagOn()
	local pStSet = sampGetServerSettingsPtr();
	NTdist = mem.getfloat(pStSet + 39)
	NTwalls = mem.getint8(pStSet + 47)
	NTshow = mem.getint8(pStSet + 56)
	mem.setfloat(pStSet + 39, 1488.0)
	mem.setint8(pStSet + 47, 0)
	mem.setint8(pStSet + 56, 1)
	nameTag = true
end

function nameTagOff()
	local pStSet = sampGetServerSettingsPtr();
	mem.setfloat(pStSet + 39, NTdist)
	mem.setint8(pStSet + 47, NTwalls)
	mem.setint8(pStSet + 56, NTshow)
	nameTag = false
end

function join_argb(a, r, g, b)
  local argb = b  -- b
  argb = bit.bor(argb, bit.lshift(g, 8))  -- g
  argb = bit.bor(argb, bit.lshift(r, 16)) -- r
  argb = bit.bor(argb, bit.lshift(a, 24)) -- a
  return argb
end

function explode_argb(argb)
  local a = bit.band(bit.rshift(argb, 24), 0xFF)
  local r = bit.band(bit.rshift(argb, 16), 0xFF)
  local g = bit.band(bit.rshift(argb, 8), 0xFF)
  local b = bit.band(argb, 0xFF)
  return a, r, g, b
end
