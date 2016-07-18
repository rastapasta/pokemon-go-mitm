###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example intercetps the server answer after a successful throw and signals
  the App that the pokemon has fleed - cleaning up can be done at home :)

  Be aware: This triggers an error message in the App but won't interfere further on
###

server = new PokemonGoMITM port: 8081, debug: true
	.setResponseHandler "CatchPokemon", (data) ->
		data.status = 'CATCH_FLEE' if data.status is 'CATCH_SUCCESS'
		data
