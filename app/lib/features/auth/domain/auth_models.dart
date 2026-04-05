// lib/features/auth/domain/auth_models.dart
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

class AuthTokens {
  final String accessToken;
  final String idToken;
  final String refreshToken;

  const AuthTokens({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
    accessToken:  j['accessToken']  as String,
    idToken:      j['idToken']      as String,
    refreshToken: j['refreshToken'] as String,
  );
}

class AppUser {
  final String email;
  final String name;
  final String role; // "hod" | "lecturer"
  final List<String> groups;

  const AppUser({
    required this.email,
    required this.name,
    required this.role,
    required this.groups,
  });

  bool get isHod => role == 'hod';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    email:  j['email']  as String? ?? '',
    name:   j['name']   as String? ?? j['email'] as String? ?? '',
    role:   (j['groups'] as List?)?.contains('hod') == true ? 'hod' : 'lecturer',
    groups: List<String>.from(j['groups'] as List? ?? []),
  );
}

enum AuthStatus {
  unauthenticated,
  loading,
  requiresPasswordChange,
  requiresMfaSetup,
  requiresMfaVerify,
  authenticated,
  sessionExpired,
}

class AuthState {
  final AuthStatus status;
  final AppUser?   user;
  final String?    errorMessage;
  final String?    session;     // Cognito challenge session token
  final String?    challengeName;
  final String?    email;       // Persisted across challenge steps
  final String?    secretCode;  // TOTP secret for MFA setup

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.session,
    this.challengeName,
    this.email,
    this.secretCode,
  });

  const AuthState.initial() : this(status: AuthStatus.unauthenticated);

  AuthState copyWith({
    AuthStatus? status,
    AppUser?    user,
    String?     errorMessage,
    String?     session,
    String?     challengeName,
    String?     email,
    String?     secretCode,
  }) => AuthState(
    status:        status        ?? this.status,
    user:          user          ?? this.user,
    errorMessage:  errorMessage,
    session:       session       ?? this.session,
    challengeName: challengeName ?? this.challengeName,
    email:         email         ?? this.email,
    secretCode:    secretCode    ?? this.secretCode,
  );
}
