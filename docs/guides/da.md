# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · **Dansk** · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Lær verdens sprog hurtigere med AI.**

Version 0.5.3 · Forhåndsversion til macOS · Apple Silicon

[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md)

Gør YouTube til dit eget sprogklasseværelse. Lær med videoer, du elsker, ved hjælp af YouTubes undertekster og automatiske oversættelser: læs to sprog side om side, afspil hver sætning igen, og gem det materiale, der betyder noget for dig.

**24 brugerfladesprog · Flersprogede undertekster**

24 er antallet af brugerfladesprog. Undertekstsprog afhænger af den valgte videos tilgængelige spor; det er ikke et løfte om at beherske 24 sprog flydende.

## Skærmbilleder

Skærmbillederne er taget i den faktiske app 0.5.3. Skærmbilledets sprog er angivet særskilt fra dette dokuments sprog.

### Velkomst og hovedforløb

![Velkomst og hovedforløb](../assets/interface-en.png)

De fire handlinger på værktøjslinjen, to synlige undertekstvælgere, oversat slogan og tydelig deaktiveret tilstand, før en video åbnes. — Skærmbillede af appen på engelsk

### Øvelse sætning for sætning

![Øvelse sætning for sætning](../assets/interface-study.png)

demo.mp4 — Sætningssøgning, spring med et klik, forrige / næste, gentagelse, løkker, afspilningshastighed og følg den aktuelle sætning. — Skærmbillede af appen på engelsk

### Første og anden undertekst

![Første og anden undertekst](../assets/interface-caption-languages.png)

Faktisk skærmbillede af den engelske brugerflades uafhængige undertekstmenuer med engelsk og traditionelt kinesisk som standard. — Skærmbillede af appen på engelsk

### Åbn et YouTube-link

![Åbn et YouTube-link](../assets/interface-youtube-dialog.png)

Faktisk skærmbillede af linkdialogen i den engelske brugerflade. Når et link åbnes, starter afspilningen, og det valgte undertekstpar anmodes. — Skærmbillede af appen på engelsk

## Kom godt i gang

### 1. Åbn YouTube

Indsæt et videolink. Tilgængelige undertekster anmodes automatisk med engelsk først og traditionelt kinesisk som det andet sprog. Første hentning kan tage cirka 1–2 minutter; tilgængeligheden er ikke garanteret.

### 2. Vælg, og øv dig

Brug de to synlige rullemenuer til undertekster. Klik på en sætning for at springe til den, afspille den igen eller gentage den i en løkke.

### 3. Gem eller eksportér

Gem video lader dig vælge en mappe til tilgængelige medier og undertekster. Eksportér tosprogede undertekster opretter Word-, TXT- eller SRT-filer ud fra indlæste undertekster.

### 4. Tilpas til dig

Skift brugerfladesprog, afspilningshastighed, undertekststørrelse og tidsforskydning for hvert spor. Appen husker valgene af brugerflade- og undertekstsprog.

## Tilgængelige funktioner

### To uafhængige undertekstspor

Engelsk / traditionelt kinesisk som standard; vælg mellem den aktuelle videos tilgængelige originaler og automatiske oversættelser. Undertekster, der er hentet til første spor, kan stadig bruges, hvis andet spor fejler.

### Øvelse sætning for sætning

Sætningssøgning, spring med et klik, forrige / næste, gentagelse, løkker, afspilningshastighed og følg den aktuelle sætning.

### Video med synkroniserede undertekster

Du kan gemme, mens undertekster indlæses. Hver handling opretter en ny mappe med tilgængelig video. Når undertekster er tilgængelige, tilføjes SRT-spor med tidskoder og tosprogede læsefiler. Det er også muligt at gemme kun videoen; uafsluttet arbejde forbliver i en .partial-mappe.

### Eksport til Word, TXT og SRT

Eksportér tilgængelige undertekster med tidsforskydningerne anvendt. Word og TXT parrer tekst efter overlappende tidsrum. Hvis kun ét spor er indlæst, kan dets indhold stadig eksporteres.

### 24 oversatte brugerflader

Menuer, statusmeddelelser og læringssloganet skifter sprog sammen. Arabisk og hebraisk understøtter layout fra højre mod venstre; underteksternes indhold ændres ikke, når brugerfladesproget skiftes.

### Lokal afspilning og tydelig betjening

Åbn lokale medie- og undertekstfiler fra menuen Arkiv. Deaktiverede handlinger er nedtonet med en begrundelse; valgte tilstande har fremhævninger og flueben; en optagetindikator vises, mens der gemmes.

## Derfor er den nyttig

### Kort vej fra at se til at øve

Fire handlinger på værktøjslinjen gør hovedforløbet enkelt: YouTube → Gem video → Undertekster → Sprog. Der er ikke brug for en ekstra knap til at hente undertekster.

### Læringsmateriale, du kan beholde

Undertekster med tidskoder og læsbare Word- / TXT-filer hjælper både med lytteøvelser og senere repetition. Eksport bruger nye destinationer og bevarer originalfilerne.

### Lokalt arbejde uden AI-API-nøgle

Lokale medier og gemte undertekster fungerer offline. YouTube leverer webstedets undertekster og automatiske oversættelser; appen har ingen telemetri, uploader ikke lokale medier og kræver ingen betalt AI-API-nøgle.

## Åbne problemer og begrænsninger

### P0 · Tilgængelighed af YouTube-undertekster og -videoer

**Verifikation af onlinetjenesten**

Den seneste livekontrol stødte på YouTubes krav om login / botkontrol. Vellykkede aktuelle onlinedownloads er ikke bekræftet. Kontrollér på det tilsigtede netværk og med repræsentative videoer før offentlig udgivelse.

### P1 · Indlejring og videoer med kontobegrænsninger

**Platformsbegrænsning**

Nogle ophavspersoner eller videoer tillader ikke indlejret afspilning. Google SSO i appen er ikke implementeret; browsergenvejen bruger en separat login- og afspilningssession. Disse begrænsninger kan ikke fremstilles som løst.

### P1 · Signering og bredere Mac-test

**Distribution og kompatibilitet**

Pakken er ad hoc-signeret uden Developer ID-notarisering. Apple Silicon med macOS 26.5.2 er testet; macOS 27 og Intel-Mac-computere er ikke. macOS 14 er et implementeringsmål, ikke bevis for, at alle versioner er testet.

### P2 · Downloadkvalitet og underteksternes nøjagtighed

**Format- og kvalitetsbegrænsninger**

Lagring bruger en komplet lyd-/videostrøm og sammenfletter ikke separate strømme i høj opløsning. Lokal afspilning afhænger af codec-understøttelsen; valgfri konvertering med FFmpeg kan udelade ekstra lydspor, HDR og indlejrede undertekster. ASS/SSA importerer kun tekst. Automatiske undertekster, oversættelser og tidsbaseret tosproget parring kan indeholde fejl.

### P2 · Læringshistorik og studieværktøjer

**Ikke implementeret**

Gendannelse af afspilningshistorik, ordsamlinger, repetition med mellemrum, OCR og udtræk af billedbaserede undertekster er ikke implementeret. Gemte sprogpræferencer er ikke gemte læringsfremskridt.

### P2 · Gennemgang af modersmålstalere

**Sproglig gennemgang**

Alle 24 brugerfladesprog og oversatte slogans bestod skiftetestene. Det bekræfter dækning og adfærd, men ikke en professionel gennemgang af hver oversættelse ved en modersmålstaler.

## Hvad der er verificeret

For 0.5.3 bestod: 105 kernekontroller, 138 modelassertioner, 29 undertekstkontroller, 60 kontroller af videolagring og 317 assertioner for den native brugerflade. Alle 24 sprogvalg blev foretaget i den faktiske menu; seks brugerfladesprog og kompakte tyske layout blev gennemgået.

Lokal afspilning, eksport, tilstandsskift og systemets gemmedialoger blev verificeret. Offlinetestdata og gemmetest med et simuleret hjælpeprogram beviser ikke, at YouTube i øjeblikket tillader download af undertekster eller videoer fra nettet. Ingen brugerloginoplysninger blev importeret.

[Detaljeret verifikationsrapport](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#da)

Appen har MIT-licens; tredjepartskomponenter bevarer deres licensmeddelelser. AxonTube er ikke tilknyttet YouTube, Google eller Apple.

Dokumentdato: 2026-10-11
