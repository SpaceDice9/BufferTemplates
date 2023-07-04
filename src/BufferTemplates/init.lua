local BitBuffer = require(script.BitBuffer)

local BufferTemplates = {}
BufferTemplates.__index = BufferTemplates

function BufferTemplates:CompressIntoBase91(data: any)
	return self.WriteIntoBuffer(data):ToBase91()
end

function BufferTemplates:DecompressFromBase91(b91: string)
	return self.ReadFromBuffer(BitBuffer.FromBase91(b91))
end

function BufferTemplates:CompressIntoBase64(data: any)
	return self.WriteIntoBuffer(data):ToBase64()
end

function BufferTemplates:DecompressFromBase64(b64: string)
	return self.ReadFromBuffer(BitBuffer.FromBase64(b64))
end

function BufferTemplates.IsTemplate(template)
	return type(template) == "table" and template.WriteIntoBuffer and template.ReadFromBuffer
end

--[[
Default Buffer Types:
  Bool v
  Bytes
  
  UInt v
  Int v
  Float32 v
  Float64 v
  
  Char v
  StringDyn v
]]

--[[
Misc Types:
  Tables
  StaticArray
  DynamicArray

]]


function spawnNewBitBuffer(buffer)
	if not buffer then
		buffer = BitBuffer.new()
	end
	
	return buffer
end

function buildEmptyTemplate(write, read, check)
	local template = {
		WriteIntoBuffer = write,
		ReadFromBuffer = read,
		Validate = check,
	}
	
	setmetatable(template, BufferTemplates)
	
	return template
end

function buildStandardTemplate(bufferDataType, check)
	local readMethod = "Read" .. bufferDataType
	local writeMethod = "Write" .. bufferDataType
	
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		buffer[writeMethod](buffer, data)
		return buffer
	end

	local read = function(buffer)
		local data = buffer[readMethod](buffer)
		return data, buffer
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

function BufferTemplates.Custom(write, read, check)
	local writeWithBuffer = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		return write(data, buffer)
	end
	
	local template = buildEmptyTemplate(writeWithBuffer, read, check)

	return template
end

--unsigned int
function BufferTemplates.UInt(bitWidth: number)
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		buffer:WriteUInt(bitWidth, data)
		return buffer
	end
	
	local read = function(buffer)
		local data = buffer:ReadUInt(bitWidth)
		return data, buffer
	end

	local check = function(data)
		return type(data) == "number"
	end
	
	local template = buildEmptyTemplate(write, read, check)
	
	return template
end

function BufferTemplates.Int(bitWidth: number)
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		buffer:WriteInt(bitWidth, data)
		return buffer
	end

	local read = function(buffer)
		local data = buffer:ReadInt(bitWidth)
		return data, buffer
	end

	local check = function(data)
		return type(data) == "number"
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

function BufferTemplates.Fixed(intBitWidth: number, fracBitWidth: number)
	assert(fracBitWidth > 1, "Fractional bit width must be greater than 1")

	if intBitWidth == 1 then
		warn("Unexpected behavior may occur at integer bit width 1")
	end

	local multiplier = 2^(fracBitWidth - 1)

	local write = function(data, buffer)
		local int, frac = math.modf(data)

		buffer = spawnNewBitBuffer(buffer)
		buffer:WriteInt(fracBitWidth, math.round(frac*multiplier))

		if intBitWidth > 0 then
			buffer:WriteInt(intBitWidth, int)
		end

		return buffer
	end

	local read = function(buffer)
		local frac = buffer:ReadInt(fracBitWidth)/multiplier
		local int = 0

		if intBitWidth > 0 then
			int = buffer:ReadInt(intBitWidth)
		end

		local data = int + frac

		return data, buffer
	end

	local check = function(data)
		return type(data) == "number"
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

function BufferTemplates.Float32()
	local check = function(data)
		return type(data) == "number"
	end

	return buildStandardTemplate("Float32", check)
end

function BufferTemplates.Float64()
	local check = function(data)
		return type(data) == "number"
	end

	return buildStandardTemplate("Float64", check)
end

function BufferTemplates.Char()
	local check = function(data)
		return type(data) == "string"
	end

	return buildStandardTemplate("Char", check)
end

function BufferTemplates.StaticString(charLength: number)
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)

		if string.len(data) ~= charLength then
			error("Attempted to encode data of forbidden size")
			return
		end
		
		local charList = string.split(data, "")

		for _, char in charList do
			buffer:WriteChar(char)
		end

		return buffer
	end

	local read = function(buffer)
		local data = ""

		for i = 1, charLength do
			data = data .. buffer:ReadChar()
		end

		return data, buffer
	end

	local check = function(data)
		return type(data) == "string"
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

function BufferTemplates.String()
	local check = function(data)
		return type(data) == "string"
	end

	return buildStandardTemplate("String", check)
end

function BufferTemplates.Bool()
	local check = function(data)
		return type(data) == "boolean"
	end

	return buildStandardTemplate("Bool", check)
end

function BufferTemplates.Table(t)
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		
		for dataKey, dataValue in pairs(data) do
			local otherTemplate = t[dataKey]

			if BufferTemplates.IsTemplate(otherTemplate) then
				otherTemplate.WriteIntoBuffer(dataValue, buffer)
			else
				error("Non-template contamination!")
			end
		end
		
		return buffer
	end

	local read = function(buffer)
		local data = {}
		
		for dataKey, otherTemplate in pairs(t) do
			if BufferTemplates.IsTemplate(otherTemplate) then
				data[dataKey] = otherTemplate.ReadFromBuffer(buffer)
			else
				print(otherTemplate)
				error("Non-template contamination!")
			end
		end
		
		return data, buffer
	end

	local check = function(data)
		if type(data) ~= "table" then
			return false
		end

		for key, value in pairs(data) do
			local template = t[key]

			if not template then
				return false
			end

			local valid = template.Validate(value)

			if not valid then
				return false
			end
		end

		return true
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

function BufferTemplates.StaticArray(size: number, repeatedTemplate)
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		
		if #data ~= size then
			error("Attempted to encode data of forbidden size")
			return
		end
		
		for _, v in pairs(data) do
			repeatedTemplate.WriteIntoBuffer(v, buffer)
		end

		return buffer
	end

	local read = function(buffer)
		local data = {}
		
		for i = 1, size do
			local value = repeatedTemplate.ReadFromBuffer(buffer)
			
			table.insert(data, value)
		end

		return data, buffer
	end

	local check = function(data)
		if type(data) ~= "table" then
			return false
		end

		for _, value in pairs(data) do
			local valid = repeatedTemplate.Validate(value)

			if not valid then
				return false
			end
		end

		return true
	end
	
	local template = buildEmptyTemplate(write, read, check)
	
	return template
end

function BufferTemplates.Array(repeatedTemplate)
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		
		local size = #data
		buffer:WriteUInt(24, size)

		for _, v in pairs(data) do
			repeatedTemplate.WriteIntoBuffer(v, buffer)
		end

		return buffer
	end

	local read = function(buffer)
		local data = {}
		local size = buffer:ReadUInt(24)

		for i = 1, size do
			local value = repeatedTemplate.ReadFromBuffer(buffer)

			table.insert(data, value)
		end

		return data, buffer
	end

	local check = function(data)
		return type(data) == "table"
	end
	
	local template = buildEmptyTemplate(write, read, check)
	
	return template
end

function BufferTemplates.Enum(enumData)
	local bitWidth = math.ceil(math.log(#enumData, 2))
	local enumLookup = {}

	for position, enum in pairs(enumData) do
		enumLookup[enum] = position
	end
	
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		local position = enumLookup[data]
		
		if not position then
			error("Could not find enum")
		end
		
		buffer:WriteUInt(bitWidth, position - 1)

		return buffer
	end

	local read = function(buffer)
		local position = buffer:ReadUInt(bitWidth)
		local data = enumData[position + 1]

		return data, buffer
	end

	local check = function(data)
		return enumLookup[data]
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

function BufferTemplates.Color3()
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		local r, g, b = math.round(data.R*255), math.round(data.G*255), math.round(data.B*255)

		buffer:WriteUInt(8, r)
		buffer:WriteUInt(8, g)
		buffer:WriteUInt(8, b)

		return buffer
	end

	local read = function(buffer)
		local r = buffer:ReadUInt(8)
		local g = buffer:ReadUInt(8)
		local b = buffer:ReadUInt(8)
		local data = Color3.fromRGB(r, g, b)
		
		return data, buffer
	end

	local check = function(data)
		return typeof(data) == "Color3"
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

function BufferTemplates.Vector3()
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		local x, y, z = data.X, data.Y, data.Z

		buffer:WriteFloat32(x)
		buffer:WriteFloat32(y)
		buffer:WriteFloat32(z)

		return buffer
	end

	local read = function(buffer)
		local x = buffer:ReadFloat32()
		local y = buffer:ReadFloat32()
		local z = buffer:ReadFloat32()
		local data = Vector3.new(x, y, z)

		return data, buffer
	end

	local check = function(data)
		return typeof(data) == "Vector3"
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

--contains multiple templates together
function BufferTemplates.Group(templates)
	local bitWidth = math.ceil(math.log(#templates, 2))

	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		
		for position, template in pairs(templates) do
			if not template.Validate then
				error("Failed to validate grouped templates")
			end

			local valid = template.Validate(data)
			
			if valid then
				buffer:WriteUInt(bitWidth, position - 1)
				template.WriteIntoBuffer(data, buffer)
				
				break
			end
		end

		return buffer
	end
	
	local read = function(buffer)
		local position = buffer:ReadUInt(bitWidth)
		local data = templates[position + 1].ReadFromBuffer(buffer)

		return data, buffer
	end

	local check = function(data)
		for _, template in pairs(templates) do
			local valid = template.Validate(data)

			if valid then
				return true
			end
		end

		return false
	end

	local template = buildEmptyTemplate(write, read, check)

	return template
end

return BufferTemplates