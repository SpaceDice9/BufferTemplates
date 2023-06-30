This is a modification of this post: https://devforum.roblox.com/t/buffertemplates-a-super-aggressive-compression-library/2436237/

> WARNING: BufferTemplates is in alpha and a proof of concept. **DO NOT USE THIS IN PRODUCTION OR LIVE EXPERIENCES**.

___
# What is BufferTemplates?

BufferTemplates is a Roblox Luau declarative abstraction layer above BitBuffers that provides a readable library for data compression while giving developers the maximum amount of control possible. Instead of reading and writing data onto a buffer, you instead get something called a "template" which is an instruction table that tells the library how to compress the specified type of data. It offers extreme compression that outperforms generic algorithms, even at smaller data sizes of less than a kilobyte.
___
# Compression in Roblox
Ever since Roblox implemented DataStores there was always a need to compress save data since back then the size limit was significantly smaller than it is today. If Roblox developers wanted to store anything big like huge player-made builds they *had* to use some form of compression. Various generic methods were used over the years such as [LZW](https://devforum.roblox.com/t/text-compression/163637) and [DataSerializer](https://devforum.roblox.com/t/dataserializer-a-package-for-compressing-data-with-support-for-datastore/1886047), but the one that was arguably the most intriguing were [BitBuffers](https://www.roblox.com/library/174612085/BitBuffer-Module) released sometime during 2014. Several more optimized and modern versions were eventually developed as well towards 2021.

To understand why BitBuffers work its important to understand how Roblox saves things. Data is saved by first converting it into a JSON string before writing it into a DataStore, which is an issue because strings take up a lot of bytes. For example, the number `100` would take 7 bits to store but Roblox would convert it into the string `"100"` which takes up 24 bits. That is a whole 17 bits wasted! BitBuffers were created to allow developers to actually use bits instead of this less efficient method. But most people still don't use BitBuffers at all. So what's the catch?

___
# The Problem with BitBuffers

BitBuffers have vast potential in the world of Roblox compression but their usage is hampered by the fact that data is appended to a bitstream. This method by itself is not a problem. It's how BitBuffer manages to condense so much information! But a one-dimensional representation like this is hard to visualize which makes maintaining and debugging the code become more nightmarish the more complicated the data becomes. Another problem is that serialization and deserialization are performed separately with no connection between the two making any update made to one function necessitate updating the other manually which makes maintenance even more tedious. Add more complex structures such as variable arrays, complex tables, and now a disaster is on the horizon! The main issue behind all this lies in BitBuffer's minimal/nonexistant abstraction. 

___
# Templates!
How BitBuffer functions is presented raw to the developer. Write bits, read bits. But it is not really necessary to do that ourselves. Once upon a time programmers were manipulating raw bits too, but today programming languages exist which abstracts most of the bit manipulation under the rug. And it turns out we can do the same with BitBuffers too. That is where BufferTemplates comes in. Instead of using BitBuffers like this:
```lua
function compress(data)
	local bitBuffer = BitBuffer.new()
	
	bitBuffer:WriteUInt(8, data._version)
	
	bitBuffer:WriteUInt(18, data.stats.hp)
	bitBuffer:WriteUInt(18, data.stats.mp)
	bitBuffer:WriteUInt(18, data.stats.speed)
	bitBuffer:WriteUInt(18, data.stats.charisma)
	
	bitBuffer:WriteString(data.characterName)
	
	-- dynamic array size property
	bitBuffer:WriteUInt(24, #data.inventory)
	for _, itemData in data.inventory do
		bitBuffer:WriteUInt(8, itemData.itemId)
		bitBuffer:WriteUInt(6, itemData.amount)
	end
	
	return bitBuffer:ToBase91()
end

function decompress(compressedData)
	local data = {}
	local bitBuffer = BitBuffer.FromBase91(compressedData)
	
	data._version = bitBuffer:ReadUInt(8)
	
	data.stats = {}
	data.stats.hp = bitBuffer:ReadUInt(18)
	data.stats.mp = bitBuffer:ReadUInt(18)
	data.stats.speed = bitBuffer:ReadUInt(18)
	data.stats.charisma = bitBuffer:ReadUInt(18)
	
	data.characterName = bitBuffer:ReadString()
	
	local inventory = {}
	data.inventory = inventory
	
	-- dynamic array size property
	local inventorySize = bitBuffer:ReadUInt(24)
	for i = 1, inventorySize do
		local itemData = {}
		
		itemData.itemId = bitBuffer:ReadUInt(8)
		itemData.amount = bitBuffer:ReadUInt(6)
		
		table.insert(inventory, itemData)
	end
	
	return data
end
```
we can use BufferTemplates to handle the BitBuffer stuff for us:
```lua
local ITEM_DATA_TEMPLATE = BufferTemplates.Table({
	itemId = BufferTemplates.UInt(8),
	amount = BufferTemplates.UInt(6),
})

local PLAYER_DATA_TEMPLATE = BufferTemplates.Table({
	_version = BufferTemplates.UInt(12),
	
	stats = BufferTemplates.Table({
		hp = BufferTemplates.UInt(18),
		mp = BufferTemplates.UInt(18),
		speed = BufferTemplates.UInt(18),
		charisma = BufferTemplates.UInt(18),
	}),
	
	characterName = BufferTemplates.String(),
	
	inventory = BufferTemplates.Array(ITEM_DATA_TEMPLATE),
})

function compress(data)
	return PLAYER_DATA_TEMPLATE:CompressIntoBase91(data)
end

function decompress(compressedData)
	return PLAYER_DATA_TEMPLATE:DecompressFromBase91(compressedData)
end
```
Notice that the developer does not even have to write the compress and decompress functions themselves. This is all handled by the templates!

BufferTemplates still requires that the developer specify precise types and sometimes bit width. This is so BufferTemplates can save as much space as possible and gives programmers a lot of control over how BufferTemplate compresses.
___
# Documentation
## BufferTemplates methods
> `Template BufferTemplates.UInt(bitWidth: number)`

Returns a template that acts on an unsigned integer.

> `Template BufferTemplates.Int(bitWidth: number)`

Returns a template that acts on an integer.

> `Template BufferTemplates.Float32()`

Returns a template that acts on a 32 bit floating point number.

> `Template BufferTemplates.Float64()`

Returns a template that acts on a 64 bit floating point number.

> `Template BufferTemplates.Char()`

Returns a template that acts on a single character.

> `Template BufferTemplates.StaticString(length: number)`

Returns a template that acts on a string with a specified length.

> `Template BufferTemplates.String()`

Returns a template that acts on a string with any length smaller than 16,777,216.

> `Template BufferTemplates.Bool()`

Returns a template that acts on a boolean.

> `Template BufferTemplates.Table(t: {[string]: Template})`

Returns a template that acts on a table.

> `Template BufferTemplates.StaticArray(size: number, template: Template)`

Returns a template that acts on an array with a set size.

> `Template BufferTemplates.Array(t: {[string]: Template})`

Returns a template that acts on an array with any size smaller than 16,777,216.

> `Template BufferTemplates.Enum(enum: {string})`

Returns a template that acts on a user-defined enum.

> `Template BufferTemplates.Color3(enum: {string})`

Returns a template that acts on a `Color3`.

> `Template BufferTemplates.Vector3(enum: {string})`

Returns a template that acts on a `Vector3`.

> `Template BufferTemplates.Group(templates: {Template})`

Returns a template that acts on ambivalent data that may use different templates based on circumstances.

> `Template BufferTemplates.Custom(write: function(data, buffer: BitBuffer?) -> (buffer: BitBuffer), read: function(buffer: BitBuffer) -> (data: any, buffer: BitBuffer)`

Returns a template with a custom read and write method.

___
## Template methods
> `string Template:CompressIntoBase91(data: any)`

Returns a compressed string in Base91 using the specified template. (Recommended)

> `string Template:CompressIntoBase64(data: any)`

Returns a compressed string in Base64 using the specified template.

> `any Template:DecompressFromBase91(compressedData: string)`

Returns decompressed data from Base91 using the specified template. (Recommended)

> `any Template:DecompressFromBase64(compressedData: string)`

Returns decompressed data from Base64 using the specified template.
___
# Benchmark
Template used:
```lua
local Races = {
	"Human",
	"Elf",
	"Dwarf",
	"Dragon",
	"Demon",
	"Angel"
}

local RACE_TEMPLATE = BufferTemplates.Enum(Races)

local ITEM_DATA_TEMPLATE = BufferTemplates.Table({
	itemId = BufferTemplates.UInt(8),
	amount = BufferTemplates.UInt(6),
})

local HEADER_TEMPLATE = BufferTemplates.Table({
	version = BufferTemplates.UInt(24),
	banned = BufferTemplates.Bool(),
})

local USER_DATA_TEMPLATE = BufferTemplates.Table({
	_header = HEADER_TEMPLATE,
	
	stats = BufferTemplates.Table({
		hp = BufferTemplates.UInt(18),
		mp = BufferTemplates.UInt(18),
	}),
	
	hairColor = BufferTemplates.Color3(),
	
	characterName = BufferTemplates.String(),
	race = RACE_TEMPLATE,
	inventory = BufferTemplates.Array(ITEM_DATA_TEMPLATE),
})
```
The data we will compress:
```lua
local data = {
	_header = {
		version = 3,
		banned = false
	},
	
	stats = {
		hp = 679,
		mp = 440,
	},
	
	hairColor = Color3.new(.4, .6, .7),
	
	characterName = "Gandolf",
	
	race = "Angel",
	
	inventory = {
		{itemId = 4, amount = 34},
		{itemId = 70, amount = 12},
	}
}
```
We will compress this data with `BufferTemplates`, `LZW`, and `zlib`.
> Uncompressed size: `191 B`

> BufferTemplates compressed size: `36 B` (18.85% of original size)

> LZW compressed size: `305 B` (159.66% of original size)

> zlib compressed size: `153 B` (80.10% of original size)

___
# Additional Info
Creator Marketplace: https://create.roblox.com/marketplace/asset/13840098917/BufferTemplates

DevForum Post: https://devforum.roblox.com/t/buffertemplates-a-super-aggressive-compression-library/2436237

BufferTemplates uses the optimized BitBuffer from this GitHub repo: https://github.com/rstk/BitBuffer