# Rob the Rich! – status

## Klart (version 1 + Fas A)
- **Världen** byggs helt i kod: torg, 8 baser (en per spelare), Rich Street med 8 valv, WANTED-tavla, topplista "Longest Reign", Fuse Machine.
- **Löpband** i varje bas: spring på det, så får du speed-poäng (+popups). Bandet trycker dig bakåt. Uppgraderas vid skylten bredvid.
- **8 rika NPC-valv** (Grandpa's Garage → THE BILLIONAIRE): 6 föremål vardera (Common → Mythic), mutationer (Gold x2, Diamond x5, Rainbow x15). Lootet delas av hela servern och fylls på efter 6–12 s.
- **Vakter** patrullerar och jagar den som bär loot. Rikare valv har snabbare vakter. Blir du fångad går lootet tillbaka, du blir stunnad och kastas upp i luften.
- **RUN!!-läget**: röd vinjett, "RUN!!", Drop-knapp, "SAFE ZONE" nära hemmet, stort "STOLEN!"-kort när lootet landar.
- **Stjäla från spelare**: Steal-prompt på andras föremål; föremålet lämnar ägaren först när tjuven når hem. **SLAP**-knappen dyker upp nära någon som bär loot och får hen att tappa det.
- **Lås basen** (60 s, 30 s cooldown). Inkräktare teleporteras ut, och servern håller dem ute hela låstiden. Ägaren går rakt igenom sin egen laser.
- **Inkomst** per föremål → samlas på COLLECT-plattan (räcker att stå still på den). Sälj föremål (håll Sell). Plot-uppgradering (6 → 30 piedestaler).
- **👑 THE RICHEST (twisten)**: rikaste spelaren (kräver minst 2 på servern) får krona, guldstråle över basen, ansiktet på WANTED-tavlan och +50 % inkomst, men **kan aldrig låsa basen**. Den som rånar hen får en bounty (2 min av den rikes inkomst, minst $500) och ett meddelande till hela servern. Tronbyten annonseras. Längsta regeringstid sparas i en global topplista.
- **Fuse Machine**: 3 identiska → 1 med nästa mutation ("FUSED!"-kort).
- **Index**, **Shop**, **offline-inkomst** (50 %, max 12 h), guide-text + pil för nya spelare, Slow Mode.
- Data sparas med ProfileStore (session lock).

### Fas A (den här omgången)
- **Kodgranskning, fixade buggar:**
  - Vakterna var rigless-humanoids i R6-läge (default), som letar efter ben och snubblar/faller. Nu R15-läge så HipHeight håller dem stående och de går.
  - HUD:en skalades med en UIScale på hela skärmen, vilket på mobil drar mitten- och högerplacerade saker (kronbaren, notiser) snett. Nu skalas varje del runt sin egen ankarpunkt. Menyerna (Shop/Index/Fuse) är större på telefon.
  - "UPGRADE PLOT"-skylten hade texten mot väggen (osynlig inifrån basen). Nu text på båda sidor, samma för löpbandsskylten.
  - Glaslocket i valven skar igenom föremålens namnskyltar. Flyttat upp.
  - Knuffen när en vakt fångar dig sattes på servern (fungerar inte på spelarens egen fysik). Nu på klienten.
  - Kronans ädelstenar satt inuti bandet. "Tall"-föremål (t.ex. Antique Clock) var platta.
  - Fuse visade "STOLEN!". Nu "FUSED!".
  - Topplistan slog upp spelarnamn varje minut, nu cachat.
  - Fuse Machine skymde "Longest Reign"-tavlan, flyttad åt sidan.
- **Headless smoke-test** (`tools/smoke.luau` + `tools/ci/smoke.py`): vid varje push laddar CI upp bygget som en *sparad* (ej publicerad) version och kör testet inne i den riktiga placen på Robloxs servrar (Open Cloud Luau Execution). Det startar alla servertjänster som riktiga servern gör och kontrollerar världen: antal baser/valv/vakter, åt vilket håll varje skylt pekar, att spawn ligger i basen, löpbandets riktning och att man räknas när man står på det, att inget står på piedestalerna, vakternas humanoid-setup, alla 48 föremål × 4 mutationer, lootet ovanför huvudet och kronan. Publicering stoppas om testet hittar fel. (Fysik och spelare finns inte i den miljön, så rörelser måste fortfarande testas på riktigt.)
- **Ops-workflow** (`tools/ops/roblox_setup.py` + `.github/workflows/ops.yml`, samma upplägg som i CM): push till en branch `ops/*` skapar alla game passes och developer products i `Config/Products.luau` via Open Cloud (matchas på namn, priser synkas), skriver tillbaka ID:n och sätter **Max Players = 8**. Loggen hamnar i `tools/ops/ops-log.md`.

## Hur du testar (iPhone)
1. Gå med → du ska stå **i din egen bas** (skylten ovanför ingången har ditt namn) med en gratis Rusty Wrench på en piedestal.
2. HUD: cash/inkomst/speed uppe till vänster, 4 knappar till vänster (SHOP, INDEX, LOCK, SLOW), kronbaren **mitt** i toppen. Inget ska ligga utanför skärmen eller under tumspaken.
3. Följ gula pilen till löpbandet, håll tumspaken framåt. Du ska få "+⚡"-popups och speed-siffran ska öka. Släpper du glider du av bakåt.
4. Läs skyltarna: "UPGRADE PLOT" vid ingången (inifrån), "UPGRADE TREADMILL" vid bandet. Knappen "Upgrade" ska bara synas för dig i din bas.
5. Ställ dig på gröna COLLECT-plattan → "+$…" och cash ökar.
6. Med ~30 speed: följ pilen till Grandpa's Garage. Vakten ska **stå upp och gå** (inte ligga ner eller sväva). Håll STEAL på ett föremål → röd skärm, "RUN!!", föremålet svävar över huvudet, vakten jagar. Spring hem → "SAFE ZONE" → "STOLEN!"-kort, föremålet står på en piedestal.
7. Bli fångad med flit: du ska studsa upp, se "CAUGHT", föremålet går tillbaka i valvet.
8. Tryck LOCK → röd laser i ingången, du kan själv gå igenom den. Knappen räknar ner.
9. Shop: ska visa R$-priser (inte "SOON") när ops-workflowet har kört. Prova att trycka ett köp (avbryt i Robloxs dialog om du inte vill köpa).
10. Med en kompis (eller ett andra konto): kronan över huvudet på den rikaste, guldstråle över basen, ansiktet på WANTED-tavlan, LOCK-knappen visar "👑 NO". Stjäl från den rikaste → bounty + meddelande till alla. SLAP-knappen när kompisen bär något nära dig.
11. Admin-kommandon i chatten (du som ägare): `!cash 1e9`, `!speed 1e6`, `!item GoldBar Diamond`, `!reroll`, `!reset`.

## Saknas / att göra
- Fas B (juice), C (retention), D (twisten på max), E (intäkter) enligt planen.
- Ingen musik än (bara ljudeffekter). Inga egna ikoner/meshes, allt är byggt av parts.
- Vakterna har ingen gånganimation än (Fas B).
- Smoke-testet och ops-workflowet behöver rätt behörigheter på API-nyckeln `RTR_PUBLISHING_KEY` (se "Nyckelbehörigheter" nedan). Saknas en behörighet loggas det och publiceringen fortsätter ändå.

## Nyckelbehörigheter (Creator Hub → Open Cloud → API Keys → RTR_PUBLISHING_KEY)
- `universe-places: write` – publicera (finns redan).
- `universe.place.luau-execution-session: write` – headless smoke-test.
- `game-pass: read + write`, `developer-product: read + write` – skapa passes/produkter.
- `universe.place: write` – Max Players.

## Balans (tools/simulate, aktiv spelare)
Museum Owner ~7 min, Gold Tycoon ~11 min, Mega Yacht ~29 min, Tech Billionaire ~65 min, THE BILLIONAIRE ~3 h.
