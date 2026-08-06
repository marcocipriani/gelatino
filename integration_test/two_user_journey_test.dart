import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gelatino/main.dart' as app;

import 'helpers/app_driver.dart';
import 'helpers/finders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reciprocal two-user journey', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    app.main();
    final driver = AppDriver(tester);

    await driver.waitForLabel('Accedi come Alice E2E');
    await driver.tapLabel('Accedi come Alice E2E');
    await driver.waitForRoute('/collection');
    await driver.waitForLabel('La tua collezione');

    await driver.tapKey('nav-/places');
    await driver.waitForRoute('/places');
    await driver.tapTooltip('Apri Gelateria E2E');
    await driver.waitFor(
      E2EFinders.key('place-save-action'),
      'Gelateria E2E detail',
    );
    await driver.ensureStateButtonSelected('place-save-action', selected: true);
    await driver.waitForDocument(
      'users/e2e-alice/place_states/e2e-place-1',
      matches: (data) => data['saved'] == true,
      description: 'Alice saved place state',
    );
    await driver.waitForLabel('Salvata');

    await driver.pageBack();
    await driver.waitForRoute('/places');
    await driver.tapKey('nav-/collection');
    await driver.waitForRoute('/collection');
    await driver.waitForLabel('Da provare');
    await driver.waitForLabel('Gelateria E2E');

    await driver.tapKey('nav-/friends');
    await driver.waitForRoute('/friends');
    await driver.enterAndSubmit('Nome o username', 'bob');
    await driver.waitForLabel('Nessun risultato');
    driver.expectAbsent(
      E2EFinders.key('friend-profile-e2e-bob'),
      'non-searchable Bob profile',
    );

    await driver.tapKey('settings-gear-shell');
    await driver.waitFor(E2EFinders.key('settings-compact'), 'Alice settings');
    await driver.setSwitch('settings-private-profile', true);
    await driver.waitForDocument(
      'users/e2e-alice',
      matches: (data) => data['profile_visibility'] == 'private',
      description: 'Alice private profile',
    );
    await driver.setSwitch('settings-private-profile', false);
    await driver.waitForDocument(
      'public_profiles/e2e-alice',
      matches: (data) =>
          data['profile_visibility'] == 'public' && data['searchable'] == true,
      description: 'Alice public searchable projection',
    );
    await driver.selectDropdown(
      key: 'settings-theme',
      option: 'Scuro',
      expectedValue: ThemeMode.dark,
    );
    await driver.selectDropdown(
      key: 'settings-default-view',
      option: 'Mappa',
      expectedValue: 'map',
    );
    await driver.waitForDocument(
      'users/e2e-alice',
      matches: (data) =>
          data['theme_mode'] == 'dark' &&
          data['default_collection_view'] == 'map',
      description: 'Alice dark theme and map default',
    );

    await driver.tapKey('settings-logout');
    await driver.waitForLabel('Accedi come Bob E2E');
    await driver.tapLabel('Accedi come Bob E2E');
    await driver.waitForRoute('/friends');
    await driver.tapKey('nav-/collection');
    await driver.waitForRoute('/collection');
    await driver.waitForLabel('La tua collezione');

    await driver.tapKey('settings-gear-shell');
    await driver.waitFor(E2EFinders.key('settings-compact'), 'Bob settings');
    await driver.setSwitch('settings-private-profile', true);
    await driver.waitForDocument(
      'users/e2e-bob',
      matches: (data) => data['profile_visibility'] == 'private',
      description: 'Bob private profile',
    );
    await driver.setSwitch('settings-private-profile', false);
    await driver.waitForDocument(
      'public_profiles/e2e-bob',
      matches: (data) =>
          data['profile_visibility'] == 'public' && data['searchable'] == true,
      description: 'Bob public searchable projection',
    );

    await driver.tapKey('settings-back');
    await driver.waitForRoute('/collection');
    await driver.tapKey('nav-/friends');
    await driver.waitForRoute('/friends');
    await driver.enterAndSubmit('Nome o username', 'alice');
    await driver.waitFor(
      E2EFinders.key('friend-send-e2e-alice'),
      'Alice result',
    );
    await driver.tapKey('friend-send-e2e-alice');
    await driver.waitForDocument(
      'friendships/ZTJlLWFsaWNl.ZTJlLWJvYg',
      matches: (data) =>
          data['state'] == 'pending' &&
          data['requester_uid'] == 'e2e-bob' &&
          data['recipient_uid'] == 'e2e-alice',
      description: 'Bob to Alice pending friendship',
    );

    await driver.tapKey('settings-gear-shell');
    await driver.waitFor(E2EFinders.key('settings-logout'), 'Alice settings');
    await driver.tapKey('settings-logout');
    await driver.waitForLabel('Accedi come Alice E2E');
    await driver.tapLabel('Accedi come Alice E2E');
    await driver.waitForRoute('/friends');
    await driver.waitFor(E2EFinders.key('friends-badge'), 'friends badge');
    await driver.waitFor(
      E2EFinders.key('friend-request-accept-e2e-bob'),
      'Bob incoming friend request',
    );
    await driver.tapKey('friend-request-accept-e2e-bob');
    await driver.waitForDocument(
      'friendships/ZTJlLWFsaWNl.ZTJlLWJvYg',
      matches: (data) => data['state'] == 'accepted',
      description: 'Alice and Bob accepted friendship',
    );
    await driver.waitFor(
      E2EFinders.key('friend-invite-send-e2e-bob'),
      'Bob accepted friend card',
    );
    await driver.tapKey('friend-invite-send-e2e-bob');
    await driver.waitForLabel('Invito inviato');
    await driver.waitForArrayQueryDocuments(
      'pings',
      whereField: 'member_uids',
      arrayContains: 'e2e-alice',
      matches: (documents) => documents.any((document) {
        final data = document.data();
        return data['sender_id'] == 'e2e-alice' &&
            data['receiver_id'] == 'e2e-bob' &&
            data['status'] == 'pending';
      }),
      description: 'Alice to Bob pending Gelatino invite',
    );

    await driver.tapKey('melt-pin');
    await driver.waitFor(E2EFinders.key('check-in-page-0'), 'photo step');
    await driver.tapKey('e2e-photo-fixture');
    await driver.waitForLabel('Foto privata caricata');
    await driver.tapEnabledButton('Continua');

    await driver.waitFor(E2EFinders.key('check-in-page-1'), 'place step');
    await driver.tapKey('place-null');
    await driver.tapTextContaining('Gelateria E2E');
    await driver.waitFor(
      E2EFinders.key('place-e2e-place-1'),
      'selected Gelateria E2E',
    );
    await driver.tapEnabledButton('Continua');

    await driver.waitFor(E2EFinders.key('check-in-page-2'), 'gelato step');
    await driver.selectChoiceChip('Cono');
    await driver.selectChoiceChip('Pistacchio');
    await driver.tapEnabledButton('Continua');

    await driver.waitFor(E2EFinders.key('check-in-page-3'), 'experience step');
    await driver.tapKey('check-in-rating-5');
    await driver.enterText('Nota (opzionale)', 'Check-in E2E Alice');
    await driver.tapEnabledButton('Continua');

    await driver.waitFor(E2EFinders.key('check-in-page-4'), 'share step');
    await driver.setCheckbox('Bob E2E', true);
    await driver.waitForLabel('Amici: Bob E2E');
    await driver.waitForLabel('Pubblica');

    await driver.activateEnabledButtonTwiceBeforePump('Pubblica');
    await driver.waitForRoute('/timeline');
    driver.expectNoFrameworkException('check-in completion transition');
    final checkIns = await driver.waitForQueryDocuments(
      'check_ins',
      whereField: 'user_id',
      isEqualTo: 'e2e-alice',
      matches: (documents) =>
          documents.length == 1 &&
          documents.single.data()['review_text'] == 'Check-in E2E Alice' &&
          (documents.single.data()['tagged_user_ids'] as List<Object?>)
              .contains('e2e-bob'),
      description: 'one canonical Alice check-in with Bob tagged',
    );
    final checkInId = checkIns.single.id;
    await driver.waitFor(
      E2EFinders.key('timeline-card-$checkInId'),
      'Alice timeline card',
    );
    driver.expectExactlyOne(
      E2EFinders.key('timeline-card-$checkInId'),
      'one Alice timeline card',
    );
    driver.expectExactlyOne(
      E2EFinders.text('Check-in E2E Alice'),
      'one Alice timeline note',
    );
    await driver.waitForDocument(
      'users/e2e-alice',
      matches: (data) => data['points'] == 25,
      description: 'Alice single 25-point award',
    );
    await driver.waitForDocument(
      'friendships/ZTJlLWFsaWNl.ZTJlLWJvYg',
      matches: (data) => data['affinity_score'] == 1,
      description: 'Alice and Bob single affinity increment',
    );

    await driver.tapKey('settings-gear-shell');
    await driver.waitFor(E2EFinders.key('settings-logout'), 'Alice settings');
    await driver.tapKey('settings-logout');
    await driver.waitForLabel('Accedi come Bob E2E');
    await driver.tapLabel('Accedi come Bob E2E');
    await driver.waitForRoute('/timeline');
    await driver.tapKey('nav-/friends');
    await driver.waitForRoute('/friends');
    await driver.tapEnabledButton('Ci sto');
    await driver.waitFor(E2EFinders.key('check-in-page-0'), 'Bob photo step');
    final bobDraft = await driver.waitForJsonPreference(
      'check_in_draft_v2_e2e-bob',
      matches: (data) =>
          data['current_step'] == 0 &&
          (data['tagged_user_ids'] as List<Object?>).contains('e2e-alice'),
      description: 'Bob draft with Alice preselected',
    );
    await driver.tapEnabledButton('Chiudi');
    await driver.waitForRoute('/timeline');
    driver.expectNoFrameworkException('Bob draft close transition');
    await driver.waitForJsonPreference(
      'check_in_draft_v2_e2e-bob',
      matches: (data) =>
          data['id'] == bobDraft['id'] &&
          data['current_step'] == 0 &&
          (data['tagged_user_ids'] as List<Object?>).contains('e2e-alice'),
      description: 'preserved Bob draft after closing check-in',
    );

    await driver.waitFor(
      E2EFinders.key('timeline-card-$checkInId'),
      'Alice card in Bob timeline',
    );
    driver.expectExactlyOne(
      E2EFinders.key('timeline-card-$checkInId'),
      'one Alice card in Bob timeline',
    );
    driver.expectExactlyOne(
      E2EFinders.text('Check-in E2E Alice'),
      'one Alice note in Bob timeline',
    );
    await driver.waitForDocument(
      'users/e2e-bob',
      matches: (data) => data['points'] == 25,
      description: 'Bob single 25-point participation award',
    );

    await driver.tapKey('nav-/friends');
    await driver.waitForRoute('/friends');
    await driver.waitFor(
      E2EFinders.key('friend-profile-e2e-alice'),
      'Alice accepted friend card',
    );
    driver.expectNoFrameworkException(
      'Bob friends card before opening Alice profile',
    );
    await driver.tapLabel('Alice E2E');
    await driver.waitFor(
      E2EFinders.key('profile-compact'),
      'Alice public profile',
    );
    driver.expectAbsent(
      E2EFinders.key('profile-settings-gear'),
      'owner settings on Alice public profile',
    );
    driver.expectAbsent(
      E2EFinders.text('Modifica Profilo'),
      'owner edit action on Alice public profile',
    );

    await driver.tapTooltip('Indietro');
    await driver.waitForRoute('/friends');
    driver.expectNoFrameworkException('public profile back transition');
    await driver.tapKey('settings-gear-shell');
    await driver.waitFor(E2EFinders.key('settings-logout'), 'Bob settings');
    await driver.tapKey('settings-logout');
    await driver.waitForLabel('Accedi come Alice E2E');
    await driver.tapLabel('Accedi come Alice E2E');
    await driver.waitForRoute('/friends');

    await driver.tapKey('settings-gear-shell');
    await driver.waitFor(E2EFinders.key('settings-compact'), 'Alice settings');
    await driver.waitForLabel('Scuro');
    await driver.waitForLabel('Mappa');
    await driver.waitForDropdownValue('settings-theme', ThemeMode.dark);
    await driver.waitForDropdownValue('settings-default-view', 'map');
    await driver.waitForDocument(
      'users/e2e-alice',
      matches: (data) =>
          data['theme_mode'] == 'dark' &&
          data['default_collection_view'] == 'map',
      description: 'persisted Alice dark theme and map default',
    );
    await driver.setSwitch('settings-private-profile', true);
    await driver.waitForDocument(
      'users/e2e-alice',
      matches: (data) =>
          data['profile_visibility'] == 'private' &&
          data['searchable'] == false,
      description: 'Alice final private profile',
    );
    await driver.waitForDocument(
      'public_profiles/e2e-alice',
      matches: (data) =>
          data['profile_visibility'] == 'private' &&
          data['searchable'] == false,
      description: 'Alice final private projection',
    );

    await driver.tapKey('settings-back');
    await driver.waitForRoute('/friends');
    await driver.waitFor(
      E2EFinders.key('friend-remove-e2e-bob'),
      'Bob remove action',
    );
    await driver.tapKey('friend-remove-e2e-bob');
    await driver.waitFor(
      E2EFinders.key('friend-remove-confirm-e2e-bob'),
      'Bob remove confirmation',
    );
    await driver.tapKey('friend-remove-confirm-e2e-bob');
    await driver.waitForDocument(
      'friendships/ZTJlLWFsaWNl.ZTJlLWJvYg',
      matches: (data) => data['state'] == 'removed',
      description: 'removed Alice and Bob friendship',
    );
    await driver.waitForAbsent(
      E2EFinders.key('friend-profile-e2e-bob'),
      'Bob accepted friend card',
    );
    await driver.tapKey('nav-/timeline');
    await driver.waitForRoute('/timeline');
    await driver.waitFor(
      E2EFinders.key('timeline-card-$checkInId'),
      'Alice own card after friend removal',
    );
    driver.expectExactlyOne(
      E2EFinders.key('timeline-card-$checkInId'),
      'one Alice own card after friend removal',
    );

    await driver.tapKey('settings-gear-shell');
    await driver.waitFor(E2EFinders.key('settings-logout'), 'Alice settings');
    await driver.tapKey('settings-logout');
    await driver.waitForLabel('Accedi come Bob E2E');
    await driver.tapLabel('Accedi come Bob E2E');
    await driver.waitForRoute('/timeline');
    await driver.waitForMissingDocument(
      'feeds/e2e-bob/items/$checkInId',
      'revoked Alice feed item for Bob',
    );
    driver.expectNoFrameworkException('friend removal projection');
    await driver.waitForLabel('Nessun amico ancora');
    driver.expectAbsent(
      E2EFinders.key('timeline-card-$checkInId'),
      'revoked Alice card in Bob timeline',
    );
    driver.expectAbsent(
      E2EFinders.text('Check-in E2E Alice'),
      'revoked Alice note in Bob timeline',
    );

    await driver.tapKey('nav-/friends');
    await driver.waitForRoute('/friends');
    await driver.waitForLabel('Nessun amico, per ora');
    await driver.waitForAbsent(
      E2EFinders.key('friend-profile-e2e-alice'),
      'Alice accepted friend card',
    );
    await driver.enterAndSubmit('Nome o username', 'alice');
    await driver.waitForLabel('Nessun risultato');
    driver.expectAbsent(
      E2EFinders.key('friend-profile-e2e-alice'),
      'private Alice search result',
    );
    await driver.waitUntil(
      () => true,
      'clean framework state after final private-profile search',
    );
    driver.expectNoFrameworkException('final reciprocal journey state');
  });
}
