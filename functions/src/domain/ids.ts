export function pairId(uidA: string, uidB: string): string {
  if (!uidA || !uidB || uidA === uidB) throw new Error('otherUid must identify another user');
  return [uidA, uidB]
    .sort()
    .map((uid) => Buffer.from(uid, 'utf8').toString('base64url'))
    .join('.');
}

export const stagingPhotoPath = (uid: string, checkInId: string): string =>
  `staging/${uid}/${checkInId}.jpg`;

export const permanentPhotoPath = (uid: string, checkInId: string, version: number): string =>
  `check_ins/${uid}/${checkInId}/${version}.jpg`;
