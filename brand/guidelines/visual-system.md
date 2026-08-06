# Visual System

## Palette Ufficiale

La palette ufficiale Gelatino e una base premium quasi monocromatica con tre accenti shock. I nomi gusto sono parte del sistema: designer e sviluppatori devono usarli come linguaggio comune.

| Nome gusto | HEX | Flutter token | Ruolo |
| --- | --- | --- | --- |
| Fior di Panna | `#FAFAFA` | `AppTheme.fiorDiPanna` | Sfondo base light, morbido e luminoso |
| Fondente Extra | `#1A1A1A` | `AppTheme.fondenteExtra` | Sfondo base dark, testi, segno monocromatico |
| Fragola Pop | `#FF4D6D` | `AppTheme.fragolaPop` | Primary accent, CTA, logo, marker attivi |
| Menta Glaciale | `#00E6B8` | `AppTheme.mentaGlaciale` | Shock accent fresco, tecno, ad alto impatto |
| Puffo Elettrico | `#00BFFF` | `AppTheme.puffoElettrico` | Shock accent divertente, nostalgico, saturo |
| Sorbetto Yuzu | `#FFEA00` | `AppTheme.sorbettoYuzu` | Shock accent acido, tagliente, rarissimo |

## Gerarchia

Fragola Pop e il colore guida dell'app. Gli shock accent non competono con Fragola Pop: servono a dare picchi di energia a badge, tag, microinterazioni e momenti speciali.

Fior di Panna e Fondente Extra sono i due separatori neutri del sistema. Quando due colori forti rischiano di vibrare, va sempre inserito uno di questi due.

## Semantica Colori Stati

Gli stati utente su gelaterie e gusti hanno un colore fisso, coerente ovunque (marker mappa, bottoni Collezione, pill, filtri):

| Stato | Colore | Token |
| --- | --- | --- |
| Mi piace (like) | Fragola Pop | `AppTheme.fragolaPop` |
| Preferiti (favorite) | Sorbetto Yuzu (giallo) | `AppTheme.sorbettoYuzu` |
| Salvati / da provare (wishlist) | Menta Glaciale (verde) | `AppTheme.mentaGlaciale` |
| Aggiunte dall'utente | Puffo Elettrico (blu) | `AppTheme.puffoElettrico` |
| Ufficiale / default | Fondente Extra | `AppTheme.fondenteExtra` |

## Light & Dark Mode

| Elemento | Light | Dark |
| --- | --- | --- |
| Sfondo app | Fior di Panna `#FAFAFA` | Fondente Extra `#1A1A1A` |
| Superficie card | Bianco `#FFFFFF` o Fior di Panna | Fondente Extra con bordo leggero |
| Testo primario | Fondente Extra `#1A1A1A` | Fior di Panna / bianco caldo |
| CTA primaria | Fragola Pop `#FF4D6D` | Fragola Pop `#FF4D6D` |
| Shock accent | Contenitore pieno, testo Fondente Extra | Testo, bordo, glow o microinterazione |

## Regole Di Accoppiamento

### Su Fior Di Panna

Usare Menta Glaciale, Puffo Elettrico e Sorbetto Yuzu come colore di riempimento per badge, tag, pill e pulsanti secondari. Dentro questi elementi, testo e icone devono essere sempre Fondente Extra.

Fragola Pop e l'unico accento abbastanza solido da poter essere usato direttamente come testo o icona su Fior di Panna.

### Su Fondente Extra

Gli shock accent possono essere usati direttamente per testi, icone, bordi luminosi e microinterazioni. Per tag o chip: testo shock su fondo Fondente Extra, bordo dello stesso colore al 20% circa, glow leggero solo quando serve feedback.

Fragola Pop resta ideale per CTA, floating action button e marker attivi.

## Divieti Assoluti

- No neon su panna: mai usare Menta Glaciale, Puffo Elettrico o Sorbetto Yuzu per testi sottili o icone lineari direttamente su Fior di Panna.
- No shock vs shock: mai sovrapporre o affiancare due shock accent senza separatore neutro.
- No Puffo su Fragola: sui pulsanti colorati il testo deve essere Fior di Panna se il fondo e scuro/intenso, oppure Fondente Extra se il fondo e chiaro/neon.
- Sorbetto Yuzu va usato con estrema parsimonia: badge rarissimi, highlight eccezionali o icona "Miglior Gelato".

## Tipografia

L'app usa Plus Jakarta Sans. La guida tipografica si allinea quindi al prodotto:

- Display: Plus Jakarta Sans ExtraBold/Black.
- Titoli: Plus Jakarta Sans Bold.
- Body: Plus Jakarta Sans Medium/Regular.
- Label e chip: Plus Jakarta Sans SemiBold.

Evitare serif decorativi nella UI principale. Eventuali serif possono comparire solo in materiali editoriali o campagne.

## Forme

Le superfici principali usano curve morbide e squircles tramite `figma_squircle`.

- Small: 8-12 dp, chip e controlli compatti.
- Medium: 20-24 dp, card, input, pill button.
- Large: 32 dp, bottom sheet e pannelli principali.

## Iconografia

Le icone UI devono essere monocromatiche, con stroke pulito e peso coerente. Per stati attivi usare riempimenti o Fragola Pop, non composizioni multicolore. Le icone custom di brand devono derivare dalla geometria del Melt Pin.

## Fotografia E Illustrazione

Fotografia: gelato reale, texture autentiche, luci calde, mani e contesti artigianali quando utili. Evitare stock generico, bambini/cartoon e composizioni troppo zuccherose.

Illustrazione: minimale, morbida, geometrica. Usare il Melt Pin come origine di pattern, badge e marker, non come decorazione ripetuta senza logica.
