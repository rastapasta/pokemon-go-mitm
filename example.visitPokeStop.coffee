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
        if fort.type is 'CHECKPOINT' and (new Date() - fort.last_modified_timestamp_ms) >= 300000
          position = new LatLon fort.latitude, fort.longitude
          distance = Math.floor currentLocation.distanceTo position
          fort.last_modified_timestamp_ms = new Date()
          if distance < 30
            console.log "[->] FortSearch"
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
                console.log "[<-] Items rewarded: ", data.items_awarded
    false