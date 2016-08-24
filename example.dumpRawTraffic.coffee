###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example dumps all raw envelopes and signatures to separate files

###

PokemonGoMITM = require './lib/pokemon-go-mitm'
fs = require 'fs'
pcrypt = require 'pcrypt'

server = new PokemonGoMITM port: 8081, debug: true
	.addRawRequestEnvelopeHandler (buffer) ->
		timestamp = Date.now()
		if decoded = @parseProtobuf buffer, 'POGOProtos.Networking.Envelopes.RequestEnvelope'
			id = decoded.request_id
		console.log "[#] Request Envelope", decoded
		fs.writeFileSync "#{timestamp}.#{id}.request", buffer, 'binary'

		# TODO: update once repeated field 6 is parsed
		return false unless decoded?.unknown6?.unknown2?.encrypted_signature

		buffer = pcrypt.decrypt decoded.unknown6?.unknown2?.encrypted_signature
		decoded = @parseProtobuf buffer, 'POGOProtos.Networking.Envelopes.Signature'
		console.log "[@] Request Envelope Signature", decoded
		fs.writeFileSync "#{timestamp}.#{id}.signature", buffer, 'binary'
		false

	.addRawResponseEnvelopeHandler (buffer) ->
		timestamp = Date.now()
		if decoded = @parseProtobuf buffer, 'POGOProtos.Networking.Envelopes.ResponseEnvelope'
			id = decoded.request_id
		console.log "[#] Response Envelope", decoded
		fs.writeFileSync "#{timestamp}.#{id}.response", buffer, 'binary'
		false

