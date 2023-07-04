local HttpService = game:GetService("HttpService")

local BufferTemplates = require(game:GetService("ServerScriptService").BufferTemplates)

local ITEM_TEMPLATE = BufferTemplates.Table({
	ItemId = BufferTemplates.Int(8),
	Amount = BufferTemplates.Int(8),

	Durability = BufferTemplates.Int(12),
	Enhanced = BufferTemplates.Bool(),

	DyeColor = BufferTemplates.Color3(),
	Natural = BufferTemplates.Bool(),
})

local INV_TEMPLATE = BufferTemplates.Array(ITEM_TEMPLATE)

function generateInv()
	local random = Random.new()
	local inventory = {}

	for i = 1, 1000 do
		local itemData = {
			ItemId = random:NextInteger(0, 255),
			Amount = random:NextInteger(0, 255),

			Durability = random:NextInteger(0, 4095),
			Enhanced = random:NextInteger(0, 1) == 1,
			DyeColor = Color3.new(random:NextNumber(), random:NextNumber(), random:NextNumber()),
			Natural = random:NextInteger(0, 1) == 1,
		}

		table.insert(inventory, itemData)
	end

	return inventory
end

local sampleInventory = generateInv()

local t_start = os.clock()
INV_TEMPLATE:CompressIntoBase91(sampleInventory)
local t_end = os.clock()

print("Time to compress BT:", t_end - t_start)