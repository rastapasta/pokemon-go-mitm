# pokemon-go-mitm-node
Pokemon Go MITM Proxy - Intercepts the traffic between your Pokemon Go App and their servers, decodes the protocol and gives you a handy tool to enrich your own game experience by altering the data on the fly.

Take a look at the **examples** to get started. Feel happily invited to contribute more!

<img width="22%" src="https://files.slack.com/files-pri/T1R4G4SH1-F1SL5TJSD/9a257af3-0c76-4fe4-b396-3cc6b7ed4a29.jpg?pub_secret=8d2362ba2e" /> <a href="https://www.youtube.com/watch?v=7lZQLSt7uc0"><img width="22%" src="https://i.imgur.com/dhqU6jz.jpg" /></a> <img width="22%" src="https://i.imgur.com/lkErths.png" /> <img width="22%" src="https://i.imgur.com/XaEcgsQ.jpg">

## How to use it?
* Get [nodejs](https://nodejs.org/en)
* Get protobuf >= 3
  * Linux: libprotobuf must be present (`apt-get install libprotobuf-dev`)
  * OSX: Use [homebrew](http://brew.sh/) to install `protobuf` with `brew install --devel protobuf`
  * Windows: hard to compile - follow [advices](https://github.com/fuwaneko/node-protobuf#windows)

* Clone the code to experiment with the examples! (otherwise use it as a [npm package](https://www.npmjs.com/package/pokemon-go-mitm))

`git clone https://github.com/rastapasta/pokemon-go-mitm-node.git && cd pokemon-go-mitm-node`

`npm install`

* Setup the [CoffeeScript](http://coffeescript.org/) interpreter

`npm install -g coffee-script`


* Run and quit one of the examples once to get a CA certificate generated

`coffee example.logTraffic.coffee`

* Copy the generated `.http-mitm-proxy/certs/ca.pem` to your mobile
* Add it to the "trusted certificates"
* Setup your connection to use your machine as a proxy (default port is 8081)
* Enjoy :)

## How to code it?

```coffeescript
PokemonGoMITM = require './lib/pokemon-go-mitm'
server = new PokemonGoMITM port: 8081
	.addResponseHandler "FortDetails", (data) ->
		data.name = "Pokemon GO MitM PoC"
		data.description = "meow!"
		data.image_urls = ["http://thecatapi.com/api/images/get?format=src&type=png"]
		data

	.addRequestHandler "*", (data, action) ->
		console.log "[<-] Request for #{action} ", data
		false

	.addResponseHandler "*", (data, action) ->
		console.log "[->] Response for #{action} ", data
		false

```

## What's the status?

Thanks to the awesom work done around [POGOProtos](https://github.com/AeonLucid/POGOProtos), all actions can be intercepted and altered on the fly by now!

### Responses (coming back from the server)

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

### Requests (going from the app to the server)

* in testing phase

Enjoy! And heaps of thanks to everyone who contributed here and on slack!
