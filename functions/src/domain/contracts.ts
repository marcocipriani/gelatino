import type * as FirebaseFirestore from 'firebase-admin/firestore';

export type FriendshipState = 'pending' | 'accepted' | 'declined' | 'removed';

export type CreateCheckInInput = {
  checkInId: string;
  placeId: string;
  gelatoTypeId: string;
  flavorIds: string[];
  rating: number;
  reviewText: string;
  taggedUserIds: string[];
  stagingObjectPath: string;
  /// When the gelato was actually eaten, epoch milliseconds. Omitted means
  /// "now", which is every check-in published as it happens. Only backdated
  /// check-ins send it.
  consumedAtMs?: number;
};

export type RespondFriendRequestInput = {
  otherUid: string;
  response: 'accepted' | 'declined';
};

export type PublicProfile = {
  uid: string;
  display_name: string;
  display_name_lower: string;
  username: string;
  username_lower: string;
  avatar_path: string | null;
  bio: string;
  city: string;
  favorite_place_id: string | null;
  favorite_flavor_id: string | null;
  favorite_flavor_ids: string[];
  profile_visibility: 'public' | 'friends' | 'private';
  searchable: boolean;
  points: number;
  monthly_points: Record<string, number>;
  updated_at: FirebaseFirestore.Timestamp;
};
