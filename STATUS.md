# STATUS – Dig Out! (fängelseflykt-grävspel)

Senast uppdaterad: 2026-10-15 · Milstolpe: **M3 PVP** (M1 + M2 publicerade)

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
- **Gym:** stå vid en station → stor LIFT-knapp. Bänk (+1), hantlar (+3, kräver 100 💪),
  skivstång (+10, kräver 600 💪). Styrka gäller slagkraften.
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
- **Gym:** två nya stationer – Tire Flip (+40, kräver 4 000 💪) och Pull-up Bar (+150, kräver 25 000 💪).
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

### Balans (`lune run tools/simulate`)
| | Gratis-spelare | Med alla pass |
|---|---|---|
| Första uppgraderingen | 38 s | 34 s |
| Zon 2 (Brick) | 4:11 | 3:51 |
| Zon 3 (Concrete) | 9:41 | 8:25 |
| Zon 4 (Reinforced) | 14:47 | 12:08 |
| Zon 5 (Clay & Pipes) | 23:35 | 19:20 |
| Zon 6 (Sewer) | 42:52 | 48:46 |

Mål: första uppgradering < 60 s ✅, zon 2 ≈ 5 min ✅, zon 3 ≈ 15 min (nu ~10 min, lite snabbt).
Siffrorna är en första omgång – simulatorn är förenklad (passen ger t.ex. för lite effekt i den).
Antal slag per block när man når en ny zon: 7–20 (zon 5 ~70 med Pickaxe → köp Jackhammer).

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
6. Gå till **Gym** i Yard och tryck LIFT några gånger – styrkan går upp.
7. Leta efter mörka block med färgad ådra (fynd) och sälj dem hos **The Fence**.
8. Vänta på natten (eller ADMIN → 🌙 Night): siren, nedräkning, dörren låses, du flyttas in
   i cellen om du var ute. ADMIN → ☀️ Day öppnar igen.
9. Titta på hyllan ovanför sängen: hittade fynd syns, saknade är "?".
10. Gräv 25 block djupt → kammaren Old Boiler Room + "BRICK"-banner. (Snabbt: ADMIN → Zone 2 och slå
   sönder blocket framför dig.)
11. PvP (behöver två spelare/enheter, dagtid): gå ut i Yard, tryck PUNCH mot den andra spelaren.
    Lägg ett fynd i kistan (Open Stash → PUT ALL), låt den andra hålla STEAL vid din kista och
    springa hem; slå hen på vägen så kommer fyndet tillbaka.
12. Prestanda: ADMIN → Stress dig → Perf. Gå runt i tunneln och kolla FPS.
13. Lämna och gå in igen: tunneln, Noodles och uppgraderingar ska finnas kvar.

## ⏳ Saknas (kommande milstolpar)
- **M4 Djup:** zon 7–10, alla 9 rariteter, vakt-inspektioner, snitch, skattjakt, events, flykt/rebirth,
  dekorationer, Laundry, Black Market, dagliga belöningar, Cellmate offline, pass/produkter.
- **M5 Polish:** tutorial, musik, ljudpass, analytics.
- Ljuden är tillfälliga (återanvända Roblox-ljud som är kontrollerade). Riktiga slag/smul-ljud
  behöver väljas i Creator Store.
- Andra spelare ser inte ditt armslag (bara smulorna och hålen).

## ☑️ Manuell checklista för Philip (Creator Hub)
Ops-workflowen försöker göra detta automatiskt – se `tools/ops/ops-log.md` för resultatet:
- [x] Gamla pass/produkter (Rob the Rich, 7 pass + 11 produkter) satta "off sale" (HTTP 204, 15 okt).
- [x] Upplevelsens namn: **Dig Out! Prison Escape** + ny beskrivning (plats och universum, HTTP 200).
- [x] Max Players = 12.
- [x] Arkivtaggen `archive/rob-the-rich` skapad.
- [ ] **Ny ikon och thumbnails** (kan inte göras via API:t – ladda upp manuellt).
- [ ] Genre/kategori och åldersenkät (Experience Questionnaire) uppdaterade för det nya spelet.
