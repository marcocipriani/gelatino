# Asset Inventory

## Sorgenti Esistenti

| File | Stato |
| --- | --- |
| [../moodboard.png](../moodboard.png) | Moodboard e fonte palette |
| [../assets/source/logo.png](../assets/source/logo.png) | Melt Pin PNG 1024x1024 |
| [../assets/source/logo-black.png](../assets/source/logo-black.png) | Melt Pin monocromatico PNG 1024x1024 |
| [../assets/source/logo-white.png](../assets/source/logo-white.png) | Melt Pin bianco PNG 1024x1024 |
| [../assets/source/logo-text.png](../assets/source/logo-text.png) | Lockup/wordmark PNG |
| [../assets/source/app-icon.png](../assets/source/app-icon.png) | App icon PNG 1254x1254 |

## Asset Da Creare

### Master Vettoriali

- `assets/source/melt-pin.svg`: simbolo master in Fragola Pop.
- `assets/source/melt-pin-mono.svg`: simbolo monocromatico Fondente Extra e bianco.
- `assets/source/melt-pin-micro.svg`: versione ottimizzata sotto 24 px.
- `assets/source/gelatino-wordmark.svg`: wordmark vettoriale.
- `assets/source/gelatino-lockup-horizontal.svg`: Melt Pin + wordmark.
- `assets/source/gelatino-lockup-stacked.svg`: versione verticale per store e press kit.

### Export PNG

- `assets/exports/png/melt-pin-{32,64,128,256,512,1024}.png`
- `assets/exports/png/melt-pin-white-{32,64,128,256,512}.png`
- `assets/exports/png/gelatino-lockup-horizontal@1x.png`
- `assets/exports/png/gelatino-lockup-horizontal@2x.png`
- `assets/exports/png/gelatino-lockup-horizontal@3x.png`
- `assets/exports/png/app-icon-1024.png`

### App E Platform

- iOS `AppIcon.appiconset` rigenerato dal master 1024 px.
- Android adaptive icon: foreground Melt Pin, background Fragola Pop o Fior di Panna, mipmap density.
- Web icons reali PNG 192 e 512 px.
- `favicon.svg` e `favicon.ico`.
- `.icns` solo se viene aggiunto un target macOS; non serve per iOS.
- `.ico` e un formato web/favicon, non un formato Android.

### Prodotto

- Marker mappa: default, selected, visited, saved, closed, cluster.
- Badge base achievement in versione locked/unlocked.
- Pattern/skeleton derivati dal Melt Pin.
- Set icone custom per gusti o categorie principali.
- Asset motion per splash: Rive, Lottie o SVG animato.

### Brand E Press

- `assets/exports/pdf/gelatino-logo-sheet.pdf`
- `assets/exports/pdf/gelatino-brand-onepager.pdf`
- Kit stampa con logo, lockup, palette e usage.
- File Figma sorgente con componenti e varianti.

## Audit Tecnico

- I file in `web/icons/*.png` e `web/favicon.png` risultano codificati come JPEG pur avendo estensione `.png`; vanno rigenerati come PNG reali.
- La palette dell'app deve riferirsi ai token ufficiali: Fior di Panna `#FAFAFA`, Fondente Extra `#1A1A1A`, Fragola Pop `#FF4D6D`, Menta Glaciale `#00E6B8`, Puffo Elettrico `#00BFFF`, Sorbetto Yuzu `#FFEA00`.
- Gli accenti legacy `#A9E5C0` e `#FFD166` non sono piu colori ufficiali del brand.
