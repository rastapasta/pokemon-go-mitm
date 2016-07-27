###
  Pokemon Go(c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>

  Cleanup script by https://github.com/prajwalkman

  Appends the IV% of good pokemon to its name, releases crappy and weak pokemon

  if IV > iv_threshold, then append IV to name
  else if CP < cp_threshold, then release the pokemon
  
  Favorited pokemon will NOT be released
###

iv_threshold = 80
cp_threshold = 800

PokemonGoMITM = require './lib/pokemon-go-mitm'
changeCase = require 'change-case'
_ = require 'lodash'

delays =
    login: 15000
    rename: 750
    release: 750

server = new PokemonGoMITM port: 8081

renameDataset = {}
releaseDataset = {}
processed = false

requestRename = (id, name) ->
    server
        .craftRequest "NicknamePokemon", pokemon_id: id, nickname: name
        .then (data) ->
            if data.result is 'SUCCESS'
                console.log "Requested rename #{id} to #{name}"

requestRelease = (id, name) ->
    server
        .craftRequest "ReleasePokemon", pokemon_id: id
        .then (data) ->
            if data.result is 'SUCCESS'
                console.log "Requested release #{id} : #{name}"

releaser = () ->
    console.log "starting releaser (#{_.keys(releaseDataset).length} items)"
    i = 0
    timer = setInterval ->
        if i >= _.keys(releaseDataset).length
            clearInterval(timer)
            console.log "finished releasing"
            return
        id = _.keys(releaseDataset)[i]
        name = releaseDataset[id]
        requestRelease(id, name)
        i = i + 1
    , delays.release

renamer = () ->
    console.log "starting renamer (#{_.keys(renameDataset).length} items)"
    i = 0
    timer = setInterval ->
        if i >= _.keys(renameDataset).length
            clearInterval(timer)
            console.log "finished renaming"
            releaser()
            return
        id = _.keys(renameDataset)[i]
        name = renameDataset[id]
        requestRename(id, name)
        i = i + 1
    , delays.rename

server.addRequestHandler "GetInventory", (data) ->
    return data if processed
    data.last_timestamp_ms = 0
    data

server.addResponseHandler "GetInventory", (data) ->
    return data if processed
    iPokemon = 0
    for item in data.inventory_delta.inventory_items
        continue unless pokemon = item.inventory_item_data.pokemon_data
        continue unless pokemon.pokemon_id
        iPokemon = iPokemon + 1
        iv = ((pokemon.individual_attack or 0)+(pokemon.individual_defense or 0)+(pokemon.individual_stamina or 0))/45.0*100;
        iv = Math.floor iv
        if iv >= iv_threshold
            # rename this
            nickname = changeCase.pascalCase(pokemon.pokemon_id) + iv
            if pokemon.nickname != nickname
                renameDataset[pokemon.id] = nickname
        else if pokemon.cp < cp_threshold and pokemon.favorite is undefined
            # release this
            releaseDataset[pokemon.id] = "#{changeCase.pascalCase(pokemon.pokemon_id)} | cp#{pokemon.cp} | iv#{iv}"
    processed = true
    console.log "Inventory processed (#{iPokemon} pokemon); waiting for login delay #{delays.login}ms"
    setTimeout renamer, delays.login
    data
