# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · **Svenska** · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Lär dig världens språk snabbare med AI.**

Version 0.5.3 · Förhandsversion för macOS · Apple Silicon

[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md) · [GitHub Packages](https://github.com/users/axonvoss-labs/packages/container/package/axontube) · [Package guide](../PACKAGES.md)

Gör YouTube till ditt eget språkklassrum. Lär dig med videor du gillar genom YouTubes undertexter och automatiska översättningar: läs två språk sida vid sida, spela upp varje mening igen och spara materialet som betyder något för dig.

**24 gränssnittsspråk · Flerspråkiga undertexter**

24 avser antalet gränssnittsspråk. Undertextspråken beror på den valda videons tillgängliga spår; det är inget löfte om att behärska 24 språk flytande.

## Skärmbilder

Skärmbilderna är tagna i den faktiska appen 0.5.3. Skärmbildens språk anges separat från dokumentets språk.

### Välkommen och huvudflöde

![Välkommen och huvudflöde](../assets/interface-en.png)

De fyra verktygsfältsåtgärderna, två synliga undertextväljare, översatt slogan och tydligt inaktivt läge innan en video öppnas. — Skärmbild av appen på engelska

### Öva mening för mening

![Öva mening för mening](../assets/interface-study.png)

demo.mp4 — Meningssökning, klicka för att hoppa, föregående / nästa, spela upp igen, upprepning i slinga, uppspelningshastighet och följ den aktuella meningen. — Skärmbild av appen på engelska

### Första och andra undertexten

![Första och andra undertexten](../assets/interface-caption-languages.png)

Faktisk skärmbild av det engelska gränssnittets oberoende undertextmenyer, med engelska och traditionell kinesiska som standard. — Skärmbild av appen på engelska

### Öppna en YouTube-länk

![Öppna en YouTube-länk](../assets/interface-youtube-dialog.png)

Faktisk skärmbild av länkrutan i det engelska gränssnittet. När en länk öppnas startar uppspelningen och det valda undertextparet begärs. — Skärmbild av appen på engelska

## Kom igång

### 1. Öppna YouTube

Klistra in en videolänk. Tillgängliga undertexter begärs automatiskt, med engelska först och traditionell kinesiska sedan. Den första hämtningen kan ta cirka 1–2 minuter; tillgängligheten garanteras inte.

### 2. Välj och öva

Använd de två synliga rullgardinsmenyerna för undertexter. Klicka på en mening för att hoppa till den, spela upp den igen eller upprepa den i en slinga.

### 3. Spara eller exportera

Med Spara video väljer du en mapp för åtkomliga medier och tillgängliga undertexter. Exportera tvåspråkiga undertexter skapar Word-, TXT- eller SRT-filer av inlästa undertexter.

### 4. Anpassa efter dig

Ändra gränssnittsspråk, uppspelningshastighet, undertextstorlek och tidsförskjutning för varje spår. Appen kommer ihåg valen av gränssnitts- och undertextspråk.

## Tillgängliga funktioner

### Två oberoende undertextspår

Engelska / traditionell kinesiska som standard; välj bland den aktuella videons tillgängliga original och automatiska översättningar. Undertexter som hämtats för det första spåret går fortfarande att använda om det andra spåret misslyckas.

### Öva mening för mening

Meningssökning, klicka för att hoppa, föregående / nästa, spela upp igen, upprepning i slinga, uppspelningshastighet och följ den aktuella meningen.

### Video med synkroniserade undertexter

Det går att spara medan undertexterna läses in. Varje åtgärd skapar en ny mapp med åtkomlig video. När undertexter finns tillgängliga läggs SRT-spår med tidskoder och tvåspråkiga läsfiler till. Det går även att spara enbart video; ofärdigt arbete ligger kvar i en .partial-mapp.

### Export till Word, TXT och SRT

Exportera tillgängliga undertexter med tidsförskjutningarna tillämpade. Word och TXT parar ihop text utifrån överlappande tider. Om bara ett spår har lästs in kan dess innehåll ändå exporteras.

### 24 översatta gränssnitt

Menyer, statusmeddelanden och inlärningssloganen byter språk tillsammans. Arabiska och hebreiska har stöd för layout från höger till vänster; undertexternas innehåll ändras inte när du byter gränssnittsspråk.

### Lokal uppspelning och tydliga kontroller

Öppna lokala medie- och undertextfiler från menyn Arkiv. Inaktiverade åtgärder är nedtonade med angivna orsaker; valda lägen har markeringar och bockar; en upptagenindikator visas när något sparas.

## Därför är den användbar

### Kort väg från att titta till att öva

Fyra verktygsfältsåtgärder gör huvudflödet enkelt: YouTube → Spara video → Undertexter → Språk. Ingen extra knapp för att hämta undertexter behövs.

### Läromaterial som du kan behålla

Undertexter med tidskoder och läsbara Word- / TXT-filer stöder både hörövningar och senare repetition. Export använder nya målsökvägar och bevarar originalfilerna.

### Lokalt arbete utan AI-API-nyckel

Lokala medier och sparade undertexter fungerar offline. YouTube tillhandahåller webbplatsens undertexter och automatiska översättningar; appen har ingen telemetri, laddar inte upp lokala medier och kräver ingen betald AI-API-nyckel.

## Öppna frågor och begränsningar

### P0 · Tillgång till undertexter och videor från YouTube

**Verifiering av onlinetjänsten**

Den senaste livekontrollen mötte YouTubes krav på inloggning / botverifiering. Lyckade nedladdningar från nätet har inte kunnat bekräftas i nuläget. Kontrollera på det avsedda nätverket och med representativa videor före offentlig lansering.

### P1 · Inbäddning och kontobegränsade videor

**Plattformsbegränsning**

Vissa upphovspersoner eller videor tillåter inte inbäddad uppspelning. Google SSO i appen är inte implementerat; webbläsargenvägen använder en separat inloggnings- och uppspelningssession. Dessa begränsningar får inte framställas som lösta.

### P1 · Signering och bredare Mac-tester

**Distribution och kompatibilitet**

Paketet är ad hoc-signerat, utan Developer ID-notarisering. Apple Silicon med macOS 26.5.2 har testats; macOS 27 och Intel-Macar har inte testats. macOS 14 är ett distributionsmål, inte bevis för att varje version har testats.

### P2 · Nedladdningskvalitet och undertexternas riktighet

**Format- och kvalitetsbegränsningar**

Sparandet använder en komplett ljud-/videoström och slår inte ihop separata högupplösta strömmar. Lokal uppspelning beror på vilka kodekar som stöds; valfri konvertering med FFmpeg kan utelämna extra ljudspår, HDR och inbäddade undertexter. ASS/SSA importerar endast text. Automatiska undertexter, översättningar och tidsbaserad tvåspråkig parning kan innehålla fel.

### P2 · Inlärningshistorik och studieverktyg

**Inte implementerat**

Återställning av uppspelningshistorik, ordsamlingar, repetition med mellanrum, OCR och extrahering av bildbaserade undertexter är inte implementerade. Sparade språkinställningar är inte sparade studieframsteg.

### P2 · Granskning av modersmålstalare

**Språklig granskning**

Alla 24 gränssnittsspråk och översatta sloganer klarade testerna för språkbyte. Det bekräftar täckning och beteende, men inte professionell modersmålsgranskning av varje översättning.

## Vad som har verifierats

För 0.5.3 godkändes: 105 kärnkontroller, 138 modellassertioner, 29 undertextkontroller, 60 kontroller av videosparande och 317 assertioner för macOS-gränssnittet. Alla 24 språkval gjordes i den faktiska menyn; sex gränssnittsspråk och kompakta tyska layouter granskades.

Lokal uppspelning, exporter, tillståndsövergångar och systemets sparadialoger verifierades. Offlinetestdata och spartester med ett simulerat hjälpprogram bevisar inte att YouTube för närvarande tillåter nedladdning av undertexter eller videor från nätet. Inga inloggningsuppgifter för användare importerades.

[Detaljerad verifieringsrapport](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#sv)

Appen har MIT-licens; tredjepartskomponenter behåller sina licensmeddelanden. AxonTube har ingen anknytning till YouTube, Google eller Apple.

Dokumentdatum: 2026-10-11
