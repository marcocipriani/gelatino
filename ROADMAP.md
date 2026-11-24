# Roadmap

Migliorie pianificate per Gelatino, in ordine di priorità. Stato al 24 novembre
2026: beta in revisione sul web e su Android (Firebase App Distribution).

| # | Voce | Perché | Stima |
| :-- | :-- | :-- | :-- |
| 1 | Cancellazione dell'account dall'app | Requisito di Google Play e App Store | 1-2 giorni |
| 2 | Segnalazione di contenuti e blocco utenti | Requisito App Store per contenuti degli utenti | 2-3 giorni |
| 3 | Provider di tile per la mappa | I tile pubblici OSM non ammettono traffico di produzione | ½ giorno |
| 4 | Build iOS e TestFlight | iOS non è mai stato compilato con Xcode | 1 giorno |
| 5 | Play Console, test interno | Distribuzione Android senza installare APK a mano | ½ giorno |
| 6 | ~~Crash reporting~~ | Fatto il 24/11, manca il deploy | ½ giorno |
| 7 | Enforcement di App Check | Il client è pronto, l'enforcement no | ½ giorno + osservazione |
| 8 | ~~CI su GitHub Actions~~ | Fatto il 24/11 | ½ giorno |
| 9 | Test end-to-end e prove su dispositivi | Mai eseguiti dopo il rinnovo dell'interfaccia | 1 giorno |
| 10 | Link di invito che aprono l'app | Oggi aprono sempre il web | 1 giorno |
| 11 | Inglese | Roma è piena di turisti; l'app parla solo italiano | 2-3 giorni |
| 12 | Catalogo gelaterie curato | Solo Roma; le aggiunte non si possono correggere | da definire |
| 13 | ~~Piccole pulizie~~ | Fatto il 24/11 | ½ giorno |

Le voci 1-5 vanno chiuse prima della pubblicazione sugli store.

---

## Prima degli store

### 1. Cancellazione dell'account

Google Play e App Store richiedono che chi crea un account possa cancellarlo
dall'app. Oggi non è possibile.

Serve una callable che cancelli in un solo passaggio il profilo, i check-in, le
foto su Storage, le amicizie e le proiezioni nei feed degli amici, e poi
l'utente Auth. Va chiesta conferma all'utente, e Google richiede la
riautenticazione recente per `user.delete()`. Il posto naturale è la sezione
Privacy delle Impostazioni, dove va aggiunto anche il link all'informativa sulla
privacy, richiesta dagli store.

### 2. Segnalazioni e blocco

Gelaterie, gusti e foto sono contenuti creati dagli utenti. L'App Store
(linea guida 1.2) chiede un modo per segnalarli e per bloccare un utente.

- "Segnala" su gelateria, gusto e check-in, con una coda in Firestore leggibile
  solo dall'amministratore.
- "Blocca" sul profilo: rimuove l'amicizia e impedisce nuove richieste.

### 3. Tile della mappa

La mappa usa i tile pubblici di OpenStreetMap, la cui policy esclude il traffico
di un'app in produzione. Opzioni: MapTiler, Stadia Maps, Thunderforest, oppure
un server di tile proprio. Il cambio è un URL e una chiave in
`place_map_surface.dart`, più l'attribuzione richiesta dal provider.

### 4. iOS

Icona, schermata di avvio e codice sono pronti, ma l'app non è mai stata
compilata con Xcode né provata su iPhone. Passi: `flutter build ios`, firma,
upload su App Store Connect, TestFlight. Va verificato anche Google Sign-In su
iOS con la configurazione attuale.

### 5. Play Console

La beta Android passa da App Distribution, che non richiede Play Console. Per
gli store serve l'app su Play Console con un test interno. Con Play App Signing
Google firma di nuovo l'app: l'impronta SHA-1 di quella chiave va aggiunta in
Firebase e nella restrizione della chiave API Android.

---

## Affidabilità

### 6. Crash reporting (fatto)

`lib/services/crash_reporting.dart` manda gli errori non gestiti a Crashlytics
su Android e iOS e, sul web, alla callable `reportClientFailure` con il tipo
`uncaught_error` (solo un codice breve, niente messaggio né stack). Nelle build
di debug non parte nulla.

Restano:

- deploy delle Functions prima del prossimo deploy web, altrimenti la callable
  rifiuta il nuovo tipo;
- attivare Crashlytics nella console Firebase;
- su iOS (voce 4), lo script di upload dei dSYM in Xcode.

### 7. App Check

Il client attiva App Check, ma nessun servizio lo richiede. Procedura nel README:
chiave reCAPTCHA Enterprise per il web, registrazione delle app, osservazione
delle metriche, poi enforcement su Firestore, Storage e callable. Attenzione:
Play Integrity non riconosce gli APK installati fuori dal Play Store, quindi
l'enforcement va attivato dopo il passaggio a Play Console (voce 5).

### 8. CI (fatto)

`.github/workflows/ci.yml` gira su ogni push e pull request: `flutter analyze`,
`flutter test`, i test web in Chrome, la build web e `npm test` in
`functions/`. `lib/firebase_options.dart` è ignorato da git, quindi il workflow
ne scrive uno con valori segnaposto.

Resta da aggiungere, se serve, il test end-to-end sugli emulatori
(`tool/run_web_e2e.sh`) in un secondo job, anche solo su `main`.

### 9. Test end-to-end e dispositivi

Il percorso completo a due utenti non è stato eseguito dopo il rinnovo
dell'interfaccia. Da fare anche a mano:

- VoiceOver e TalkBack su accesso, ricerca, mappa e check-in;
- testo al 200%, Riduci movimento, alto contrasto;
- leggibilità all'aperto, in chiaro e in scuro;
- fluidità di mappa e web su telefoni di fascia media.

---

## Prodotto

### 10. Link di invito

La route `/invite/:uid` esiste, ma Android e iOS non dichiarano App Links e
Universal Links: un invito aperto dal telefono finisce nel browser anche con
l'app installata. Servono `intent-filter` con `autoVerify`, l'entitlement
`associated-domains` e i file `assetlinks.json` e `apple-app-site-association`
serviti da Firebase Hosting.

### 11. Inglese

Tutti i testi sono in `AppStrings` e `supportedLocales` contiene solo
l'italiano. Il passaggio a file ARB con `flutter gen-l10n` è meccanico; il
lavoro vero è tradurre in un inglese con lo stesso tono e decidere come
trattare i nomi dei gusti (es. "Fior di latte" resta in italiano?).

### 12. Catalogo gelaterie

Il catalogo iniziale copre solo Roma (307 gelaterie). Le gelaterie aggiunte
dagli utenti sono visibili a tutti ma non si possono correggere né cancellare,
e nessuno controlla i duplicati. Prima di aprire ad altre città:

- proposte di correzione (orari, indirizzo, chiusura definitiva);
- avviso di possibile duplicato in fase di aggiunta, per nome e distanza;
- un ruolo di moderazione, anche solo via console.

Il feed ordinato per data di consumo invece che di pubblicazione resta
rimandato finché l'uso reale non lo giustifica.

### 13. Piccole pulizie (fatto)

- `UserSettings.reducedMotion` è stato rimosso: l'app segue l'impostazione di
  sistema. Le regole Firestore accettano ancora `reduced_motion` per i client
  della beta 1.0.0+2; la chiave si può togliere quando nessuno li usa più.
- L'alto contrasto resta salvato solo sul dispositivo. Sincronizzarlo richiede
  un campo in `UserSettings` e la stessa logica di identità del tema: da fare
  solo se qualcuno lo chiede.
- Lo zoom a pizzico sul web resta disabilitato da Flutter, che sostituisce il
  tag viewport di `web/index.html`. Nessuna modifica: da rivalutare se arrivano
  segnalazioni.
