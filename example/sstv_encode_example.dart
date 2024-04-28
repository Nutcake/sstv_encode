import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:sstv_encode/sstv_encode.dart';

void main() async {
  final enc = Encoder();
  final image = File("test.jpg");
  final cmd = img.Command()..decodeImage(image.readAsBytesSync());
  final pcm = await enc.robot36((await cmd.execute()).outputImage ?? (throw "Failed to read image"));
  final outFile = File("out.pcm");
  outFile.writeAsBytesSync(pcm);
}
