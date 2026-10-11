# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · **Suomi** · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Opi maailman kieliä nopeammin tekoälyn avulla.**

Versio 0.5.3 · macOS-ennakkoversio · Apple silicon

[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md)

Tee YouTubesta oma kieliluokkasi. Opi suosikkivideoistasi YouTuben tekstitysten ja automaattisten käännösten avulla: lue kahta kieltä rinnakkain, toista jokainen lause ja säilytä sinulle tärkeä materiaali.

**24 käyttöliittymäkieltä · Monikieliset tekstitykset**

24 tarkoittaa käyttöliittymän kielivaihtoehtojen määrää. Tekstityskielet riippuvat valitun videon saatavilla olevista raidoista; kyse ei ole lupauksesta oppia 24 kieltä sujuvasti.

## Näyttökuvat

Näyttökuvat on otettu varsinaisesta 0.5.3-sovelluksesta. Näyttökuvan kieli ilmoitetaan erikseen tämän asiakirjan kielestä.

### Tervetuloa ja päätyönkulku

![Tervetuloa ja päätyönkulku](../assets/interface-en.png)

Työkalupalkin neljä toimintoa, kaksi näkyvää tekstitysvalitsinta, käännetty iskulause ja selkeä käytöstä poistettu tila ennen videon avaamista. — Näyttökuva englanninkielisestä sovelluksesta

### Harjoittelua lause kerrallaan

![Harjoittelua lause kerrallaan](../assets/interface-study.png)

demo.mp4 — Lausehaku, siirtyminen napsauttamalla, edellinen / seuraava, uudelleentoisto, jatkuva toisto, toistonopeus ja nykyisen lauseen seuraaminen. — Näyttökuva englanninkielisestä sovelluksesta

### Ensimmäinen ja toinen tekstitys

![Ensimmäinen ja toinen tekstitys](../assets/interface-caption-languages.png)

Todellinen näyttökuva englanninkielisen käyttöliittymän riippumattomista tekstitysvalikoista, joiden oletukset ovat englanti ja perinteinen kiina. — Näyttökuva englanninkielisestä sovelluksesta

### Avaa YouTube-linkki

![Avaa YouTube-linkki](../assets/interface-youtube-dialog.png)

Todellinen näyttökuva englanninkielisen käyttöliittymän linkkivalintaikkunasta. Linkin avaaminen käynnistää toiston ja pyytää valitun tekstitysparin. — Näyttökuva englanninkielisestä sovelluksesta

## Aloittaminen

### 1. Avaa YouTube

Liitä videolinkki. Saatavilla olevia tekstityksiä pyydetään automaattisesti: ensimmäiseksi englanti ja toiseksi perinteinen kiina. Ensimmäinen haku voi kestää noin 1–2 minuuttia; saatavuutta ei taata.

### 2. Valitse ja harjoittele

Käytä kahta näkyvää tekstitysten pudotusvalikkoa. Napsauta lausetta siirtyäksesi siihen, toistaaksesi sen uudelleen tai käynnistääksesi lauseen jatkuvan toiston.

### 3. Tallenna tai vie

Tallenna video -toiminnolla valitaan kansio saatavilla olevalle medialle ja tekstityksille. Vie kaksikieliset tekstitykset luo ladatuista tekstityksistä Word-, TXT- tai SRT-tiedostoja.

### 4. Muokkaa itsellesi sopivaksi

Muuta käyttöliittymän kieltä, toistonopeutta, tekstityksen kokoa ja kummankin raidan aikasiirtymää. Sovellus muistaa käyttöliittymän ja tekstitysten kielivalinnat.

## Käytettävissä olevat toiminnot

### Kaksi riippumatonta tekstitysraitaa

Oletuksena englanti / perinteinen kiina; valitse nykyisen videon saatavilla olevista alkuperäistekstityksistä ja automaattisista käännöksistä. Onnistuneesti haettu ensimmäinen raita pysyy käytettävissä, jos toisen haku epäonnistuu.

### Harjoittelua lause kerrallaan

Lausehaku, siirtyminen napsauttamalla, edellinen / seuraava, uudelleentoisto, jatkuva toisto, toistonopeus ja nykyisen lauseen seuraaminen.

### Video ja synkronoidut tekstitykset

Tallennus on käytettävissä myös tekstitysten latautuessa. Jokainen toiminto luo uuden kansion saatavilla olevalle videolle. Kun tekstityksiä on saatavilla, mukaan lisätään ajastetut SRT-raidat ja kaksikieliset lukutiedostot. Myös pelkän videon tallennus on tuettu; keskeneräinen työ säilyy .partial-kansiossa.

### Vienti Word-, TXT- ja SRT-muotoon

Vie saatavilla olevat tekstitykset aikasiirtymät huomioiden. Word ja TXT yhdistävät tekstit ajallisen päällekkäisyyden perusteella. Jos vain yksi raita on ladattu, sen sisällön voi silti viedä.

### 24 käännettyä käyttöliittymää

Valikot, tilaviestit ja oppimiseen kannustava iskulause vaihtavat kieltä yhdessä. Arabia ja heprea tukevat asettelua oikealta vasemmalle; käyttöliittymän kielen vaihto ei muuta tekstitysten sisältöä.

### Paikallinen toisto ja selkeät säätimet

Avaa paikalliset media- ja tekstitystiedostot Tiedosto-valikosta. Käytöstä poistetut toiminnot näkyvät himmennettyinä syineen; valitut tilat korostetaan ja merkitään valintamerkein; tallennuksen aikana näytetään varattu tila.

## Miksi se on hyödyllinen

### Lyhyt matka katselusta harjoitteluun

Työkalupalkin neljä toimintoa pitävät työnkulun suorana: YouTube → Tallenna video → Tekstitykset → Kieli. Erillistä tekstitysten hakupainiketta ei tarvita.

### Oppimateriaali, jonka voit säilyttää

Ajastetut tekstitykset ja luettavat Word- / TXT-tiedostot tukevat sekä kuunteluharjoittelua että myöhempää kertausta. Viennit käyttävät uusia kohteita ja säilyttävät alkuperäiset tiedostot.

### Paikallista käyttöä ilman tekoälyrajapinnan avainta

Paikallinen media ja tallennetut tekstitykset toimivat ilman verkkoa. YouTube toimittaa sivuston tekstitykset ja automaattiset käännökset; sovelluksessa ei ole telemetriaa, se ei lähetä paikallista mediaa eikä vaadi maksullista tekoälyrajapinnan avainta.

## Avoimet asiat ja rajoitukset

### P0 · YouTube-tekstitysten ja -videoiden saatavuus

**Verkkopalvelun toiminnan varmistus**

Viimeisin verkkotarkistus pysähtyi YouTuben kirjautumis- / bottitarkistusvaatimukseen. Verkkolatausten onnistumista tällä hetkellä ei ole varmistettu. Tarkista toiminta aiotussa verkossa ja edustavalla videojoukolla ennen julkista julkaisua.

### P1 · Upotus ja tilirajoitetut videot

**Alustan rajoitus**

Jotkin tekijät tai videot eivät salli upotettua toistoa. Sovelluksen sisäistä Google SSO:ta ei ole toteutettu; selaimen pikavalinta käyttää erillistä kirjautumis- ja toistoistuntoa. Näitä rajoituksia ei voi esittää ratkaistuina.

### P1 · Allekirjoitus ja laajempi Mac-testaus

**Jakelu ja yhteensopivuus**

Paketti on allekirjoitettu ad hoc ilman Developer ID -notarisointia. Apple Silicon macOS 26.5.2:lla on testattu; macOS 27:ää ja Intel-Maceja ei ole. macOS 14 on käyttöönoton kohdeversio, ei todiste kaikkien versioiden testaamisesta.

### P2 · Latauslaatu ja tekstitysten tarkkuus

**Muoto- ja laaturajoitukset**

Tallennus käyttää yhtä kokonaista ääni-/videovirtaa eikä yhdistä erillisiä suuren tarkkuuden virtoja. Paikallinen toisto riippuu koodekkituesta; valinnainen FFmpeg-muunnos voi jättää pois ylimääräiset ääniraidat, HDR:n ja upotetut tekstitykset. ASS/SSA-tuonti tuo vain tekstin. Automaattisissa tekstityksissä, käännöksissä ja aikaan perustuvassa kaksikielisessä yhdistämisessä voi olla virheitä.

### P2 · Oppimishistoria ja opiskelutyökalut

**Ei toteutettu**

Toistohistorian palauttamista, sanastokokoelmia, hajautettua kertausta, OCR:ää ja kuvamuotoisten tekstitysten poimintaa ei ole toteutettu. Tallennetut kieliasetukset eivät tarkoita tallennettua oppimisen edistymistä.

### P2 · Äidinkielisten puhujien tekemä tarkistus

**Kielentarkistus**

Kaikki 24 käyttöliittymäkieltä ja käännetyt iskulauseet läpäisivät vaihtotestit. Tämä osoittaa kattavuuden ja toiminnan, ei jokaisen käännöksen ammattimaista äidinkielistä tarkistusta.

## Mitä on varmistettu

Versiossa 0.5.3 läpäistiin 105 ydintarkistusta, 138 mallin väittämää, 29 tekstitystarkistusta, 60 videon tallennuksen tarkistusta ja 317 natiivin käyttöliittymän väittämää. Kaikki 24 kielivaihtoehtoa valittiin varsinaisesta valikosta; kuusi käyttöliittymäkieltä ja saksan tiiviit asettelut tarkistettiin.

Paikallinen toisto, viennit, tilasiirtymät ja järjestelmän tallennusvalintaikkunat varmistettiin. Verkon ulkopuoliset testiaineistot ja simuloidulla apuohjelmalla tehdyt tallennustestit eivät todista, että YouTube sallii tällä hetkellä tekstitysten tai videoiden lataamisen verkosta. Käyttäjien kirjautumistietoja ei tuotu.

[Yksityiskohtainen tarkistusraportti](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#fi)

Sovelluksen lisenssi on MIT; kolmansien osapuolten osat säilyttävät omat lisenssi-ilmoituksensa. AxonTube ei ole sidoksissa YouTubeen, Googleen tai Appleen.

Asiakirjan päivämäärä: 2026-10-11
