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
mapRadius = 150 # Approx size of level 15 s2 cell

server = new PokemonGoMITM port: 8081
	# Fetch our current location as soon as it gets passed to the API
	.addRequestHandler "GetMapObjects", (data) ->
		currentLocation = new LatLon data.latitude, data.longitude
		console.log "[+] Current position of the player #{currentLocation}"
		false

	# Parse the wild pokemons nearby
	.addResponseHandler "GetMapObjects", (data) ->
		return false if not data.map_cells.length

		oldPokemons = pokemons
		pokemons = []
		seen = {}

		# Store wild pokemons
		addPokemon = (pokemon) ->
			return if seen[pokemon.encounter_id]
			return if pokemon.time_till_hidden_ms < 0

			console.log "new wild pokemon", pokemon
			pokemons.push pokemon
			seen[pokemon.encounter_id] = pokemon

		for cell in data.map_cells
			addPokemon pokemon for pokemon in cell.wild_pokemons

		# Use server timestamp
		timestampMs = Number(data.map_cells[0].current_timestamp_ms)
		# Add previously known pokemon, unless expired
		for pokemon in oldPokemons when not seen[pokemon.encounter_id]
			expirationMs = Number(pokemon.last_modified_timestamp_ms) + pokemon.time_till_hidden_ms
			pokemons.push pokemon unless expirationMs < timestampMs
			seen[pokemon.encounter_id] = pokemon

		# Correct steps display for known nearby Pokémon (idea by @zaksabeast)
		return false if not currentLocation
		for cell in data.map_cells
			for nearby in cell.nearby_pokemons when seen[nearby.encounter_id]
				pokemon = seen[nearby.encounter_id]
				position = new LatLon pokemon.latitude, pokemon.longitude
				nearby.distance_in_meters = Math.floor currentLocation.distanceTo position
		data

	# Whenever a poke spot is opened, populate it with the radar info!
	.addResponseHandler "FortDetails", (data) ->
		console.log "fetched fort request", data
		info = ""

		# Populate some neat info about the pokemon's whereabouts
		pokemonInfo = (pokemon) ->
			name = changeCase.titleCase pokemon.pokemon_data.pokemon_id
			name = name.replace(" Male", "♂").replace(" Female", "♀")
			expirationMs = Number(pokemon.last_modified_timestamp_ms) + pokemon.time_till_hidden_ms
			position = new LatLon pokemon.latitude, pokemon.longitude
			expires = moment(expirationMs).fromNow()
			distance = Math.floor currentLocation.distanceTo position
			bearing = currentLocation.bearingTo position
			direction = switch true
				when bearing>330 then "↑"
				when bearing>285 then "↖"
				when bearing>240 then "←"
				when bearing>195 then "↙"
				when bearing>150 then "↓"
				when bearing>105 then "↘"
				when bearing>60 then "→"
				when bearing>15 then "↗"
				else "↑"

			"#{name} #{direction} #{distance}m expires #{expires}"

		# Create map marker for pokemon location
		markers = {}
		addMarker = (id, lat, lon) ->
			label = id.charAt(0)
			name = changeCase.paramCase id.replace(/_([MF]).*/, "_$1")
			icon = "http://raw.github.com/msikma/pokesprite/master/icons/pokemon/regular/#{name}.png"
			markers[id] = "&markers=label:#{label}%7Cicon:#{icon}" if not markers[id]
			markers[id] += "%7C#{lat},#{lon}"

		for modifier in data.modifiers when modifier.item_id is 'ITEM_TROY_DISK'
			expires = moment(Number(modifier.expiration_timestamp_ms)).fromNow()
			info += "Lure by #{modifier.deployer_player_codename} expires #{expires}\n"

		mapPokemons = []
		if currentLocation
			# Limit to map radius
			for pokemon in pokemons
				position = new LatLon pokemon.latitude, pokemon.longitude
				if mapRadius > currentLocation.distanceTo position
					mapPokemons.push pokemon
					addMarker(pokemon.pokemon_data.pokemon_id, pokemon.latitude, pokemon.longitude)

			# Create map image url
			loc = "#{currentLocation.lat},#{currentLocation.lon}"
			img = "http://maps.googleapis.com/maps/api/staticmap?" +
				"center=#{loc}&zoom=17&size=384x512&markers=color:blue%7Csize:tiny%7C#{loc}"
			img += (marker for id, marker of markers).join ""
			data.image_urls.unshift img

			# Sort pokemons by distance
			mapPokemons.sort (p1, p2) ->
				d1 = currentLocation.distanceTo new LatLon(p1.latitude, p1.longitude)
				d2 = currentLocation.distanceTo new LatLon(p2.latitude, p2.longitude)
				d1 - d2


		info += if mapPokemons.length
			(pokemonInfo(pokemon) for pokemon in mapPokemons).join "\n"
		else
			"No wild Pokémon near you..."
		data.description = info
		data
