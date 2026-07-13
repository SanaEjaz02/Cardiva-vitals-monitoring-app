import 'dart:math' as math;

/// Sliding-window accelerometer buffer that extracts the same 70 features
/// used to train the fall detection model in Fall_Detection.py.
///
/// Feature order (MUST match training feature_cols exactly):
///   [0-8]   x: mean,std,max,min,range,rms,zcr,skew,kurt
///   [9-17]  y: mean,std,max,min,range,rms,zcr,skew,kurt
///   [18-26] z: mean,std,max,min,range,rms,zcr,skew,kurt
///   [27-35] mag: mean,std,max,min,range,rms,zcr,skew,kurt
///   [36-42] x_fft: mean,std,max,dom_freq,entropy,low_energy,high_energy
///   [43-49] y_fft: same
///   [50-56] z_fft: same
///   [57-63] mag_fft: same
///   [64]    sma           (signal magnitude area)
///   [65]    xy_corr
///   [66]    xz_corr
///   [67]    yz_corr
///   [68]    impact_ratio  (mag_max / mag_mean)
///   [69]    total_energy  (sum of x²+y²+z²)
class AccelBuffer {
  static const int windowSize = 100;
  static const int stepSize   = 50;

  final List<double> _x = [];
  final List<double> _y = [];
  final List<double> _z = [];

  bool get hasWindow => _x.length >= windowSize;

  /// Add one accelerometer sample. Returns true when a full window is ready.
  bool addSample(double x, double y, double z) {
    _x.add(x);
    _y.add(y);
    _z.add(z);
    return _x.length >= windowSize;
  }

  /// Extract the 70 features from the current window, then slide by [stepSize].
  /// Only call this when [hasWindow] is true.
  List<double> extractAndSlide() {
    final xw = List<double>.from(_x.take(windowSize));
    final yw = List<double>.from(_y.take(windowSize));
    final zw = List<double>.from(_z.take(windowSize));

    // Slide — drop first stepSize samples
    if (_x.length > stepSize) {
      _x.removeRange(0, stepSize);
      _y.removeRange(0, stepSize);
      _z.removeRange(0, stepSize);
    } else {
      _x.clear(); _y.clear(); _z.clear();
    }

    return _extractFeatures(xw, yw, zw);
  }

  void reset() { _x.clear(); _y.clear(); _z.clear(); }

  // ── Feature extraction ────────────────────────────────────────────────────

  static List<double> _extractFeatures(
      List<double> xw, List<double> yw, List<double> zw) {
    final n = xw.length;
    final mag = List<double>.generate(
        n, (i) => math.sqrt(xw[i] * xw[i] + yw[i] * yw[i] + zw[i] * zw[i]));

    final features = <double>[];

    // Time-domain stats for x, y, z, mag  (4 × 9 = 36 features)
    for (final arr in [xw, yw, zw, mag]) {
      features.addAll(_stats(arr));
    }

    // FFT features for x, y, z, mag  (4 × 7 = 28 features)
    for (final arr in [xw, yw, zw, mag]) {
      features.addAll(_fftFeatures(arr));
    }

    // Extra features  (6 features)
    final sma = _absSum(xw) / n + _absSum(yw) / n + _absSum(zw) / n;
    features.add(sma);                           // 64
    features.add(_correlation(xw, yw));          // 65 xy_corr
    features.add(_correlation(xw, zw));          // 66 xz_corr
    features.add(_correlation(yw, zw));          // 67 yz_corr

    final magMean = _mean(mag);
    final magMax  = mag.reduce(math.max);
    features.add(magMax / (magMean + 1e-6));     // 68 impact_ratio

    double totalEnergy = 0;
    for (int i = 0; i < n; i++) {
      totalEnergy += xw[i] * xw[i] + yw[i] * yw[i] + zw[i] * zw[i];
    }
    features.add(totalEnergy);                   // 69 total_energy

    return features;
  }

  // 9 time-domain stats — matches Python stats() in Fall_Detection.py
  static List<double> _stats(List<double> arr) {
    final n   = arr.length;
    final m   = _mean(arr);
    final m2  = arr.fold(0.0, (s, v) => s + (v - m) * (v - m)) / n;
    final std = math.sqrt(m2);
    final maxV = arr.reduce(math.max);
    final minV = arr.reduce(math.min);
    final rms  = math.sqrt(arr.fold(0.0, (s, v) => s + v * v) / n);

    // Zero crossing rate: count sign changes
    double zcr = 0;
    for (int i = 0; i < n - 1; i++) {
      if (arr[i] * arr[i + 1] < 0) zcr++;
    }
    zcr /= n;

    // Skewness — biased Fisher-Pearson (pandas default for large n)
    double skew = 0;
    if (std > 1e-10) {
      final m3 = arr.fold(0.0, (s, v) => s + math.pow(v - m, 3)) / n;
      skew = m3 / math.pow(std, 3);
    }

    // Excess kurtosis (Fisher's G2)
    double kurt = 0;
    if (std > 1e-10) {
      final m4 = arr.fold(0.0, (s, v) => s + math.pow(v - m, 4)) / n;
      kurt = m4 / math.pow(std, 4) - 3.0;
    }

    return [m, std, maxV, minV, maxV - minV, rms, zcr, skew, kurt];
  }

  // 7 FFT features — matches Python fft_features() in Fall_Detection.py
  static List<double> _fftFeatures(List<double> arr) {
    final fftMags  = _rfft(arr);
    final halfN    = fftMags.length;
    final totalPow = fftMags.fold(0.0, (s, v) => s + v) + 1e-6;
    final freqStep = 1.0 / arr.length;

    final fftMean = fftMags.fold(0.0, (s, v) => s + v) / halfN;
    final fftStd  = math.sqrt(
      fftMags.fold(0.0, (s, v) => s + (v - fftMean) * (v - fftMean)) / halfN,
    );
    final fftMax  = fftMags.reduce(math.max);
    final domIdx  = fftMags.indexOf(fftMax);
    final domFreq = domIdx * freqStep;

    // Spectral entropy
    double entropy = 0;
    for (final v in fftMags) {
      final p = v / totalPow;
      if (p > 1e-12) entropy -= p * math.log(p + 1e-6) / math.ln2;
    }

    final third      = halfN ~/ 3;
    final lowEnergy  = fftMags.sublist(0, third).fold(0.0, (s, v) => s + v) / totalPow;
    final highEnergy = fftMags.sublist(third).fold(0.0, (s, v) => s + v) / totalPow;

    return [fftMean, fftStd, fftMax, domFreq, entropy, lowEnergy, highEnergy];
  }

  // Real DFT magnitude spectrum — O(n²) fine for n=100 (5 100 ops)
  static List<double> _rfft(List<double> signal) {
    final n     = signal.length;
    final halfN = n ~/ 2 + 1;
    final mags  = List<double>.filled(halfN, 0.0);
    for (int k = 0; k < halfN; k++) {
      double re = 0.0, im = 0.0;
      final angle = 2 * math.pi * k / n;
      for (int t = 0; t < n; t++) {
        re += signal[t] * math.cos(angle * t);
        im -= signal[t] * math.sin(angle * t);
      }
      mags[k] = math.sqrt(re * re + im * im);
    }
    return mags;
  }

  static double _mean(List<double> arr) =>
      arr.fold(0.0, (s, v) => s + v) / arr.length;

  static double _absSum(List<double> arr) =>
      arr.fold(0.0, (s, v) => s + v.abs());

  static double _correlation(List<double> a, List<double> b) {
    final n    = a.length;
    final stdA = _stdOf(a);
    final stdB = _stdOf(b);
    if (stdA <= 1e-10 || stdB <= 1e-10) return 0.0;
    final mA = _mean(a);
    final mB = _mean(b);
    double cov = 0;
    for (int i = 0; i < n; i++) {
      cov += (a[i] - mA) * (b[i] - mB);
    }
    return (cov / n) / (stdA * stdB);
  }

  static double _stdOf(List<double> arr) {
    final m = _mean(arr);
    return math.sqrt(
      arr.fold(0.0, (s, v) => s + (v - m) * (v - m)) / arr.length,
    );
  }
}
