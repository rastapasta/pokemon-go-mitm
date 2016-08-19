###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example intercepts the server answer for a successful evolve and causes
  the app to think that the evolution failed, but replaces the Pokémon anyway

  Be aware: This triggers an error message in the app which can be ignored
###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM port: 8081
	.addResponseHandler "EvolvePokemon", (data) ->
		data.result = 'FAILED_POKEMON_MISSING' if data.result is 'SUCCESS'
		data
