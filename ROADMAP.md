# Roadmap

Migliorie pianificate per Gelatino, in ordine di priorità. Stato al 24 novembre
2026: beta su web e Android (Firebase App Distribution). Le voci fatte restano
qui con quello che manca, le altre hanno le istruzioni per chiuderle.

| # | Voce | Stato |
| :-- | :-- | :-- |
| 1 | Cancellazione dell'account dall'app | ✅ Fatto |
| 2 | Segnalazione di contenuti e blocco utenti | ✅ Fatto |
| 3 | Provider di tile per la mappa | ⏳ Serve un account del provider |
| 4 | Build iOS e TestFlight | 🟡 Codice pronto, servono Xcode e un account Apple |
| 5 | Play Console, test interno | ⏳ Da fare in console |
| 6 | Crash reporting | ✅ Fatto, Crashlytics da attivare in console |
| 7 | Enforcement di App Check | ⏳ Dopo la voce 5 |
| 8 | CI su GitHub Actions | ✅ Fatto |
| 9 | Test end-to-end e prove su dispositivi | 🟡 E2E verde, prove manuali da fare |
| 10 | Link di invito che aprono l'app | 🟡 Android fatto, iOS aspetta il Team ID |
| 11 | Inglese | ✅ Fatto |
| 12 | Catalogo gelaterie curato | da definire |
| 13 | Piccole pulizie | ✅ Fatto |

Prima della pubblicazione sugli store restano le voci 3, 4 e 5.

---

## Fatto

### 1. Cancellazione dell'account

Impostazioni → Account → *Elimina account*. L'app chiede conferma, fa
riaccedere con Google e chiama la callable `deleteAccount`, che rifiuta sessioni
più vecchie di 5 minuti. La callable cancella i check-in (passando
dall'eliminazione normale, quindi punti, visite e affinità tornano indietro),
amicizie, inviti, profilo, feed, foto su Storage e infine l'utente Auth. Restano
le gelaterie e i gusti aggiunti al catalogo e le segnalazioni inviate.

Lo stesso percorso funziona dal web, quindi su Play Console l'URL per le
richieste di cancellazione può essere `https://gelatino.web.app/settings`.

L'informativa è in `web/privacy.html`, servita su
`https://gelatino.web.app/privacy.html` e collegata dalla sezione Privacy delle
Impostazioni.

### 2. Segnalazioni e blocco

- *Segnala* (icona bandiera) su gelateria, check-in di altri e profilo; sui
  gusti con una pressione lunga sulla pastiglia. Le segnalazioni finiscono in
  `reports/`, che un client può solo creare: si leggono dalla console Firestore.
- *Blocca* sul profilo. Il blocco è lo stato `blocked` sul documento di
  amicizia della coppia, con `requester_uid` uguale a chi blocca. Termina
  l'amicizia o la richiesta, il trigger esistente toglie i post dalle due
  bacheche e `sendFriendRequest` rifiuta nuove richieste in entrambe le
  direzioni. Solo chi ha bloccato vede *Sblocca*; chi è bloccato vede un
  estraneo.

Manca una coda di moderazione con un'interfaccia: per ora la console basta.

### 6. Crash reporting

Gli errori non gestiti vanno a Crashlytics su Android e iOS e, sul web, alla
callable `reportClientFailure` con il tipo `uncaught_error`. Resta da attivare
Crashlytics nella console Firebase (Crashlytics → *Attiva*).

### 8. CI

`.github/workflows/ci.yml`: analyze, test Flutter e web, build web e test delle
Functions su ogni push e pull request. I test sugli emulatori e l'E2E non sono
in CI: richiedono Java, la CLI Firebase e chromedriver.

### 9. Test end-to-end

Il percorso a due utenti (`tool/run_web_e2e.sh`) passa dopo il rinnovo
dell'interfaccia. Per rilanciarlo serve chromedriver sulla porta 4444, della
stessa versione di Chrome:

```sh
npx @puppeteer/browsers install chromedriver@<versione di Chrome>
<percorso>/chromedriver --port=4444 &
firebase emulators:exec --project demo-gelatino \
  --only auth,firestore,storage,functions "bash tool/run_web_e2e.sh"
```

Restano le prove a mano: VoiceOver e TalkBack su accesso, ricerca, mappa e
check-in; testo al 200%, Riduci movimento e alto contrasto; leggibilità
all'aperto in chiaro e in scuro; fluidità di mappa e web su un telefono di
fascia media.

### 11. Inglese

`AppStrings` è bilingue: italiano se il dispositivo è in italiano, inglese
altrimenti, scelto all'avvio (un cambio di lingua vale dal lancio successivo).
I messaggi d'errore scritti accanto alla logica restano letterali italiani e le
classi di errore li traducono quando vengono letti, con la tabella in
`AppStrings.translated`. Un messaggio nuovo che manca dalla tabella resta in
italiano anche in inglese.

Restano in italiano, per scelta o da fare:

- nomi di gusti e formati del catalogo (*Fior di latte* resta *Fior di latte*);
- i testi delle notifiche push, scritti nelle Functions.

### 13. Piccole pulizie

`UserSettings.reducedMotion` è stato rimosso; le regole accettano ancora
`reduced_motion` per i client della beta 1.0.0+2. L'alto contrasto resta per
dispositivo e lo zoom a pizzico sul web resta disabilitato da Flutter.

---

## Da fare

### 3. Tile della mappa

I tile pubblici di OpenStreetMap non ammettono il traffico di un'app in
produzione.

1. Crea un account su MapTiler (piano gratuito: 100.000 tile al mese) e una
   chiave limitata a `gelatino.web.app` e agli ID app `com.gelatino.gelatino`.
2. In `lib/widgets/places/place_map_surface.dart` sostituisci `urlTemplate`
   con
   `'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$_tileKey'`,
   dove `const _tileKey = String.fromEnvironment('MAP_TILE_KEY');`.
3. Aggiorna l'attribuzione: `AppStrings.mapAttribution` diventa
   `'© MapTiler © OpenStreetMap'` e `_MapAttribution` apre
   `https://www.maptiler.com/copyright/`.
4. Passa `--dart-define=MAP_TILE_KEY=...` a ogni build (web, APK, iOS) e al
   job di build in CI, se serve.

Stadia Maps e Thunderforest funzionano allo stesso modo: cambiano l'URL e
l'attribuzione.

### 4. iOS e TestFlight

Già fatto: le dipendenze Swift Package si risolvono (tutti i plugin FlutterFire
usano firebase-ios-sdk 12.19.3) e l'entitlement `associated-domains` è in
`ios/Runner/Runner.entitlements`. La build non è mai arrivata fino in fondo
perché sul Mac manca la piattaforma iOS.

1. Xcode → Settings → Components: installa la piattaforma iOS 26.5.
2. Iscrizione all'Apple Developer Program, poi in Xcode (`ios/Runner.xcodeproj`)
   → target Runner → Signing & Capabilities: scegli il team. Aggiungi le
   capability *Push Notifications* e *Background Modes → Remote notifications*
   per FCM.
3. Firebase Console → Impostazioni progetto → Cloud Messaging: carica la
   chiave APNs (.p8) creata su developer.apple.com.
4. Crashlytics: aggiungi una Run Script Phase al target Runner con
   `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`
   per caricare i dSYM.
5. Universal Links (voce 10): crea `web/.well-known/apple-app-site-association`
   con il Team ID e fai il deploy di Hosting:

   ```json
   {"applinks": {"details": [{"appIDs": ["<TEAM_ID>.com.gelatino.gelatino"],
     "components": [{"/": "/join"}, {"/": "/invite/*"}]}]}}
   ```

6. `flutter build ipa`, poi carica con Xcode Organizer o Transporter e attiva
   TestFlight su App Store Connect.
7. Prova Google Sign-In: lo schema URL `REVERSED_CLIENT_ID` è già in
   `Info.plist`.

### 5. Play Console

1. Crea l'app su Play Console con il pacchetto `com.gelatino.gelatino`.
2. `flutter build appbundle` (firmato con la chiave di upload in
   `android/key.properties`), caricalo nel canale *Test interno*.
3. Play Console → Integrità app → Firma dell'app: copia SHA-1 e SHA-256 della
   chiave di firma di Google, poi:
   - Firebase Console → app Android → aggiungi le due impronte (serve a Google
     Sign-In);
   - Google Cloud → Credenziali → chiave API Android: aggiungi l'SHA-1 alla
     restrizione;
   - aggiungi l'SHA-256 a `web/.well-known/assetlinks.json` accanto a quella
     della chiave di upload e fai il deploy di Hosting, altrimenti i link di
     invito non aprono l'app installata dal Play Store.
4. Scheda dello store: informativa `https://gelatino.web.app/privacy.html`,
   URL di cancellazione `https://gelatino.web.app/settings`, modulo Sicurezza
   dei dati (dati raccolti: elencati nell'informativa).

### 7. App Check

Dopo la voce 5: Play Integrity rifiuta gli APK installati fuori dal Play Store,
quindi i tester di App Distribution verrebbero bloccati.

1. Firebase Console → App Check: registra Android (Play Integrity), iOS (App
   Attest) e web. Per il web crea una chiave reCAPTCHA Enterprise e passala in
   build con `--dart-define=APP_CHECK_WEB_KEY=...`.
2. Osserva le metriche per qualche giorno: le richieste non verificate devono
   arrivare quasi a zero.
3. Attiva l'enforcement su Firestore e Storage dalla console, poi metti
   `ENFORCE_APP_CHECK=true` in `functions/.env` e fai il deploy delle
   Functions.

### 12. Catalogo gelaterie

Il catalogo iniziale copre solo Roma (307 gelaterie). Le gelaterie aggiunte
dagli utenti sono visibili a tutti ma non si possono correggere né cancellare,
e nessuno controlla i duplicati. Prima di aprire ad altre città:

- proposte di correzione (orari, indirizzo, chiusura definitiva);
- avviso di possibile duplicato in fase di aggiunta, per nome e distanza;
- un ruolo di moderazione, anche solo via console.

Il feed ordinato per data di consumo invece che di pubblicazione resta
rimandato finché l'uso reale non lo giustifica.
