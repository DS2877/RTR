# Creator Hub setup – 2026-10-11 16:42 UTC

Catalog: 5 entries in Products.luau

## Listing existing
- LIST pass: HTTP 200 {"gamePasses":[],"nextPageToken":""}
- LIST product: HTTP 200 {"developerProducts":[],"nextPageToken":null}

## Creating
- CREATE pass '2x Cash' (199 R$): HTTP 200 {"gamePassId":2026352893,"name":"2x Cash","description":"Everything on your plot earns double, forever.","isForSale":true,"iconAssetId":133448903949274,"createdTimestamp":"2026-10-11T16:42:20.321Z","updatedTimestamp":"2026-10-11T16:42:20.321Z","priceInformation":{"defaultPriceInRobux":199,"enabledFeatures":[]},"isManagedPricingEnabled":false}
  -> DoubleCash: pass 2026352893
- CREATE pass '2x Treadmill' (149 R$): HTTP 200 {"gamePassId":2026682939,"name":"2x Treadmill","description":"Your treadmill gives double speed points, forever.","isForSale":true,"iconAssetId":133448903949274,"createdTimestamp":"2026-10-11T16:42:20.87Z","updatedTimestamp":"2026-10-11T16:42:20.87Z","priceInformation":{"defaultPriceInRobux":149,"enabledFeatures":[]},"isManagedPricingEnabled":false}
  -> DoubleSpeed: pass 2026682939
- CREATE pass 'Mega Lock' (99 R$): HTTP 200 {"gamePassId":2026112940,"name":"Mega Lock","description":"Your base lock lasts 2x longer.","isForSale":true,"iconAssetId":133448903949274,"createdTimestamp":"2026-10-11T16:42:21.379Z","updatedTimestamp":"2026-10-11T16:42:21.379Z","priceInformation":{"defaultPriceInRobux":99,"enabledFeatures":[]},"isManagedPricingEnabled":false}
  -> LongLock: pass 2026112940
- CREATE product 'Speed Pack' (29 R$): HTTP 200 {"productId":3717972926,"name":"Speed Pack","description":"+10 minutes of treadmill points instantly.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":29,"enabledFeatures":[]},"isImmutable":false,"createdTimestamp":"2026-10-11T16:42:22.314Z","updatedTimestamp":"2026-10-11T16:42:22.314Z","isManagedPricingEnabled":false}
  -> Speed10: product 3717972926
- CREATE product 'Cash Bag' (49 R$): HTTP 200 {"productId":3717972928,"name":"Cash Bag","description":"+30 minutes of your current income instantly.","iconImageAssetId":88963008124478,"universeId":10770392871,"isForSale":true,"priceInformation":{"defaultPriceInRobux":49,"enabledFeatures":[]},"isImmutable":false,"createdTimestamp":"2026-10-11T16:42:22.873Z","updatedTimestamp":"2026-10-11T16:42:22.873Z","isManagedPricingEnabled":false}
  -> Cash30: product 3717972928

## Max Players
- PATCH serverSize=8: HTTP 200 {"path":"universes/10770392871/places/95313582510402","createTime":"2026-10-11T16:10:04.725Z","updateTime":"2026-10-11T16:42:21.007Z","displayName":"Rob the Rich!","description":"","serverSize":8,"root":true,"universeRuntimeCreation":false,"templatePlace":""}

Result: ALL OK
