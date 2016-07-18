###
  Pokemon Go (c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  This example replaces all PokeStops with beautiful kitten images :)
###

PokemonGoMITM = require './lib/pokemon-go-mitm'

server = new PokemonGoMITM(8081)
	.setResponseHandler "FortDetails", (data) ->
		data.name = "Pokemon GO MitM PoC"
		data.description = "meow!"
		data.image_urls = ["http://thecatapi.com/api/images/get?format=src&type=png"]
		data
