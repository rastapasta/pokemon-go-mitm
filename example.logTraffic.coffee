###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example just dumps all incoming and outgoing message and response

###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM port: 8081
	.addRequestHandler "*", (data, action) ->
		console.log "[<-] Request for #{action} ", data
		false

	.addResponseHandler "*", (data, action) ->
		console.log "[->] Response for #{action} ", data
		false