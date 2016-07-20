###
  Pokemon Go (c) ManInTheMiddle Radar "mod"
  Michael Strassburger <codepoet@cpan.org>

  Enriches every PokeStop description with information about
  - directions to nearby wild pokemons
  - time left if a PokeStop has an active lure
###

PokemonGoMITM = require './lib/pokemon-go-mitm'
changeCase = require 'change-case'
moment = require 'moment'
LatLon = require('geodesy').LatLonSpherical

pokemons = []
currentLocation = null

server = new PokemonGoMITM port: 8081
	# Fetch our current location as soon as it gets passed to the API
	.addRequestHandler "GetMapObjects", (data) ->
		currentLocation = new LatLon data.latitude, data.longitude
		console.log "[+] Current position of the player #{currentLocation}"
		false

	# Parse the wild pokemons nearby
	.addResponseHandler "GetMapObjects", (data) ->
		pokemons = []
		seen = {}
		addPokemon = (pokemon) ->
			return if seen[hash = pokemon.spawnpoint_id + ":" + pokemon.pokemon_data.pokemon_id]
			return if pokemon.expiration_timestamp_ms < 0

			seen[hash] = true
			pokemons.push
				type: pokemon.pokemon_data.pokemon_id
				latitude: pokemon.latitude
				longitude: pokemon.longitude
				expirationMs: pokemon.expiration_timestamp_ms
				data: pokemon.pokemon_data

		for cell in data.map_cells
			addPokemon pokemon for pokemon in cell.wild_pokemons

		false

	# Whenever a poke spot is opened, populate it with the radar info!
	.addResponseHandler "FortDetails", (data) ->
		console.log "fetched fort request", data
		info = ""

		for modifier in data.modifiers
			if modifier.item_id is 'ITEM_TROY_DISK'
				info += "Lock expires "+moment(data.modifiers[0].expirationMs).toNow()+"\n"

		info += if pokemons.length
			(pokemonInfo(pokemon) for pokemon in pokemons).join "\n"
		else
			"No wild pokemons nearby... yet!"

		data.description = info
		data

# Populate some neat info about the pokemon's whereabouts 
pokemonInfo = (pokemon) ->
	console.log pokemon
	name = changeCase.titleCase pokemon.data.pokemon_id
	position = new LatLon pokemon.latitude, pokemon.longitude
	distance = Math.floor currentLocation.distanceTo position
	bearing = currentLocation.bearingTo position
	direction = switch true
		when bearing>330 then "N"
		when bearing>285 then "NW"
		when bearing>240 then "W"
		when bearing>195 then "SW"
		when bearing>150 then "S"
		when bearing>105 then "SE"
		when bearing>60 then "E"
		when bearing>15 then "NE"
		else "N"

	"#{name} in #{distance}m -> #{direction}"
