class ChatbotEngine {
  ChatbotEngine._();

  static const String _greeting =
      'Hello! I\'m CARDIVA\'s health assistant. You can ask me about: '
      'heart rate, SpO2, HRV, respiration, fall detection, emergency response, '
      'confidence score, or activity.';

  static String get greeting => _greeting;

  static String getResponse(String userInput) {
    final input = userInput.toLowerCase();

    if (input.contains('heart rate') || input.contains(' hr ') || input.startsWith('hr')) {
      return 'Heart Rate (HR) measures how many times your heart beats per minute. '
          'Normal resting range is 60–100 BPM. '
          'Above 100 BPM at rest is called tachycardia; below 60 BPM is bradycardia. '
          'CARDIVA adjusts HR thresholds based on your current activity — '
          'a rate of 170 BPM is normal while running but an emergency while resting.';
    }

    if (input.contains('spo2') || input.contains('oxygen') || input.contains('blood oxygen')) {
      return 'SpO2 (Blood Oxygen Saturation) measures the percentage of oxygen in your blood. '
          'Normal is 95% and above. '
          'Between 90–94% is concerning. '
          'Below 90% is a medical emergency and CARDIVA will trigger an alert immediately, '
          'regardless of other vitals or activity.';
    }

    if (input.contains('hrv') || input.contains('variability')) {
      return 'HRV (Heart Rate Variability) measures variation in time between heartbeats (SDNN). '
          'Higher HRV generally indicates good cardiovascular health and recovery. '
          'Normal is above 50 ms. '
          'Below 20 ms is an emergency signal indicating severe stress or cardiovascular strain.';
    }

    if (input.contains('respiration') || input.contains('breathing') || input.contains('breath')) {
      return 'Respiration Rate is how many breaths you take per minute. '
          'Normal adult range is 12–20 breaths per minute. '
          'Below 8 or above 25 triggers a warning; below 5 or above 30 is an emergency.';
    }

    if (input.contains('fall')) {
      return 'Fall Detection uses the wearable\'s accelerometer to detect sudden impacts. '
          'When a fall is detected, CARDIVA immediately triggers an emergency response — '
          'sending your GPS location via SMS to you and your emergency contact — '
          'regardless of your other vital readings or confidence score.';
    }

    if (input.contains('emergency')) {
      return 'When an emergency is triggered, CARDIVA: '
          '1) Gets your GPS location, '
          '2) Sends an SMS alert to you and your emergency contact with vitals and a maps link, '
          '3) Logs the event to the cloud, '
          '4) Shows an in-app emergency notification. '
          'You can mark it as a false alarm from the Emergency screen.';
    }

    if (input.contains('confidence') || input.contains('score')) {
      return 'The confidence score (0–100) measures how certain CARDIVA is that an alert is real. '
          'It is calculated from the severity of all vitals and adjusted for activity. '
          'A score of 70+ alongside emergency-level vitals triggers a real alert. '
          'Below 70, the alert is downgraded to a warning to reduce false positives.';
    }

    if (input.contains('activity')) {
      return 'Activity classification (resting, walking, running, lying down) adjusts '
          'heart rate thresholds to avoid false alarms. '
          'For example, a heart rate of 170 BPM is normal during running '
          'but would be an emergency alert while resting. '
          'SpO2 thresholds are never adjusted by activity.';
    }

    return 'I can help with: heart rate, SpO2 (blood oxygen), HRV, respiration rate, '
        'fall detection, emergency response, confidence score, and activity classification. '
        'What would you like to know?';
  }
}
