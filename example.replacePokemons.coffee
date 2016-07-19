###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example replaces all your pokemons with Mew, Mewto, Dragonite, ...

  Be aware: this is just visible to you and won't gain you any special powers
            all display pokemons will act as their original ones
###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM port: 8081
	.addResponseHandler "GetInventory", (data) ->
		
		biggest = 151
		if data.inventory_delta
			for item in data.inventory_delta.inventory_items
				if pokemon = item.inventory_item_data.pokemon_data
					pokemon.pokemon_id = biggest--
					pokemon.cp = 1337

					break unless biggest
		data