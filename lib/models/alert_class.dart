enum AlertClass {
  emergency,   // Class 1 — Fall=True  + Vitals=High Risk
  fallAlert,   // Class 2 — Fall=True  + Vitals=Low Risk
  vitalsAlert, // Class 3 — Fall=False + Vitals=High Risk
  normal,      // Class 4 — Fall=False + Vitals=Low Risk
}

extension AlertClassX on AlertClass {
  int get classNumber => switch (this) {
        AlertClass.emergency => 1,
        AlertClass.fallAlert => 2,
        AlertClass.vitalsAlert => 3,
        AlertClass.normal => 4,
      };

  String get label => switch (this) {
        AlertClass.emergency => 'EMERGENCY',
        AlertClass.fallAlert => 'FALL ALERT',
        AlertClass.vitalsAlert => 'VITALS ALERT',
        AlertClass.normal => 'NORMAL',
      };

  String get shortLabel => switch (this) {
        AlertClass.emergency => 'Class 1',
        AlertClass.fallAlert => 'Class 2',
        AlertClass.vitalsAlert => 'Class 3',
        AlertClass.normal => 'Class 4',
      };

  String get message => switch (this) {
        AlertClass.emergency =>
          'Fall detected with high-risk vitals. Immediate emergency response required.',
        AlertClass.fallAlert =>
          'Fall detected. Vitals are within acceptable range.',
        AlertClass.vitalsAlert =>
          'Vitals are at high risk. No fall detected.',
        AlertClass.normal =>
          'No fall detected and all vitals are within normal range.',
      };

  bool get isEmergency => this == AlertClass.emergency;

  bool get requiresAction =>
      this == AlertClass.emergency || this == AlertClass.fallAlert;
}
