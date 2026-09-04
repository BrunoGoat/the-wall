/// Deterministic, allocation-free hashing used across the whole simulation.
///
/// Every visual detail of the wall (stone silhouettes, colour jitter, crack
/// placement, easter-egg glyphs) is derived from these functions instead of
/// being stored, so the wall rebuilds itself identically on every launch and a
/// brick placed a year ago never changes shape.
///
/// All arithmetic is kept inside 32 bits so results are identical on the JS
/// (web) and native backends.
library;

int _mul32(int a, int b) {
  final al = a & 0xFFFF;
  final ah = (a >>> 16) & 0xFFFF;
  return ((al * b) + (((ah * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}

int _avalanche(int x) {
  x &= 0xFFFFFFFF;
  x ^= x >>> 16;
  x = _mul32(x, 0x7feb352d);
  x ^= x >>> 15;
  x = _mul32(x, 0x846ca68b);
  x ^= x >>> 16;
  return x & 0xFFFFFFFF;
}

/// Hashes up to four integer coordinates into a stable 32-bit value.
int hash32(int a, [int b = 0, int c = 0, int d = 0]) {
  var h = 0x9e3779b9;
  h = _avalanche(h ^ (a & 0xFFFFFFFF));
  h = _avalanche(h ^ _mul32(b & 0xFFFFFFFF, 0x85ebca6b));
  h = _avalanche(h ^ _mul32(c & 0xFFFFFFFF, 0xc2b2ae35));
  h = _avalanche(h ^ _mul32(d & 0xFFFFFFFF, 0x27d4eb2f));
  return h;
}

/// Uniform value in `[0, 1)`.
double hash01(int a, [int b = 0, int c = 0, int d = 0]) =>
    hash32(a, b, c, d) / 4294967296.0;

/// Uniform value in `[min, max)`.
double hashRange(double min, double max, int a, [int b = 0, int c = 0, int d = 0]) =>
    min + (max - min) * hash01(a, b, c, d);

/// Signed value in `[-amount, amount)`.
double hashJitter(double amount, int a, [int b = 0, int c = 0, int d = 0]) =>
    (hash01(a, b, c, d) * 2.0 - 1.0) * amount;

/// Integer in `[0, max)`.
int hashInt(int max, int a, [int b = 0, int c = 0, int d = 0]) =>
    max <= 0 ? 0 : hash32(a, b, c, d) % max;

/// Bell-ish distribution in `[0, 1)`, useful for sizes that should cluster
/// around the middle instead of spreading flat.
double hashBell(int a, [int b = 0, int c = 0, int d = 0]) =>
    (hash01(a, b, c, d) + hash01(a, b, c, d + 7919)) * 0.5;

/// A tiny sequential generator for throwaway values (particles, sparks) where
/// determinism across launches does not matter but repeatability inside a
/// single burst does.
class SeqRandom {
  SeqRandom(this._state);
  int _state;

  double next() {
    _state = _avalanche(_state + 0x9e3779b9);
    return _state / 4294967296.0;
  }

  double range(double min, double max) => min + (max - min) * next();
  double jitter(double amount) => (next() * 2 - 1) * amount;
  int intN(int max) => max <= 0 ? 0 : (next() * max).floor();
}
