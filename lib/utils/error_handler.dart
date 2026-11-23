import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

class ErrorHandler {
  /// Converte un'eccezione tecnica in un messaggio amichevole per l'utente in italiano.
  static String getReadableError(dynamic error) {
    if (error == null) return 'Errore sconosciuto';

    final String message = error.toString();
    
    // Controlla se si tratta di un'eccezione Firebase
    if (error is FirebaseException) {
      switch (error.code) {
        case 'quota-exceeded':
          return 'Quota di caricamento di Firebase superata per oggi (limite piano gratuito Spark). Riprova più tardi!';
        case 'permission-denied':
          return 'Accesso negato: permessi insufficienti per leggere o scrivere i dati.';
        case 'unauthorized':
          return 'Operazione non autorizzata: verifica di aver effettuato correttamente l\'accesso.';
        case 'network-request-failed':
          return 'Impossibile connettersi ai server. Verifica la tua connessione a internet.';
        case 'user-disabled':
          return 'Questo account utente è stato disabilitato.';
        case 'user-not-found':
          return 'Nessun utente trovato con queste credenziali.';
        case 'wrong-password':
          return 'Password errata. Riprova.';
        case 'invalid-credential':
          return 'Credenziali non valide o scadute.';
        default:
          return 'Errore Firebase (${error.code}): ${error.message ?? error.toString()}';
      }
    }

    // Controlli basati sul testo della stringa (fallback per web/js wrapper)
    if (message.contains('quota-exceeded') || message.contains('quota exceeded')) {
      return 'Spazio o quota di Firebase esauriti per oggi. Riprova più tardi!';
    }
    if (message.contains('permission-denied') || message.contains('permission denied')) {
      return 'Permessi non sufficienti per completare l\'azione sul database.';
    }
    if (message.contains('unauthorized')) {
      return 'Non sei autorizzato a compiere questa azione. Prova a rifare il login.';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'Errore di rete: controlla la tua connessione internet.';
    }
    if (message.contains('Utente non loggato')) {
      return 'Devi prima effettuare l\'accesso con Google!';
    }

    return 'Errore: $message';
  }

  /// Mostra un Toast di errore fluttuante personalizzato nello stile Creamy Flat dell'app.
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final readableMessage = getReadableError(error);
    
    // Rimuove eventuali SnackBar attive per mostrare subito quella nuova
    ScaffoldMessenger.of(context).clearSnackBars();
    
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: colors.inversePrimary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(readableMessage)),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
