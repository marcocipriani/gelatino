import 'package:cloud_firestore/cloud_firestore.dart';

class Ping {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'declined'

  Ping({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.createdAt,
    this.status = 'pending',
  });

  factory Ping.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ping(
      id: doc.id,
      senderId: data['sender_id'] ?? '',
      senderName: data['sender_name'] ?? '',
      receiverId: data['receiver_id'] ?? '',
      createdAt: data['created_at'] != null 
          ? (data['created_at'] as Timestamp).toDate() 
          : DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'receiver_id': receiverId,
      'created_at': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  Ping copyWith({
    String? senderId,
    String? senderName,
    String? receiverId,
    DateTime? createdAt,
    String? status,
  }) {
    return Ping(
      id: id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
