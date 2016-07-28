###
  Pokemon Go(c) MITM node proxy
  Example by iDigitalFlame <idf@idfla.me>

  This module allows you to see Pokemon in a wider range area.
  You can see some far away Pokemon loaded, but not all are catchable.

  The module also makes PokeStops and Gyms open from far away, but are not useable.

###

PokemonGoMITM = require './lib/pokemon-go-mitm'
changeCase = require 'change-case'
moment = require 'moment'
LatLon = require('geodesy').LatLonSpherical

server = new PokemonGoMITM port: 8081
	.addResponseHandler "DownloadSettings", (data) ->
		if data.settings
			data.settings.map_settings.pokemon_visible_range = 1500
			data.settings.map_settings.poke_nav_range_meters = 1500
			data.settings.map_settings.encounter_range_meters = 1500
			data.settings.fort_settings.interaction_range_meters = 1500
			data.settings.fort_settings.max_total_deployed_pokemon = 50
		data
