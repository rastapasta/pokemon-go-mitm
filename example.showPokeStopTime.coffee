###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  Example by iDigitalFlame <idf@idfla.me>
  
  This example just shows the timeouts for PokeStops in the description of the stop
###

PokemonGoMITM = require './lib/pokemon-go-mitm'
changeCase = require 'change-case'
moment = require 'moment'
LatLon = require('geodesy').LatLonSpherical

forts = []

server = new PokemonGoMITM port: 8081
	.addResponseHandler "GetMapObjects", (data) ->
		forts = []
		for cell in data.map_cells
      		for fort in cell.forts
        		forts.push fort
        		zfta = parseInt((parseFloat(fort.cooldown_complete_timestamp_ms) - parseFloat(new Date().getTime())) / 1000)
        		if zfta <= 0
        			console.log "PokeStop '#{fort.id}' is ready!"
		false
	.addResponseHandler "FortDetails", (data) ->
		info = ""
		for fort in forts
			if data.fort_id == fort.id
				if fort.cooldown_complete_timestamp_ms > 0
					zexpir = moment(Number(fort.cooldown_complete_timestamp_ms)).fromNow()
					ztda = parseInt((parseFloat(fort.cooldown_complete_timestamp_ms) - parseFloat(new Date().getTime())) / 1000)
					if ztda > 0
						info += "Ready in #{ztda} seconds (#{zexpir})\n"
					else
						console.log "PokeStop '#{data.name}' is ready!"
				break
		data.description = info
		data
