###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  Replaces the name of each pokemon with its corresponding IV

###

PokemonGoMITM = require './lib/pokemon-go-mitm'
changeCase = require 'change-case'

server = new PokemonGoMITM port: 8081
	# Always get the full inventory
	.addRequestHandler "GetInventory", (data) ->
		data.last_timestamp_ms = 0
		data

	# Replace all pokemon nicknames with their IVs
	.addResponseHandler "GetInventory", (data) ->
		if data.inventory_delta
			for item in data.inventory_delta.inventory_items
				if pokemon = item.inventory_item_data.pokemon_data
					iv = ((pokemon.individual_attack or 0)+(pokemon.individual_defense or 0)+(pokemon.individual_stamina or 0))/45.0*100;
					iv = Math.floor(iv*10)/10
					pokemon.nickname = "IV: #{iv}%"
		data
