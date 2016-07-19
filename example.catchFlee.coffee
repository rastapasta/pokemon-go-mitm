###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example intercetps the server answer after a successful throw and signals
  the App that the pokemon has fleed - cleaning up can be done at home :)

  Be aware: This triggers an error message in the App but won't interfere further on
###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM port: 8081
	.addResponseHandler "CatchPokemon", (data) ->
		data.status = 'CATCH_FLEE' if data.status is 'CATCH_SUCCESS'
		data
