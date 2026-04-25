class ApiEndpoints {
  ApiEndpoints._();

  // Supabase — configure via dart-define once credentials are ready
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Supabase table names
  static const String vitalReadings = 'vital_readings';
  static const String healthEvents = 'health_events';
  static const String alerts = 'alerts';
  static const String emergencyContacts = 'emergency_contacts';
  static const String users = 'users';
  static const String feedback = 'feedback';

  // Twilio — configure via dart-define or secure storage
  static const String twilioAccountSid = String.fromEnvironment('TWILIO_ACCOUNT_SID');
  static const String twilioAuthToken = String.fromEnvironment('TWILIO_AUTH_TOKEN');
  static const String twilioFromNumber = String.fromEnvironment('TWILIO_FROM_NUMBER');
}
