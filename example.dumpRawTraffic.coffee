###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example dumps all raw envelopes and signatures to separate files

###

PokemonGoMITM = require './lib/pokemon-go-mitm'
fs = require 'fs'
pcrypt = require 'pcrypt'

# Uncomment if you want to filter the regular messages
# ignore = ['GetHatchedEggs', 'DownloadSettings', 'GetInventory', 'CheckAwardedBadges', 'GetMapObjects']
ignore = []

server = new PokemonGoMITM port: 8081, debug: true
	.addRawRequestEnvelopeHandler (buffer) ->
		timestamp = Date.now()
		decoded = @parseProtobuf buffer, 'POGOProtos.Networking.Envelopes.RequestEnvelope'
		console.log "[#] Request Envelope", decoded
		fs.writeFileSync "#{timestamp}.#{decoded.request_id}.request", buffer, 'binary'

		buffer = pcrypt.decrypt decoded.unknown6?.unknown2?.encrypted_signature
		decoded = @parseProtobuf signature, 'POGOProtos.Networking.Envelopes.Signature'
		console.log "[@] Request Envelope Signature", buffer
		fs.writeFileSync "#{timestamp}.#{decoded.request_id}.signature", buffer, 'binary'
		false

	.addRawResponseEnvelopeHandler (data) ->
		timestamp = Date.now()
		decoded = @parseProtobuf buffer, 'POGOProtos.Networking.Envelopes.RequestEnvelope'
		console.log "[#] Response Envelope", decoded
		fs.writeFileSync "#{timestamp}.#{decoded.request_id}.response", buffer, 'binary'
		false


