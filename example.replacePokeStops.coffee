###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example replaces all PokeStops with beautiful kitten images :)

  Be aware: this is just visible to you and won't gain you any special powers
            but makes the the gaming experience a lot more fun :-)
###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM port: 8081
	.addResponseHandler "FortDetails", (data) ->
		data.name = "Pokemon GO MitM PoC"
		data.description = "meow!"
		data.image_urls = ["http://thecatapi.com/api/images/get?format=src&type=png"]
		data