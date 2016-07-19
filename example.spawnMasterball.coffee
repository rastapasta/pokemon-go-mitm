###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  Spinning a Pokestop - a gift that keeps on giving

  Be aware: you can see it, you can touch it - you won't own it :)
###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM port: 8081
	.addResponseHandler "FortSearch", (data) ->
		data.items_awarded = [
			{item_type: 'ITEM_MASTER_BALL', item_count: 1}
			{item_type: 'ITEM_SPECIAL_CAMERA', item_count: 1}
			{item_type: 'ITEM_PINAP_BERRY', item_count: 1}
			{item_type: 'ITEM_STORAGE_UPGRADE', item_count: 1}
		]
		data.xp_awarded = 1337
		data