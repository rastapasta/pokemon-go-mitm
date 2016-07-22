###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  All your hitting throws will be spinned and just perfect, +XP time!
###

PokemonGoMITM = require './lib/pokemon-go-mitm'
server = new PokemonGoMITM port: 8081, debug: true
	.addRequestHandler "CatchPokemon", (data) ->

		data.normalized_reticle_size = 1.950
		data.spin_modifier = 0.850
		if data.hit_pokemon
			data.normalized_hit_position = 1.0

		data
