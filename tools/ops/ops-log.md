# Creator Hub setup – 2026-10-11 17:20 UTC

Catalog: 11 entries in Products.luau

## Listing existing
- LIST pass: HTTP 200 {"gamePasses":[{"gamePassId":2026184973,"name":"Quick Hands","description":"Steal instantly: no more holding the STEAL button.","isForSale":true,"iconAssetId":133448903949274,"createdTimestamp":"2026-10-11T17:08:57.847Z","updatedTimestamp":"2026-10-11T17:08:57.847Z","priceInformation":{"defaultPrice…
- LIST product: HTTP 200 {"developerProducts":[{"productId":3717978646,"name":"Cash Vault","description":"+3 hours of your current income instantly.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":199,"enabledFeatures":[]},"isImmutable":false,"createdTim…

## Creating
  -> VIP: pass 2026682948
     gift product 3717978609
  -> DoubleCash: pass 2026352893
     gift product 3717978612
  -> AutoCollect: pass 2025980943
     gift product 3717978623
  -> DoubleSpeed: pass 2026682939
     gift product 3717978626
  -> QuickHands: pass 2026184973
     gift product 3717978633
- CREATE pass 'Rainbow Trail' (79 R$): HTTP 200 {"gamePassId":2025284943,"name":"Rainbow Trail","description":"A rainbow trail behind you while you run. Equip it in the Trails shop.","isForSale":true,"iconAssetId":133448903949274,"createdTimestamp":"2026-10-11T17:20:03.108Z","updatedTimestamp":"2026-10-11T17:20:03.108Z","priceInformation":{"defaultPriceInRobux":79,"enabledFeatures":[]},"isManagedPricingEnabled":false}
  -> RainbowTrail: pass 2025284943
- CREATE product 'Gift: Rainbow Trail' (79 R$): HTTP 200 {"productId":3717980845,"name":"Gift: Rainbow Trail","description":"Gift the Rainbow Trail pass to a friend. A rainbow trail behind you while you run. Equip it in the Trails shop.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":79,"enabledFeatures":[]},"isImmutable":false,"createdTimestamp":"2026-10-11T17:20:03.718Z","updatedTimestamp":"2026-10-11T17:20:03.718Z","isManagedPricingEnabled":false}
     gift product 3717980845
  -> LongLock: pass 2026112940
     gift product 3717978641
  -> Speed10: product 3717972926
  -> Speed60: product 3717978642
  -> Cash30: product 3717972928
  -> Cash180: product 3717978646

## Max Players
- PATCH serverSize=8: HTTP 200 {"path":"universes/10770392871/places/95313582510402","createTime":"2026-10-11T16:10:04.725Z","updateTime":"2026-10-11T17:18:21.538Z","displayName":"Rob the Rich!","description":"","serverSize":8,"root":true,"universeRuntimeCreation":false,"templatePlace":""}

Result: ALL OK
