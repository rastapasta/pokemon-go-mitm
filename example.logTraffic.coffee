###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example just dumps all in-/outgoing messages and responses

###

PokemonGoMITM = require './lib/pokemon-go-mitm'

# Uncomment if you want to filter the regular messages
# ignore = ['GetHatchedEggs', 'DownloadSettings', 'GetInventory', 'CheckAwardedBadges', 'GetMapObjects']
ignore = []

server = new PokemonGoMITM port: 8081
	.addRequestHandler "*", (data, action) ->
		console.log "[<-] Request for #{action} ", data, "\n" unless action in ignore
		false

	.addResponseHandler "*", (data, action) ->
		console.log "[->] Response for #{action} ", JSON.stringify(data, null, 4), "\n" unless action in ignore
		false
