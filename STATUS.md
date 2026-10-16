# STATUS – Dig Out! (fängelseflykt-grävspel)

Senast uppdaterad: 2026-10-16 · Milstolpe: **M5 POLISH** (M1–M4 publicerade)

Det gamla spelet (Rob the Rich!) är raderat från koden och arkiverat i git-taggen
`archive/rob-the-rich` (sista commit `374cd1d`). Ny spelardata sparas i `DigOut_v1`, så gammal
data blandas aldrig in.

## ✅ Klart

### Steg 0 – nystart
- All Rob the Rich-kod, config, tester och dokumentation borttagen. Verktygen är kvar (rokit,
  StyLua, Selene, Lune, deploy/ops-workflows, smoke-test, ProfileStore, RateLimit, UI, Panel,
  Sound, Shake). Admin-inställningarna (ägaren/gruppens rank 254) är kvar.
- Ny ProfileStore `DigOut_v1` med `Version`-fält + migreringsfunktion.
- Nytt Rojo-projekt (`DigOut`), ny CLAUDE.md, README och den här filen.
- Ops-workflow: sätter gamla pass/produkter till "off sale", byter namn/beskrivning på
  upplevelsen, Max Players = 12 och skapar arkivtaggen (se checklistan nedan).

### M1 – spelbar
- **Fängelset byggs i kod:** cellblock med 12 celler (två rader om 6 mot en korridor), varje cell
  med säng, toalett, handfat, affisch, lampa, gallerdörr och skylt med namn + djup. Korridor med
  gula golvlinjer → **Common Room** (Workshop, Commissary, The Fence med NPC-diskar, bord, klocka,
  högtalare) → **Yard** (staket, vakttorn med strålkastare, strålkastare på stolpar, **Rubble Dump**,
  **Gym** med 3 stationer).
- Varje spelare får en egen cell när hen går in. Cellens bakvägg är början på din tunnel.
- **Grävning:** voxelrutnät 18 × 12 × 600 block (2 studs). Zon 1–3 är öppna: Plaster → Brick →
  Concrete (djupare block är "för hårda – kommer snart"). Varje zon har egen färgpalett, material,
  ljus-tint och svårighet. Vid zon 2 och 3 bryter du dig in i en färdigbyggd kammare (Old Boiler
  Room, Forgotten Bunker) → banner "NEW ZONE UNLOCKED", konfetti, skakning och chattmeddelande till
  hela servern.
- **Slag:** stor PUNCH-knapp (tryck = ett slag, håll = autoslag), auto-sikte på blocket närmast
  kamerans riktning, rutnät som visar exakt vilka block som träffas, armslag, skakning,
  träff-blink, sprickor på skadade block (3 steg), smulor (små kuber) och ljud.
- **Penslar:** 1 block → kors (5) → 3×3 (9). (Stort kors och 5×5 finns i config, öppnas senare.)
- **Dammsugare:** håll VACUUM – smulor och grushögar sugs in i dig med virvel-effekt. Gruset hamnar
  i ryggsäcken (servern räknar).
- **Ryggsäck:** när den är full nekas slag och en stor röd ruta + gul ledstråle visar vägen till
  Yard-dumpen. Dumpa = Noodles 🍜.
- **Fynd:** "malmblock" (mörka med glödande ådra i raritetens färg) syns så fort de blottas. 12 fynd
  i 3 rariteter (Common/Uncommon/Rare) för zon 1–3. Sälj hos **The Fence** (sälj allt / ett i taget).
- **Butiker** (ProximityPrompt vid disken, inga butiksknappar i HUD): Workshop (verktyg: Spoon,
  Shovel, Pickaxe + penslar), Commissary (ryggsäck, fyndplatser, dammsugarräckvidd).
- **Gym:** se "Fängelse-uppdateringen" nedan (det gamla LIFT-gymmet är borttaget).
- **HUD:** Noodles, styrka + slagkraft, ryggsäcksmätare, fyndplatser, zon + djup, notiser.
- **Kamera:** tredje person; i tunneln axel-vy och kortare zoom så väggar inte skymmer, pannlampa
  och zonens färgton.
- **Spara/ladda:** allt sparas (tunneln komprimeras RLE + base64, en ny tunnel ≈ 50 tecken).
- **Säkerhet:** servern kontrollerar varje slag (blocket finns, är blottat, inom räckhåll,
  slagtakt, plats i ryggsäcken). Att radera block på klienten ger ingenting.
- **Admin (för iPhone-test):** ADMIN-knapp uppe till höger: +1M/+1B Noodles, styrka 1K/100K,
  hoppa till zon 2/3, fyll ryggsäck, stresstest-grävning, återställ tunnel, prestandamätare
  (FPS, antal voxel-delar, smulor), återställ all data. Samma kommandon i chatten: `!noodles 1e6`,
  `!strength 500`, `!zone 3`, `!resettunnel`, `!stress`, `!fill`, `!reset`.

### M2 – fängelset
- **Dag/natt** för hela servern: DAG 3 min, NATT 5 min (Config/Cycle). Stor klocka uppe till höger
  med nedräkning. 10 s före natten: siren + "LIGHTS OUT!"-nedräkning i mitten av skärmen. Vid
  natt: alla som inte är i sin egen cell/tunnel förs tillbaka till cellen, gallerdörrarna glider
  igen och låses. Himlen och ljuset tonar mellan dag och natt (solnedgång).
- **Nattgrävning ger +25 % fynd** (extra överraskningsfynd i vanliga block).
- **Zon 1–6 öppna:** Plaster, Brick, Concrete, Reinforced Concrete, Clay & Pipes, Sewer, med
  kamrar vid varje zongräns (Rebar Vault, Pipe Junction, Old Sewer Canal …).
- 27 fynd totalt, nu även **Epic** (zon 4–6). Fler verktyg (Jackhammer, Drill), penseln Big Cross,
  större ryggsäckar, fler fyndplatser, större dammsugare.
- **Samlingshylla** i cellen (ovanför sängen): varje zon har en rad, saknade fynd visas som "?".
  **Komplett zon-set = +10 % Noodles för alltid** + meddelande till hela servern.
- **Mess Hall** söder om Common Room (långbord, serveringsdisk, kock, meny). Buffar kommer i M4.
- Admin: ☀️ Day / 🌙 Night tvingar fram fas, Zone 4 / Zone 6.

### M3 – PvP (natten är säker, dagen är farlig)
- **Yard Brawl:** på dagen slår PUNCH-knappen närmaste spelare framför dig (röd kontur) när ingen
  vägg är inom räckhåll. Säkra zoner: celler/tunnlar, butiksdiskarna, gymmet och dumpen. Slapstick-
  knuff, ingen skada/blod, en STAMINA-mätare. Starkare = hårdare slag. Stamina 0 = knockout:
  yrsel-stjärnor, du tappar 30 % av gruset i ryggsäcken + ditt dyraste fynd som en hög på marken
  som vem som helst kan plocka upp. 8 s skydd efter knockout.
- **Stash-kista** i varje cell: "Open Stash" → lägg in alla fynd / ta ut alla (12 platser).
- **Cellräder:** på dagen kan andra gå in i din cell och hålla **STEAL** vid din kista för att ta
  ETT fynd (det dyraste). Tjuven blir långsammare och lyser guld, och får en gul stråle hem. När
  tjuven når sin egen cell är fyndet hens (meddelas hela servern). Slå tjuven = fyndet går
  tillbaka till kistan. Kommer natten tar vakterna tillbaka det. Sålda fynd är alltid säkra.
- **Försvar** (Commissary): Lock (Padlock/Deadbolt/Vault Lock: 5/8/12 s att dyrka), Trap (såpa –
  tjuven halkar en gång per dag), Alarm (du får larm + röd stråle mot tjuven).
- **TOP DOG:** rikaste spelaren på servern bär en guldkedja, syns på TOP DOG-tavlan i Common Room
  och får "YOU ARE TOP DOG" i HUD:en.
- **LONGEST TUNNEL-tavla:** djupaste tunnlarna på servern + all-time topp 5 (sparas globalt).

### M4 – djupet
- **Zon 7–10 öppna:** Bedrock, Crystal Cave, Magma, Ancient Ruins (alla med kammare, egna färger
  och ljus). **Alla 9 rariteter** finns nu: 58 fynd, upp till Secret, Cosmic och Divine
  ("The First Golden Spoon" 🥄 i Ancient Ruins). Nya verktyg: Laser, Plasma Cutter, Quantum Fist;
  fler ryggsäckar, fyndplatser, dammsugare och två nya gymstationer.
- **FLYKT (rebirth):** när du slagit igenom sista lagret (600 m) dyker en stor **ESCAPE!**-knapp
  upp → filmsekvens (strålkastare, flygtur över muren) → "...but the guards caught you!" →
  **High Security**, sedan Island Prison, Space Prison. Varje flykt ger permanent
  +50 % slagkraft, gym och Noodles. Tunnel, Noodles, styrka och verktyg nollställs; djuprekordet,
  samlingen, försvaren och dekorationerna sparas. Tunneln får fängelsets färgton.
- **Vaktinspektioner** på natten: fotsteg + ljus under dörren + stor **HIDE!**-knapp i 5 s
  (affisch över hålet, du hoppar i sängen). Åkt fast = du förlorar osålda fynd i fyndplatserna
  (aldrig Noodles eller framsteg).
- **Snitch** (hos Black Market): betala Noodles för att tipsa vakten om en spelare → garanterat
  besök nästa natt. Den som blivit tjallad kan **BRIBE** vakten.
- **Server-events** (slumpas var 15–25 min): BLACKOUT (alla väggar 2x svagare i 2 min), RIOT
  (dörrarna står öppna på natten), INSPECTION DAY (var i cellen med tom ryggsäck → bonus),
  **TREASURE RACE** (en skatt på samma djup i varje tunnel, markerad; först fram vinner).
- **Laundry** (i Mess Hall): fängelseuniformer i 7 färger + Fire/Ice/Toxic/Royal-fists (spår).
- **Mess Hall:** måltider som gäller till morgonen: Hearty Stew (+25 % slag), Lucky Noodle Bowl
  (+30 % fynd), Prison Coffee (15 % snabbare slag).
- **Black Market** (tält i Yard-hörnet): 3 varor per dag som byts 00:00 UTC (nedräkning syns):
  Dynamite, Lucky Charm, Protein Shake, Rubble Magnet, Iron Gloves.
- **Dekorationer:** köp i Workshop (💡 DECOR-knappen) – lampor, räls, gruvvagn, skylt, tunna,
  flagga, troféstativ (visar ditt finaste fynd). Placera med 💡-knappen i din tunnel. Alla ser dem.
- **Dagliga belöningar** (streak upp till 7 dagar, dag 7 ger dynamit), **speltidsgåvor** var
  10:e minut, **grupp-bonus** +10 % Noodles för medlemmar, **Cellmate** gräver när du är offline
  (max din lediga ryggsäcksplats, halva värdet).
- **Monetisering** (STORE-disken i Common Room, kända innehåll, ingen slump):
  pass: 2x Noodles (199 R$), Auto-Vacuum (149), Huge Backpack (149), 2x Strength (199),
  VIP Prisoner (299: guldnävar, [VIP]-chattagg, VIP-hörnet i Common Room).
  Produkter: Dynamite (49), Noodle Crate (39) / Noodle Truck (149) – exakt mängd visas i butiken,
  Instant Backpack Empty (25). 🧨-knappen syns i din tunnel.
- Admin-panelen har nu: Zone 10, Bottom→Escape, Inspect me, Blackout, Riot, Inspection,
  Treasure, 🧨 x5.

### M5 – polish
- **Tutorial** första minuten: en instruktion i taget + en gul stråle dit du ska: PUNCH väggen →
  VACUUM gruset → DUMP i Yard → SÄLJ hos The Fence (hoppas över om du inte har fynd) → KÖP en
  uppgradering i Workshop. Sparas, så den visas bara tills den är klar.
- **Musik:** licensierad spellista (Heist Time m.fl.) + jakt-musik medan du bär ett stulet fynd.
  Music-switchen till vänster stänger av.
- **Gnistor** vid varje slag (direkt, innan servern svarat) för mer "punch".
- **Fotoläge** för ikon/thumbnails: ADMIN → 📸 Photo döljer allt UI i 15 s.
- **Analytics** (Creator Hub → Analytics): onboarding-tratt (Joined → Punch → Vacuum → Dump →
  Sell → Upgrade → TutorialDone), zon-progression, försäljningar, uppgraderingar och sessionslängd.

### Ny HUD (inspirerad av din referensbild)
- **Vänster:** glansiga ikonrutor med liten text över nederkanten och röda "!"-bubblor:
  🛒 **Store** (Robux-butiken), ⚡ **Event** (syns bara under ett event, visar nedräkningen),
  📖 **Index** (samlingsalbumet – bubblan räknar nya fynd), 🎁 **Gift** (minuter till nästa
  speltidsgåva). Under dem en liten **Music**-switch (som "Slow Mode").
- **Nere till vänster:** siffror utan rutor, bara ikon + färgad text med tunn kontur:
  🍜 Noodles (störst), 💎 fynd, 🧱 ryggsäck (blir röd när den är full), 💪 styrka + ⚡ slagkraft,
  och en liten boost-rad (TOP DOG, flykt-multiplikator, grupp-boost, aktiva buffar).
- **Nere i mitten:** hotbar-rutor (mörka, genomskinliga) för 🧨 Dynamite (antal) och 💡 Decor –
  bara i din tunnel.
- **Nere till höger:** genomskinliga runda knappar med tunn vit ring, som hoppknappen: stor
  👊 PUNCH, 🌀 VACUUM ovanför. Klockan som smal text: "🌙 in 2:31".
- **Höger:** 🛠️ Admin-ruta (bara admins).
- **Allt annat smalare:** tunnare konturer och text överallt, alla menyer/butiker har ny stil
  (glansigt färgat huvud, liten röd X-knapp, ljus kropp, tunna rader), smala notiser, smal
  "BACKPACK FULL"-pill, mindre fyndkort, smal stamina-mätare och tutorial-rad.
- Obs: Store-knappen i HUD:en är Robux-butiken (som i referensen). Fängelsebutikerna (Workshop,
  Commissary, The Fence m.fl.) öppnas fortfarande bara vid disken.

### Fängelse-uppdateringen (ljus, försäljare, gym, väggkänsla)
- **Ljus:** grått och mörkt. Avmättad färgkorrigering, grå dimma, molntäcke, kalla lysrör.
  Golv, väggar, galler och skyltar i betong/stål (inga glada färger). Natten är riktigt mörk.
  Zon 1 är nu grå betong.
- **Försäljarna är riktiga fängelseplatser** (diskarna öppnas fortfarande med prompten):
  🔨 **TOOL CRIB** (verktygsförråd bakom galler), **COMMISSARY** (kiosklucka med galler),
  **THE FENCE** (fånge vid ett hörn), 📞 **VISITATION** (Robux-butiken: telefonbås med glasruta),
  **LAUNDRY** (tvättmaskiner) och **BLACK MARKET** (ett hål i stängslet). Dumpen heter **RUBBLE**.
- **Nytt gym (YARD GYM) – helt omgjort och roligare:** 7 stationer längs Yard där du lyfter
  löjliga saker över huvudet: 🚽 Toilet Curl (+1), Mattress Stack (+3, 100 💪), Vending Machine
  (+10, 600 💪), Sleeping Guard (+40, 4 000 💪), Washing Machine (+150, 25 000 💪), Warden's Desk
  (+600, 150 000 💪), Prison Bus (+2 500, 1 M 💪). En timing-mätare sveper fram och tillbaka: tryck
  **LIFT** när nålen är i det gröna = GOOD, i det guldiga = **PERFECT** (dubbelt + combo upp till
  x2), utanför = OOF! Tyngre saker = snabbare nål och mindre zon. Servern räknar nålen själv (med
  hänsyn till ping), så det går inte att fuska.
- **Väggkänsla som i videon:** bakväggen är en hel slät betongyta; trådram-kuber visar vad du
  träffar – **vita** = tar skada, **röda** = går sönder på nästa slag. Skadade block rycker till och
  får tunna mörka sprickor. Trasiga block ramlar ut som nästan hela kuber som studsar och **lägger
  sig i högar** på golvet, med dammpuffar. Dammsugaren har ett munstycke i handen med vita
  luftstrimmor och suger in kuberna som krymper in i munstycket.
- Emoji som Roblox inte kan visa (rutor) är utbytta mot säkra (🧱, 💰, 💡 m.fl.).

### Finputs: inga flimrande väggar, riktigt slag, snygga fynd-notiser
- **Flimmer borta:** väggar och delar som låg i samma plan och "slogs" om att synas (z-fighting) är
  fixade överallt – bl.a. där Common Room-väggen gick in i cellblocket, målade väggband, sängar,
  galler, glasrutor, soffor, gymskyltar, staket och NPC-kepsar. Röktestet i CI letar nu automatiskt
  efter överlappande ytor och stoppar publiceringen om det finns några.
- **Slaget syns:** hela kroppen slår – laddning bakåt, överkroppen vrids, lutar sig in, raka armen
  ut, andra armen i gard; växlar höger/vänster. **Andra spelare ser också dina slag.** Varje träff
  ger en vit chockring på blocket, ett dammpuff och blocket rycker till direkt (innan servern svarat).
- **Fynd-notiser:** smala mörka kort uppe till höger med blank raritetsruta, liten raritetstext, namn
  och värde. Glider/tonar in, staplas (max 3) och tonar ut; Rare+ får ett ljussvep. Samma stil för
  skatt och belöningar.
- **Notiser** är smala mörka "piller" med färgad prick, och zon-bannern är en tunn filmisk remsa
  (hårfina linjer, bred titel, liten undertext) som tonar in och ut.

### Kvalitetslyftet: riktiga figurer och detaljerade föremål överallt
- **Riktiga avatarer för alla NPC:er:** vakter, kock, försäljare, besökare och medfångar är nu
  riktiga R15-figurer med kläder från katalogen (vaktuniform med keps och bälte, kockrock och
  kockmössa, orange fångdräkt med olika frisyrer och hudtoner). De har tomgångsanimation. De
  patrullerande vakterna går med gånganimation och har en ficklampa i handen.
- **Spelarna bär riktiga fångkläder** (skjorta + INMATE-byxor) över sin egen hudfärg och sina
  accessoarer, i stället för orangemålade kroppsdelar.
- **Cellen:** ny säng (stålram, madrass med kant, vikt filt, kudde), porslinstoalett med cistern
  och spolknapp, ett riktigt handfat.
- **Common Room:** runda fängelsebord i stål med fastsvetsade pallar (schack och kortspel), en
  TV-hörna (tjock-TV på vagn med PRISON NEWS och nyhetsrad, VCR, antenner, två slitna soffor och
  en matta).
- **Affischer i papper** överallt: färgtoning, ram, lätt sned och fasttejpade.
- **Smuts och skuggor** i alla rum: mörka band vid golv och tak, mörkare golvkanter.
- **Yard:** buskar och träd i planteringar i stället för gröna bollar.
- **Gymmet:** porslinstoalett att lyfta och en upplyst snacksautomat (SNAX, hyllor med snacks
  bakom glas, knappsats och myntinkast). Samma automat står i Common Room.
- **Testa på iPhone:** titta på vakterna (de ska gå och svänga med armarna) och på din egen
  gubbe (orange skjorta och INMATE-byxor). Gå till TV-hörnan och borden i Common Room, och kolla
  sängen och toaletten i cellen.
- **Saknas:** flera gym-föremål (tvättmaskin, buss, skrivbord) och borden i Mess Hall är kvar i
  den enklare stilen.

### Kritikergenomgången (hela spelet)
Jag gick igenom hela spelet: kod, världen (renderad) och balansen. En separat granskning letade
buggar. Åtgärdat:
- **CRIT-slag:** 8 % av slagen är kritiska och slår 3× hårdare (servern slumpar). Blocket blixtrar
  varmt, kameran sparkar, "CRIT!" poppar ut ur väggen med eget ljud. Balansen är omräknad
  (`tools/tune write`): flykt 2:03 för gratisspelare, alla zoner ≤ 15 slag/block.
- **Tydligt mål hela tiden:** under "Record" finns en tunn mätare mot nästa zon ("8m to BRICK")
  i nästa zons färg. Den studsar när du kommer in i en ny zon.
- **"Uppgradering redo":** första gången du har råd med nästa verktyg, pensel eller ryggsäck glider
  ett grönt kort in ("Pickaxe is ready · Tool Crib · 🍜 60"). Ett i taget, aldrig tjat.
- **WORK DETAIL – dagliga jobb:** ny ruta 📋 Jobs uppe till vänster (där Event-rutan satt;
  händelser syns redan i kortet högst upp). Tre jobb per dag – lätt, medel, svårt – t.ex. "Break
  300 blocks", "Land 20 CRIT punches", "Dig 10m deeper", "Hit 20 PERFECT lifts", "Sell 5 finds".
  Färdiga jobb ger ett kort och en grön siffra på rutan. Hämta belöningen i panelen; alla tre ger en
  bonus. Belöningarna är kända Noodles-belopp efter din zon och byts kl 02:00 svensk tid.
- **Yard med liv:** picknickbord, en tunna med eld och bänkar runt (varmt ljus på natten),
  fängelseodling ("PRISON GARDEN – DO NOT DIG HERE"), tvättlina med fångdräkter, telefonkiosk
  ("COLLECT CALLS ONLY"), däckstapel, koner, målad "RUBBLE DUMP ▼"-markering och grästuvor.
- **Buggar som fixats (18 st):**
  - Efter ESCAPE kunde du fastna i sten. Nu flyttas du till cellen.
  - "Reset" medan du bar ett stulet fynd gav dig fyndet direkt. Nu går det tillbaka.
  - Inspektion när du är djupt i tunneln: du får nu 15 s **plus gångtiden** tillbaka (max 75 s),
    och händelsekortet visar en nedräkning "GUARD INSPECTION · 23s".
  - Vakten "såg ett hål" efter en flykt fast väggen var hel. Fixat.
  - Jordbävningen gjorde inget efter en flykt. Fixat.
  - Gymmet tog bort tjuvens långsamhet. Nu kan du inte lyfta när du bär ett stulet fynd eller
    ligger i sängen.
  - Dynamiten från daglig streak syntes som "BUY". Fixat.
  - "Instant Backpack Empty" kunde köpas med tom ryggsäck. Nu nekas det, och PAYDAY räknas med.
  - BRIBE låg exakt ovanpå ESCAPE. ESCAPE syns nu bara i din tunnel och inte när du lyfter, och
    den kommer tillbaka om servern inte svarade.
  - "Sleep" fungerade från hela tunneln (en gratis teleport). Nu bara vid sängen.
  - Ett nekat slag kunde rulla upp tapeten, och dynamit fungerade från sängen. Fixat.
  - Skattens pris kunde göra Stash för full. Nu ges Noodles om den är full.
  - Angivna (snitchade) fångar får nu alltid besöket först. Inget beslut tas efter natten.
  - Gränser för hur ofta GymStop, Vacuum och TourDone kan anropas.
  - Ett andra slag i rad kortades av för tidigt (det gällde när du blev slagen). Fixat.
  - Toaletterna tog inte grus under RIOT men prompten syntes. Nu stängs den.

### Rundtur för nya spelare, inga pilar, lugnare varningar, levande Mess Hall
- **Ingen pil eller stegruta under spelet längre:** guidepilen till dumpen och den gamla
  steg-för-steg-rutan är borta.
- **Rundtur första gången du spelar:** kameran åker runt och visar det viktiga – din vägg
  (gräva), Rubble Dump, The Fence, Tool Crib, Commissary, gymmet, Mess Hall, natten/vakterna
  och flykten – med ett smalt kort längst ner (titel, en mening, prickar, "Next ›" / "Skip").
  Visas en gång (sparas i profilen). ADMIN → 🎬 Tour spelar den igen.
- **Full ryggsäck tjatar inte:** varningen är ett litet mörkt chip med röd prick ("Backpack full
  · dump it in the Yard") som syns i 5 s när läget ändras, inte vid varje slag. Servern skickar
  varningen högst var 20:e sekund. Den stora röda remsan är borta.
- **Mess Hall:** röd/kräm kakelgolv, målade nedre väggar med guldlist, sju fönster med galler och
  dagsljus (dimmas på natten), takfläktar som snurrar, rör, brickor med gröt/mugg/bröd på alla
  bord, brickställ, kök med kyl, spis och hyllor med burkar, ånga från grytorna, soptunnor,
  hink + "CAUTION WET FLOOR", golvbrunnar, affischer ("NO SECONDS", "MYSTERY MEAT MONDAY" …),
  klocka, ventiler, brandsläckare och en vakt vid dörren.
- **Common Room:** anslagstavla med lappar ("LOST: SPOON", "MISSING: 1 WALL" …),
  vattenfontän, brandsläckare, ventiler, golvbrunnar och städhink vid Mess Hall-dörren.

### Inspektion, säng, Mess Hall-dörren, banner, vaktbubbla, VIP
- **Mer tid vid inspektion:** 15 sekunder (förut 5) från fotstegen till att vakten står vid dörren.
- **Gömma sig är inte längre en skärmknapp:** gå fram till sängen och **håll** "Sleep" (1,2 s) för
  att lägga dig, och gå fram till väggen och håll "Cover the hole" (0,8 s) för att rulla ner
  tapeten. HIDE-knappen vid inspektion är borta – du måste själv hinna till sängen och väggen.
  Bara din egen cells prompter syns. Rör joysticken eller håll "Get up" för att kliva upp.
- **Dörren till Mess Hall var blockerad:** det fanns ett hål i golvet i dörröppningen och den
  målade väggranden gick tvärs över öppningen. Båda fixade, och röktestet kollar nu att dörrarna
  till Mess Hall och Yard har golv och är fria.
- **Zon-bannern** ("CONCRETE – NEW ZONE UNLOCKED") försvinner nu säkert efter ~3,5 s.
- **Vakternas pratbubbla:** en liten halvgenomskinlig skylt i världen, storleksatt i studs så den
  krymper med avståndet (täcker aldrig skärmen), utan pil och utan skrivmaskinseffekt.
- **VIP-loungen** är ombyggd: mörka trähalvväggar med rökfärgat glas och guldlister, guldstolpar,
  röd matta med guldkanter från ett sammetsrep (VIP ser repet avhakat och går rakt in),
  "★ VIP LOUNGE ★" i guld på svart skylt, skinnsoffor med guldkuddar, marmorbord med
  champagne, minibar med flaskor, krukväxter, tavla och en kristallkrona med varmt ljus.

### Grävningen stoppas aldrig + gömställe + nya händelser
- **Full ryggsäck stoppar inte längre grävningen:** du kan slå vidare, gruset blir liggande på
  golvet (värt något först när du har plats igen) och rutan varnar. Ryggsäckarnas storlek är
  tillbaka som förut (Pockets 20, Sock 60 … Garbage Truck 8 000) – 3× större var för mycket.
- **Fulla fyndplatser stoppar inte heller:** nya fynd hamnar i din Stash-kista (om det finns plats,
  annars smulas fyndet sönder) och du får en varning.
- **"Håll VACUUM"-rutan** visas inte längre om du har Auto-Vacuum (då finns ingen knapp).
- **Inga gratislampor i tunneln:** arbetslamporna som sattes ut automatiskt är borta. Ljus köper
  du som Decor och placerar själv (pannlampan finns kvar).
- **Gömställe i cellen:**
  - **Tapeten** (förut den platta "DREAM BIG"-skylten) är nu en stor väggbonad med solnedgång,
    hav, palmer och "DREAM BIG · NOTHING TO SEE BEHIND HERE" på en trärulle. Knappen 🖼️
    **Cover/Uncover** rullar ner/upp den när du vill (alla ser den). Slår du på väggen rullas den upp.
  - Knappen 🛏️ **Sleep** lägger dig **liggande i sängen** (på rygg, huvudet på kudden) när du vill.
    Tryck **Get up** eller rör joysticken/hoppa för att kliva upp. Inga slag från sängen.
  - **Inspektion:** du klarar dig bara om du ligger i sängen OCH hålet är täckt (eller du inte har
    grävt än). HIDE-knappen under inspektionen gör båda på en gång. Ligger du i sängen men hålet
    syns: "The guard spotted the hole in your wall!".
- **Händelser:** var 5–8:e minut (förut 15–25), aldrig samma två gånger i rad. Nya:
  💎 GOLD RUSH (mycket fler fynd), 🍜 PAYDAY (dumpa/spola ger 2×), 🌋 EARTHQUAKE (skakningar och
  ett 20-tal block bryts loss gratis längst fram i allas tunnlar), 📦 SUPPLY DROP (dagtid: en låda
  med fallskärm landar i Yard – först dit får Noodles). Ett smalt kort under toppen visar händelsen,
  vad den gör och en nedräkning; Event-rutan till vänster får händelsens ikon.

### Natten: kortare + något att göra med full ryggsäck
- **Natten är kortare:** LOCKDOWN 3:00 (var 4:30), YARD TIME 3:20 (var 2:40).
- **Spola ner gruset:** på natten (LIGHTS OUT + LOCKDOWN) får toaletten i din cell en prompt
  "Flush rubble · 60%": töm ryggsäcken där för 60 % av värdet och fortsätt gräva. På dagen
  betalar Yard-dumpen fullt. Rutan säger "BACKPACK FULL → Flush it down your toilet 🚽" på natten.
- **Vakten i golvet fixad:** inspektionsvakten placerades med kroppens mitt i golvhöjd och sjönk
  ner till midjan. Nu står han på fötterna.
- Dubbla "+N 💪"-notiser i gymmet borttagna (mätaren visar redan siffrorna).

### Nytt slag + diskret väg till dumpen
- **Slaget är omgjort från grunden:** ingen frysning längre. Det är nu en egen boxningsanimation
  som läggs ovanpå gå/stå-animationen: nävarna åker upp i gard när du börjar slå, varje slag har
  laddning (näven dras bak, överkroppen vrids bort) → snärt (rak arm, vridning in, lutning och ett
  litet kliv framåt) → kort stopp → tillbaka till garden. Höger/vänster växlar och vart 4:e slag är
  en tyngre overhand. Håller du PUNCH blir det en flytande kombination; släpper du sänks armarna
  mjukt. Funkar med alla avatarer (gamla och nya leder), och du ser andra spelares slag också.
- **Ryggsäck full:** den stora gula ljusstrålen är borta. I stället en liten pulserande pil på
  golvet framför dig som pekar mot dumpen, och en liten etikett "🗑️ DUMP · 42m" över dumpen
  (syns genom väggar). Pilen försvinner när du är framme.

### Gubben, smala menyer, roligare gym, pratigare vakter
- **Glödande händer/bröst fixat:** VIP-guldnävarna och TOP DOG-kedjan var gjorda av Neon, som
  bloom gjorde till lysande klumpar. Nu är de polerat guld. 3D-kläder från avataren (t.ex. röda
  byxor eller tröjor) tas av så att fångdräkten syns ordentligt.
- **Smala menyer:** alla menyer (Visitation, Tool Crib, Commissary, The Fence, Laundry, Mess Hall,
  Black Market, Decor, Index, Stash, Admin) har samma stil som fynd-korten: mörkt halvgenomskinligt
  glas, liten titel med färgad linje, tunna rader och smala knappar. "Ej tillgänglig"/OWNED är en
  diskret kontur i stället för en stor grå knapp.
- **Gymmet är ett spel nu:** det gröna fältet hoppar till ett nytt ställe efter varje lyft (servern
  räknar ut samma plats), PERFECT i rad bygger combo med nivåer (WARMING UP → ON FIRE 🔥 → BEAST
  MODE → YARD LEGEND) och tonen stiger, 10 lyft i rad utan miss = **SET** med bonusstyrka, siffror
  flyger upp, och en rad under mätaren visar nästa sak du kan lyfta ("NEXT 🛏️ MATTRESS STACK ·
  63 / 100 💪"). Armarna åker upp på riktigt (animation som alla ser), saken är mindre och sitter
  ovanför huvudet, och den stora "Lift"-prompten döljs medan du lyfter.
- **Vakterna:** ~100 repliker (från ~40) + egna personligheter (Dave = mat, Brenda = skvaller,
  Sgt. Lumpy = ser ingenting) + repliker om TOP DOG. En "kortlek" per situation gör att ingen
  replik upprepas förrän alla är sagda. Pratbubblan är ett litet halvgenomskinligt piller med
  namnet i blått, skrivs ut bokstav för bokstav och tonar ut.

### Automatisk kvalitet + butiksbilder
- **Automatisk kvalitet:** spelet mäter FPS. Under ~45 FPS i 4 sekunder går det ner ett steg
  (High → Medium → Low), över ~57 FPS i 20 sekunder upp igen. Stegen sänker hur långt tunnlarna
  ritas (40/32/24 block), antalet riktiga lampor (28/14/6), skuggor från lampor, max antal
  skräpkuber (150/100/60), partiklar och bloom. ADMIN → Perf visar nivån ("quality High").
- **Butiksbilder klara att ladda upp:** `marketing/store/icon.png` (512×512) och sex miniatyrer
  (1920×1080): fången som slår igenom väggen, kristallgrottan, lavasjön, gymmet (fånge lyfter en
  toalett bredvid en vakt), korridoren på natten med vaktens ficklampa och den gamla flyktporten.
  Renderade från den riktiga världen med logga "DIG OUT!" och rubriker. Ladda upp i Creator Hub →
  upplevelsen → Configure → Icon / Thumbnails.

### AAA-passet: jag kan nu SE spelet
- **Nytt verktyg (tools/view):** CI exporterar hela den byggda världen och jag renderar den i 3D
  (three.js i en headless-webbläsare) – cell, korridor, Common Room, Yard, tunnlar och kamrar. Det
  var så jag hittade vad som såg dåligt ut (och det var mycket).
- **Tunnlarna:** golv i zonens material (inte svart berggrund längre), en varm hängande arbetslampa
  var 10:e meter (med skuggor), mjukare färgvariation, armeringsjärn som rostiga stänger i betongen,
  lavaådror som slingrar sig organiskt genom mörk sten, kristallkluster som lyser i mörk grotta,
  kvartsådror i berget.
- **Kamrarna (WOW-ögonblicken) är riktiga rum nu:** pannrum med ångande panna, bunker med britsar
  och "ESCAPE PLAN v1", valv med kassaskåpsdörr och guldtackor, rörkorsning, kloakkanal med båt och
  gummianka, droppstensgrotta, kristallgrotta med jättekristaller, lavasjö med stenbro och glöd,
  och sist: porten där skelettet sitter med sin sked – "HE ALMOST MADE IT".
- **Fängelset:** hängande industrilampor i stället för platta ljusrutor, rör längs taken,
  övervakningskameror, schackrutigt golv och frostade fönster (mörka på natten) i Common Room,
  varuautomater, väggklocka, papperskorgar, affischer ("NO DIGGING", "REPORT TUNNELS – REWARD: 5
  NOODLES"), cellerna med matta, skrivbord med böcker, spegel och streckräkning på väggen.
- **Yard:** taggtråd på alla staket, basketplan med korgar, bänkar, vattenpölar, en hög yttre
  fängelsemur med vakttorn och taggtråd, och en sökarlampa som sveper över gården.
- **Landskap:** en gräsbacke över cellblocket (tunnlarna grävs in i den), slätter och bergskedjor
  vid horisonten i stället för grå tomhet.
- **Alla fångar bär orange overall** med sitt cellnummer på ryggen (om man inte valt en annan).
- **Ljus:** Robloxs "Future"-belysning – riktiga skuggor från lampor, lava och kristaller.
- **Känsla:** kameran gör en liten "punch" (FOV) när block krossas.

### Slaganimation, patrullerande vakter och fängelseschemat
- **Slaganimation (fixad):** den förra animationen vred lederna direkt, vilket nyare Roblox-avatarer
  inte alltid har – därför syntes inget. Nu spelas riktiga animationer via Animator (Robloxs egna
  "lunge" och var tredje slag ett "slash"), som fungerar på alla avatarer och syns för alla andra.
- **Vakter som patrullerar:** Officer Dave (Yard), Officer Brenda (Common Room) och Sgt. Lumpy
  (korridoren). De går sina rundor, tittar runt i hörnen, och på natten går de i korridoren med
  ficklampa. Var 9–15:e sekund säger de något i en pratbubbla – beroende på vad de *inte* ser: någon
  som springer med stulet byte, slagsmål, grävljud, en fullproppad ryggsäck, någon som lyfter på
  gymmet, eller ditt namn när du går förbi ("Gravel in your pockets, Philip? Must be a new diet.").
- **Fängelseschemat styr spelet:** 📋 ROLL CALL → ☀️ YARD TIME → 🚨 LIGHTS OUT → 🌙 LOCKDOWN.
  Vid roll call räknas alla som står i sin cell när den tar slut (+Noodles) – stanna eller rusa ut?
  Klockan i spelet går hela tiden (06:00 → 18:00 → natt) med riktig gryning och skymning. En smal
  ruta ovanför knapparna visar fas, klockslag, en tidslinje, reglerna just nu och vad som kommer.

### Ljud, balans och zoner (stora uppdateringen)
- **Ljud (licensierade ProSoundEffects-ljud):** varje slag = luftsus + tung knytnäve + zonens
  materialljud (betong, tegel, jord, armeringsjärn, sten, glas/kristall). Ljudet blir ljusare för
  varje spricka – du *hör* när blocket är på väg att ge vika. Krossade block får eget krossljud +
  grus, och snabba krossar i följd klättrar i tonhöjd (rytm-belöning). Kuber som landar smattrar i
  3D, dammsugaren har motorljud och "plopp" som stiger i ton när kuberna sugs in. Andras grävande
  hörs där de står. Varje zon har ett eget bakgrundsljud (ihålig tunnel, ventilationsbrus,
  droppande vatten, lavamuller, kristallklang) och musiken sänks i tunnlarna. Celldörrarna smäller
  vid nattlåsning, dynamiten smäller som en riktig sprängning, knappar klickar.
- **Balans:** förut tog det ~13 timmar att nå botten och sista zonen krävde ~1 500 slag per block.
  Nu: gratisspelare flyr på ~2 h (med pass ~1 h 25 min), varje zon tar lite längre än förra och
  i snitt max ~15 slag per block i alla zoner. Verktygen kommer ungefär ett per zon (inga 50x-hopp
  i pris längre), djupa zoner betalar för nästa verktyg. Nytt verktyg `lune run tools/tune write`
  räknar fram blockens hp mot tidsmålen.
- **Zonerna ser olika ut inuti:** streckräkning (fångars dagräkning) i putsen, kopparrör i teglet,
  elrör i betongen, ett gallerverk av armeringsjärn, stora lerrör och järnrör, slem som lyser och
  rostiga rör i kloaken, kvartsådror och fossiler i berget, lysande kristaller, glödande lavaådror
  och obsidian, pelare med guldband och inristade tecken i ruinerna. Plus svävande partiklar per
  zon: damm, droppar, stigande glöd, gnistrande kristalldamm, guldstoft.

### Balans (`lune run tools/simulate all`)
| | Gratis-spelare | Med alla pass |
|---|---|---|
| Första uppgraderingen | 38 s | 34 s |
| Zon 2 (Brick) | 4:11 | 3:51 |
| Zon 3 (Concrete) | 8:52 | 7:50 |
| Zon 4 (Reinforced) | 14:52 | 11:55 |
| Zon 5 (Clay & Pipes) | 22:53 | 16:47 |
| Zon 6 (Sewer) | 33:57 | 27:36 |
| Zon 7 (Bedrock) | 45:13 | 32:16 |
| Zon 8 (Crystal Cave) | 1:01:59 | 47:38 |
| Zon 9 (Magma) | 1:21:15 | 54:03 |
| Zon 10 (Ancient Ruins) | 1:55:42 | 1:02:01 |
| Första flykten (600 m) | ~2:04 h | ~1:23 h |

Mål: första uppgradering < 60 s ✅, zon 2 < 6 min ✅, zon 3 < 17 min ✅, flykt < 2:30 ✅,
snitt ≤ 15 slag per block i varje zon ✅ (simulatorn varnar om något av detta spricker).
När nästa lager kräver fler än ~15 slag "farmar" spelaren bredare i en grundare zon för Noodles och
köper nästa verktyg – det är tänkt så (som i andra simulatorspel), inte en vägg.

### Kontroller
- CI: StyLua, Selene, Lune-tester, balanssimulering, Rojo-bygge och **smoke-test i den riktiga
  platsen: 169 godkända, 0 fel** (hela M1-loopen spelas av en simulerad spelare: slag, sönderslaget
  block, dammsugning, dump, köp, gym, fynd + försäljning, kammare + zon 2, samlingshylla, dag/natt med låsta dörrar, sparning, stresstest).

### Prestanda
- Stresstestet (admin "Stress dig": 6×6-tunnel 120 block djup med 6 stora sidorum) ger **3 852
  skal-delar totalt, varav 1 416 inom strömningsradien** (budget 3 000). Smulor max 150.
- FPS på iPhone 11 måste mätas av dig: tryck ADMIN → Stress dig → Perf och skriv av siffran.

## 📱 Hur du testar på iPhone
1. Starta spelet. Du hamnar i din cell framför bakväggen.
2. Håll **PUNCH** mot väggen (rutnätet visar vad som träffas). Efter några slag smulas blocket.
3. Håll **VACUUM** (blå knappen) nära grushögarna – ryggsäcksmätaren fylls.
4. När den är full: följ den gula strålen ut genom korridoren → Common Room → Yard → **Rubble Dump**
   (tryck på prompten).
5. Gå tillbaka in i Common Room: **Workshop** – köp Spoon (15 🍜). Slå igen: färre slag per block.
6. Gå till **YARD GYM** i Yard, tryck prompten vid toaletten – du lyfter den över huvudet. Tryck
   **LIFT** när nålen är i det gröna/guldiga (PERFECT ger combo). **DROP** lägger ner den.
7. Leta efter mörka block med färgad ådra (fynd) – ett smalt kort glider in uppe till höger – och
   sälj dem hos **The Fence**. Titta på din gubbe när du slår: hela kroppen ska slå.
8. Vänta på natten (eller ADMIN → 🌙 Night): siren, nedräkning, dörren låses, du flyttas in
   i cellen om du var ute. ADMIN → ☀️ Day öppnar igen.
9. Titta på hyllan ovanför sängen: hittade fynd syns, saknade är "?".
10. Gräv 25 block djupt → kammaren Old Boiler Room + "BRICK"-banner. (Snabbt: ADMIN → Zone 2 och slå
   sönder blocket framför dig.)
11. PvP (behöver två spelare/enheter, dagtid): gå ut i Yard, tryck PUNCH mot den andra spelaren.
    Lägg ett fynd i kistan (Open Stash → PUT ALL), låt den andra hålla STEAL vid din kista och
    springa hem; slå hen på vägen så kommer fyndet tillbaka.
12. M4: ADMIN → Bottom→Escape → tryck ESCAPE! (filmsekvens + High Security). ADMIN → 🌙 Night →
    Inspect me → tryck HIDE. ADMIN → 💰 Treasure och följ markeringen. ADMIN → 🧨 x5 och tryck 🧨
    mot väggen. Köp en lampa i Workshop → 💡 DECOR och placera den i tunneln med 💡-knappen.
13. AAA: gå runt i Common Room, korridoren och Yard (titta på lampor, golv, mur, sökarlampa). ADMIN
    → Zone 2..10 och slå hål in i kammaren i början av zonen – varje kammare är ett eget rum.
14. Kvalitet: ADMIN → Perf – titta på FPS och "quality". Gå ner djupt med mycket lampor/lava och se
    att FPS håller sig (nivån kan gå ner till Medium/Low av sig själv).
15. Schema/vakter: titta på rutan ovanför knapparna (fas + klocka). ADMIN → 📋 Roll call, stå kvar
    i cellen tills YARD TIME → "Counted at roll call!". Gå förbi vakterna med full ryggsäck och läs
    pratbubblorna. Slå på väggen och titta på gubben: den ska göra ett riktigt slag.
16. Ljud/zoner: ha ljudet på. Slå på väggen (hör sprickorna stiga i ton), krossa flera i rad.
    ADMIN → Zone 4 (armeringsjärn), Zone 5 (rör), Zone 8 (kristaller), Zone 9 (lava) – gräv en bit
    och titta på väggarna och lyssna på bakgrundsljudet.
17. Kritikergenomgången: slå på väggen tills du ser "CRIT!". Titta på mätaren under Record.
    Tryck 📋 Jobs och gör ett jobb, hämta belöningen. Spara ihop till nästa verktyg och se kortet
    "… is ready". Gå runt i Yard. ADMIN → 👮 Inspect me när du är djupt nere: nedräkningen visas.
    Nytt konto/ADMIN → 🎬 Tour: följ rundturen (Next/Skip). Gå in i Mess Hall och titta runt.
    Gräv med full ryggsäck: chipet syns en kort stund, inte vid varje slag.
    Gräv med full ryggsäck (fortsätter, gruset blir liggande). I cellen: håll "Cover the
    hole" vid väggen och "Sleep" vid sängen – rör joysticken för att kliva upp. ADMIN → 👮 Inspect
    me: du har 15 s att täcka hålet och lägga dig. Gå in i Mess Hall. Titta på VIP-loungen. ADMIN → 💎 Gold rush / 🍜 Payday /
    🌋 Quake / 📦 Supply (gå ut i Yard och ta lådan).
    Natt: ADMIN → 🌙 Night, gräv tills ryggsäcken är full, gå till toaletten i cellen → "Flush
    rubble". Kolla att inspektionsvakten står på golvet. Slå några slag i rad: garden, växling
    höger/vänster, vart 4:e tyngre. Full ryggsäck på dagen: liten pil på golvet + "DUMP"-etikett.
    Titta också på gubben (VIP/TOP DOG) – inga lysande klumpar på händer/bröst. Öppna Visitation
    och Tool Crib – smala mörka menyer. Gå till gymmet: lyft toaletten, följ det gröna fältet som
    hoppar, gör 10 i rad (SET!) och bygg combo. Gå förbi vakterna och läs de nya replikerna.
18. Prestanda: ADMIN → Stress dig → Perf. Gå runt i tunneln och kolla FPS.
19. Lämna och gå in igen: tunneln, Noodles och uppgraderingar ska finnas kvar.

## ⏳ Saknas (kommande milstolpar)
- UI:t (knappar, menyer) har inte kunnat renderas i visaren än – där är jag fortfarande blind.
- Prestanda: automatisk kvalitet finns nu, men kolla gärna på riktig iPhone 11 (ADMIN → Perf).
- Ladda upp ikon + miniatyrer i Creator Hub (görs för hand).
- Balansen bygger på simulatorn – finjustera med riktiga speldata när spelare kommer in.
- Ljudnivåerna är satta "på papper" – lyssna på iPhone och säg till om något är för högt/lågt.

## ☑️ Manuell checklista för Philip (Creator Hub)
Ops-workflowen försöker göra detta automatiskt – se `tools/ops/ops-log.md` för resultatet:
- [x] Gamla pass/produkter (Rob the Rich, 7 pass + 11 produkter) satta "off sale" (HTTP 204, 15 okt).
- [x] Upplevelsens namn: **Dig Out! Prison Escape** + ny beskrivning (plats och universum, HTTP 200).
- [x] Max Players = 12.
- [x] Arkivtaggen `archive/rob-the-rich` skapad.
- [x] De nya passen (5) och produkterna (4) skapade i Creator Hub (15 okt) med id:n i Config/Products.
- [ ] **Ikoner för passen/produkterna** (de har Robloxs standardikon – ladda upp bilder i Creator Hub).
- [ ] **Ny ikon och thumbnails** (kan inte göras via API:t – ladda upp manuellt).
- [ ] Genre/kategori och åldersenkät (Experience Questionnaire) uppdaterade för det nya spelet.
