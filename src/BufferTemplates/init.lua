local BitBuffer = require(script.BitBuffer)

local BufferTemplates = {}

local Template = {}
Template.__index = Template

function Template:CompressIntoBase91(data: any)
	return self.WriteIntoBuffer(data):ToBase91()
end

function Template:DecompressFromBase91(b91: string)
	return self.ReadFromBuffer(BitBuffer.FromBase91(b91))
end

function Template:CompressIntoBase64(data: any)
	return self.WriteIntoBuffer(data):ToBase64()
end

function Template:DecompressFromBase64(b64: string)
	return self.ReadFromBuffer(BitBuffer.FromBase64(b64))
end

function Template.IsTemplate(template)
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

function buildEmptyTemplate(write, read)
	local template = {
		WriteIntoBuffer = write,
		ReadFromBuffer = read,
	}
	
	setmetatable(template, Template)
	
	return template
end

function buildStandardTemplate(bufferDataType)
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

	local template = buildEmptyTemplate(write, read)

	return template
end

function BufferTemplates.Custom(write, read)
	local writeWithBuffer = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		return write(data, buffer)
	end
	
	local template = buildEmptyTemplate(writeWithBuffer, read)

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
	
	local template = buildEmptyTemplate(write, read)
	
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

	local template = {
		WriteIntoBuffer = write,
		ReadFromBuffer = read,
	}

	return template
end

function BufferTemplates.Float32()
	return buildStandardTemplate("Float32")
end

function BufferTemplates.Float64()
	return buildStandardTemplate("Float64")
end

function BufferTemplates.Char()
	return buildStandardTemplate("Char")
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

	local template = buildEmptyTemplate(write, read)

	return template
end

function BufferTemplates.String()
	return buildStandardTemplate("String")
end

function BufferTemplates.Bool()
	return buildStandardTemplate("Bool")
end

function BufferTemplates.Table(t)
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		
		for dataKey, dataValue in pairs(data) do
			local otherTemplate = t[dataKey]

			if Template.IsTemplate(otherTemplate) then
				otherTemplate.WriteIntoBuffer(dataValue, buffer)
			else
				print(dataKey)
				error("Non-template contamination!")
			end
		end
		
		return buffer
	end

	local read = function(buffer)
		local data = {}
		
		for dataKey, otherTemplate in pairs(t) do
			if Template.IsTemplate(otherTemplate) then
				data[dataKey] = otherTemplate.ReadFromBuffer(buffer)
			else
				error("Non-template contamination!")
			end
		end
		
		return data, buffer
	end

	local template = buildEmptyTemplate(write, read)

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
	
	local template = buildEmptyTemplate(write, read)
	
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
	
	local template = buildEmptyTemplate(write, read)
	
	return template
end

function BufferTemplates.Enum(enumData)
	local bitWidth = math.ceil(math.log(#enumData, 2))
	
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		local position = table.find(enumData, data)
		
		if not position then
			error("Could not find enum")
		end
		
		buffer:WriteUInt(bitWidth, position)

		return buffer
	end

	local read = function(buffer)
		local position = buffer:ReadUInt(bitWidth)
		local data = enumData[position]

		return data, buffer
	end

	local template = buildEmptyTemplate(write, read)

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

	local template = buildEmptyTemplate(write, read)

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

	local template = buildEmptyTemplate(write, read)

	return template
end

--contains multiple templates together
function BufferTemplates.Group(templates)
	local bitWidth = math.ceil(math.log(#templates, 2))
	
	local write = function(data, buffer)
		buffer = spawnNewBitBuffer(buffer)
		
		for position, template in pairs(templates) do
			local newBuffer = buffer:clone()--BitBuffer.FromBase91(buffer:ToBase91())
			local success, msg = pcall(template.WriteIntoBuffer, data, newBuffer)
			
			if success then
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
	
	local template = buildEmptyTemplate(write, read)
	
	return template
end

return BufferTemplates