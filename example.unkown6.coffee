###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  Logs the data about you which is sent along in each request

  Using https://github.com/laverdet/pcrypt - big thanks!

###

PokemonGoMITM = require './lib/pokemon-go-mitm'
POGOProtos = require 'pokemongo-protobuf'
pcrypt = require 'pcrypt'

server = new PokemonGoMITM port: 8081
	.addRequestEnvelopeHandler (data) ->
		buffer = pcrypt.decrypt data.unknown6?.unknown2?.encrypted_signature
		console.log POGOProtos.parseWithUnknown buffer, 'POGOProtos.Networking.Envelopes.Signature'
		false
