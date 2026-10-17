# Creator Hub setup – 2026-10-17 05:56 UTC

Catalog: 13 entries in Products.luau

## Listing existing
- LIST pass: HTTP 200 {"gamePasses":[{"gamePassId":2038340615,"name":"VIP Prisoner","description":"Gold fists, a VIP chat tag and the VIP corner in the Common Room.","isForSale":true,"iconAssetId":133448903949274,"createdTimestamp":"2026-10-15T12:05:27.8Z","updatedTimestamp":"2026-10-15T12:05:27.8Z","priceInformation":{"…
- LIST product: HTTP 200 {"developerProducts":[{"productId":3718744929,"name":"Instant Backpack Empty","description":"Dump your whole backpack right where you stand, for full Noodles.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":25,"enabledFeatures":[…

## Creating
  -> DoubleNoodles: pass 2039846388
  -> AutoVacuum: pass 2039576400
  -> HugeBackpack: pass 2036384610
  -> DoubleStrength: pass 2038250596
  -> VIP: pass 2038340615
  -> Dynamite: product 3718744920
  -> NoodlesSmall: product 3718744921
  -> NoodlesBig: product 3718744924
- CREATE product 'Starter Pack' (79 R$): HTTP 200 {"productId":3719132943,"name":"Starter Pack","description":"Once per prisoner: 3 Dynamite, 30 minutes of NOODLE RUSH (2x Noodles), the Fresh Fish uniform and a Noodle Crate.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":79,"enabledFeatures":[]},"isImmutable":false,"createdTimestamp":"2026-10-17T05:56:07.861Z","updatedTimestamp":"2026-10-17T05:56:07.861Z","isManagedPricingEnabled":false}
  -> StarterPack: product 3719132943
- CREATE product 'Noodle Rush' (49 R$): HTTP 200 {"productId":3719132947,"name":"Noodle Rush","description":"2x Noodles from rubble for 30 minutes (adds up if you buy more).","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":49,"enabledFeatures":[]},"isImmutable":false,"createdTimestamp":"2026-10-17T05:56:08.606Z","updatedTimestamp":"2026-10-17T05:56:08.606Z","isManagedPricingEnabled":false}
  -> NoodleRush: product 3719132947
- CREATE product 'Noodle Train' (449 R$): HTTP 200 {"productId":3719132950,"name":"Noodle Train","description":"A whole train of Noodles (24x a crate). The exact amount is shown in the Store.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":449,"enabledFeatures":[]},"isImmutable":false,"createdTimestamp":"2026-10-17T05:56:09.492Z","updatedTimestamp":"2026-10-17T05:56:09.492Z","isManagedPricingEnabled":false}
  -> NoodlesHuge: product 3719132950
- CREATE product 'Prison Pass Premium' (399 R$): HTTP 200 {"productId":3719132958,"name":"Prison Pass Premium","description":"This season's Prison Pass premium track: every premium reward listed in the Pass panel (Riot Gear, Lightning Fists, the Jailbird cellmate and more) plus +25% pass XP. Lasts this season.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":399,"enabledFeatures":[]},"isImmutable":false,"createdTimestamp":"2026-10-17T05:56:10.278Z","updatedTimestamp":"2026-10-17T05:56:10.278Z","isManagedPricingEnabled":false}
  -> PrisonPass: product 3719132958
  -> InstantEmpty: product 3718744929

## Off sale (everything on Roblox that is not in Products.luau)
- OFF SALE pass '2x Cash' (2026352893): HTTP 204 
- OFF SALE pass '2x Treadmill' (2026682939): HTTP 204 
- OFF SALE pass 'Auto Collect' (2025980943): HTTP 204 
- OFF SALE pass 'Mega Lock' (2026112940): HTTP 204 
- OFF SALE pass 'Quick Hands' (2026184973): HTTP 204 
- OFF SALE pass 'Rainbow Trail' (2025284943): HTTP 204 
- OFF SALE pass 'VIP' (2026682948): HTTP 204 
- OFF SALE product 'Cash Bag' (3717972928): HTTP 204 
- OFF SALE product 'Cash Vault' (3717978646): HTTP 204 
- OFF SALE product 'Gift: 2x Cash' (3717978612): HTTP 204 
- OFF SALE product 'Gift: 2x Treadmill' (3717978626): HTTP 204 
- OFF SALE product 'Gift: Auto Collect' (3717978623): HTTP 204 
- OFF SALE product 'Gift: Mega Lock' (3717978641): HTTP 204 
- OFF SALE product 'Gift: Quick Hands' (3717978633): HTTP 204 
- OFF SALE product 'Gift: Rainbow Trail' (3717980845): HTTP 204 
- OFF SALE product 'Gift: VIP' (3717978609): HTTP 204 
- OFF SALE product 'Mega Speed Pack' (3717978642): HTTP 204 
- OFF SALE product 'Speed Pack' (3717972926): HTTP 204 

## Experience name + description
- PATCH place name/description/serverSize=12: HTTP 200 {"path":"universes/10770392871/places/95313582510402","createTime":"2026-10-11T16:10:04.725Z","updateTime":"2026-10-17T05:56:21.728Z","displayName":"Dig Out! Prison Escape","description":"You're a prisoner with a plan. Punch through the back wall of your cell and dig a tunnel 600 m down to freedom!\…
- PATCH universe name/description: HTTP 200 {"path":"universes/10770392871","createTime":"2026-10-11T16:10:04.950Z","updateTime":"2026-10-17T05:56:21.716Z","displayName":"Dig Out! Prison Escape","description":"You're a prisoner with a plan. Punch through the back wall of your cell and dig a tunnel 600 m down to freedom!\n\n⛏️ Smash through 10…

Result: ALL OK
