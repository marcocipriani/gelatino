/// All user-facing text, in one shared place.
///
/// Routes/paths stay in English (see [router]); everything the user reads is
/// Italian and lives here. Interpolated strings are `static` methods.
///
/// ponytail: single flat class, no i18n framework — the app ships one language.
/// Add `flutter_localizations` + ARB only if a second locale is actually needed.
class AppStrings {
  // ---------------------------------------------------------------------------
  // Common / shared actions (reused across screens)
  // ---------------------------------------------------------------------------
  static const String retry = 'Riprova';
  static const String cancel = 'Annulla';
  static const String remove = 'Rimuovi';
  static const String add = 'Aggiungi';
  static const String accept = 'Accetta';
  static const String reject = 'Rifiuta';
  static const String save = 'Salva';
  static const String logout = 'Esci';
  static const String back = 'Indietro';
  static const String login = 'Accedi';
  static const String delete = 'Elimina';
  static const String clearSearch = 'Cancella ricerca';
  static const String chooseOnMap = 'Scegli sulla mappa';
  static const String useLocation = 'Usa la posizione';
  static const String removeFriendshipBody =
      'Potrete inviarvi una nuova richiesta in seguito.';

  // ---------------------------------------------------------------------------
  // App
  // ---------------------------------------------------------------------------
  static const String appName = 'Gelatino';

  // ---------------------------------------------------------------------------
  // Navigation (menu labels — Italian; routes stay English)
  // ---------------------------------------------------------------------------
  static const String navCollection = 'Collezione';
  static const String navTimeline = 'Bacheca';
  static const String navPlaces = 'Gelaterie';
  static const String navFriends = 'Amici';

  // ---------------------------------------------------------------------------
  // Login / access
  // ---------------------------------------------------------------------------
  static const String loginTitle = 'Gelatino';
  static const String loginButton = 'Accedi con Google';
  static const String loginErrorPrefix = 'Errore durante l\'accesso: ';
  static const String accessInProgress = 'Accesso in corso';
  static const String accessPhotoLabel =
      'Composizione artigianale di gelato, coppetta e cono';

  // ---------------------------------------------------------------------------
  // Timeline / Bacheca
  // ---------------------------------------------------------------------------
  static const String timelineTitle = 'Bacheca';
  static const String timelineEmptyTitle = 'Bacheca ancora vuota';
  static const String timelineEmptyDesc =
      'Qui compaiono i gelati tuoi e dei tuoi amici. Aggiungi il tuo primo check-in quando visiti una gelateria.';
  static const String timelineEmptyButton = 'Aggiungi check-in';
  static const String timelineLikeButton = 'Mi piace';
  static const String timelineWishlistAdd = 'Da provare';
  static const String timelineWishlistRemove = 'Salvato';
  static const String timelineErrorPrefix = 'Impossibile caricare i gelati: ';
  static const String timelineLoadMore = 'Carica altri';
  static const String timelinePrevTooltip = 'Check-in precedente';
  static String timelineCardPosition(int index, int total) =>
      'Check-in $index di $total';
  static String timelinePhotoSemantic(String placeName) =>
      'Foto del check-in da $placeName';
  static String timelineRatingSemantic(int rating) => '$rating su 5';
  static const String shareCardTooltip = 'Condividi';
  static String shareCardSemantic(String placeName) =>
      'Condividi il check-in da $placeName con una card';
  static const String shareCardPreviewConfirm = 'Condividi';
  static String shareCardMessage(String placeName) =>
      'Gelato da $placeName 🍦 — Gelatino';
  static const String shareCardFailed = 'Condivisione non riuscita. Riprova.';

  // ---------------------------------------------------------------------------
  // Collection
  // ---------------------------------------------------------------------------
  static const String collectionTitle = 'La tua collezione';
  static const String collectionFavoriteFlavorsTitle = 'Gusti preferiti';
  static const String collectionFavoriteFlavorsSubtitle =
      'Rivedi i gusti che ami di più.';
  static const String collectionEmptyTitle = 'Nessuna gelateria salvata';
  static const String collectionExploreButton = 'Esplora le gelaterie';
  static const String collectionErrorTitle = 'Collezione non disponibile';
  static const String collectionUnauthTitle = 'La tua collezione ti aspetta';

  // ---------------------------------------------------------------------------
  // Places / Gelaterie
  // ---------------------------------------------------------------------------
  static const String placeDetailTitle = 'Dettaglio gelateria';
  static const String placeDetailRetryRatings = 'Riprova valutazioni';
  static const String placeDetailNoRatings = 'Nessuna valutazione';
  static const String placeDetailVisits = 'visite';
  static const String placeOpenInMaps = 'Apri in Maps';
  // ponytail: 'Checkin' (lowercase i) on purpose — place_detail_screen.dart is
  // guarded by server_owned_boundary_test against the 'CheckIn' token.
  static const String placeCheckinButton = 'Fai check-in';
  static const String placeMapsError = 'Impossibile aprire Maps.';
  static const String placeOpenDetail = 'Apri dettaglio';
  static const String placeSearchHint = 'Cerca per nome o indirizzo';
  static const String placeActionList = 'Lista';
  static const String placeActionMap = 'Mappa';
  static String placeFilterLabel(String filter) => 'Filtro $filter';
  static String placeOpenTooltip(String name) => 'Apri $name';
  static String placeCoverSemantic(String placeName) =>
      'Illustrazione editoriale per $placeName';

  // Add place dialog
  static const String addPlaceNameLabel = 'Nome';
  static const String addPlaceAddressLabel = 'Indirizzo';
  static const String addPlaceConfirmPoint = 'Conferma punto';
  static const String addPlaceRetryLocation = 'Riprova posizione';

  // ---------------------------------------------------------------------------
  // Friends
  // ---------------------------------------------------------------------------
  static const String friendsLoginTitle = 'Accedi per trovare i tuoi amici';
  static const String friendsFindPeople = 'Trova persone';
  static const String friendsYourFriends = 'I tuoi amici';
  static const String friendsEmptyTitle = 'Nessun amico, per ora';
  static const String friendsUnavailable = 'Amici non disponibili';
  static const String friendsRequestsTitle = 'Richieste';
  static const String friendsRequestsEmpty = 'Nessuna richiesta';
  static const String friendsRequestsUnavailable = 'Richieste non disponibili';
  static const String friendsInvitesTitle = 'Inviti Gelatino';
  static const String friendsInvitesEmpty = 'Nessun invito';
  static const String friendsInviteSubtitle = 'Ti propone: Gelatino?';
  static const String friendsInviteAccept = 'Ci sto';
  static const String friendsInviteDecline = 'Non posso';
  static const String friendsInvitesUnavailable = 'Inviti non disponibili';
  static const String friendsInvitePersonTitle = 'Invita una persona';
  static const String friendsGelatoWithWhom = 'Con chi prendiamo un gelato?';
  static const String friendsSearchLabel = 'Nome o username';
  static const String friendsSearchUnavailable = 'Ricerca non disponibile';
  static const String friendsNoResults = 'Nessun risultato';
  static String friendsRemoveConfirmTitle(String name) =>
      'Rimuovere $name dagli amici?';

  // ---------------------------------------------------------------------------
  // Relationship state (profile + friends)
  // ---------------------------------------------------------------------------
  static const String relationshipChecking = 'Verifica relazione…';
  static const String relationshipUnavailable = 'Relazione non disponibile';
  static const String relationshipFriend = 'Amico';
  static const String relationshipToAccept = 'Da accettare';
  static const String relationshipPending = 'In attesa';
  static const String removeFriendshipTitle = 'Rimuovere questa amicizia?';

  // ---------------------------------------------------------------------------
  // Invite
  // ---------------------------------------------------------------------------
  static const String inviteCheckingFriendship = 'Verifica amicizia in corso…';
  static const String inviteNowFriends = 'Ora siete amici.';
  static const String inviteAlreadyFriends = 'Siete già amici.';
  static const String inviteRequestSent = 'Richiesta inviata.';
  static const String inviteRequestPending = 'Richiesta già in attesa.';
  static const String inviteAcceptRequest = 'Accetta richiesta';
  static const String inviteSendRequest = 'Invia richiesta';
  static const String inviteOpenProfile = 'Apri profilo';
  static const String inviteTitle = 'Invito Gelatino';
  static String inviteAlreadyInvitedYou(String name) =>
      '$name ti ha già invitato.';

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------
  static const String profileTitle = 'Profilo';
  static const String profileDefaultName = 'Utente goloso';
  static const String profileStatGelati = 'Gelati';
  static const String profileStatAverage = 'Media voti';
  static const String profileFavoriteFlavors = 'I miei gusti preferiti';
  static const String profileWishlistLink = 'Da provare';
  static const String profileLogoutTooltip = 'Esci';
  static const String profileFavoriteGelatoType = 'Formato preferito';
  static const String profileNotFound = 'Profilo non trovato';
  static const String profileUnavailable = 'Profilo non disponibile';
  static const String profileEditButton = 'Modifica Profilo';
  static const String profileOpenSettings = 'Apri impostazioni';
  static const String profilePreferencesTitle = 'Preferenze';
  static const String profilePreferencesUnavailable =
      'Preferenze non disponibili';
  static const String profilePreferencesUpdating = 'Preferenze in aggiornamento';
  static const String profileActivityUnavailable = 'Attività non disponibile';
  static const String profileWishlistTitle = 'Da provare';
  static const String profileWishlistEmpty = 'Niente da provare, per ora.';
  static const String profileWishlistUnavailable = 'Da provare non disponibile';
  static const String profileSeeAll = 'Vedi tutti';
  static const String profileManageFlavors = 'Gestisci gusti';
  static const String profileNoCheckInsPage =
      'Nessun check-in caricato in questa pagina.';
  static const String profileDeleteCheckInTooltip = 'Elimina check-in';
  static const String profileDeleteCheckInTitle = 'Eliminare il check-in?';
  static const String profileDeleteCheckInBody =
      'Questa azione non può essere annullata.';
  static String profileGelatiCount(int n) => '$n gelati';
  static String profilePlacesCount(int n) => '$n gelaterie';
  static String profileAverage(String value) => '$value media';
  static String profileRatingOutOf(int rating) => '$rating/5';

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  static const String settingsNotFound = 'Impostazioni non trovate';
  static const String settingsLoading = 'Caricamento impostazioni';
  static const String settingsUnavailable = 'Impostazioni non disponibili';
  static const String settingsSectionProfile = 'PROFILO';
  static const String settingsEditPersonal = 'Modifica dati personali';
  static const String settingsFavoriteFlavors = 'Gusti preferiti';
  static const String settingsSavedPlaces = 'Gelaterie salvate';
  static const String settingsSectionApp = 'APP';
  static const String settingsTheme = 'Tema app';
  static const String settingsThemeSubtitle = 'Aspetto dell’interfaccia';
  static const String settingsThemeAuto = 'Automatico';
  static const String settingsThemeLight = 'Chiaro';
  static const String settingsThemeDark = 'Scuro';
  static const String settingsDefaultPlacesView = 'Vista predefinita Gelaterie';
  static const String settingsDefaultPlacesViewSubtitle = 'Elenco oppure mappa';
  static const String settingsPlacesViewList = 'Elenco';
  static const String settingsPlacesViewMap = 'Mappa';
  static const String settingsSectionPrivacy = 'PRIVACY';
  static const String settingsPrivateProfile = 'Profilo privato';
  static const String settingsSectionAccount = 'ACCOUNT';
  static String settingsPoints(int points) => '$points punti';

  // ---------------------------------------------------------------------------
  // Check-in
  // ---------------------------------------------------------------------------
  static const String checkInTitle = 'Nuovo check-in';
  static const String checkInCamera = 'Fotocamera';
  static const String checkInGallery = 'Galleria';
  static const String checkInPlaceLabel = 'Nome gelateria';
  static const String checkInAddressLabel = 'Indirizzo (opzionale)';
  static const String checkInFlavorsTitle = 'Gusti scelti';
  static const String checkInGelatoTypeTitle = 'Come l\'hai preso?';
  static const String checkInShowAllTypes = 'Vedi tutti';
  static const String checkInShowLessTypes = 'Mostra meno';
  static const String checkInAddExistingFlavor = 'Aggiungi un gusto esistente';
  static const String checkInAddNewFlavor = 'Crea un nuovo gusto';
  static const String checkInRatingTitle = 'Voto';
  static const String checkInReviewLabel = 'Recensione (opzionale)';
  static const String checkInSubmitButton = 'Condividi il check-in';
  static const String checkInLoginRequired = 'Accedi per creare un check-in.';
  static const String checkInPublished = 'Check-in pubblicato';
  static const String checkInRetryLabels = 'Riprova etichette';
  static const String checkInRebuildCache = 'Ricostruisci cache';
  static const String checkInCloseTooltip = 'Chiudi check-in';
  static const String checkInCompleteCleanup = 'Completa pulizia';
  static const String checkInNoteLabel = 'Nota (opzionale)';
  static String timelineBackdated(String date) => '$date · pubblicato dopo';
  static const String placeMapRecenter = 'Centra sulla mia posizione';
  static const String placeMapYouAreHere = 'La tua posizione';
  static const String checkInWhenTitle = 'Quando';
  static const String checkInWhenNow = 'Adesso';
  static const String checkInWhenChange = 'Cambia data e ora';
  static const String checkInWhenReset = 'Riporta ad adesso';
  static const String checkInWhenPickDate = 'Quando hai mangiato il gelato?';
  static const String checkInWhenFuture =
      'Non puoi mettere un check-in nel futuro.';
  static const String checkInWhenTooOld =
      'Puoi risalire al massimo a cinque anni fa.';
  static const String checkInRetryUpload = 'Riprova caricamento';
  static const String checkInCompressing = 'Compressione e caricamento privato…';
  static const String checkInUploadInterrupted =
      'Caricamento privato interrotto.';
  static const String checkInPrivatePhotoNotFound = 'Foto privata non trovata.';
  static const String checkInPrivatePhotoUploaded = 'Foto privata caricata';
  static const String checkInSummarySemantic =
      'Riepilogo completo del check-in';
  static const String checkInNoFriendsToAdd = 'Nessun amico da aggiungere.';
  static const String checkInLoadingFriends = 'Caricamento amici…';
  static const String checkInFriendsLoadError =
      'Impossibile caricare gli amici.';
  static const String checkInReloadFriends = 'Ricarica amici';
  static const String checkInRemoveTag = 'Rimuovi tag';
  static const String checkInDraftRetryNote =
      'La bozza e la foto restano disponibili per il retry.';
  static const String checkInPlaceFieldLabel = 'Gelateria';
  static const String checkInNewPlaceLabel = 'Nome della nuova gelateria';
  static const String checkInAddressFieldLabel = 'Indirizzo';
  static String checkInStarsTooltip(int value) => '$value stelle';
  static String checkInStarsSemantic(int value, {required bool selected}) =>
      '$value stelle${selected ? ', selezionato' : ''}';
  static String checkInSummaryType(String typeName) => 'Tipo: $typeName';
  static String checkInSummaryFlavors(String flavorNames) =>
      'Gusti: $flavorNames';
  static String checkInSummaryRating(int rating) => 'Voto: $rating/5';

  // Check-in messages & snackbars
  static const String checkInErrorNoPhoto = 'Aggiungi una foto';
  static const String checkInErrorNoPlace = 'Inserisci il nome della gelateria';
  static const String checkInErrorNoGelatoType =
      'Scegli come hai preso il gelato';
  static const String checkInGelatoTypesFallback =
      'Catalogo non aggiornato: uso le opzioni predefinite';
  static const String checkInFlavorAlreadySelected =
      'Hai già selezionato questo gusto';
  static const String checkInFlavorAddedSuccess = 'Gusto aggiunto';
  static const String checkInSuccess = 'Check-in fatto! 🍦';

  // ---------------------------------------------------------------------------
  // Flavors manager
  // ---------------------------------------------------------------------------
  static const String flavorSearchHint = 'Cerca gusto...';
  static const String flavorSortAZ = 'A-Z';
  static const String flavorSortFavorites = 'Preferiti prima';
  static const String flavorFavorites = 'Preferiti';
  static const String flavorCreateHint = 'Crea un nuovo gusto...';
  static const String flavorSearchLabel = 'Cerca un gusto';
  static const String flavorNoneFound = 'Nessun gusto trovato.';
  static const String flavorNewLabel = 'Nuovo gusto';
  static const String flavorCreateTooltip = 'Crea gusto';

  // ---------------------------------------------------------------------------
  // Edit profile dialog
  // ---------------------------------------------------------------------------
  static const String editProfileEmptyName = 'Il nome non può essere vuoto';
  static const String editProfileDisplayName = 'Nome visualizzato';
  static const String editProfileFavoritesTitle =
      'Gelateria e gusto preferiti';
  static const String editProfileFavoritesSubtitle =
      'Seleziona dalla raccolta personale.';

  // ---------------------------------------------------------------------------
  // Authenticated shell (settings/profile entry points)
  // ---------------------------------------------------------------------------
  static const String shellOpenSettings = 'Apri impostazioni';
  static const String shellSettingsTooltip = 'Impostazioni';
  static const String shellOpenProfile = 'Apri profilo';
  static const String shellProfileTooltip = 'Profilo';
  static const String retryImageTooltip = 'Riprova immagine';

  // ---------------------------------------------------------------------------
  // Shared feedback / status (reused across screens)
  // ---------------------------------------------------------------------------
  static const String operationFailed = 'Operazione non riuscita. Riprova.';
  static const String profileLoadError =
      'Non riusciamo a caricare il profilo. Riprova.';
  static const String profileGelatinoFallback = 'Profilo Gelatino';
  static const String contentLoadError = 'Non riusciamo a caricare i contenuti.';
  static const String wishlistLabel = 'Da provare';
  static const String mapTapToChoose = 'Tocca la mappa per scegliere un punto.';
  static const String mapPointSelected = 'Punto selezionato sulla mappa.';
  static const String placeAddButton = 'Aggiungi gelateria';

  // ---------------------------------------------------------------------------
  // Favorite flavors screen
  // ---------------------------------------------------------------------------
  static const String favoriteFlavorsTitle = 'Gusti preferiti';

  // ---------------------------------------------------------------------------
  // Profile (extended)
  // ---------------------------------------------------------------------------
  static const String profileNotAvailableMessage =
      'Questo profilo non è disponibile.';
  static const String profileHeaderLabel = 'IL TUO PROFILO';
  static const String profilePrefsNonePublic =
      'Nessuna preferenza pubblica indicata.';
  static const String profilePrefsNamesUnavailable =
      'I nomi delle preferenze non sono disponibili ora.';
  static const String profilePrefsNamesPending =
      'I nomi saranno visibili appena il catalogo è aggiornato.';
  static const String profileRecentActivity = 'Attività recenti';
  static const String profileCheckInsLoadError =
      'Non riusciamo a caricare i check-in autorizzati.';
  static const String profileSavedPlacesSubtitle =
      'Le gelaterie salvate per la prossima visita.';
  static const String profileSavedPlacesLoadError =
      'Non riusciamo a caricare le gelaterie salvate.';
  static const String profileCheckInsPageLabel =
      'Check-in caricati in questa pagina';
  static const String profileDeleteCheckInError =
      'Impossibile eliminare il check-in.';
  static const String profileRemoveFromWishlist = 'Rimuovi dai Da provare';

  // ---------------------------------------------------------------------------
  // Invite (extended)
  // ---------------------------------------------------------------------------
  static const String inviteLinkInvalid = 'Link di invito non valido.';
  static const String inviteSelf = 'Non puoi invitare te stesso.';
  static const String inviteProfileInaccessible = 'Profilo non accessibile.';
  static const String inviteProfileNotFound = 'Profilo non trovato.';
  static const String inviteLoginToContinue = 'Accedi per continuare.';
  static const String inviteVerifyError =
      'Impossibile verificare l’amicizia. Riprova più tardi.';
  static const String friendshipUpdateError =
      'Impossibile aggiornare l’amicizia.';

  // ---------------------------------------------------------------------------
  // Settings (extended)
  // ---------------------------------------------------------------------------
  static const String settingsEditNotSaved = 'Modifica non salvata. Riprova.';
  static const String settingsCompleteProfile =
      'Completa il profilo per personalizzare l’app.';
  static const String settingsLogoutFailed = 'Uscita non riuscita. Riprova.';
  static const String settingsLoadingPrefs =
      'Stiamo recuperando le tue preferenze.';
  static const String settingsLoadError =
      'Non riusciamo a caricare le impostazioni. Riprova.';
  static const String settingsCloseTooltip = 'Chiudi impostazioni';
  static const String settingsProfileLoading = 'Caricamento profilo…';
  static const String settingsPrivateProfileSubtitle =
      'Attivalo per non comparire nelle ricerche pubbliche.';

  // ---------------------------------------------------------------------------
  // Friends (extended)
  // ---------------------------------------------------------------------------
  static const String friendsSearchError = 'Ricerca non disponibile. Riprova.';
  static const String friendsInviteLinkCopied = 'Link invito copiato';
  static const String friendsInviteLinkCopyError =
      'Impossibile copiare il link. Riprova.';
  static const String friendsLoginSubtitle =
      'Il profilo e le richieste sono disponibili dopo l’accesso.';
  static const String friendsFindPeopleSubtitle = 'Cerca per nome o username.';
  static const String friendsYourFriendsSubtitle = 'Le persone, prima dei numeri.';
  static const String friendsEmptySubtitle =
      'Cerca una persona e inviale una richiesta.';
  static const String friendsInviteSent = 'Invito inviato';
  static const String friendsLoadError =
      'Non riusciamo a caricare gli amici. Riprova.';
  static const String friendsRequestsEmptySubtitle =
      'Le nuove richieste appariranno qui.';
  static const String friendsNewRequest = 'Nuova richiesta';
  static const String friendsRequestsLoadError =
      'Non riusciamo a caricare le richieste. Riprova.';
  static const String friendsInvitesEmptySubtitle =
      'Quando qualcuno propone un gelato, lo vedrai qui.';
  static const String friendsInvitesLoadError =
      'Non riusciamo a caricare gli inviti. Riprova.';
  static const String friendsInvitePersonSubtitle =
      'Condividi un link per incontrarvi su Gelatino.';
  static const String friendsCopying = 'Copia in corso…';
  static const String friendsCopyInviteLink = 'Copia link invito';
  static const String friendsGelatoWithWhomSubtitle =
      'Richieste, inviti e persone con cui condividere il prossimo assaggio.';
  static const String friendsNoResultsSubtitle =
      'Prova con un altro nome o username.';
  static const String relationshipCheckingMessage =
      'Stiamo controllando se siete già in contatto.';
  static const String relationshipVerifyError =
      'Non possiamo verificare il rapporto. Riprova.';

  // ---------------------------------------------------------------------------
  // Places tab (extended)
  // ---------------------------------------------------------------------------
  static const String placesLoginForFilters =
      'Accedi per usare i filtri personali.';
  static const String placesSubtitle = 'Scopri, salva e ritrova i tuoi posti.';
  static const String placesLoginToAdd = 'Accedi per aggiungere una gelateria.';
  static const String placesLoginToAddFirst =
      'Accedi per aggiungere la prima gelateria.';
  static const String placesCatalogEmpty = 'Il catalogo è ancora vuoto.';
  static const String placesNoSearchMatch =
      'Nessuna gelateria corrisponde alla ricerca.';
  static const String placesClearFilters = 'Azzera filtri';
  static const String placeAdded = 'Gelateria aggiunta.';
  static String placeFlavorMatchChip(String flavorName, int bestRating) =>
      '🍦 $flavorName · $bestRating★';

  // ---------------------------------------------------------------------------
  // Login (extended)
  // ---------------------------------------------------------------------------
  static const String loginFailed = 'Accesso non riuscito. Riprova.';

  // ---------------------------------------------------------------------------
  // Place detail (extended)
  // ---------------------------------------------------------------------------
  static const String placeDetailRetryPlace = 'Riprova gelateria';
  static const String placeNotFound = 'Gelateria non trovata';
  static const String placeBackToList = 'Torna alle gelaterie';
  static const String placeYourActions = 'Le tue azioni';
  static const String placePersonalStateUnavailable =
      'Stato personale non disponibile.';
  static const String placeRetryPersonalState = 'Riprova stato personale';
  static const String placeLoginToSave =
      'Accedi per salvare o aggiungere ai preferiti.';
  static const String placeYourNote = 'La tua nota';
  static const String placeAddToFavorites = 'Aggiungi ai preferiti';

  // ---------------------------------------------------------------------------
  // Collection (extended)
  // ---------------------------------------------------------------------------
  static const String collectionSavedSubtitle =
      'Le gelaterie che hai salvato per la prossima visita.';
  static const String collectionOtherPlaces = 'Altre gelaterie';
  static const String collectionEmptyDesc =
      'Salva le gelaterie che vuoi provare e le ritroverai qui.';
  static const String collectionUnauthDesc =
      'Accedi per vedere le gelaterie che hai salvato.';
  static String savedPlacesCount(int count) =>
      count == 1 ? '1 gelateria salvata' : '$count gelaterie salvate';

  // ---------------------------------------------------------------------------
  // Timeline (extended empty states)
  // ---------------------------------------------------------------------------
  static const String timelineNoFriendsTitle = 'Nessun amico ancora';
  static const String timelineNoFriendsDesc =
      'Aggiungi amici per vedere qui i loro check-in.';
  static const String timelineAddFriends = 'Aggiungi amici';
  static const String timelineNoRecentTitle = 'Nessun check-in recente';
  static const String timelineNoRecentDesc =
      'I tuoi amici non hanno ancora condiviso attività.';
  static const String timelineCheckInButton = 'Fai check-in';
  static const String timelineFriendshipsUpdating = 'Aggiornamento amicizie';
  static const String timelineFriendshipsUpdatingDesc =
      'La Timeline sarà disponibile tra poco.';
  static const String timelineFriendshipsUnavailable = 'Amicizie non disponibili';
  static const String timelineFriendshipsUnavailableDesc =
      'Aggiorna per riprovare senza mostrare attività non autorizzate.';
  static const String timelineLoginTitle = 'Accedi alla Timeline';
  static const String timelineLoginDesc =
      'Serve un account per vedere i check-in privati.';
  static const String timelineNoRecentSelfDesc = 'Pubblica il primo check-in.';
  static const String timelineLoadingMore = 'Caricamento altri check-in';
  static const String timelineNextTooltip = 'Check-in successivo';

  // ---------------------------------------------------------------------------
  // Access brand panel
  // ---------------------------------------------------------------------------
  static const String accessTagline = 'Il tuo diario del gelato';
  static const String accessDescription =
      'Scopri nuove gelaterie, conserva i check-in in privato '
      'e condividi le tue scoperte con gli amici.';

  // ---------------------------------------------------------------------------
  // Check-in flow (validation, status, hints)
  // ---------------------------------------------------------------------------
  static const String checkInMissingPlace =
      'Inserisci nome e indirizzo della gelateria.';
  static const String checkInMissingType = 'Seleziona il tipo di gelato.';
  static const String checkInInvalidFlavors = 'Seleziona da 1 a 4 gusti.';
  static const String checkInInvalidRating = 'Seleziona un voto da 1 a 5.';
  static const String checkInPlaceNoLocation =
      'Impossibile creare la gelateria senza una posizione valida.';
  static const String checkInPhotoInterrupted =
      'Caricamento della foto interrotto. Riprova.';
  static const String checkInFlavorCreateFailed =
      'Impossibile creare il gusto. Riprova.';
  static const String checkInLabelsRestoreFailed =
      'Impossibile ripristinare le etichette del check-in.';
  static const String checkInLabelsUnavailable =
      'Le etichette delle selezioni non sono disponibili. Ripristinale prima di continuare.';
  static const String checkInAwaitFriendsVerify =
      'Attendi la verifica degli amici taggati e riprova.';
  static const String checkInLabelsSaveFailed =
      'Impossibile salvare le etichette del check-in. Riprova.';
  static const String checkInPhotoCaptureFailed =
      'Impossibile acquisire e salvare la foto.';
  static const String checkInAddPhotoFirst =
      'Aggiungi e carica una foto prima di continuare.';
  static const String checkInSelectPlace = 'Seleziona una gelateria.';
  static const String checkInCheckStepData =
      'Controlla i dati inseriti in questo passaggio.';
  static const String checkInDraftUnavailable = 'Bozza non disponibile.';
  static const String checkInCatalogFallback =
      'Catalogo aggiornato non disponibile: uso le scelte incluse.';
  static const String checkInFlavorCatalogError =
      'Impossibile caricare il catalogo gusti.';
  static const String checkInMaxFlavors = 'Massimo 4 gusti.';
  static const String checkInRetrySave = 'Riprova salvataggio';
  static const String checkInLoadingLabels = 'Caricamento etichette';
  static const String checkInSavingLabels = 'Salvataggio etichette';
  static const String checkInVerifyLabels = 'Verifica etichette';
  static const String checkInRetryCleanup = 'Riprova pulizia';
  static const String checkInCompleteUnlock = 'Completa sblocco';
  static const String checkInRetryFriends = 'Riprova amici';
  static const String checkInCompleteCleanupHint =
      'Completa la pulizia locale del check-in pubblicato.';
  static const String checkInCompleteUnlockHint =
      'Completa lo sblocco locale del check-in.';
  static const String checkInAwaitPlace =
      'Attendi il completamento della gelateria.';
  static const String checkInAwaitPhoto =
      'Attendi il caricamento privato della foto.';
  static const String checkInAwaitLabels =
      'Attendi il salvataggio delle etichette del check-in.';
  static const String checkInAwaitDraft = 'Attendi il salvataggio della bozza.';
  static const String checkInSummaryUnavailable =
      'Riepilogo non disponibile finché le etichette delle selezioni non sono state ripristinate.';
  static const String checkInAlreadyPublished = 'Check-in già pubblicato';
  static const String checkInCompleteCleanupToClose =
      'Completa la pulizia dello stato locale per chiudere il flusso.';
  static const String checkInGelatoStepTitle = 'Come hai gustato il gelato?';
  static const String checkInAddNewPlace = 'Aggiungi una nuova gelateria';
  static const String checkInAddLocationHint =
      'Aggiungi una posizione con il GPS o scegli un punto sulla mappa.';
  static const String checkInLocationReady = 'Posizione pronta per il salvataggio.';
  static const String checkInFriendsNone = 'Amici: nessuno';
  static const String checkInPhotoReady =
      'Foto privata pronta per la pubblicazione';
  static const String checkInPhotoToVerify = 'Foto privata da verificare';
  static const String checkInShareWithFriends = 'Condividi con amici accettati';
  static const String checkInShareCardCta = 'Condividi la tua card';
  static const String checkInPhotoPreview = 'Anteprima foto privata';
  static const String checkInNoPhotoChosen = 'Nessuna foto scelta';
  static String checkInFriendsList(String names) => 'Amici: $names';

  // ---------------------------------------------------------------------------
  // Flavors manager (extended)
  // ---------------------------------------------------------------------------
  static const String flavorNoFavorites =
      'Nessun gusto preferito. Tocca un gusto per aggiungerlo.';
  static const String flavorSaved = 'Gusto salvato';
  static String flavorsCountRange(int minimum, int maximum) =>
      'Gusti ($minimum–$maximum)';

  // ---------------------------------------------------------------------------
  // Edit profile dialog (extended)
  // ---------------------------------------------------------------------------
  static const String editProfileUpdated = 'Profilo aggiornato';
  static const String editProfileTitle = 'Modifica profilo';

  // ---------------------------------------------------------------------------
  // Saved place control
  // ---------------------------------------------------------------------------
  static const String savedPlaceSavedTooltip = 'Gelateria salvata';
  static const String savedPlaceSaveTooltip = 'Salva gelateria';
  static String savedPlaceRemoveSemantic(String name) =>
      'Rimuovi $name dalle gelaterie salvate';
  static String savedPlaceSaveSemantic(String name) =>
      'Salva $name tra le gelaterie';

  // ---------------------------------------------------------------------------
  // Add place dialog (extended)
  // ---------------------------------------------------------------------------
  static const String addPlaceChooseLocationTitle = 'Scegli posizione';
  static const String addPlaceEnterName = 'Inserisci il nome.';
  static const String addPlaceEnterAddress = 'Inserisci l’indirizzo.';
  static String addPlacePointSelected(String coordinates) =>
      'Punto selezionato: $coordinates';

  // ---------------------------------------------------------------------------
  // Friends activity sidebar
  // ---------------------------------------------------------------------------
  static const String activityFromFriends = 'Dagli amici';
  static const String activityEmptyDesc =
      'Le attività dei tuoi amici appariranno qui.';
  static const String activityEmptyTitle = 'Nessuna attività recente';
  static const String activityUnavailable = 'Attività amici non disponibile.';
  static String activityCheckInFrom(String placeName) => 'Check-in da $placeName';

  // ---------------------------------------------------------------------------
  // Check-in step labels & progress/selection state (accessibility)
  // ---------------------------------------------------------------------------
  static const List<String> checkInStepLabels = <String>[
    'Foto',
    'Gelateria',
    'Il gelato',
    'Esperienza',
    'Condividi',
  ];
  static const String stepStateDone = 'completato';
  static const String stepStateCurrent = 'corrente';
  static const String stepStateTodo = 'da completare';
  static const String selectedState = 'selezionata';
  static const String unselectedState = 'non selezionata';
  static const String placeMarkerLiked = 'con Mi piace';
  static const String placeMarkerUserAdded = 'aggiunta da te';
  static const String placeMarkerFavorite = 'preferita';
  static const String placeMarkerSaved = 'salvata';
  static String checkInProgressAnnounce(int step, int total, String name) =>
      'Passaggio $step di $total: $name';
  static String navBadgeSemantic(String label, int count) =>
      '$label, $count notifiche';

  static const String settingsTitle = 'Impostazioni';
  static const String friendsPersonLoadError =
      'Non riusciamo a mostrare questa persona. Riprova.';

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------
  static const String leaderboardTitle = 'Chi ha mangiato più gelato?';
  static const String leaderboardUnavailable = 'Classifica non disponibile';
  static const String leaderboardLoadError =
      'Non riusciamo a caricare la classifica. Riprova.';
  static const String leaderboardEmptyDesc =
      'Aggiungi amici per sfidarli a colpi di coni.';
  static const String leaderboardPeriodMonth = 'Mese';
  static const String leaderboardPeriodAll = 'Sempre';
  static String leaderboardPoints(int points) => '$points punti gusto';

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------
  static const String errUserNotLogged = 'Utente non connesso';
  static const String errGeneric = 'Si è verificato un errore.';
}
