/// All user-facing text, in Italian and English, in one shared place.
///
/// Routes/paths stay in English (see [router]). Interpolated strings are
/// `static` methods.
///
/// ponytail: no ARB/gen-l10n. The language is picked once at startup from the
/// device ([useDeviceLocale]); changing it while the app runs takes effect on
/// the next launch. Move to ARB if a third language arrives.
class AppStrings {
  /// Italian for Italian devices, English for everyone else.
  static bool english = false;

  static void useDeviceLocale(String languageCode) =>
      english = languageCode != 'it';

  static String _t(String it, String en) => english ? en : it;

  /// For messages that live next to their logic instead of in this class.
  static String pick(String it, String en) => _t(it, en);

  /// English for Italian messages written next to their logic, mostly error
  /// classes with const constructors that translate when read. Text missing
  /// from the table stays Italian.
  static String translated(String italian) =>
      english ? (_englishFor[italian] ?? italian) : italian;

  static const _englishFor = <String, String>{
    'I servizi di localizzazione GPS sono disattivi.':
        'Location services are turned off.',
    'I permessi di localizzazione GPS sono stati negati.':
        'Location permission was denied.',
    'I permessi GPS sono stati disattivati permanentemente.':
        'Location permission is permanently off.',
    'Stato di pubblicazione incompleto: la bozza locale non corrisponde.':
        'Publishing incomplete: the local draft doesn’t match.',
    'Check-in pubblicato, ma la bozza locale non corrisponde.':
        'Check-in published, but the local draft doesn’t match.',
    'Impossibile verificare la foto privata.':
        'Couldn’t check the private photo.',
    'Impossibile ripristinare la bozza del check-in.':
        'Couldn’t restore the check-in draft.',
    'Riseleziona la foto per riprendere il caricamento.':
        'Pick the photo again to resume the upload.',
    'Caricamento della foto interrotto. Riprova.':
        'Photo upload interrupted. Try again.',
    'Impossibile creare la gelateria senza una posizione valida.':
        'Can’t create the gelateria without a valid location.',
    'Impossibile preparare la pubblicazione in modo sicuro.':
        'Couldn’t prepare publishing safely.',
    'Stato di pubblicazione incompleto: la bozza locale non è disponibile.':
        'Publishing incomplete: the local draft isn’t available.',
    'Pubblicazione interrotta. Riprova.': 'Publishing interrupted. Try again.',
    'Check-in inviato, ma la conferma locale non è stata salvata.':
        'Check-in sent, but the local confirmation wasn’t saved.',
    'Pubblicazione rifiutata, ma lo sblocco locale non è stato salvato.':
        'Publishing rejected, but the local unlock wasn’t saved.',
    'La pubblicazione è stata rifiutata. Correggi il check-in.':
        'Publishing was rejected. Fix the check-in.',
    'Pubblicazione rifiutata, ma lo stato locale non è stato ripulito.':
        'Publishing rejected, but the local state wasn’t cleaned up.',
    'Check-in pubblicato, ma la bozza locale non è stata rimossa.':
        'Check-in published, but the local draft wasn’t removed.',
    'Check-in pubblicato, ma lo stato locale non è stato ripulito.':
        'Check-in published, but the local state wasn’t cleaned up.',
    'Impossibile salvare l’ultima modifica della bozza.':
        'Couldn’t save the last change to the draft.',
    'Attendi il completamento della gelateria.':
        'Wait for the gelateria to finish.',
    'Il check-in è già pubblicato: completa la pulizia locale.':
        'The check-in is already published: finish the local cleanup.',
    'I dati del check-in non sono validi.':
        'The check-in details aren’t valid.',
    'Errore sconosciuto': 'Unknown error',
    'Quota di caricamento di Firebase superata per oggi (limite piano gratuito Spark). Riprova più tardi!':
        'Today’s upload quota is used up. Try again later!',
    'Accesso negato: permessi insufficienti per leggere o scrivere i dati.':
        'Access denied: not enough permissions to read or write this data.',
    'Operazione non autorizzata: verifica di aver effettuato correttamente l\'accesso.':
        'Not authorised: check that you’re signed in.',
    'Impossibile connettersi ai server. Verifica la tua connessione a internet.':
        'Can’t reach the servers. Check your internet connection.',
    'Questo account utente è stato disabilitato.':
        'This account has been disabled.',
    'Nessun utente trovato con queste credenziali.':
        'No user found with these credentials.',
    'Password errata. Riprova.': 'Wrong password. Try again.',
    'Credenziali non valide o scadute.': 'Invalid or expired credentials.',
    'Spazio o quota di Firebase esauriti per oggi. Riprova più tardi!':
        'Today’s storage quota is used up. Try again later!',
    'Permessi non sufficienti per completare l\'azione sul database.':
        'Not enough permissions to complete this action.',
    'Non sei autorizzato a compiere questa azione. Prova a rifare il login.':
        'You’re not allowed to do this. Try signing in again.',
    'Errore di rete: controlla la tua connessione internet.':
        'Network error: check your internet connection.',
    'Devi prima effettuare l\'accesso con Google!':
        'Sign in with Google first!',
    'Accedi per modificare questa gelateria.':
        'Sign in to change this gelateria.',
    'Impossibile aggiornare le gelaterie salvate.':
        'Couldn’t update your saved gelaterias.',
    'Impossibile aggiornare la gelateria preferita.':
        'Couldn’t update your favourite gelateria.',
    'Impossibile aggiornare il Mi piace.': 'Couldn’t update the like.',
    'Invito Gelatino non valido.': 'Invalid Gelatino invite.',
    'Puoi invitare solo un’amicizia accettata.':
        'You can only invite an accepted friend.',
    'Solo chi riceve l’invito può rispondere.':
        'Only the person invited can reply.',
    'Invito Gelatino non trovato.': 'Gelatino invite not found.',
    'Accedi per inviare un invito.': 'Sign in to send an invite.',
    'Completa tutti i campi obbligatori prima di pubblicare.':
        'Fill in every required field before publishing.',
    'ID check-in non valido.': 'Invalid check-in ID.',
    'Risposta di pubblicazione non valida.': 'Invalid publishing response.',
    'Stato di pubblicazione non valido.': 'Invalid publishing state.',
    'Accedi di nuovo per pubblicare il check-in.':
        'Sign in again to publish the check-in.',
    'Non hai i permessi per pubblicare questo check-in.':
        'You’re not allowed to publish this check-in.',
    'La foto privata non è più disponibile. Selezionala di nuovo.':
        'The private photo is no longer available. Pick it again.',
    'Il check-in non può essere pubblicato nello stato attuale.':
        'The check-in can’t be published in its current state.',
    'Pubblicazione interrotta. Riprova senza ricreare il check-in.':
        'Publishing interrupted. Try again without recreating the check-in.',
    'Errore remoto durante la pubblicazione del check-in.':
        'Server error while publishing the check-in.',
    'La foto non è utilizzabile: serve un JPEG sotto i 5 MB. Scegline un’altra.':
        'This photo can’t be used: it must be a JPEG under 5 MB. Pick another one.',
    'La gelateria scelta non esiste più. Torna al passo Luogo e selezionane un’altra.':
        'The chosen gelateria no longer exists. Go back to the Gelateria step and pick another.',
    'Il tipo di gelato scelto non è più disponibile. Torna al passo Gelato e selezionane un altro.':
        'The chosen gelato type is no longer available. Go back to the Gelato step and pick another.',
    'Uno dei gusti scelti non è più disponibile. Torna al passo Gelato e selezionane un altro.':
        'One of the chosen flavours is no longer available. Go back to the Gelato step and pick another.',
    'I dati della gelateria o del gusto non sono validi. Riprova con un’altra selezione.':
        'The gelateria or flavour details aren’t valid. Try a different choice.',
    'Il tuo profilo non è completo: aggiungi il nome dal tuo profilo e riprova.':
        'Your profile is incomplete: add your name in your profile and try again.',
    'Il tuo account non è ancora pronto. Esci e rientra, poi riprova.':
        'Your account isn’t ready yet. Log out and back in, then try again.',
    'Uno degli amici taggati non è più tra i tuoi amici. Rimuovilo dal tag e riprova.':
        'One of the tagged people is no longer your friend. Remove the tag and try again.',
    'Questo check-in è stato eliminato e non può essere ripubblicato. Creane uno nuovo.':
        'This check-in was deleted and can’t be published again. Create a new one.',
    'Hai raggiunto il limite di punti registrabili. Contatta l’assistenza.':
        'You’ve reached the points limit. Contact support.',
    'Richiesta di amicizia non valida.': 'Invalid friend request.',
    'Profilo o amicizia non trovato.': 'Profile or friendship not found.',
    'Non puoi modificare questa amicizia.': 'You can’t change this friendship.',
    'Questa amicizia non è più modificabile.':
        'This friendship can no longer be changed.',
    'Accedi per gestire le amicizie.': 'Sign in to manage friends.',
    'Servizio amicizie non disponibile. Riprova.':
        'Friends service unavailable. Try again.',
    'Impossibile aggiornare l’amicizia.': 'Couldn’t update the friendship.',
    'Accedi per vedere la Timeline.': 'Sign in to see the feed.',
    'Timeline temporaneamente non disponibile. Riprova.':
        'The feed is temporarily unavailable. Try again.',
    'La pagina della Timeline non è valida.': 'Invalid feed page.',
    'Impossibile caricare la Timeline.': 'Couldn’t load the feed.',
    'La foto selezionata non è un’immagine valida.':
        'The selected photo isn’t a valid image.',
  };

  // ---------------------------------------------------------------------------
  // Common / shared actions (reused across screens)
  // ---------------------------------------------------------------------------
  static String get retry => _t('Riprova', 'Retry');
  static String get cancel => _t('Annulla', 'Cancel');
  static String get remove => _t('Rimuovi', 'Remove');
  static String get add => _t('Aggiungi', 'Add');
  static String get accept => _t('Accetta', 'Accept');
  static String get reject => _t('Rifiuta', 'Decline');
  static String get save => _t('Salva', 'Save');
  static String get logout => _t('Esci', 'Log out');
  static String get back => _t('Indietro', 'Back');
  static String get login => _t('Accedi', 'Sign in');
  static String get delete => _t('Elimina', 'Delete');
  static String get clearSearch => _t('Cancella ricerca', 'Clear search');
  static String get chooseOnMap => _t('Scegli sulla mappa', 'Choose on map');
  static String get useLocation => _t('Usa la posizione', 'Use my location');
  static String get removeFriendshipBody => _t(
    'Potrete inviarvi una nuova richiesta in seguito.',
    'You can send each other a new request later.',
  );

  // ---------------------------------------------------------------------------
  // App
  // ---------------------------------------------------------------------------
  static String get appName => _t('Gelatino', 'Gelatino');

  // ---------------------------------------------------------------------------
  // Navigation (menu labels — Italian; routes stay English)
  // ---------------------------------------------------------------------------
  static String get navCollection => _t('Collezione', 'Collection');
  static String get navTimeline => _t('Bacheca', 'Feed');
  static String get navPlaces => _t('Gelaterie', 'Gelaterias');
  static String get navFriends => _t('Amici', 'Friends');

  // ---------------------------------------------------------------------------
  // Login / access
  // ---------------------------------------------------------------------------
  static String get loginTitle => _t('Gelatino', 'Gelatino');
  static String get loginButton =>
      _t('Accedi con Google', 'Sign in with Google');
  static String get loginErrorPrefix =>
      _t('Errore durante l\'accesso: ', 'Sign-in error: ');
  static String get accessInProgress => _t('Accesso in corso', 'Signing in');
  static String get accessPhotoLabel => _t(
    'Composizione artigianale di gelato, coppetta e cono',
    'Artisan gelato, cup and cone',
  );

  // ---------------------------------------------------------------------------
  // Timeline / Bacheca
  // ---------------------------------------------------------------------------
  static String get timelineTitle => _t('Bacheca', 'Feed');
  static String get timelineEmptyTitle =>
      _t('Bacheca ancora vuota', 'Your feed is still empty');
  static String get timelineEmptyDesc => _t(
    'Qui compaiono i gelati tuoi e dei tuoi amici. Aggiungi il tuo primo check-in quando visiti una gelateria.',
    'Your gelato and your friends’ show up here. Add your first check-in when you visit a gelateria.',
  );
  static String get timelineEmptyButton =>
      _t('Aggiungi check-in', 'Add check-in');
  static String get timelineLikeButton => _t('Mi piace', 'Like');
  static String get timelineWishlistAdd => _t('Da provare', 'To try');
  static String get timelineWishlistRemove => _t('Salvato', 'Saved');
  static String get timelineErrorPrefix =>
      _t('Impossibile caricare i gelati: ', 'Couldn’t load gelato: ');
  static String get timelineLoadMore => _t('Carica altri', 'Load more');
  static String get timelinePrevTooltip =>
      _t('Check-in precedente', 'Previous check-in');
  static String timelineCardPosition(int index, int total) =>
      _t('Check-in $index di $total', 'Check-in $index of $total');
  static String timelinePhotoSemantic(String placeName) =>
      _t('Foto del check-in da $placeName', 'Check-in photo from $placeName');
  static String timelineRatingSemantic(int rating) =>
      _t('$rating su 5', '$rating out of 5');
  static String get shareCardTooltip => _t('Condividi', 'Share');
  static String shareCardSemantic(String placeName) => _t(
    'Condividi il check-in da $placeName con una card',
    'Share the check-in from $placeName as a card',
  );
  static String get shareCardPreviewConfirm => _t('Condividi', 'Share');
  static String shareCardMessage(String placeName) => _t(
    'Gelato da $placeName 🍦 — Gelatino',
    'Gelato from $placeName 🍦 — Gelatino',
  );
  static String get shareCardFailed =>
      _t('Condivisione non riuscita. Riprova.', 'Sharing failed. Try again.');

  // ---------------------------------------------------------------------------
  // Collection
  // ---------------------------------------------------------------------------
  static String get collectionTitle =>
      _t('La tua collezione', 'Your collection');
  static String get collectionFavoriteFlavorsTitle =>
      _t('Gusti preferiti', 'Favourite flavours');
  static String get collectionFavoriteFlavorsSubtitle =>
      _t('Rivedi i gusti che ami di più.', 'The flavours you love most.');
  static String get collectionEmptyTitle =>
      _t('Nessuna gelateria salvata', 'No saved gelaterias');
  static String get collectionExploreButton =>
      _t('Esplora le gelaterie', 'Explore gelaterias');
  static String get collectionErrorTitle =>
      _t('Collezione non disponibile', 'Collection unavailable');
  static String get collectionUnauthTitle =>
      _t('La tua collezione ti aspetta', 'Your collection is waiting');

  // ---------------------------------------------------------------------------
  // Places / Gelaterie
  // ---------------------------------------------------------------------------
  static String get placeDetailTitle => _t('Dettaglio gelateria', 'Gelateria');
  static String get placeDetailRetryRatings =>
      _t('Riprova valutazioni', 'Retry ratings');
  static String get placeDetailNoRatings =>
      _t('Nessuna valutazione', 'No ratings');
  static String get placeDetailVisits => _t('visite', 'visits');
  static String get placeOpenInMaps => _t('Apri in Maps', 'Open in Maps');
  // ponytail: 'Checkin' (lowercase i) on purpose — place_detail_screen.dart is
  // guarded by server_owned_boundary_test against the 'CheckIn' token.
  static String get placeCheckinButton => _t('Fai check-in', 'Check in');
  static String get placeMapsError =>
      _t('Impossibile aprire Maps.', 'Couldn’t open Maps.');
  static String get placeOpenDetail => _t('Apri dettaglio', 'Open details');
  static String get placeSearchHint =>
      _t('Nome, via o gusto', 'Name, street or flavour');
  static String get placeActionList => _t('Lista', 'List');
  static String get placeActionMap => _t('Mappa', 'Map');
  static String placeFilterLabel(String filter) =>
      _t('Filtro $filter', 'Filter $filter');
  static String placeOpenTooltip(String name) => _t('Apri $name', 'Open $name');
  static String placeCoverSemantic(String placeName) => _t(
    'Illustrazione editoriale per $placeName',
    'Illustration for $placeName',
  );

  // Add place dialog
  static String get addPlaceNameLabel => _t('Nome', 'Name');
  static String get addPlaceAddressLabel => _t('Indirizzo', 'Address');
  static String get addPlaceConfirmPoint =>
      _t('Conferma punto', 'Confirm point');
  static String get addPlaceRetryLocation =>
      _t('Riprova posizione', 'Retry location');

  // ---------------------------------------------------------------------------
  // Friends
  // ---------------------------------------------------------------------------
  static String get friendsLoginTitle =>
      _t('Accedi per trovare i tuoi amici', 'Sign in to find your friends');
  static String get friendsFindPeople => _t('Trova persone', 'Find people');
  static String get friendsYourFriends => _t('I tuoi amici', 'Your friends');
  static String get friendsEmptyTitle =>
      _t('Nessun amico, per ora', 'No friends yet');
  static String get friendsUnavailable =>
      _t('Amici non disponibili', 'Friends unavailable');
  static String get friendsRequestsTitle => _t('Richieste', 'Requests');
  static String get friendsRequestsEmpty =>
      _t('Nessuna richiesta', 'No requests');
  static String get friendsRequestsUnavailable =>
      _t('Richieste non disponibili', 'Requests unavailable');
  static String get friendsInvitesTitle =>
      _t('Inviti Gelatino', 'Gelatino invites');
  static String get friendsInvitesEmpty => _t('Nessun invito', 'No invites');
  static String get friendsInviteSubtitle =>
      _t('Ti propone: Gelatino?', 'Up for a gelato?');
  static String get friendsInviteAccept => _t('Ci sto', 'I’m in');
  static String get friendsInviteDecline => _t('Non posso', 'Can’t make it');
  static String get friendsInvitesUnavailable =>
      _t('Inviti non disponibili', 'Invites unavailable');
  static String get friendsInvitePersonTitle =>
      _t('Invita una persona', 'Invite someone');
  static String get friendsGelatoWithWhom =>
      _t('Con chi prendiamo un gelato?', 'Who’s coming for gelato?');
  static String get friendsSearchLabel =>
      _t('Nome o username', 'Name or username');
  static String get friendsSearchUnavailable =>
      _t('Ricerca non disponibile', 'Search unavailable');
  static String get friendsNoResults => _t('Nessun risultato', 'No results');
  static String friendsRemoveConfirmTitle(String name) =>
      _t('Rimuovere $name dagli amici?', 'Remove $name from friends?');

  // ---------------------------------------------------------------------------
  // Relationship state (profile + friends)
  // ---------------------------------------------------------------------------
  static String get relationshipChecking =>
      _t('Verifica relazione…', 'Checking…');
  static String get relationshipUnavailable =>
      _t('Relazione non disponibile', 'Relationship unavailable');
  static String get relationshipFriend => _t('Amico', 'Friend');
  static String get relationshipBlocked => _t('Bloccato', 'Blocked');
  static String get block => _t('Blocca', 'Block');
  static String get unblock => _t('Sblocca', 'Unblock');
  static String get blockConfirmTitle =>
      _t('Bloccare questo utente?', 'Block this user?');
  static String get blockConfirmBody => _t(
    'L’amicizia finisce, sparite dalle rispettive bacheche e nessuno dei '
        'due potrà mandare richieste. Puoi sbloccarlo quando vuoi.',
    'Your friendship ends, you disappear from each other’s feeds and neither of you can send requests. You can unblock them any time.',
  );

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------
  static String get reportTooltip => _t('Segnala', 'Report');
  static String get reportTitle =>
      _t('Perché lo segnali?', 'Why are you reporting this?');
  static String get reportSent =>
      _t('Grazie, la segnalazione è arrivata.', 'Thanks, we got your report.');
  static String reportReason(String reason) => _t(
    switch (reason) {
      'spam' => 'Spam o pubblicità',
      'offensive' => 'Contenuto offensivo o inappropriato',
      'wrong' => 'Informazioni sbagliate o duplicate',
      _ => 'Altro',
    },
    switch (reason) {
      'spam' => 'Spam or advertising',
      'offensive' => 'Offensive or inappropriate',
      'wrong' => 'Wrong or duplicate information',
      _ => 'Something else',
    },
  );
  static String get relationshipToAccept => _t('Da accettare', 'To accept');
  static String get relationshipPending => _t('In attesa', 'Pending');
  static String get removeFriendshipTitle =>
      _t('Rimuovere questa amicizia?', 'Remove this friend?');

  // ---------------------------------------------------------------------------
  // Invite
  // ---------------------------------------------------------------------------
  static String get inviteCheckingFriendship =>
      _t('Verifica amicizia in corso…', 'Checking friendship…');
  static String get inviteNowFriends =>
      _t('Ora siete amici.', 'You’re now friends.');
  static String get inviteAlreadyFriends =>
      _t('Siete già amici.', 'You’re already friends.');
  static String get inviteRequestSent =>
      _t('Richiesta inviata.', 'Request sent.');
  static String get inviteRequestPending =>
      _t('Richiesta già in attesa.', 'Request already pending.');
  static String get inviteAcceptRequest =>
      _t('Accetta richiesta', 'Accept request');
  static String get inviteSendRequest => _t('Invia richiesta', 'Send request');
  static String get inviteOpenProfile => _t('Apri profilo', 'Open profile');
  static String get inviteTitle => _t('Invito Gelatino', 'Gelatino invite');
  static String inviteAlreadyInvitedYou(String name) =>
      _t('$name ti ha già invitato.', '$name has already invited you.');

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------
  static String get profileTitle => _t('Profilo', 'Profile');
  static String get profileDefaultName => _t('Utente goloso', 'Gelato lover');
  static String get profileStatGelati => _t('Gelati', 'Gelati');
  static String get profileStatAverage => _t('Media voti', 'Average rating');
  static String get profileFavoriteFlavors =>
      _t('I miei gusti preferiti', 'My favourite flavours');
  static String get profileWishlistLink => _t('Da provare', 'To try');
  static String get profileLogoutTooltip => _t('Esci', 'Log out');
  static String get profileFavoriteGelatoType =>
      _t('Formato preferito', 'Favourite format');
  static String get profileNotFound =>
      _t('Profilo non trovato', 'Profile not found');
  static String get profileUnavailable =>
      _t('Profilo non disponibile', 'Profile unavailable');
  static String get profileEditButton => _t('Modifica Profilo', 'Edit profile');
  static String get profileOpenSettings =>
      _t('Apri impostazioni', 'Open settings');
  static String get profilePreferencesTitle => _t('Preferenze', 'Preferences');
  static String get profilePreferencesUnavailable =>
      _t('Preferenze non disponibili', 'Preferences unavailable');
  static String get profilePreferencesUpdating =>
      _t('Preferenze in aggiornamento', 'Updating preferences');
  static String get profileActivityUnavailable =>
      _t('Attività non disponibile', 'Activity unavailable');
  static String get profileWishlistTitle => _t('Da provare', 'To try');
  static String get profileWishlistEmpty =>
      _t('Niente da provare, per ora.', 'Nothing to try, for now.');
  static String get profileWishlistUnavailable =>
      _t('Da provare non disponibile', 'To-try list unavailable');
  static String get profileSeeAll => _t('Vedi tutti', 'See all');
  static String get profileManageFlavors =>
      _t('Gestisci gusti', 'Manage flavours');
  static String get profileNoCheckInsPage => _t(
    'Nessun check-in caricato in questa pagina.',
    'No check-ins loaded on this page.',
  );
  static String get profileDeleteCheckInTooltip =>
      _t('Elimina check-in', 'Delete check-in');
  static String get profileDeleteCheckInTitle =>
      _t('Eliminare il check-in?', 'Delete this check-in?');
  static String get profileDeleteCheckInBody =>
      _t('Questa azione non può essere annullata.', 'This can’t be undone.');
  static String profileGelatiCount(int n) => _t('$n gelati', '$n gelati');
  static String profilePlacesCount(int n) =>
      _t('$n gelaterie', n == 1 ? '1 gelateria' : '$n gelaterias');
  static String profileAverage(String value) =>
      _t('$value media', '$value average');
  static String profileRatingOutOf(int rating) => _t('$rating/5', '$rating/5');

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  static String get settingsNotFound =>
      _t('Impostazioni non trovate', 'Settings not found');
  static String get settingsLoading =>
      _t('Caricamento impostazioni', 'Loading settings');
  static String get settingsUnavailable =>
      _t('Impostazioni non disponibili', 'Settings unavailable');
  static String get settingsSectionProfile => _t('PROFILO', 'PROFILE');
  static String get settingsEditPersonal =>
      _t('Modifica dati personali', 'Edit personal details');
  static String get settingsFavoriteFlavors =>
      _t('Gusti preferiti', 'Favourite flavours');
  static String get settingsSavedPlaces =>
      _t('Gelaterie salvate', 'Saved gelaterias');
  static String get settingsSectionApp => _t('APP', 'APP');
  static String get settingsTheme => _t('Tema app', 'App theme');
  static String get settingsThemeSubtitle =>
      _t('Aspetto dell’interfaccia', 'How the app looks');
  static String get settingsThemeAuto => _t('Automatico', 'Automatic');
  static String get settingsThemeLight => _t('Chiaro', 'Light');
  static String get settingsThemeDark => _t('Scuro', 'Dark');
  static String get settingsDefaultPlacesView =>
      _t('Vista predefinita Gelaterie', 'Default gelateria view');
  static String get settingsDefaultPlacesViewSubtitle =>
      _t('Elenco oppure mappa', 'List or map');
  static String get settingsPlacesViewList => _t('Elenco', 'List');
  static String get settingsPlacesViewMap => _t('Mappa', 'Map');
  static String get settingsHighContrast =>
      _t('Alto contrasto', 'High contrast');
  static String get settingsHighContrastSubtitle => _t(
    'Testi e bordi più marcati, su questo dispositivo',
    'Stronger text and borders, on this device',
  );
  static String get settingsSectionPrivacy => _t('PRIVACY', 'PRIVACY');
  static String get settingsPrivateProfile =>
      _t('Profilo privato', 'Private profile');
  static String get settingsSectionAccount => _t('ACCOUNT', 'ACCOUNT');
  static String settingsPoints(int points) =>
      _t('$points punti', '$points points');

  // ---------------------------------------------------------------------------
  // Check-in
  // ---------------------------------------------------------------------------
  static String get checkInTitle => _t('Nuovo check-in', 'New check-in');
  static String get checkInCamera => _t('Fotocamera', 'Camera');
  static String get checkInGallery => _t('Galleria', 'Gallery');
  static String get checkInCropTitle =>
      _t('Inquadra la foto', 'Frame the photo');
  static String get checkInCropHint => _t(
    'Trascina e avvicina con due dita: i tuoi amici la vedranno così.',
    'Drag and pinch: this is how your friends will see it.',
  );
  static String get checkInCropConfirm =>
      _t('Usa questa inquadratura', 'Use this framing');
  static String get checkInCropFrameSemantic =>
      _t('Anteprima dell’inquadratura della foto', 'Photo framing preview');
  static String get checkInPlaceLabel => _t('Nome gelateria', 'Gelateria name');
  static String get checkInAddressLabel =>
      _t('Indirizzo (opzionale)', 'Address (optional)');
  static String get checkInFlavorsTitle =>
      _t('Gusti scelti', 'Chosen flavours');
  static String get checkInGelatoTypeTitle =>
      _t('Come l\'hai preso?', 'How did you have it?');
  static String get checkInShowAllTypes => _t('Vedi tutti', 'See all');
  static String get checkInShowLessTypes => _t('Mostra meno', 'Show less');
  static String get checkInAddExistingFlavor =>
      _t('Aggiungi un gusto esistente', 'Add an existing flavour');
  static String get checkInAddNewFlavor =>
      _t('Crea un nuovo gusto', 'Create a new flavour');
  static String get checkInRatingTitle => _t('Voto', 'Rating');
  static String get checkInReviewLabel =>
      _t('Recensione (opzionale)', 'Review (optional)');
  static String get checkInSubmitButton =>
      _t('Condividi il check-in', 'Share the check-in');
  static String get checkInLoginRequired =>
      _t('Accedi per creare un check-in.', 'Sign in to create a check-in.');
  static String get checkInPublished =>
      _t('Check-in pubblicato', 'Check-in published');
  static String get checkInRetryLabels =>
      _t('Riprova etichette', 'Retry labels');
  static String get checkInRebuildCache =>
      _t('Ricostruisci cache', 'Rebuild cache');
  static String get checkInCloseTooltip =>
      _t('Chiudi check-in', 'Close check-in');
  static String get checkInCompleteCleanup =>
      _t('Completa pulizia', 'Finish cleanup');
  static String get checkInNoteLabel =>
      _t('Nota (opzionale)', 'Note (optional)');
  static String timelineBackdated(String date) =>
      _t('$date · pubblicato dopo', '$date · posted later');
  static String get placeMapRecenter =>
      _t('Centra sulla mia posizione', 'Centre on my location');
  static String get placeMapYouAreHere =>
      _t('La tua posizione', 'Your location');
  static String get checkInWhenTitle => _t('Quando', 'When');
  static String get checkInWhenNow => _t('Adesso', 'Now');
  static String get checkInWhenChange =>
      _t('Cambia data e ora', 'Change date and time');
  static String get checkInWhenReset => _t('Riporta ad adesso', 'Back to now');
  static String get checkInWhenPickDate =>
      _t('Quando hai mangiato il gelato?', 'When did you have the gelato?');
  static String get checkInWhenFuture => _t(
    'Non puoi mettere un check-in nel futuro.',
    'A check-in can’t be in the future.',
  );
  static String get checkInWhenTooOld => _t(
    'Puoi risalire al massimo a cinque anni fa.',
    'You can go back at most five years.',
  );
  static String get checkInRetryUpload =>
      _t('Riprova caricamento', 'Retry upload');
  static String get checkInCompressing => _t(
    'Compressione e caricamento privato…',
    'Compressing and uploading privately…',
  );
  static String checkInUploadingPercent(int percent) =>
      _t('Caricamento privato… $percent%', 'Uploading privately… $percent%');
  static String get checkInUploadInterrupted =>
      _t('Caricamento privato interrotto.', 'Private upload interrupted.');
  static String get checkInPrivatePhotoNotFound =>
      _t('Foto privata non trovata.', 'Private photo not found.');
  static String get checkInPrivatePhotoUploaded =>
      _t('Foto privata caricata', 'Private photo uploaded');
  static String get checkInSummarySemantic =>
      _t('Riepilogo completo del check-in', 'Full check-in summary');
  static String get checkInNoFriendsToAdd =>
      _t('Nessun amico da aggiungere.', 'No friends to add.');
  static String get checkInLoadingFriends =>
      _t('Caricamento amici…', 'Loading friends…');
  static String get checkInFriendsLoadError =>
      _t('Impossibile caricare gli amici.', 'Couldn’t load friends.');
  static String get checkInReloadFriends =>
      _t('Ricarica amici', 'Reload friends');
  static String get checkInRemoveTag => _t('Rimuovi tag', 'Remove tag');
  static String get checkInDraftRetryNote => _t(
    'La bozza e la foto restano disponibili per il retry.',
    'Your draft and photo are kept so you can retry.',
  );
  static String get checkInPlaceFieldLabel => _t('Gelateria', 'Gelateria');
  static String get checkInNewPlaceLabel =>
      _t('Nome della nuova gelateria', 'New gelateria name');
  static String get checkInAddressFieldLabel => _t('Indirizzo', 'Address');
  static String checkInStarsTooltip(int value) =>
      _t('$value stelle', '$value stars');
  static String checkInStarsSemantic(int value, {required bool selected}) => _t(
    '$value stelle${selected ? ', selezionato' : ''}',
    '$value stars${selected ? ', selected' : ''}',
  );
  static String checkInSummaryType(String typeName) =>
      _t('Tipo: $typeName', 'Type: $typeName');
  static String checkInSummaryFlavors(String flavorNames) =>
      _t('Gusti: $flavorNames', 'Flavours: $flavorNames');
  static String checkInSummaryRating(int rating) =>
      _t('Voto: $rating/5', 'Rating: $rating/5');

  // Check-in messages & snackbars
  static String get checkInErrorNoPhoto =>
      _t('Aggiungi una foto', 'Add a photo');
  static String get checkInErrorNoPlace =>
      _t('Inserisci il nome della gelateria', 'Enter the gelateria name');
  static String get checkInErrorNoGelatoType =>
      _t('Scegli come hai preso il gelato', 'Choose how you had your gelato');
  static String get checkInGelatoTypesFallback => _t(
    'Catalogo non aggiornato: uso le opzioni predefinite',
    'Catalogue out of date: using the default options',
  );
  static String get checkInFlavorAlreadySelected => _t(
    'Hai già selezionato questo gusto',
    'You’ve already picked this flavour',
  );
  static String get checkInFlavorAddedSuccess =>
      _t('Gusto aggiunto', 'Flavour added');
  static String get checkInSuccess =>
      _t('Check-in fatto! 🍦', 'Checked in! 🍦');

  // ---------------------------------------------------------------------------
  // Flavors manager
  // ---------------------------------------------------------------------------
  static String get flavorSearchHint =>
      _t('Cerca gusto...', 'Search flavours...');
  static String get flavorSortAZ => _t('A-Z', 'A-Z');
  static String get flavorSortFavorites =>
      _t('Preferiti prima', 'Favourites first');
  static String get flavorFavorites => _t('Preferiti', 'Favourites');
  static String get flavorCreateHint =>
      _t('Crea un nuovo gusto...', 'Create a new flavour...');
  static String get flavorSearchLabel =>
      _t('Cerca un gusto', 'Search for a flavour');
  static String get flavorNoneFound =>
      _t('Nessun gusto trovato.', 'No flavours found.');
  static String get flavorNewLabel => _t('Nuovo gusto', 'New flavour');
  static String get flavorCreateTooltip => _t('Crea gusto', 'Create flavour');

  // ---------------------------------------------------------------------------
  // Edit profile dialog
  // ---------------------------------------------------------------------------
  static String get editProfileEmptyName =>
      _t('Il nome non può essere vuoto', 'The name can’t be empty');
  static String get editProfileDisplayName =>
      _t('Nome visualizzato', 'Display name');
  static String get editProfileFavoritesTitle =>
      _t('Gelateria e gusto preferiti', 'Favourite gelateria and flavour');
  static String get editProfileFavoritesSubtitle => _t(
    'Seleziona dalla raccolta personale.',
    'Pick from your own collection.',
  );

  // ---------------------------------------------------------------------------
  // Authenticated shell (settings/profile entry points)
  // ---------------------------------------------------------------------------
  static String get shellOpenSettings =>
      _t('Apri impostazioni', 'Open settings');
  static String get shellSettingsTooltip => _t('Impostazioni', 'Settings');
  static String get shellOpenProfile => _t('Apri profilo', 'Open profile');
  static String get shellProfileTooltip => _t('Profilo', 'Profile');
  static String get retryImageTooltip => _t('Riprova immagine', 'Retry image');

  // ---------------------------------------------------------------------------
  // Shared feedback / status (reused across screens)
  // ---------------------------------------------------------------------------
  static String get operationFailed => _t(
    'Operazione non riuscita. Riprova.',
    'Something went wrong. Try again.',
  );
  static String get profileLoadError => _t(
    'Non riusciamo a caricare il profilo. Riprova.',
    'We couldn’t load the profile. Try again.',
  );
  static String get profileGelatinoFallback =>
      _t('Profilo Gelatino', 'Gelatino profile');
  static String get contentLoadError => _t(
    'Non riusciamo a caricare i contenuti.',
    'We couldn’t load this content.',
  );
  static String get wishlistLabel => _t('Da provare', 'To try');
  static String get mapTapToChoose => _t(
    'Tocca la mappa per scegliere un punto.',
    'Tap the map to choose a point.',
  );
  static String get mapPointSelected =>
      _t('Punto selezionato sulla mappa.', 'Point selected on the map.');
  static String get placeAddButton => _t('Aggiungi gelateria', 'Add gelateria');

  // ---------------------------------------------------------------------------
  // Favorite flavors screen
  // ---------------------------------------------------------------------------
  static String get favoriteFlavorsTitle =>
      _t('Gusti preferiti', 'Favourite flavours');

  // ---------------------------------------------------------------------------
  // Profile (extended)
  // ---------------------------------------------------------------------------
  static String get profileNotAvailableMessage =>
      _t('Questo profilo non è disponibile.', 'This profile isn’t available.');
  static String get profilePrefsNonePublic =>
      _t('Nessuna preferenza pubblica indicata.', 'No public preferences.');
  static String get profilePrefsNamesUnavailable => _t(
    'I nomi delle preferenze non sono disponibili ora.',
    'Preference names aren’t available right now.',
  );
  static String get profilePrefsNamesPending => _t(
    'I nomi saranno visibili appena il catalogo è aggiornato.',
    'Names will show once the catalogue is updated.',
  );
  static String get profileRecentActivity =>
      _t('Attività recenti', 'Recent activity');
  static String get profileCheckInsLoadError => _t(
    'Non riusciamo a caricare i check-in autorizzati.',
    'We couldn’t load the check-ins you can see.',
  );
  static String get profileSavedPlacesSubtitle => _t(
    'Le gelaterie salvate per la prossima visita.',
    'Gelaterias saved for your next visit.',
  );
  static String get profileSavedPlacesLoadError => _t(
    'Non riusciamo a caricare le gelaterie salvate.',
    'We couldn’t load the saved gelaterias.',
  );
  static String get profileCheckInsPageLabel =>
      _t('Check-in caricati in questa pagina', 'Check-ins on this page');
  static String get profileDeleteCheckInError =>
      _t('Impossibile eliminare il check-in.', 'Couldn’t delete the check-in.');
  static String get profileRemoveFromWishlist =>
      _t('Rimuovi dai Da provare', 'Remove from To try');

  // ---------------------------------------------------------------------------
  // Invite (extended)
  // ---------------------------------------------------------------------------
  static String get inviteLinkInvalid =>
      _t('Link di invito non valido.', 'Invalid invite link.');
  static String get inviteSelf =>
      _t('Non puoi invitare te stesso.', 'You can’t invite yourself.');
  static String get inviteProfileInaccessible =>
      _t('Profilo non accessibile.', 'Profile not accessible.');
  static String get inviteProfileNotFound =>
      _t('Profilo non trovato.', 'Profile not found.');
  static String get inviteLoginToContinue =>
      _t('Accedi per continuare.', 'Sign in to continue.');
  static String get inviteVerifyError => _t(
    'Impossibile verificare l’amicizia. Riprova più tardi.',
    'Couldn’t check the friendship. Try again later.',
  );
  static String get friendshipUpdateError => _t(
    'Impossibile aggiornare l’amicizia.',
    'Couldn’t update the friendship.',
  );

  // ---------------------------------------------------------------------------
  // Settings (extended)
  // ---------------------------------------------------------------------------
  static String get settingsEditNotSaved =>
      _t('Modifica non salvata. Riprova.', 'Change not saved. Try again.');
  static String get settingsCompleteProfile => _t(
    'Completa il profilo per personalizzare l’app.',
    'Complete your profile to personalise the app.',
  );
  static String get settingsLogoutFailed =>
      _t('Uscita non riuscita. Riprova.', 'Couldn’t log out. Try again.');
  static String get settingsPrivacyPolicy =>
      _t('Informativa sulla privacy', 'Privacy policy');
  static String get settingsDeleteAccount =>
      _t('Elimina account', 'Delete account');
  static String get settingsDeleteAccountTitle =>
      _t('Eliminare l’account?', 'Delete your account?');
  static String get settingsDeleteAccountBody => _t(
    'Cancelliamo profilo, check-in, foto e amicizie. Non si può annullare. '
        'Ti chiederemo di accedere di nuovo con Google per confermare.',
    'We delete your profile, check-ins, photos and friendships. This can’t be undone. We’ll ask you to sign in with Google again to confirm.',
  );
  static String get settingsDeleteAccountFailed =>
      _t('Eliminazione non riuscita. Riprova.', 'Deletion failed. Try again.');
  static String get settingsLoadingPrefs =>
      _t('Stiamo recuperando le tue preferenze.', 'Fetching your preferences.');
  static String get settingsLoadError => _t(
    'Non riusciamo a caricare le impostazioni. Riprova.',
    'We couldn’t load your settings. Try again.',
  );
  static String get settingsCloseTooltip =>
      _t('Chiudi impostazioni', 'Close settings');
  static String get settingsProfileLoading =>
      _t('Caricamento profilo…', 'Loading profile…');
  static String get settingsPrivateProfileSubtitle => _t(
    'Attivalo per non comparire nelle ricerche pubbliche.',
    'Turn it on to stay out of public search.',
  );

  // ---------------------------------------------------------------------------
  // Friends (extended)
  // ---------------------------------------------------------------------------
  static String get friendsSearchError =>
      _t('Ricerca non disponibile. Riprova.', 'Search unavailable. Try again.');
  static String get friendsInviteLinkCopied =>
      _t('Link invito copiato', 'Invite link copied');
  static String get friendsInviteLinkCopyError => _t(
    'Impossibile copiare il link. Riprova.',
    'Couldn’t copy the link. Try again.',
  );
  static String get friendsLoginSubtitle => _t(
    'Il profilo e le richieste sono disponibili dopo l’accesso.',
    'Your profile and requests are available after you sign in.',
  );
  static String get friendsFindPeopleSubtitle =>
      _t('Cerca per nome o username.', 'Search by name or username.');
  static String get friendsYourFriendsSubtitle =>
      _t('Le persone, prima dei numeri.', 'People before numbers.');
  static String get friendsEmptySubtitle => _t(
    'Cerca una persona e inviale una richiesta.',
    'Find someone and send them a request.',
  );
  static String get friendsInviteSent => _t('Invito inviato', 'Invite sent');
  static String get friendsLoadError => _t(
    'Non riusciamo a caricare gli amici. Riprova.',
    'We couldn’t load your friends. Try again.',
  );
  static String get friendsRequestsEmptySubtitle => _t(
    'Le nuove richieste appariranno qui.',
    'New requests will show up here.',
  );
  static String get friendsNewRequest => _t('Nuova richiesta', 'New request');
  static String get friendsRequestsLoadError => _t(
    'Non riusciamo a caricare le richieste. Riprova.',
    'We couldn’t load requests. Try again.',
  );
  static String get friendsInvitesEmptySubtitle => _t(
    'Quando qualcuno propone un gelato, lo vedrai qui.',
    'When someone suggests a gelato, you’ll see it here.',
  );
  static String get friendsInvitesLoadError => _t(
    'Non riusciamo a caricare gli inviti. Riprova.',
    'We couldn’t load invites. Try again.',
  );
  static String get friendsInvitePersonSubtitle => _t(
    'Condividi un link per incontrarvi su Gelatino.',
    'Share a link to meet on Gelatino.',
  );
  static String get friendsCopying => _t('Copia in corso…', 'Copying…');
  static String get friendsCopyInviteLink =>
      _t('Copia link invito', 'Copy invite link');
  static String get friendsGelatoWithWhomSubtitle => _t(
    'Richieste, inviti e persone con cui condividere il prossimo assaggio.',
    'Requests, invites and people to share your next taste with.',
  );
  static String get friendsNoResultsSubtitle => _t(
    'Prova con un altro nome o username.',
    'Try another name or username.',
  );
  static String get relationshipCheckingMessage => _t(
    'Stiamo controllando se siete già in contatto.',
    'Checking whether you’re already connected.',
  );
  static String get relationshipVerifyError => _t(
    'Non possiamo verificare il rapporto. Riprova.',
    'We can’t check your connection. Try again.',
  );

  // ---------------------------------------------------------------------------
  // Places tab (extended)
  // ---------------------------------------------------------------------------
  static String get placesLoginForFilters => _t(
    'Accedi per usare i filtri personali.',
    'Sign in to use your personal filters.',
  );
  static String get placesLoginToAdd =>
      _t('Accedi per aggiungere una gelateria.', 'Sign in to add a gelateria.');
  static String get placesLoginToAddFirst => _t(
    'Accedi per aggiungere la prima gelateria.',
    'Sign in to add the first gelateria.',
  );
  static String get placesCatalogEmpty =>
      _t('Il catalogo è ancora vuoto.', 'The catalogue is still empty.');
  static String get placesNoSearchMatch => _t(
    'Nessuna gelateria corrisponde alla ricerca.',
    'No gelateria matches your search.',
  );
  static String get placesClearFilters => _t('Azzera filtri', 'Clear filters');
  static String get placeAdded => _t('Gelateria aggiunta.', 'Gelateria added.');
  static String placeFlavorMatchChip(String flavorName, int bestRating) =>
      _t('🍦 $flavorName · $bestRating★', '🍦 $flavorName · $bestRating★');

  // ---------------------------------------------------------------------------
  // Login (extended)
  // ---------------------------------------------------------------------------
  static String get loginFailed =>
      _t('Accesso non riuscito. Riprova.', 'Sign-in failed. Try again.');

  // ---------------------------------------------------------------------------
  // Place detail (extended)
  // ---------------------------------------------------------------------------
  static String get placeDetailRetryPlace =>
      _t('Riprova gelateria', 'Retry gelateria');
  static String get placeNotFound =>
      _t('Gelateria non trovata', 'Gelateria not found');
  static String get placeBackToList =>
      _t('Torna alle gelaterie', 'Back to gelaterias');
  static String get placeYourActions => _t('Le tue azioni', 'Your actions');
  static String get placePersonalStateUnavailable => _t(
    'Stato personale non disponibile.',
    'Your saved state is unavailable.',
  );
  static String get placeRetryPersonalState =>
      _t('Riprova stato personale', 'Retry');
  static String get placeLoginToSave => _t(
    'Accedi per salvare o aggiungere ai preferiti.',
    'Sign in to save or add to favourites.',
  );
  static String get placeYourNote => _t('La tua nota', 'Your note');
  static String get placeAddToFavorites =>
      _t('Aggiungi ai preferiti', 'Add to favourites');

  // ---------------------------------------------------------------------------
  // Collection (extended)
  // ---------------------------------------------------------------------------
  static String get collectionSavedSubtitle => _t(
    'Le gelaterie che hai salvato per la prossima visita.',
    'The gelaterias you saved for your next visit.',
  );
  static String get collectionOtherPlaces =>
      _t('Altre gelaterie', 'Other gelaterias');
  static String get collectionEmptyDesc => _t(
    'Salva le gelaterie che vuoi provare e le ritroverai qui.',
    'Save the gelaterias you want to try and you’ll find them here.',
  );
  static String get collectionUnauthDesc => _t(
    'Accedi per vedere le gelaterie che hai salvato.',
    'Sign in to see the gelaterias you saved.',
  );
  static String savedPlacesCount(int count) => _t(
    count == 1 ? '1 gelateria salvata' : '$count gelaterie salvate',
    count == 1 ? '1 saved gelateria' : '$count saved gelaterias',
  );

  // ---------------------------------------------------------------------------
  // Timeline (extended empty states)
  // ---------------------------------------------------------------------------
  static String get timelineNoFriendsTitle =>
      _t('Nessun amico ancora', 'No friends yet');
  static String get timelineNoFriendsDesc => _t(
    'Aggiungi amici per vedere qui i loro check-in.',
    'Add friends to see their check-ins here.',
  );
  static String get timelineAddFriends => _t('Aggiungi amici', 'Add friends');
  static String get timelineNoRecentTitle =>
      _t('Nessun check-in recente', 'No recent check-ins');
  static String get timelineNoRecentDesc => _t(
    'I tuoi amici non hanno ancora condiviso attività.',
    'Your friends haven’t shared anything yet.',
  );
  static String get timelineCheckInButton => _t('Fai check-in', 'Check in');
  static String get timelineFriendshipsUpdating =>
      _t('Aggiornamento amicizie', 'Updating friendships');
  static String get timelineFriendshipsUpdatingDesc => _t(
    'La Timeline sarà disponibile tra poco.',
    'The feed will be ready in a moment.',
  );
  static String get timelineFriendshipsUnavailable =>
      _t('Amicizie non disponibili', 'Friendships unavailable');
  static String get timelineFriendshipsUnavailableDesc => _t(
    'Aggiorna per riprovare senza mostrare attività non autorizzate.',
    'Refresh to try again without showing activity you can’t see.',
  );
  static String get timelineLoginTitle =>
      _t('Accedi alla Timeline', 'Sign in to the feed');
  static String get timelineLoginDesc => _t(
    'Serve un account per vedere i check-in privati.',
    'You need an account to see private check-ins.',
  );
  static String get timelineNoRecentSelfDesc =>
      _t('Pubblica il primo check-in.', 'Post your first check-in.');
  static String get timelineLoadingMore =>
      _t('Caricamento altri check-in', 'Loading more check-ins');
  static String get timelineNextTooltip =>
      _t('Check-in successivo', 'Next check-in');

  // ---------------------------------------------------------------------------
  // Access brand panel
  // ---------------------------------------------------------------------------
  static String get accessTagline =>
      _t('Il tuo diario del gelato', 'Your gelato diary');
  static String get accessDescription => _t(
    'Scopri nuove gelaterie, conserva i check-in in privato '
        'e condividi le tue scoperte con gli amici.',
    'Discover new gelaterias, keep your check-ins private and share your finds with friends.',
  );

  // ---------------------------------------------------------------------------
  // Check-in flow (validation, status, hints)
  // ---------------------------------------------------------------------------
  static String get checkInMissingPlace => _t(
    'Inserisci nome e indirizzo della gelateria.',
    'Enter the gelateria name and address.',
  );
  static String get checkInMissingType =>
      _t('Seleziona il tipo di gelato.', 'Choose the type of gelato.');
  static String get checkInInvalidFlavors =>
      _t('Seleziona da 1 a 4 gusti.', 'Choose 1 to 4 flavours.');
  static String get checkInInvalidRating =>
      _t('Seleziona un voto da 1 a 5.', 'Choose a rating from 1 to 5.');
  static String get checkInPlaceNoLocation => _t(
    'Impossibile creare la gelateria senza una posizione valida.',
    'Can’t create the gelateria without a valid location.',
  );
  static String get checkInPhotoInterrupted => _t(
    'Caricamento della foto interrotto. Riprova.',
    'Photo upload interrupted. Try again.',
  );
  static String get checkInFlavorCreateFailed => _t(
    'Impossibile creare il gusto. Riprova.',
    'Couldn’t create the flavour. Try again.',
  );
  static String get checkInLabelsRestoreFailed => _t(
    'Impossibile ripristinare le etichette del check-in.',
    'Couldn’t restore the check-in labels.',
  );
  static String get checkInLabelsUnavailable => _t(
    'Le etichette delle selezioni non sono disponibili. Ripristinale prima di continuare.',
    'The labels for your choices aren’t available. Restore them before continuing.',
  );
  static String get checkInAwaitFriendsVerify => _t(
    'Attendi la verifica degli amici taggati e riprova.',
    'Wait for the tagged friends to be checked and try again.',
  );
  static String get checkInLabelsSaveFailed => _t(
    'Impossibile salvare le etichette del check-in. Riprova.',
    'Couldn’t save the check-in labels. Try again.',
  );
  static String get checkInPhotoCaptureFailed => _t(
    'Impossibile acquisire e salvare la foto.',
    'Couldn’t capture and save the photo.',
  );
  static String get checkInAddPhotoFirst => _t(
    'Aggiungi e carica una foto prima di continuare.',
    'Add and upload a photo before continuing.',
  );
  static String get checkInSelectPlace =>
      _t('Seleziona una gelateria.', 'Choose a gelateria.');
  static String get checkInCheckStepData => _t(
    'Controlla i dati inseriti in questo passaggio.',
    'Check the details in this step.',
  );
  static String get checkInDraftUnavailable =>
      _t('Bozza non disponibile.', 'Draft unavailable.');
  static String get checkInCatalogFallback => _t(
    'Catalogo aggiornato non disponibile: uso le scelte incluse.',
    'Updated catalogue unavailable: using the built-in choices.',
  );
  static String get checkInFlavorCatalogError => _t(
    'Impossibile caricare il catalogo gusti.',
    'Couldn’t load the flavour catalogue.',
  );
  static String get checkInMaxFlavors =>
      _t('Massimo 4 gusti.', '4 flavours at most.');
  static String get checkInRetrySave =>
      _t('Riprova salvataggio', 'Retry saving');
  static String get checkInLoadingLabels =>
      _t('Caricamento etichette', 'Loading labels');
  static String get checkInSavingLabels =>
      _t('Salvataggio etichette', 'Saving labels');
  static String get checkInVerifyLabels =>
      _t('Verifica etichette', 'Check labels');
  static String get checkInRetryCleanup =>
      _t('Riprova pulizia', 'Retry cleanup');
  static String get checkInCompleteUnlock =>
      _t('Completa sblocco', 'Finish unlocking');
  static String get checkInRetryFriends => _t('Riprova amici', 'Retry friends');
  static String get checkInCompleteCleanupHint => _t(
    'Completa la pulizia locale del check-in pubblicato.',
    'Finish the local cleanup of the published check-in.',
  );
  static String get checkInCompleteUnlockHint => _t(
    'Completa lo sblocco locale del check-in.',
    'Finish unlocking the check-in on this device.',
  );
  static String get checkInAwaitPlace => _t(
    'Attendi il completamento della gelateria.',
    'Wait for the gelateria to finish.',
  );
  static String get checkInAwaitPhoto => _t(
    'Attendi il caricamento privato della foto.',
    'Wait for the private photo upload.',
  );
  static String get checkInAwaitLabels => _t(
    'Attendi il salvataggio delle etichette del check-in.',
    'Wait for the check-in labels to save.',
  );
  static String get checkInAwaitDraft =>
      _t('Attendi il salvataggio della bozza.', 'Wait for the draft to save.');
  static String get checkInSummaryUnavailable => _t(
    'Riepilogo non disponibile finché le etichette delle selezioni non sono state ripristinate.',
    'Summary unavailable until the labels for your choices are restored.',
  );
  static String get checkInAlreadyPublished =>
      _t('Check-in già pubblicato', 'Check-in already published');
  static String get checkInCompleteCleanupToClose => _t(
    'Completa la pulizia dello stato locale per chiudere il flusso.',
    'Finish cleaning up local state to close.',
  );
  static String get checkInGelatoStepTitle =>
      _t('Come hai gustato il gelato?', 'How did you have your gelato?');
  static String get checkInAddNewPlace =>
      _t('Aggiungi una nuova gelateria', 'Add a new gelateria');
  static String get checkInAddLocationHint => _t(
    'Aggiungi una posizione con il GPS o scegli un punto sulla mappa.',
    'Add a location with GPS or pick a point on the map.',
  );
  static String get checkInLocationReady =>
      _t('Posizione pronta per il salvataggio.', 'Location ready to save.');
  static String get checkInFriendsNone => _t('Amici: nessuno', 'Friends: none');
  static String get checkInPhotoReady => _t(
    'Foto privata pronta per la pubblicazione',
    'Private photo ready to publish',
  );
  static String get checkInPhotoToVerify =>
      _t('Foto privata da verificare', 'Private photo to check');
  static String get checkInShareWithFriends =>
      _t('Condividi con amici accettati', 'Share with accepted friends');
  static String get checkInShareCardCta =>
      _t('Condividi la tua card', 'Share your card');
  static String get checkInPhotoPreview =>
      _t('Anteprima foto privata', 'Private photo preview');
  static String get checkInNoPhotoChosen =>
      _t('Nessuna foto scelta', 'No photo chosen');
  static String checkInFriendsList(String names) =>
      _t('Amici: $names', 'Friends: $names');

  // ---------------------------------------------------------------------------
  // Flavors manager (extended)
  // ---------------------------------------------------------------------------
  static String get flavorNoFavorites => _t(
    'Nessun gusto preferito. Tocca un gusto per aggiungerlo.',
    'No favourite flavours. Tap a flavour to add it.',
  );
  static String get flavorSaved => _t('Gusto salvato', 'Flavour saved');
  static String flavorsCountRange(int minimum, int maximum) =>
      _t('Gusti ($minimum–$maximum)', 'Flavours ($minimum–$maximum)');

  // ---------------------------------------------------------------------------
  // Edit profile dialog (extended)
  // ---------------------------------------------------------------------------
  static String get editProfileUpdated =>
      _t('Profilo aggiornato', 'Profile updated');
  static String get editProfileTitle => _t('Modifica profilo', 'Edit profile');

  // ---------------------------------------------------------------------------
  // Saved place control
  // ---------------------------------------------------------------------------
  static String get savedPlaceSavedTooltip =>
      _t('Gelateria salvata', 'Saved gelateria');
  static String get savedPlaceSaveTooltip =>
      _t('Salva gelateria', 'Save gelateria');
  static String savedPlaceRemoveSemantic(String name) => _t(
    'Rimuovi $name dalle gelaterie salvate',
    'Remove $name from saved gelaterias',
  );
  static String savedPlaceSaveSemantic(String name) =>
      _t('Salva $name tra le gelaterie', 'Save $name to your gelaterias');

  // ---------------------------------------------------------------------------
  // Add place dialog (extended)
  // ---------------------------------------------------------------------------
  static String get addPlaceChooseLocationTitle =>
      _t('Scegli posizione', 'Choose location');
  static String get addPlaceEnterName =>
      _t('Inserisci il nome.', 'Enter the name.');
  static String get addPlaceEnterAddress =>
      _t('Inserisci l’indirizzo.', 'Enter the address.');
  static String addPlacePointSelected(String coordinates) =>
      _t('Punto selezionato: $coordinates', 'Point selected: $coordinates');

  // ---------------------------------------------------------------------------
  // Friends activity sidebar
  // ---------------------------------------------------------------------------
  static String get activityFromFriends => _t('Dagli amici', 'From friends');
  static String get activityEmptyDesc => _t(
    'Le attività dei tuoi amici appariranno qui.',
    'Your friends’ activity will show up here.',
  );
  static String get activityEmptyTitle =>
      _t('Nessuna attività recente', 'No recent activity');
  static String get activityUnavailable =>
      _t('Attività amici non disponibile.', 'Friends’ activity unavailable.');
  static String activityCheckInFrom(String placeName) =>
      _t('Check-in da $placeName', 'Check-in from $placeName');

  // ---------------------------------------------------------------------------
  // Check-in step labels & progress/selection state (accessibility)
  // ---------------------------------------------------------------------------
  static List<String> get checkInStepLabels => english
      ? <String>['Photo', 'Gelateria', 'The gelato', 'Experience', 'Share']
      : <String>['Foto', 'Gelateria', 'Il gelato', 'Esperienza', 'Condividi'];
  static String get stepStateDone => _t('completato', 'done');
  static String get stepStateCurrent => _t('corrente', 'current');
  static String get stepStateTodo => _t('da completare', 'to do');
  static String get selectedState => _t('selezionata', 'selected');
  static String get unselectedState => _t('non selezionata', 'not selected');
  static String get placeMarkerLiked => _t('con Mi piace', 'liked');
  static String get placeMarkerUserAdded =>
      _t('aggiunta da te', 'added by you');
  static String get placeMarkerFavorite => _t('preferita', 'favourite');
  static String get placeMarkerSaved => _t('salvata', 'saved');
  static String checkInProgressAnnounce(int step, int total, String name) =>
      _t('Passaggio $step di $total: $name', 'Step $step of $total: $name');
  static String navBadgeSemantic(String label, int count) =>
      _t('$label, $count notifiche', '$label, $count notifications');

  static String get settingsTitle => _t('Impostazioni', 'Settings');
  static String get friendsPersonLoadError => _t(
    'Non riusciamo a mostrare questa persona. Riprova.',
    'We can’t show this person. Try again.',
  );

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------
  static String get leaderboardTitle =>
      _t('Chi ha mangiato più gelato?', 'Who ate the most gelato?');
  static String get leaderboardUnavailable =>
      _t('Classifica non disponibile', 'Leaderboard unavailable');
  static String get leaderboardLoadError => _t(
    'Non riusciamo a caricare la classifica. Riprova.',
    'We couldn’t load the leaderboard. Try again.',
  );
  static String get leaderboardEmptyDesc => _t(
    'Aggiungi amici per sfidarli a colpi di coni.',
    'Add friends and challenge them cone by cone.',
  );
  static String get leaderboardPeriodMonth => _t('Mese', 'Month');
  static String get leaderboardPeriodAll => _t('Sempre', 'All time');
  static String leaderboardPoints(int points) =>
      _t('$points punti gusto', '$points flavour points');

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------
  static String get errUserNotLogged =>
      _t('Utente non connesso', 'Not signed in');
  static String get errGeneric =>
      _t('Si è verificato un errore.', 'Something went wrong.');

  // ---------------------------------------------------------------------------
  // Ricerca, mappa e controlli
  // ---------------------------------------------------------------------------
  static String checkInStepOf(int step, int total) =>
      _t('Passo $step di $total', 'Step $step of $total');
  static String get mapSemantic => _t('Mappa delle gelaterie', 'Gelateria map');
  static String get mapAttribution => _t('© OpenStreetMap', '© OpenStreetMap');
  static String get placeMapZoomIn => _t('Ingrandisci la mappa', 'Zoom in');
  static String get placeMapZoomOut => _t('Riduci la mappa', 'Zoom out');
  static String get placeMapClosePreview =>
      _t('Chiudi anteprima', 'Close preview');
  static String get checkInPlaceSearchHint =>
      _t('Nome o via', 'Name or street');
  static String get checkInPickPlace =>
      _t('Scegli la gelateria', 'Choose the gelateria');
  static String get checkInPlaceNoMatch =>
      _t('Nessuna gelateria trovata.', 'No gelateria found.');
  static String get editProfileChangePhoto =>
      _t('Cambia foto del profilo', 'Change profile photo');
  static String get done => _t('Fine', 'Done');
  static String placeResultsCount(int count) => _t(
    count == 1 ? '1 gelateria' : '$count gelaterie',
    count == 1 ? '1 gelateria' : '$count gelaterias',
  );
  static String placeClusterSemantic(
    int count, {
    required bool includesOwn,
  }) => _t(
    '$count gelaterie vicine${includesOwn ? ', incluse le tue' : ''}, '
        'tocca per ingrandire',
    '$count gelaterias nearby${includesOwn ? ', including yours' : ''}, tap to zoom in',
  );
  static String placesNoMatchFor(String query) => _t(
    'Niente per «$query». Prova con una parola sola, la via o un gusto.',
    'Nothing for “$query”. Try a single word, the street or a flavour.',
  );
  static String flavorColorSemantic(int index, int total) =>
      _t('Colore $index di $total', 'Colour $index of $total');
}
