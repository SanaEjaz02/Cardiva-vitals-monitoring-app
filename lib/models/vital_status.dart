enum VitalStatus { normal, stable, warning, emergency }

extension VitalStatusX on VitalStatus {
  bool get isAtLeastWarning =>
      this == VitalStatus.warning || this == VitalStatus.emergency;

  bool get isEmergencyLevel => this == VitalStatus.emergency;

  int get severity {
    switch (this) {
      case VitalStatus.normal:
        return 0;
      case VitalStatus.stable:
        return 1;
      case VitalStatus.warning:
        return 2;
      case VitalStatus.emergency:
        return 3;
    }
  }
}
