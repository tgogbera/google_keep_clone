import 'user.dart';

class AuthResponse {
  final String token;
  final String? refreshToken;
  final User user;

  AuthResponse({required this.token, this.refreshToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String?,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {'token': token, 'refresh_token': refreshToken, 'user': user.toJson()};
  }
}
