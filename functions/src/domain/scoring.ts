export const CHECK_IN_BASE_POINTS = 10;
export const SHARED_CHECK_IN_BASE_POINTS = 15;
export const FIRST_PLACE_BONUS = 10;
export const MIN_REPEAT_POINTS = 2;
export const TAGGED_FRIEND_AFFINITY = 1;

export function monthKey(now: Date): string {
  return now.toISOString().slice(0, 7);
}

export function pointsForParticipation(
  base: number,
  priorVisits: number,
): number {
  return priorVisits === 0
    ? base + FIRST_PLACE_BONUS
    : Math.max(MIN_REPEAT_POINTS, base - priorVisits);
}
