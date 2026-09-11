import 'package:youtube_explode_dart/youtube_explode_dart.dart';
void main() async {
  var yt = YoutubeExplode();
  var manifest = await yt.videos.streamsClient.getManifest('M7lc1UVf-VE');
  print(manifest.muxed.first.url);
  yt.close();
}
