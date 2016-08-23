# pokemon-go-mitm-node
![pokemon](https://img.shields.io/badge/Pokemon%20GO-0.35.0-blue.svg?style=flat-square")
[![npm version](https://badge.fury.io/js/pokemon-go-mitm.svg)](https://badge.fury.io/js/pokemon-go-mitm)
![dependencies](https://david-dm.org/rastapasta/pokemon-go-mitm-node.svg)
![license](https://img.shields.io/github/license/rastapasta/pokemon-go-mitm-node.svg)

Pokemon Go MITM Proxy - Intercepts the traffic between your Pokemon Go App and their servers, decodes the protocol and gives you a handy tool to enrich your own game experience by altering the data on the fly.

Take a look at the **examples** to get started. Feel happily invited to contribute more!

<img width="22%" src="https://files.slack.com/files-pri/T1R4G4SH1-F1SL5TJSD/9a257af3-0c76-4fe4-b396-3cc6b7ed4a29.jpg?pub_secret=8d2362ba2e" /> <img src="https://camo.githubusercontent.com/f53cc9cd861a7b9feb516df352d51bdc0f58c9c6/68747470733a2f2f692e696d6775722e636f6d2f476d61696872502e706e67" height="341"> <img width="22%" src="https://i.imgur.com/lkErths.png" /> <img width="22%" src="https://i.imgur.com/XaEcgsQ.jpg">



## How to use it?

### Setting up the server

* Get [nodejs](https://nodejs.org/en)
* Get protobuf >= 3
  * Linux: libprotobuf must be present (`apt-get install libprotobuf-dev`)
  * OSX: Use [homebrew](http://brew.sh/) to install `protobuf` with `brew install pkg-config` and `brew install --devel protobuf`
  * Windows: hard to compile - follow [advices](https://github.com/fuwaneko/node-protobuf#windows)

* Clone the code to experiment with the examples! (otherwise use it as a [npm package](https://www.npmjs.com/package/pokemon-go-mitm))

  `git clone https://github.com/rastapasta/pokemon-go-mitm-node.git && cd pokemon-go-mitm-node`

  `npm install`

* Setup the [CoffeeScript](http://coffeescript.org/) interpreter (optional if using `npm` scripts)
  `npm install -g coffee-script`

### Setting up your device

#### Prepare your phone to accept the MITM certificate
* Android
  * on a **rooted** phone: install the Xposed module [pokemon-go-xposed](https://github.com/rastapasta/pokemon-go-xposed)
  * **otherwise**: install a [pre-patched version](https://github.com/rastapasta/pokemon-go-mitm/issues/69#issuecomment-238457389)

* iPhone
  * you have to be **jailbroken** to use [ilendemli](https://github.com/ilendemli)'s nice certificate pinning [patch](https://github.com/ilendemli/trustme/blob/master/packages/info.ilendemli.trustme_0.0.1-1_iphoneos-arm.deb)

#### Using Xposed on Android

If you are using [pokemon-go-xposed](https://github.com/rastapasta/pokemon-go-xposed), set the custom endpoint to your machines IP (default port it **8082**). All done! 

#### Using iOS or Android without Xposed

* Generate a CA MITM certificate

  * Run `npm start` (or `coffee example.logTraffic.coffee`) to generate a CA certificate
  * Download the generated certificate from the started server via `http://host:8082/ca.crt` (or copy the file `.http-mitm-proxy/certs/ca.pem`)
  * Add the certificate to the "trusted certificates" of your mobile (for "VPN and apps" on Android)

* Setup your mobile's connection to use your machine as a proxy (default proxy port is **8081**)
* Done!

## Troubleshooting

* Android N requires a different certificate format, make sure you download `http://host:8082/ca.crt` to your mobile
* To let an iPhone or iPad trust the certificate, you might have to save and email `http://host:8082/ca.crt` to yourself to open it in the Mail app

* On very few systems (Raspberry Pi) the CA certificate has to be generated manually:

  ```
  openssl genrsa -out .http-mitm-proxy/keys/ca.private.key 2048
  openssl rsa -in .http-mitm-proxy/keys/ca.private.key -pubout > .http-mitm-proxy/keys/ca.public.key
  openssl req -x509 -new -nodes -key .http-mitm-proxy/keys/ca.private.key -days 1024 -out .http-mitm-proxy/certs/ca.pem -subj "/C=US/ST=Utah/L=Provo/O=PokemonCA/CN=example.com"
  ```
* If you are unable to log in after installing the certificate on Android, you may have to reboot for apps to see the new CA (#208)

## How to code it?

```coffeescript
PokemonGoMITM = require './lib/pokemon-go-mitm'
server = new PokemonGoMITM port: 8081

# Replace all PokeStops with kittys!
server.addResponseHandler "FortDetails", (data) ->
	data.name = "Pokemon GO MitM PoC"
	data.description = "meow!"
	data.image_urls = ["http://thecatapi.com/api/images/get?format=src&type=png"]
	data

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
