/**
 * Shared options for every callable.
 *
 * App Check is enforced only when `ENFORCE_APP_CHECK=true` is set in
 * `functions/.env`, read when the functions are loaded. Turn it on only once
 * the shipped clients send App Check tokens (see README): enforcing earlier
 * rejects every call from builds that predate App Check.
 */
export function appCheckEnforced(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.ENFORCE_APP_CHECK === 'true';
}

export const callableOptions = {
  region: 'europe-west1',
  enforceAppCheck: appCheckEnforced(),
} as const;
