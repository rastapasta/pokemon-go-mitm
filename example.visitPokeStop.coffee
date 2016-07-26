###
  Pokemon Go(c) MITM node proxy
  Example by Daniel Gothenborg <daniel@dgw.no>

  This will auto-spin PokeStops within 30m with no cooldown.

###

PokemonGoMITM = require './lib/pokemon-go-mitm'

LatLon = require('geodesy').LatLonSpherical

forts = null
currentLocation = null

server = new PokemonGoMITM port: 8081
  .addRequestHandler "*", (data) ->
    currentLocation = new LatLon data.latitude, data.longitude if data.latitude
    false

  .addResponseHandler "GetMapObjects", (data) ->
    forts = []
    for cell in data.map_cells
      for fort in cell.forts
        forts.push fort
    false

  .addRequestHandler "*", (data, action) ->
    if currentLocation and forts
      for fort in forts
        if fort.type is 'CHECKPOINT'
          if not fort.cooldown_complete_timestamp_ms or (parseFloat(new Date().getTime()) - (parseFloat(fort.cooldown_complete_timestamp_ms)-(3600*2*1000))) >= 300000
            position = new LatLon fort.latitude, fort.longitude
            distance = Math.floor currentLocation.distanceTo position
            fort.cooldown_complete_timestamp_ms = new Date().getTime().toString();
            if distance < 30
              server.craftRequest "FortSearch",
                {
                  fort_id: fort.id,
                  fort_latitude: fort.latitude,
                  fort_longitude: fort.longitude,
                  player_latitude: fort.latitude,
                  player_longitude: fort.longitude
                }
              .then (data) ->
                if data.result is 'SUCCESS'
                  console.log "[<-] Items awarded:", data.items_awarded
    false