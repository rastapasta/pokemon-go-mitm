###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example just dumps all in-/outgoing messages and responses plus all envelopes and signatures

###

PokemonGoMITM = require './lib/pokemon-go-mitm'
POGOProtos = require 'pokemongo-protobuf'
pcrypt = require 'pcrypt'

# Uncomment if you want to filter the regular messages
# ignore = ['GetHatchedEggs', 'DownloadSettings', 'GetInventory', 'CheckAwardedBadges', 'GetMapObjects']
ignore = []

server = new PokemonGoMITM port: 8081, debug: true
	.addRequestEnvelopeHandler (data) ->
		console.log "[#] Envelope Request", JSON.stringify(data, null, 4)
		false

	.addResponseEnvelopeHandler (data) ->
		console.log "[#] Envelope Response", JSON.stringify(data, null, 4)
		false

	.addRequestEnvelopeHandler (data) ->
		buffer = pcrypt.decrypt data.unknown6?.unknown2?.encrypted_signature
		decoded = POGOProtos.parseWithUnknown buffer, 'POGOProtos.Networking.Envelopes.Signature'
		console.log "[@] Envelope Request Signature", JSON.stringify(decoded, null, 4)
		false
