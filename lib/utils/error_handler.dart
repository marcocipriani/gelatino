import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA), // Fior di Panna (Sfondo Light)
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF4D6D), // Fragola Pop (Primary Border)
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D6D).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/images/logo.svg', // Melt Pin logo as warning icon
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ATTENZIONE',
                      style: TextStyle(
                        color: Color(0xFFFF4D6D), // Fragola Pop
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Plus Jakarta Sans',
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      readableMessage,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A), // Fondente Extra (Testo primario)
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Float it above the bottom navigation pill
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
