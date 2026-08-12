import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthSession {
  const AuthSession({
    this.id,
    required this.method,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final int? id;
  final String method;
  final String email;
  final String displayName;
  final String? photoUrl;

  bool get isGoogle => method == 'google';
  bool get isGuest => method == 'guest';
}

class AuthService {
  static const String _googleClientIdEnv = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  AuthService({required ApiService apiService, GoogleSignIn? googleSignIn})
    : _apiService = apiService,
      _googleSignIn =
          googleSignIn ??
          (_googleClientIdEnv.isNotEmpty
              ? GoogleSignIn(
                  scopes: const ['email'],
                  serverClientId: _googleClientIdEnv,
                )
              : GoogleSignIn(scopes: const ['email']));

  static const String _methodKey = 'auth_method';
  static const String _idKey = 'auth_id';
  static const String _emailKey = 'auth_email';
  static const String _displayNameKey = 'auth_display_name';
  static const String _photoUrlKey = 'auth_photo_url';
  static const String _tokenKey = 'auth_token';

  final ApiService _apiService;
  final GoogleSignIn _googleSignIn;

  Future<AuthSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final method = prefs.getString(_methodKey);
    if (method == null || method.isEmpty) {
      return null;
    }

    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      _apiService.setAuthToken(token);
    }

    if (method == 'google') {
      final user =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      if (user != null) {
        final session = AuthSession(
          id: prefs.getInt(_idKey),
          method: 'google',
          email: user.email,
          displayName: user.displayName ?? user.email,
          photoUrl: user.photoUrl,
        );
        await _persistSession(session);
        return session;
      }
    }

    final email = prefs.getString(_emailKey) ?? '';
    final displayName = prefs.getString(_displayNameKey) ?? email;
    final photoUrl = prefs.getString(_photoUrlKey);
    if (email.isEmpty) {
      return null;
    }

    return AuthSession(
      id: prefs.getInt(_idKey),
      method: method,
      email: email,
      displayName: displayName.isEmpty ? email : displayName,
      photoUrl: photoUrl,
    );
  }

  Future<AuthSession> signInWithGoogle() async {
    final user = await _googleSignIn.signIn();
    if (user == null) {
      throw Exception('Google sign-in was cancelled.');
    }
    final auth = await user.authentication;
    if (auth.idToken == null && auth.accessToken == null) {
      throw Exception(
        'Google sign-in returned no token. Configure GOOGLE_CLIENT_ID when building the app and ensure your Android OAuth client ID is allowed by the backend.',
      );
    }
    final payload = await _apiService.verifyGoogleSignIn(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );
    _apiService.setAuthToken(payload['token']?.toString());
    final session = AuthSession(
      id: payload['id'] as int?,
      method: 'google',
      email: payload['email']?.toString() ?? user.email,
      displayName:
          payload['display_name']?.toString() ?? user.displayName ?? user.email,
      photoUrl: payload['photo_url']?.toString() ?? user.photoUrl,
    );
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> signInWithEmail(String email) async {
    final normalized = email.trim();
    final payload = await _apiService.verifyEmailSignIn(normalized);
    _apiService.setAuthToken(payload['token']?.toString());
    final session = AuthSession(
      id: payload['id'] as int?,
      method: 'email',
      email: payload['email']?.toString() ?? normalized,
      displayName:
          payload['display_name']?.toString() ?? normalized.split('@').first,
    );
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> signInAsGuest() async {
    final payload = await _apiService.verifyGuestSignIn();
    _apiService.setAuthToken(payload['token']?.toString());
    final session = AuthSession(
      id: payload['id'] as int?,
      method: 'guest',
      email: payload['email']?.toString() ?? 'guest@novel.app',
      displayName: payload['display_name']?.toString() ?? 'Guest',
      photoUrl: payload['photo_url']?.toString(),
    );
    await _persistSession(session);
    return session;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _apiService.setAuthToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_methodKey);
    await prefs.remove(_idKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_photoUrlKey);
    await prefs.remove(_tokenKey);
  }

  Future<void> _persistSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_methodKey, session.method);
    final token = _apiService.authTokenForPersistence;
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
    }
    if (session.id != null) {
      await prefs.setInt(_idKey, session.id!);
    } else {
      await prefs.remove(_idKey);
    }
    await prefs.setString(_emailKey, session.email);
    await prefs.setString(_displayNameKey, session.displayName);
    if (session.photoUrl != null && session.photoUrl!.isNotEmpty) {
      await prefs.setString(_photoUrlKey, session.photoUrl!);
    } else {
      await prefs.remove(_photoUrlKey);
    }
  }
}
