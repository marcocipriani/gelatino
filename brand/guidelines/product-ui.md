# Product UI

## Splash Screen

- Sfondo: Fior di Panna `#FAFAFA` o Fondente Extra `#1A1A1A`.
- Elemento principale: Melt Pin, non lockup completo.
- Nessun testo secondario o copyright.
- Animazione breve, morbida e non giocosa.

## Navigazione

La UI dell'app e collection-first: all'avvio l'utente atterra sulla propria collezione personale (locali salvati e gusti preferiti). Discovery (mappa, gelaterie) e social (feed amici) restano a un tap di distanza nella navigazione principale. Gli stati attivi usano Fragola Pop `#FF4D6D`; Menta Glaciale, Puffo Elettrico e Sorbetto Yuzu sono shock accent da usare solo con le regole del visual system.

Ordine tab consigliato: Collezione, Feed, Gelaterie, Amici.

Su Fior di Panna, gli shock accent devono essere contenitori con testo e icone in Fondente Extra. Su Fondente Extra possono diventare testo, bordi, glow o feedback di microinterazione.

## Widget

I widget home e lock screen devono usare:

- Melt Pin come segno compatto;
- sfondi Fior di Panna o Fondente Extra;
- testo breve;
- nessun collage fotografico rumoroso;
- un singolo dato utile: posto vicino, gusto salvato, streak o suggerimento.

## Achievement

I badge devono derivare dalla sagoma Melt Pin o da squircles coerenti. Evitare trofei generici e palette rainbow. Le categorie possono usare metalli o accenti funzionali, ma il sistema deve rimanere sobrio.

## Marker Mappa

Il marker usa il Melt Pin colorato secondo lo stato della gelateria per l'utente. Asset: `assets/images/pin-<gusto>.svg`.

| Stato | Colore | Token | Pin |
| --- | --- | --- | --- |
| Ufficiale / default | Fondente Extra | `AppTheme.fondenteExtra` | `pin-fondente.svg` |
| Mi piace (like) | Fragola Pop | `AppTheme.fragolaPop` | `pin-fragola.svg` |
| Preferiti (favorite) | Sorbetto Yuzu | `AppTheme.sorbettoYuzu` | `pin-sorbetto.svg` |
| Salvati / da provare (wishlist) | Menta Glaciale | `AppTheme.mentaGlaciale` | `pin-menta.svg` |
| Aggiunte dall'utente | Puffo Elettrico | `AppTheme.puffoElettrico` | `pin-puffo.svg` |

Precedenza quando coesistono più stati: preferiti > salvati > mi piace > aggiunte dall'utente > default.

Ogni variante deve distinguersi anche per forma, dimensione o icona quando possibile, non solo per colore.
