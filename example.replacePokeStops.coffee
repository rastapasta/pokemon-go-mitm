###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example replaces all PokeStops with beautiful kitten images :)

  Be aware: this is just visible to you and won't gain you any special powers
            but makes the the gaming experience a lot more fun :-)
###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM port: 8081
	.setResponseHandler "FortDetails", (data) ->
		data.name = "Pokemon GO MitM PoC"
		data.description = "meow!"
		data.image_urls = ["http://thecatapi.com/api/images/get?format=src&type=png"]
		data

	.setResponseHandler "FortSearch", (data) ->
		data.items_awarded = [
			{item_type: 'ITEM_MASTER_BALL', item_count: 1}
			{item_type: 'ITEM_SPECIAL_CAMERA', item_count: 1}
			{item_type: 'ITEM_PINAP_BERRY', item_count: 1}
			{item_type: 'ITEM_STORAGE_UPGRADE', item_count: 1}
		]
		data.xp_awarded = 1337
		data