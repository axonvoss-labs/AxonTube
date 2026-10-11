# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · **Nederlands** · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Leer de talen van de wereld sneller met AI.**

Versie 0.5.3 · macOS-preview · Apple silicon

[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md)

Maak van YouTube je persoonlijke taalklas. Leer met YouTube-ondertitels en automatische vertalingen van video's die je graag kijkt: lees twee talen naast elkaar, speel elke zin opnieuw af en bewaar het materiaal dat voor jou telt.

**24 interfacetalen · Meertalige ondertitels**

24 verwijst naar het aantal interfacetalen. Ondertiteltalen hangen af van de beschikbare sporen van de gekozen video; het is geen belofte dat je 24 talen vloeiend leert spreken.

## Schermafbeeldingen

De schermafbeeldingen zijn gemaakt in de daadwerkelijke app 0.5.3. De taal van elke schermafbeelding staat apart vermeld van de taal van dit document.

### Welkom en hoofdroute

![Welkom en hoofdroute](../assets/interface-en.png)

De vier werkbalkacties, twee zichtbare ondertitelkeuzes, vertaalde slogan en duidelijke uitgeschakelde toestand voordat een video wordt geopend. — Schermafbeelding van de Engelstalige app

### Oefenen per zin

![Oefenen per zin](../assets/interface-study.png)

demo.mp4 — Zinnen zoeken, klikken om erheen te springen, vorige / volgende, opnieuw afspelen, herhalen in een lus, afspeelsnelheid en de huidige zin volgen. — Schermafbeelding van de Engelstalige app

### Eerste en tweede ondertitel

![Eerste en tweede ondertitel](../assets/interface-caption-languages.png)

Echte opname van de Engelse interface met de onafhankelijke ondertitelmenu's, standaard ingesteld op Engels en Traditioneel Chinees. — Schermafbeelding van de Engelstalige app

### Open een YouTube-link

![Open een YouTube-link](../assets/interface-youtube-dialog.png)

Echte opname van het linkvenster in de Engelse interface. Een link openen start het afspelen en vraagt het geselecteerde ondertitelpaar op. — Schermafbeelding van de Engelstalige app

## Aan de slag

### 1. Open YouTube

Plak een videolink. Beschikbare ondertitels worden automatisch opgevraagd, met Engels als eerste taal en Traditioneel Chinees als tweede. Het eerste ophalen kan ongeveer 1–2 minuten duren; beschikbaarheid is niet gegarandeerd.

### 2. Kies en oefen

Gebruik de twee zichtbare keuzemenu's voor ondertitels. Klik op een zin om erheen te springen, deze opnieuw af te spelen of de zin in een lus te herhalen.

### 3. Sla op of exporteer

Met Video opslaan kies je een map voor toegankelijke media en beschikbare ondertitels. Tweetalige ondertitels exporteren maakt Word-, TXT- of SRT-bestanden van de geladen ondertitels.

### 4. Pas het aan

Wijzig de interfacetaal, afspeelsnelheid, ondertitelgrootte en tijdverschuiving per spoor. De app onthoudt je keuzes voor de interface- en ondertiteltalen.

## Beschikbare functies

### Twee onafhankelijke ondertitelsporen

Standaard Engels / Traditioneel Chinees; kies uit de beschikbare originele ondertitels en automatische vertalingen van de huidige video. Succesvol geladen ondertitels van het eerste spoor blijven bruikbaar als het tweede spoor mislukt.

### Oefenen per zin

Zinnen zoeken, klikken om erheen te springen, vorige / volgende, opnieuw afspelen, herhalen in een lus, afspeelsnelheid en de huidige zin volgen.

### Video met gesynchroniseerde ondertitels

Opslaan blijft beschikbaar terwijl ondertitels laden. Elke bewerking maakt een nieuwe map met toegankelijke video. Als ondertitels beschikbaar zijn, worden SRT-sporen met tijdcodes en tweetalige leesbestanden toegevoegd. Alleen video opslaan wordt ook ondersteund; onvoltooid werk blijft in een .partial-map.

### Export naar Word, TXT en SRT

Exporteer beschikbare ondertitels met de ingestelde tijdverschuivingen. Word en TXT koppelen tekst op basis van overlappende tijden. Als slechts één spoor is geladen, kan de inhoud daarvan nog steeds worden geëxporteerd.

### 24 vertaalde interfaces

Menu's, statusmeldingen en de leerslogan veranderen samen van taal. Arabisch en Hebreeuws ondersteunen een indeling van rechts naar links; de ondertitelinhoud verandert niet wanneer je de interfacetaal wijzigt.

### Lokaal afspelen en duidelijke bediening

Open lokale media- en ondertitelbestanden via het menu Bestand. Uitgeschakelde acties zijn gedimd met een uitleg; geselecteerde modi hebben markeringen en vinkjes; tijdens opslaan wordt een bezigstatus getoond.

## Waarom het handig is

### Snel van kijken naar oefenen

Vier werkbalkacties houden de hoofdroute eenvoudig: YouTube → Video opslaan → Ondertitels → Taal. Een extra knop om ondertitels op te halen is niet nodig.

### Leermateriaal om te bewaren

Ondertitels met tijdcodes en leesbare Word- / TXT-bestanden helpen bij luisteroefeningen en later herhalen. Exports gebruiken nieuwe bestemmingen en behouden de originele bestanden.

### Lokaal werken, zonder AI-API-sleutel

Lokale media en opgeslagen ondertitels werken offline. YouTube levert website-ondertitels en automatische vertalingen; de app heeft geen telemetrie, uploadt geen lokale media en vereist geen betaalde AI-API-sleutel.

## Openstaande punten en beperkingen

### P0 · Beschikbaarheid van YouTube-ondertitels en -video's

**Verificatie van de live dienst**

Bij de laatste live controle vroeg YouTube om aanmelding / botverificatie. Succesvolle online downloads zijn op dit moment niet aangetoond. Controleer dit vóór publieke uitgave op het beoogde netwerk en met representatieve video's.

### P1 · Insluiten en video's met accountbeperkingen

**Platformbeperking**

Sommige makers of video's staan ingesloten afspelen niet toe. Google SSO in de app is niet geïmplementeerd; de browsersnelkoppeling gebruikt een aparte aanmeld- en afspeelsessie. Deze beperkingen mogen niet als opgelost worden gepresenteerd.

### P1 · Ondertekening en bredere Mac-tests

**Distributie en compatibiliteit**

Het pakket is ad-hoc ondertekend, zonder Developer ID-notarisatie. Apple Silicon op macOS 26.5.2 is getest; macOS 27 en Intel-Macs niet. macOS 14 is een implementatiedoel, geen bewijs dat elke versie is getest.

### P2 · Downloadkwaliteit en nauwkeurigheid van ondertitels

**Formaat- en kwaliteitsbeperkingen**

Opslaan gebruikt één volledige audio-/videostream en voegt geen aparte streams met hoge resolutie samen. Lokaal afspelen hangt af van codec-ondersteuning; optionele conversie met FFmpeg kan extra audiosporen, HDR en ingesloten ondertitels weglaten. ASS/SSA importeert alleen tekst. Automatische ondertitels, vertalingen en tweetalige koppeling op basis van tijd kunnen fouten bevatten.

### P2 · Leergeschiedenis en studiehulpmiddelen

**Niet geïmplementeerd**

Herstel van de afspeelgeschiedenis, woordenverzamelingen, gespreide herhaling, OCR en extractie van ondertitels uit afbeeldingen zijn niet geïmplementeerd. Opgeslagen taalvoorkeuren zijn geen opgeslagen leervoortgang.

### P2 · Taalcontrole door moedertaalsprekers

**Redactionele controle**

Alle 24 interfacetalen en vertaalde slogans hebben de wisseltests doorstaan. Dat toont dekking en gedrag aan, geen professionele controle van elke vertaling door moedertaalsprekers.

## Wat is gecontroleerd

Voor 0.5.3: 105 kerncontroles, 138 modelasserties, 29 ondertitelcontroles, 60 controles voor video-opslag en 317 asserties voor de native interface geslaagd. Alle 24 talen zijn in het echte menu geselecteerd; zes interfacetalen en compacte Duitse indelingen zijn beoordeeld.

Lokaal afspelen, exports, toestandsovergangen en native opslagdialoogvensters zijn gecontroleerd. Offline testgegevens en opslagtests met een gesimuleerd hulpprogramma bewijzen niet dat YouTube momenteel online ondertitel- of videodownloads toestaat. Er zijn geen gebruikersgegevens voor aanmelding geïmporteerd.

[Gedetailleerd verificatieverslag](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#nl)

De app heeft een MIT-licentie; voor componenten van derden blijven hun licentievermeldingen gelden. AxonTube is niet verbonden aan YouTube, Google of Apple.

Documentdatum: 2026-10-11
