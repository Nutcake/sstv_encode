import 'dart:typed_data';
import 'package:complex/complex.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class Encoder {
  static const int imgWidth = 320;
  static const int imgHeight = 240;
  static const gain = 1.555602005e+02;
  static const bufSize = 256;
  static const sampleRate = 11025;
  static const tau = 0.003906;
  late List<double> _xv;
  late List<double> _yv;
  late List<int> _outBuf;
  late Complex _osc;

  Encoder() {
    _init();
  }

  double _filterSample(double f) {
    _xv[0] = _xv[1];
    _xv[1] = _xv[2];
    _xv[2] = _xv[3];
    _xv[3] = _xv[4];
    _xv[4] = _xv[5];
    _xv[5] = _xv[6];
    _xv[6] = _xv[7];
    _xv[7] = _xv[8];
    _xv[8] = f / gain;
    _yv[0] = _yv[1];
    _yv[1] = _yv[2];
    _yv[2] = _yv[3];
    _yv[3] = _yv[4];
    _yv[4] = _yv[5];
    _yv[5] = _yv[6];
    _yv[6] = _yv[7];
    _yv[7] = _yv[8];
    _yv[8] = (_xv[0] + _xv[8]) -
        4 * (_xv[2] + _xv[6]) +
        6 * _xv[4] +
        (-0.1604951873 * _yv[0]) +
        (0.9423465126 * _yv[1]) +
        (-3.0341838933 * _yv[2]) +
        (6.3246272229 * _yv[3]) +
        (-9.3774455861 * _yv[4]) +
        (9.9657261890 * _yv[5]) +
        (-7.5658697910 * _yv[6]) +
        (3.7429505786 * _yv[7]);
    return _yv[8];
  }

  void _bufferFloat(double f) {
    _outBuf.add((_filterSample(f) * 255).round());
  }

  void _blank({required double ms}) {
    final nSamp = (sampleRate * ms / 1000).floor();
    for (var i = 0; i < nSamp; i++) {
      _bufferFloat(0);
    }
  }

  void _pulse({required double freq, required double ms}) {
    final nSamp = (sampleRate * ms / 1000).floor();

    Complex m = (Complex.i * 2 * math.pi * freq / sampleRate).exp();
    for (var i = 0; i < nSamp; i++) {
      _osc *= m;
      _bufferFloat(_osc.real);
    }
  }

  void _vis({required int code}) {
    _pulse(freq: 1900, ms: 300);
    _pulse(freq: 1200, ms: 10);
    _pulse(freq: 1900, ms: 300);
    _pulse(freq: 1200, ms: 30);
    var parity = 0;
    for (var i = 0; i < 8; i++) {
      if (code & 1 >= 1) {
        _pulse(freq: 1100, ms: 30);
        parity++;
      } else {
        _pulse(freq: 1300, ms: 30);
      }
      code = code >> 1;
    }
    _pulse(freq: parity.isEven ? 1300 : 1100, ms: 30);
    _pulse(freq: 1200, ms: 30);
  }

  double _toFreq(double v) => 1500 + (v * 3.1372549);

  void _scanlinePair(img.Image image, img.Image halfImage, int y) {
    const ySamples = 88 * sampleRate / 1000;
    const samples = 44 * sampleRate / 1000;

    _pulse(freq: 1200, ms: 9);
    _pulse(freq: 1500, ms: 3);

    for (var i = 0; i < ySamples; i++) {
      final x = (i * imgWidth) ~/ ySamples;
      final px = image.getPixel(x, y);
      final v = 16 + (tau * ((65.738 * px.r) + (129.057 * px.g) + (25.064 * px.b)));
      final freq = _toFreq(v);
      final m = (Complex.i * 2 * math.pi * freq / sampleRate).exp();
      _osc *= m;
      _bufferFloat(_osc.real);
    }

    _pulse(freq: 1500, ms: 4.5);
    _pulse(freq: 1900, ms: 1.5);

    for (var i = 0; i < samples; i++) {
      final x = (i * (imgWidth ~/ 2)) ~/ samples;
      final px = halfImage.getPixel(x, (y ~/ 2));
      final v = 128 + (tau * ((112.439 * px.r) + (-94.154 * px.g) + (-18.285 * px.b)));
      final freq = _toFreq(v);
      final m = (Complex.i * 2 * math.pi * freq / sampleRate).exp();
      _osc *= m;
      _bufferFloat(_osc.real);
    }

    _pulse(freq: 1200, ms: 9);
    _pulse(freq: 1500, ms: 3);

    for (var i = 0; i < ySamples; i++) {
      final x = (i * imgWidth) ~/ ySamples;
      final px = image.getPixel(x, y + 1);
      final v = 16 + (tau * ((65.737 * px.r) + (129.057 * px.g) + (25.064 * px.b)));
      final freq = _toFreq(v);
      final m = (Complex.i * 2 * math.pi * freq / sampleRate).exp();
      _osc *= m;
      _bufferFloat(_osc.real);
    }

    _pulse(freq: 2300, ms: 4.5);
    _pulse(freq: 1900, ms: 1.5);

    for (var i = 0; i < samples; i++) {
      final x = (i * (imgWidth ~/ 2)) ~/ samples;
      final px = halfImage.getPixel(x, ((y + 1) ~/ 2));
      final v = 128 + (tau * ((-37.945 * px.r) + (-74.494 * px.g) + (112.439 * px.b)));
      final freq = _toFreq(v);
      final m = (Complex.i * 2 * math.pi * freq / sampleRate).exp();
      _osc *= m;
      _bufferFloat(_osc.real);
    }
  }

  void _init() {
    _xv = List.generate(9, (index) => 0);
    _yv = List.generate(9, (index) => 0);
    _outBuf = [];
    _osc = Complex(0.15);
  }

  Future<Uint8List> robot36(img.Image image) async {
    var cmd = img.Command()
      ..image(image)
      ..convert(numChannels: 3)
      ..copyResize(width: imgWidth, height: imgHeight);
    image = (await cmd.execute()).outputImage ?? (throw "Failed to re-encode image");

    const halfHeight = imgHeight ~/ 2;
    const halfWidth = imgWidth ~/ 2;
    cmd = img.Command()
      ..image(image)
      ..copyResize(width: halfWidth, height: halfHeight);
    final halfImage = (await cmd.execute()).outputImage ?? (throw "Failed to create half-size image");

    _init();

    _blank(ms: 500);
    _vis(code: 128 + 8);

    for (var y = 0; y < imgHeight; y += 2) {
      _scanlinePair(image, halfImage, y);
    }

    _blank(ms: 500);

    return Uint8List.fromList(_outBuf);
  }
}
