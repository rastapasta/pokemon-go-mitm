# pokemon-go-mitm-node
Pokemon Go MITM Proxy - Intercepts the traffic between your Pokemon Go App and their servers, decodes the protocol and gives you a handy tool to enrich your own game experience by altering the data on the fly.

Take a look at the **examples** or the [pokemon-go-infospot](https://github.com/rastapasta/pokemon-go-infospot) implementation to get started. Feel happily invited to contribute mor more!

![screenshot](https://files.slack.com/files-pri/T1R4G4SH1-F1SL5TJSD/9a257af3-0c76-4fe4-b396-3cc6b7ed4a29.jpg?pub_secret=8d2362ba2e)
![screenshot](https://files.slack.com/files-pri/T1R4G4SH1-F1SHL752S/bildschirmfoto_2016-07-18_um_09.35.29.png?pub_secret=04cbc25c54)

## How to use it?
* For development and examples, pull the master branch and do a **npm install**
* To use it in another project go for **npm install --save pokemon-go-mitm**
* **coffee example.replacePokeStops.coffee**
* Run it once to get a CA certificate generated
* Copy .http-mitm-proxy/certs/ca.pem to your Android device
* Add it to "trusted certificates"
* Setup your connection to use your server as a proxy (default port is 8081)
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

* AddFortModifierMessage
* AttackGymMessage
* CatchPokemonMessage
* CheckAwardedBadgesMessage
* CheckCodenameAvailableMessage
* ClaimCodenameMessage
* CollectDailyBonusMessage
* CollectDailyDefenderBonusMessage
* DiskEncounterMessage
* DownloadItemTemplatesMessage
* DownloadRemoteConfigVersionMessage
* DownloadSettingsMessage
* EchoMessage
* EncounterMessage
* EncounterTutorialCompleteMessage
* EquipBadgeMessage
* EvolvePokemonMessage
* FortDeployPokemonMessage
* FortDetailsMessage
* FortRecallPokemonMessage
* FortSearchMessage
* GetAssetDigestMessage
* GetDownloadUrlsMessage
* GetGymDetailsMessage
* GetHatchedEggsMessage
* GetIncensePokemonMessage
* GetInventoryMessage
* GetMapObjectsMessage
* GetPlayerMessage
* GetPlayerProfileMessage
* GetSuggestedCodenamesMessage
* IncenseEncounterMessage
* LevelUpRewardsMessage
* NicknamePokemonMessage
* PlayerUpdateMessage
* RecycleInventoryItemMessage
* ReleasePokemonMessage
* SetAvatarMessage
* SetContactSettingsMessage
* SetFavoritePokemonMessage
* SetPlayerTeamMessage
* StartGymBattleMessage
* UpgradePokemonMessage
* UseIncenseMessage
* UseItemCaptureMessage
* UseItemEggIncubatorMessage
* UseItemGymMessage
* UseItemPotionMessage
* UseItemReviveMessage
* UseItemXpBoostMessage

### Requests (going from the app to the server)

* in testing phase

Enjoy! And heaps of thanks to everyone who contributed here and on slack!
