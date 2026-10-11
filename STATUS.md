# Rob the Rich! – status

## Klart (version 1, spelbar)
- **Världen** byggs helt i kod: torg, 8 baser (en per spelare), Rich Street med 8 valv, WANTED-tavla, topplista "Longest Reign", Fuse Machine.
- **Löpband** i varje bas: spring på det, så får du speed-poäng (+popups). Bandet trycker dig bakåt. Uppgraderas vid skylten bredvid.
- **8 rika NPC-valv** (Grandpa's Garage → THE BILLIONAIRE): 6 föremål vardera (Common → Mythic), mutationer (Gold x2, Diamond x5, Rainbow x15). Lootet delas av hela servern och fylls på efter 6–12 s.
- **Vakter** patrullerar och jagar den som bär loot. Rikare valv har snabbare vakter. Blir du fångad går lootet tillbaka och du blir stunnad.
- **RUN!!-läget**: röd vinjett, "RUN!!", Drop-knapp, "SAFE ZONE" nära hemmet, stort "STOLEN!"-kort när lootet landar.
- **Stjäla från spelare**: Steal-prompt på andras föremål; föremålet lämnar ägaren först när tjuven når hem. **SLAP**-knappen dyker upp nära någon som bär loot och får hen att tappa det.
- **Lås basen** (60 s, 30 s cooldown). Inkräktare teleporteras ut.
- **Inkomst** per föremål → samlas på COLLECT-plattan. Sälj föremål (håll Sell). Plot-uppgradering (6 → 30 piedestaler).
- **👑 THE RICHEST (twisten)**: rikaste spelaren (kräver minst 2 på servern) får krona, guldstråle över basen, ansiktet på WANTED-tavlan och +50 % inkomst, men **kan aldrig låsa basen**. Den som rånar hen får en bounty (2 min av den rikes inkomst) och ett meddelande till hela servern. Tronbyten annonseras. Längsta regeringstid sparas i en global topplista.
- **Fuse Machine**: 3 identiska → 1 med nästa mutation.
- **Index**, **Shop** (passes/produkter visas som "SOON" tills ID:n finns), **offline-inkomst** (50 %, max 12 h), guide-text + pil för nya spelare, Slow Mode.
- Data sparas med ProfileStore (session lock).

## Hur du testar
1. Gå med i spelet → du hamnar i din bas med en gratis Rusty Wrench.
2. Spring på löpbandet tills du har ~30 speed. Följ den gula pilen till Grandpa's Garage, håll STEAL och spring hem.
3. Admin-kommandon i chatten (du som ägare): `!cash 1e9`, `!speed 1e6`, `!item GoldBar Diamond`, `!reroll`, `!reset`.
4. Kronan kräver 2 spelare: testa med en kompis eller med Studio → Test → 2 Players.

## Saknas / att göra
- **Game passes/produkter**: skapa dem i Creator Hub och klistra in ID:n i `src/shared/Config/Products.luau` (eller be mig sätta upp ett ops-workflow som skapar dem automatiskt).
- **Server size**: sätt Max Players till **8** i Creator Hub (en bas per spelare).
- Ingen musik än (bara ljudeffekter). Inga egna ikoner/meshes, allt är byggt av parts.
- Inte testat i Roblox-klienten än: första publiceringen är första riktiga körningen. Rapportera allt som ser fel ut.
- Idéer till v2: rebirth, events (t.ex. "Bank Heist Hour"), dagliga belöningar, likes på baser, fler valv.

## Balans (tools/simulate, aktiv spelare)
Museum Owner ~7 min, Gold Tycoon ~11 min, Mega Yacht ~29 min, Tech Billionaire ~65 min, THE BILLIONAIRE ~3 h.
