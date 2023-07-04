local BufferTemplates = require(game:GetService("ServerScriptService").BufferTemplates)

local enumData = {
	"one",
	"two",
	"three",
	"four",
	"five",
}

local enum = BufferTemplates.Enum(enumData)

local t2 = BufferTemplates.Group({
	BufferTemplates.Color3(),
	BufferTemplates.Vector3()
})

local t = BufferTemplates.Table({
	bool = BufferTemplates.Bool(),
	uint = BufferTemplates.UInt(12),
	int = BufferTemplates.Int(12),
	float32 = BufferTemplates.Float32(),
	float64 = BufferTemplates.Float64(),
	char = BufferTemplates.Char(),
	staticString = BufferTemplates.StaticString(8),
	string = BufferTemplates.String(),

	fixed = BufferTemplates.Fixed(4, 3),

	staticArray = BufferTemplates.StaticArray(4, enum),
	array = BufferTemplates.Array(t2)
})

function generateSampleData()
	local random = Random.new()

	local data = {
		bool = random:NextInteger(0, 1) == 1,
		uint = random:NextInteger(0, 4095),
		int = random:NextInteger(0, 2047),
		float32 = random:NextNumber()*100,
		float64 = random:NextNumber()*100,
		char = "y",
		staticString = "EIGHTf0u",
		string = "TemplateTest",

		fixed = -5.6346
	}

	local staticArray = {}

	for _ = 1, 4 do
		table.insert(staticArray, enumData[random:NextInteger(1, #enumData)])
	end

	local array = {}

	for i = 1, random:NextInteger(100, 500) do
		local isVector = random:NextInteger(0, 1) == 1
		local v

		if isVector then
			v = Vector3.new(random:NextNumber(), random:NextNumber(), random:NextNumber())*random:NextNumber(-50, 0)
		else
			v = Color3.new(random:NextNumber(), random:NextNumber(), random:NextNumber())
		end

		table.insert(array, v)
	end

	data.staticArray = staticArray
	data.array = array

	return data
end

local uncompressed = generateSampleData()

local t_start = os.clock()
local compressed = t:CompressIntoBase91(uncompressed)
local t_end = os.clock()

print("Original data:", uncompressed)
print("Time spent:", t_end - t_start)
print("Data retrieved:", t:DecompressFromBase91(compressed))