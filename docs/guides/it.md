# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · **Italiano** · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Impara le lingue del mondo più velocemente con l’IA.**

Versione 0.5.3 · Anteprima per macOS · Chip Apple

[macOS DMG · ZIP · SHA-256](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3) · [Install / 安装](../INSTALL.md) · [GitHub Packages](https://github.com/users/axonvoss-labs/packages/container/package/axontube) · [Package guide](../PACKAGES.md)

Trasforma YouTube nella tua aula di lingue personale. Impara con i video che ami grazie ai sottotitoli e alle traduzioni automatiche di YouTube: leggi due lingue affiancate, riascolta ogni frase e conserva il materiale che conta per te.

**24 lingue dell’interfaccia · Sottotitoli multilingue**

24 indica il numero di lingue disponibili per l’interfaccia. Le lingue dei sottotitoli dipendono dalle tracce disponibili per il video scelto; non è una promessa di padronanza di 24 lingue.

## Schermate

Le schermate sono acquisite dall’applicazione reale 0.5.3. La lingua di ciascuna schermata è indicata separatamente dalla lingua di questo documento.

### Benvenuto e flusso principale

![Benvenuto e flusso principale](../assets/interface-en.png)

Le quattro azioni della barra degli strumenti, i due selettori di sottotitoli visibili, lo slogan localizzato e lo stato disabilitato chiaramente indicato prima di aprire un video. — Schermata dell’applicazione in inglese

### Esercizi incentrati sulle singole frasi

![Esercizi incentrati sulle singole frasi](../assets/interface-study.png)

demo.mp4 — Ricerca di frasi, salto con un clic, frase precedente / successiva, riascolto, ripetizione in ciclo, velocità di riproduzione e scorrimento al seguito della frase corrente. — Schermata dell’applicazione in inglese

### Primo e secondo sottotitolo

![Primo e secondo sottotitolo](../assets/interface-caption-languages.png)

Schermata reale dell’interfaccia in inglese con i menu indipendenti dei sottotitoli, impostati per default su inglese e cinese tradizionale. — Schermata dell’applicazione in inglese

### Aprire un link YouTube

![Aprire un link YouTube](../assets/interface-youtube-dialog.png)

Schermata reale della finestra del link nell’interfaccia in inglese. L’apertura di un link avvia la riproduzione e richiede le due tracce di sottotitoli selezionate. — Schermata dell’applicazione in inglese

## Primi passi

### 1. Apri YouTube

Incolla il link di un video. I sottotitoli disponibili vengono richiesti automaticamente, con l’inglese come prima traccia e il cinese tradizionale come seconda. Il primo recupero può richiedere circa 1–2 minuti; la disponibilità non è garantita.

### 2. Scegli ed esercitati

Usa i due menu a discesa dei sottotitoli visibili. Fai clic su una frase per raggiungerla, riascoltarla o attivarne la ripetizione in ciclo.

### 3. Salva o esporta

Salva video consente di scegliere una cartella per i contenuti accessibili e i sottotitoli disponibili. Esporta sottotitoli bilingui crea file Word, TXT o SRT a partire dai sottotitoli caricati.

### 4. Adattalo a te

Cambia la lingua dell’interfaccia, la velocità di riproduzione, la dimensione dei sottotitoli e lo scostamento temporale di ogni traccia. L’app ricorda le lingue scelte per l’interfaccia e i sottotitoli.

## Funzioni disponibili

### Due tracce di sottotitoli indipendenti

Inglese / cinese tradizionale come impostazione predefinita; scegli fra gli originali e le traduzioni automatiche disponibili per il video corrente. Se il recupero della seconda traccia non riesce, i sottotitoli ottenuti per la prima restano utilizzabili.

### Esercizi incentrati sulle singole frasi

Ricerca di frasi, salto con un clic, frase precedente / successiva, riascolto, ripetizione in ciclo, velocità di riproduzione e scorrimento al seguito della frase corrente.

### Video con sottotitoli sincronizzati

Il salvataggio resta disponibile durante il caricamento dei sottotitoli. Ogni operazione crea una nuova cartella per il video accessibile e, quando sono disponibili sottotitoli, aggiunge le tracce SRT temporizzate e i file di lettura bilingue. È possibile salvare anche il solo video; il lavoro incompleto rimane in una cartella .partial.

### Esportazione in Word, TXT e SRT

Esporta i sottotitoli disponibili applicando gli scostamenti temporali. Word e TXT abbinano i testi in base alla sovrapposizione temporale. Se è caricata una sola traccia, puoi comunque esportarne il contenuto.

### 24 interfacce localizzate

Menu, messaggi di stato e slogan di apprendimento cambiano lingua insieme. Arabo ed ebraico supportano layout da destra a sinistra; cambiare l’interfaccia non modifica il contenuto dei sottotitoli.

### Riproduzione locale e comandi chiari

Apri file multimediali e sottotitoli locali dal menu File. Le azioni non disponibili sono attenuate e accompagnate dal motivo; le modalità selezionate sono evidenziate e contrassegnate da un segno di spunta; durante il salvataggio viene mostrato uno stato occupato.

## Perché è utile

### Dalla visione alla pratica in pochi passi

Quattro azioni nella barra degli strumenti rendono diretto il percorso principale: YouTube → Salva video → Sottotitoli → Lingua. Non serve un pulsante aggiuntivo per recuperare i sottotitoli.

### Materiale di studio da conservare

I sottotitoli temporizzati e i file Word / TXT facili da leggere servono sia per esercitare l’ascolto sia per ripassare in seguito. Le esportazioni usano nuove destinazioni e preservano i file originali.

### Lavoro locale, senza chiavi API di IA

I file multimediali locali e i sottotitoli salvati funzionano offline. YouTube fornisce i sottotitoli del sito e le traduzioni automatiche; l’app non usa telemetria, non carica online i contenuti multimediali locali e non richiede una chiave API di IA a pagamento.

## Problemi aperti e limiti

### P0 · Disponibilità di video e sottotitoli YouTube

**Verifica del servizio reale**

L’ultima verifica online si è fermata alla richiesta di accesso / verifica anti-bot di YouTube. Il successo dei download online nelle condizioni attuali non è stato accertato. Prima della pubblicazione, occorre verificare sulla rete prevista e su un insieme rappresentativo di video.

### P1 · Video con restrizioni di incorporamento o di account

**Restrizione della piattaforma**

Alcuni autori o video non consentono la riproduzione incorporata. Google SSO nell’app non è implementato; il collegamento al browser usa una sessione di accesso e riproduzione separata. Queste restrizioni non possono essere presentate come risolte.

### P1 · Firma e test su più Mac

**Distribuzione e compatibilità**

Il pacchetto ha una firma ad hoc, senza notarizzazione Developer ID. Sono stati eseguiti test su Apple Silicon con macOS 26.5.2; macOS 27 e i Mac Intel non sono stati testati. macOS 14 è il target di distribuzione, non la prova che ogni versione sia stata verificata.

### P2 · Qualità dei download e fedeltà dei sottotitoli

**Limiti di formato e qualità**

Il salvataggio usa un flusso completo audio/video e non unisce flussi separati ad alta risoluzione. Da ASS/SSA viene importato solo il testo. Sottotitoli automatici, traduzioni e abbinamento bilingue basato sui tempi possono contenere errori. La riproduzione locale dipende dai codec supportati. La conversione facoltativa con FFmpeg può omettere tracce audio aggiuntive, HDR e sottotitoli incorporati.

### P2 · Cronologia di apprendimento e strumenti di studio

**Non implementato**

Ripristino della cronologia di riproduzione, raccolte di vocaboli, ripasso dilazionato, OCR ed estrazione di sottotitoli da immagini non sono implementati. Le preferenze linguistiche salvate non sono progressi di apprendimento salvati.

### P2 · Revisione linguistica da parte di madrelingua

**Revisione editoriale**

Tutte le 24 lingue dell’interfaccia e gli slogan localizzati hanno superato le verifiche di cambio lingua. Questo conferma copertura e comportamento, non una revisione professionale di ogni traduzione da parte di madrelingua.

## Cosa è stato verificato

Per 0.5.3: superati 105 controlli del nucleo, 138 asserzioni del modello, 29 controlli dei sottotitoli, 60 controlli del salvataggio video e 317 asserzioni dell’interfaccia nativa. Tutte le 24 lingue sono state selezionate nel menu reale; sono state esaminate sei lingue dell’interfaccia e i layout compatti in tedesco.

Sono stati verificati riproduzione locale, esportazioni, transizioni di stato e finestre native di salvataggio. I dati di prova offline e i test di salvataggio con un programma ausiliario simulato non dimostrano che YouTube consenta attualmente di scaricare sottotitoli o video online. Non sono state importate credenziali degli utenti.

[Resoconto dettagliato delle verifiche](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#it)

L’applicazione usa la licenza MIT; i componenti di terze parti mantengono i propri avvisi. AxonTube non è affiliato a YouTube, Google o Apple.

Data del documento: 2026-10-11
