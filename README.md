# pokemon-go-mitm-node
[![npm version](https://badge.fury.io/js/pokemon-go-mitm.svg)](https://badge.fury.io/js/pokemon-go-mitm)
![dependencies](https://david-dm.org/rastapasta/pokemon-go-mitm-node.svg)
![license](https://img.shields.io/github/license/rastapasta/pokemon-go-mitm-node.svg)

***IMPORTANT:***
Niantic introduced certificate pinning in the most recent version of the app. Either downgrade to [0.29.3](https://www.apkmirror.com/apk/niantic-inc/pokemon-go/pokemon-go-0-29-3-release/) or root your phone and use [pokemon-go-xposed](https://github.com/rastapasta/pokemon-go-xposed) to make it work again like smooth whipped cream!

Pokemon Go MITM Proxy - Intercepts the traffic between your Pokemon Go App and their servers, decodes the protocol and gives you a handy tool to enrich your own game experience by altering the data on the fly.

Take a look at the **examples** to get started. Feel happily invited to contribute more!

<img width="22%" src="https://files.slack.com/files-pri/T1R4G4SH1-F1SL5TJSD/9a257af3-0c76-4fe4-b396-3cc6b7ed4a29.jpg?pub_secret=8d2362ba2e" /> <img src="https://camo.githubusercontent.com/f53cc9cd861a7b9feb516df352d51bdc0f58c9c6/68747470733a2f2f692e696d6775722e636f6d2f476d61696872502e706e67" height="341""> <img width="22%" src="https://i.imgur.com/lkErths.png" /> <img width="22%" src="https://i.imgur.com/XaEcgsQ.jpg">



## How to use it?
* Get [nodejs](https://nodejs.org/en)
* Get protobuf >= 3
  * Linux: libprotobuf must be present (`apt-get install libprotobuf-dev`)
  * OSX: Use [homebrew](http://brew.sh/) to install `protobuf` with `brew install pkg-config` and `brew install --devel protobuf`
  * Windows: hard to compile - follow [advices](https://github.com/fuwaneko/node-protobuf#windows)

* Clone the code to experiment with the examples! (otherwise use it as a [npm package](https://www.npmjs.com/package/pokemon-go-mitm))

  `git clone https://github.com/rastapasta/pokemon-go-mitm-node.git && cd pokemon-go-mitm-node`

  `npm install`

* Setup the [CoffeeScript](http://coffeescript.org/) interpreter
  `npm install -g coffee-script`

* Prepare your phone to accept the MITM certificate

  * If you are using Pokemon > version 0.30

    * Android
      * on a rooted phone: install the Xposed module [pokemon-go-xposed](https://github.com/rastapasta/pokemon-go-xposed)
      * otherwise: install a [pre-patched version](https://github.com/rastapasta/pokemon-go-mitm-node/issues/69#issuecomment-236424792)

    * iPhone
      * on a jailbroken phone: use [ilendemli](https://github.com/ilendemli)'s nice [patch](https://github.com/ilendemli/trustme/blob/master/packages/info.ilendemli.trustme_0.0.1-1_iphoneos-arm.deb)
      * otherwise: downgrade.

  * Run and quit `coffee example.logTraffic.coffee` to generate a CA certificate
  * Copy the generated `.http-mitm-proxy/certs/ca.pem` to your mobile
  * Add it to the "trusted certificates"

* Setup your connection to use your machine as a proxy (default port is 8081)
* Enjoy :)

## How to code it?

```coffeescript
PokemonGoMITM = require './lib/pokemon-go-mitm'
server = new PokemonGoMITM port: 8081
	
# Every throw you hit is a super-duper-curved ball -> +XP
server.addRequestHandler "CatchPokemon", (data) ->
	data.normalized_reticle_size = 1.950
	data.spin_modifier = 0.850
	if data.hit_pokemon
		data.normalized_hit_position = 1.0
	data

# Replace all PokeStops with kittys!
server.addResponseHandler "FortDetails", (data) ->
	data.name = "Pokemon GO MitM PoC"
	data.description = "meow!"
	data.image_urls = ["http://thecatapi.com/api/images/get?format=src&type=png"]
	data

# Send crafted requests directly to the API as a new request - to release a pokemon as example
server.addResponseHandler "GetInventory", (data) ->
	for item in data.inventory_delta.inventory_items
		if item.inventory_item_data and pokemon = item.inventory_item_data.pokemon_data

			server
				.craftRequest "ReleasePokemon", pokemon_id: pokemon.id
				.then (data) ->
					if data.result is "SUCCESS"
						console.log "[+] Pokemon #{pokemon.pokemon_id} got released!"
	false
```

## What's the status?

Thanks to the awesom work done around [POGOProtos](https://github.com/AeonLucid/POGOProtos), all requests and responses can be intercepted and altered on the fly by now!

* AddFortModifier
* AttackGym
* CatchPokemon
* CheckAwardedBadges
* CheckCodenameAvailable
* ClaimCodename
* CollectDailyBonus
* CollectDailyDefenderBonus
* DiskEncounter
* DownloadItemTemplates
* DownloadRemoteConfigVersion
* DownloadSettings
* Echo
* Encounter
* EncounterTutorialComplete
* EquipBadge
* EvolvePokemon
* FortDeployPokemon
* FortDetails
* FortRecallPokemon
* FortSearch
* GetAssetDigest
* GetDownloadUrls
* GetGymDetails
* GetHatchedEggs
* GetIncensePokemon
* GetInventory
* GetMapObjects
* GetPlayer
* GetPlayerProfile
* GetSuggestedCodenames
* IncenseEncounter
* LevelUpRewards
* NicknamePokemon
* PlayerUpdate
* RecycleInventoryItem
* ReleasePokemon
* SetAvatar
* SetContactSettings
* SetFavoritePokemon
* SetPlayerTeam
* StartGymBattle
* UpgradePokemon
* UseIncense
* UseItemCapture
* UseItemEggIncubator
* UseItemGym
* UseItemPotion
* UseItemRevive
* UseItemXpBoost

Enjoy! And heaps of thanks to everyone who contributed here and on slack!
