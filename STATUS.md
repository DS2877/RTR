# Rob the Rich! – status

## Klart

### Kärnspelet (v1 + Fas A)
- **Världen** byggs helt i kod: torg, 8 baser (en per spelare), Rich Street med 8 valv, WANTED-tavla, topplista "Longest Reign", Fuse Machine.
- **Löpband**: stå på det så får du speed-poäng. Det räcker att stå still (går att AFK:a på telefonen): gubben springer och bandet rullar.
- **8 rika NPC-valv** (Grandpa's Garage → THE BILLIONAIRE), 6 föremål vardera (Common → Mythic), mutationer (Gold x2, Diamond x5, Rainbow x15). Lootet delas av hela servern och fylls på efter 6–12 s.
- **Vakter** patrullerar och jagar den som bär loot. Rikare valv har snabbare vakter. Blir du fångad går lootet tillbaka, du blir stunnad och kastas upp.
- **Carry**: RUN!!, Drop, SAFE ZONE, STOLEN!-kort. **Stjäla från spelare**, **SLAP**, **lås basen** (60 s, servern håller inkräktare ute).
- **Inkomst** → COLLECT-plattan (räcker att stå på den). Sälj, plot-uppgradering (6 → 30 piedestaler), Fuse (3 lika → nästa mutation), Index, offline-inkomst.
- **👑 THE RICHEST**: krona, guldstråle, WANTED-tavlan, +50 % inkomst, kan aldrig låsa, bounty till den som rånar hen.

### Arbetsorder "AAA" (den här omgången)
**Spellogik, testad inne i Roblox vid varje push (548 kontroller):**
- Smoke-testet kör nu **hela spelloopen med två simulerade spelare** i den riktiga placen:
  - inkomst, insamling och uppgradering (med erbjudande när pengarna inte räcker), löpbandet
  - stöld från valv, vakten som larmar och fångar, deposit hemma
  - Guard Strike, Cash Frenzy, Gold Rush
  - stöld från spelare: pilen till tjuven, offret varnas, föremålet lämnar först när tjuven är hemma, slap
  - THE RICHEST: krona, stråle, kan inte låsa, bounty betalas
  - lås (inkräktare ut), sälj, fuse, Auto Collect, spelare som lämnar mitt i en stöld
- Alla 23 ljud-, musik- och animations-ID:n kontrolleras mot Roblox (att de finns och är licensierade).
- Bugg hittad och fixad: bountyn räknades ut *efter* att det stulna föremålet lämnat den rikaste, så den blev för låg när man stal hens bästa sak. Nu räknas den innan.

**Roligare:**
- **Express lanes**: två rullband längs torget och hela Rich Street (blått ut, gult hem, +18 fart). Kortar den tråkiga promenaden i början.
- **Server-events** var 10–15:e minut i 90 s, annonserade med riktig nedräkning i HUD:en:
  - ✨ **GOLD RUSH**: 4x mutationschans, alla valv fylls på direkt.
  - 😴 **GUARD STRIKE**: vakterna sover.
  - 💸 **CASH FRENZY**: 2x inkomst.
- **THE RICHEST växer**: bountyn ökar 15 % per minut av regeringen (max x3), kronan blir större och strålen bredare. Visas på WANTED-tavlan och i kronbaren.
- **Tjuvlarm**: när någon bär ditt föremål visas en röd pil från dig till tjuven och "GO GET THEM! SLAP THE THIEF!". Slappar du tjuven annonseras det för hela servern.
- **Vaktlarm**: summer, röd blixt och skak när en vakt får syn på dig. Vakterna sträcker armarna framåt när de jagar.
- **Onboarding**: checklista uppe till höger första gången (löpband → stjäl → spring hem → collect) med bockar.

**Grafik:**
- Ny ljussättning: gyllene eftermiddag, Future lighting, himmel, solstrålar, bloom och färgkorrigering.
- **Unikt tema i varje valv**, byggt av parts:
  - Grandpa: veteranbil, verktygsvägg, oljefat.
  - Influencer: rosa soffa, ringlampor, neonskylt, ballonger.
  - Pirate: mast med segel, kistor med guld, kanoner.
  - Museum: pelare, dinosaurieskelett, tavlor, avspärrning.
  - Gold Tycoon: myntberg, guldtackor, guldstaty.
  - Mega Yacht: pool, solstolar, båt.
  - Tech Billionaire: blinkande serverrack, raket, hologram.
  - THE BILLIONAIRE: guldstaty, guldbil, kristallkrona, snurrande diamant.
  - Markis och spotlights vid varje entré.
- **Stadssiluett** med glastorn och lysande fönster bakom valven. Trottoarer med gul kantsten, övergångsställe och palmer.
- Torget: två fontäner med vattenpartiklar och bänkar.
- Baserna: hörntorn med lysande toppar i basens färg, entrématta och en lysande ring under varje upplåst piedestal.
- Vakterna: ny modell (skjorta, slips, bricka, keps, öronsnäcka) med **gånganimation**.
- Löpbandet har rullande ränder och din gubbe springer på det.

**Juice:**
- **Musik**: licensierade APM-spår (Heist Time, Smooth Operator, Code Heist, Funky Disco Beats). Byter till jaktmusik (Spy Action) när du bär loot. 🎵-knappen stänger av.
- Kameraskak (stöld, fångad, slap) och FOV-kick när du springer med loot.
- Mynt som flyger in i kassan och en kassasiffra som räknar upp.
- Gnistregn på piedestalen när loot landar och en pulserande COLLECT-platta.
- Nya ljud: kassaapparat, slap, whoosh, larm, fanfarer.

**Monetisering (allt med känt innehåll, inga slumpköp, inga falska timers):**
- Nya passes:
  - **💎 VIP** (299 R$): +25 % cash, VIP-skylt över huvudet och chattagg.
  - **🧲 Auto Collect** (149 R$).
  - **🧤 Quick Hands** (99 R$): stjäl utan att hålla inne.
  - 2x Cash, 2x Treadmill och Mega Lock finns kvar.
- Nya produkter: **🚀 Mega Speed Pack** (129 R$, 60 min) och **🏦 Cash Vault** (199 R$, 3 h). "BEST VALUE" räknas fram ur riktiga mängder per Robux.
- **🎁 Gåvor**: alla passes kan ges bort till någon på servern (egen gåvoprodukt per pass). Lämnar mottagaren innan köpet är klart får köparen passet. Det står i dialogen.
- **Kontextuella erbjudanden**:
  - fångad av en vakt du är för långsam för → Speed Pack
  - försöker uppgradera utan pengar → Cash Bag
  - max ett var 4:e minut, aldrig när en meny är öppen, alltid med "NO THANKS"
- **Premium**: +10 % cash för Roblox Premium-medlemmar (ger också Premium Payouts).
- Köp och gåvor annonseras för servern ("X unlocked 💎 VIP!").
- Ny shop: sektionerna PASSES (för alltid) och BOOSTS (engångs), större kort och 🎁-knapp på passen.
- Ops-workflowet skapar nu även gåvoprodukterna.

### Ljusfix (skärmdump 11 okt: överexponerat)
- Ljuset ligger nu nära Robloxs standard:
  - ljusstyrka 2 i stället för 3 och lite negativ exponering
  - normal omgivningsfärg och inget dis
  - bloom bara på den starkaste neonen (tröskel 2)
  - mindre färgförstärkning
- Torget och entréhallen är ljusgrå i stället för vita (vita studs bländade i solen).
- "Slow Mode"-texten sitter nu bredvid strömbrytaren (den hamnade uppe vid Store).

### Omdesign efter genre-videon (Steal From The Rich), 609 kontroller i Roblox
- **Rich Street är en korridor med zoner i rad.** Man springer rakt igenom zon efter zon (längre bort = rikare):
  - stor port med namnet (syns åt båda hållen) och egen färg och golv
  - den rika personen själv som stor figur (Grandpa med keps, piraten med trekantig hatt, Gold Tycoon med hög hatt och guldkedja …)
  - tre ställ med loot på varje sida av gången, vakter som patrullerar och temarekvisita längs väggarna
  - smoke-testet kontrollerar att springvägen genom alla zoner är fri från hinder
- **Baserna är palats:**
  - limegrön studs-gård (LEGO-stil)
  - mörk gång med lysande plattor i basens färg
  - upphöjd scen längst in med palatsfasad (pelare, banderoller, guldgavel) där föremålen står tätt
  - löpband och COLLECT-platta på gården
- **Hela världen** har studs, starka mättade färger och klart ljus utan dis. Rullbanden, stadssiluetten och trottoarerna är borttagna.
- **Föremålen** är 1,5x större på ställ och podier. Legendary och Mythic brinner (eld-aura). Etiketten visar som i videon: sällsynthet, namn, "+$X/s" och odds ("1 in 222").
- **HUD:en följer videons layout:**
  - vänster: Store, Event (🎃, öppnar godis-spåren) och Index som app-ikoner, plus en Slow Mode-strömbrytare
  - nere till vänster: Friend Boost, 👟 speed, 🍬 godis och 💵 cash som text med kontur, utan rutor
  - överst: "You earn $X/Day offline! 😈"
  - nere till höger: lås-knapp och "🌙 in 1m 11s" (riktig tid till nästa event)
  - uppe till höger: 🌈 Trails och 🎵
  - THE RICHEST är en guldrad under topptexten
  - typsnittet är runt och fett, som i genren

### Efter speltest på iPhone (skärmdumpar 11 okt)
- **HUD:en städad:**
  - Hela HUD:en skalas ner på telefon (cirka 20 % mindre).
  - Cash och inkomst sitter i ett kort, med speed i en liten pill under.
  - 4 mindre knappar (SHOP, INDEX, LOCK, SLOW). Musiken är en liten 🎵-ikon bredvid kassan.
  - "+SPEED"-chippet är borttaget (det krockade med kronbaren).
  - Kronbaren syns bara när någon faktiskt är THE RICHEST.
  - Checklistan till höger och den stora tipstexten är ersatta av **en** kompakt uppdragsrad nere i mitten ("STEP 2/4 • 💰 STEAL loot at Grandpa's Garage"), med guldpilen kvar.
  - Drop/Slap är större för tummen.
- **"Upgrade Treadmill"-prompten poppar inte längre upp när du tränar**: skylten är flyttad och räckvidden är kortare. Smoke-testet mäter avståndet.
- **Baserna är öppna**:
  - Låga, ljusa murar (4,5 studs i stället för 12 tegel) och en osynlig barriär ovanpå, så det går inte att hoppa in och låset håller.
  - Entrébåge med namnskylt och "FREE BASE" på lediga baser.
  - Runda podier och mörkare "hyllband" under varje rad.
  - Torget är inte längre en korridor mellan murar.
- Föremålen visar stor grön inkomst ("+$35/s") synlig på längre håll.
- Bänkarna är borta ur gången och man springer igenom pumporna.
- Kameran börjar längre bak vid varje spawn.

### Från referensspelet (den här omgången, 567 kontroller i Roblox)
- **Cash-pickups längs Rich Street** (och på rullbanden): spring igenom för 4 s av din inkomst (minst $25). De kommer tillbaka efter 20 s.
- **🌈 TRAILS SHOP** på torget vid porten till Rich Street:
  - 6 spår för cash: Sparkle $5K, Neon Blue $500K, Fire $50M, Money Rain $2B, Lightning $100B, Galaxy $5T.
  - 2 Halloween-spår för godis: Pumpkin 150 🍬 och Ghost 400 🍬.
  - **Rainbow Trail** som pass (79 R$).
  - Köp, sätt på och ta av i menyn.
- **👥 Friend Boost**: +10 % cash per Roblox-vän på servern (max +30 %). Syns i inkomstpillret.
- **🎃 Halloween-säsong** (1 okt–3 nov, slås av och på automatiskt varje år):
  - pumpor vid alla entréer och på torget, spindelnät på baserna, fladdermöss över stan, spöken på Rich Street
  - pickups ger 🍬-godis, och vissa är pumpor värda 5
  - 🍬-pill i HUD:en
- "**SAFE ZONE**" på golvet vid varje basentré.
- Uppgraderingsskyltarna visar nästa mål: "UPGRADE PLOT · Lv 3 → 4 · $1.2K".
- Siffror som flyger upp i världen: "+⚡" ur dig på löpbandet, "+$" och "+🍬" vid pickups, och inkomst ur varje föremål på din plot var 3:e sekund.
- **Välkommen tillbaka-kort**: vad du tjänat medan du var borta och vad din plot drar in per dag offline.
- STOLEN!-kortet säger "YOU STOLE FROM MUSEUM OWNER!" (eller "YOU ROBBED <namn>!").
- Ett litet "⚡ +SPEED R$29"-erbjudande bredvid pillren. Det är det enda på HUD:en, som förblir ren.
- Admin: `!candy 500` ger godis för att testa godis-spåren.

## Hur du testar (iPhone)
0. **Nytt efter omdesignen:**
   - Gå ut genom porten "RICH STREET" och spring rakt fram genom zonerna: Grandpa → Influencer → Pirate … Varje zon har port, rik person, ställ på båda sidor och vakter.
   - Hemma: limegrön gård, gången med lysande plattor och föremålen på scenen framför palatsfasaden.
   - HUD:en ska likna videon: ikoner till vänster, stats nere till vänster och "You earn …/Day offline!" överst.
1. Gå med: musiken startar och ljuset är gyllene. Checklistan uppe till höger visar 4 steg.
2. Ställ dig på löpbandet och **släpp tumspaken**: gubben springer, bandet rullar, speed ökar och första bocken kommer.
3. Gå ut ur basen och ställ dig på det **blå rullbandet** (pilar mot Rich Street), så åker du snabbt mot valven. Det **gula** tar dig hem.
4. Titta in i valven: varje valv har sitt tema. Vakterna går med armar och ben.
5. Stjäl: skak, whoosh, jaktmusik och RUN!!. Vakten larmar (summer, röd blixt) och sträcker armarna efter dig. Spring hem: STOLEN!-kort och gnistor på piedestalen.
6. Stå på COLLECT: mynt flyger upp i kassan och siffran räknar upp.
7. Försök uppgradera utan pengar: efter en sekund kommer ett Cash Bag-erbjudande med "NO THANKS".
8. Shop: 6 passes och 4 boosts, "BEST VALUE" på de större boostsen. 🎁-knappen öppnar en lista med spelarna på servern.
9. Testa events: skriv `!event GoldRush`, `!event GuardStrike` eller `!event CashFrenzy` i chatten. Bannern med nedräkning ska synas under kronbaren.
10. Från referensspelet:
    - Spring längs Rich Street genom guldmynten: "+$" flyger upp och 🍬 räknas upp (Halloween).
    - TRAILS SHOP vid porten: köp Sparkle ($5K), spring och se spåret bakom dig.
    - Pumporna, spindelnäten och "SAFE ZONE" på golvet vid din entré.
    - Uppgraderingsskylten visar nivå och pris.
    - Lämna spelet i några minuter och gå med igen: välkommen tillbaka-kortet ska visas.
11. Med en kompis:
    - Kronan växer efter några minuter och bountyn visar t.ex. "(x1.6)".
    - Stjäl från varandra: den som blir bestulen ser den röda pilen och "GO GET THEM!".
    - 👑/💎-taggar syns i chatten.

## Saknas / att göra
- Ingen människa har spelat det här än. Testet täcker logiken, men inte känslan, prestandan på äldre telefoner eller hur UI:t ser ut på just din skärm.
- Pass-ikonerna är Robloxs standardbild (egna ikoner kräver bilduppladdning).
- Fas C: rebirth, dagliga belöningar och quests, likes, fler topplistor.
- Fas D: coup i slow motion, kosmetiska kronor, gruppbonus, promokoder.
- Grenen `claude/smoke-baseline` kan raderas på GitHub (det gick inte härifrån).

## Ops (`tools/ops/ops-log.md`)
- Ändra eller lägg till något i `Config/Products.luau` → pusha en branch `ops/<namn>` → workflowet skapar det som saknas, synkar priser och skriver tillbaka ID:n → merga till main.

## Nyckelbehörigheter (RTR_PUBLISHING_KEY, alla fungerar)
`universe-places: write`, `universe.place.luau-execution-session: write`, `game-pass: read + write`, `developer-product: read + write`, `universe.place: write`.

## Balans (tools/simulate, aktiv spelare)
Museum Owner ~7 min, Gold Tycoon ~11 min, Mega Yacht ~29 min, Tech Billionaire ~65 min, THE BILLIONAIRE ~3 h. Rullbanden gör det i praktiken lite snabbare tidigt.
