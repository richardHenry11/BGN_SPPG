import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';

class CommunityReceiptService {
  final ApiClient _client;

  CommunityReceiptService(this._client);

  Future<String> uploadPhoto(String filePath, {Map<String, String>? headers, Uint8List? bytes}) async {
    final streamed = await _client.uploadPhoto(
      '/api/distribution/upload',
      filePath,
      headers: headers,
      bytes: bytes,
    );
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      try {
        final err = jsonDecode(body);
        throw Exception((err['error'] ?? err['message'] ?? err).toString());
      } catch (_) {
        throw Exception('Upload gagal (${streamed.statusCode})');
      }
    }
    final result = jsonDecode(body) as Map<String, dynamic>;
    return (result['url'] ?? result['path'] ?? '').toString();
  }

  Future<Map<String, dynamic>> submit({
    required int packagingLogId,
    String? email,
    String? reviewerName,
    String? reviewerSchool,
    required String kelengkapan,
    required String keutuhan,
    required String kebersihan,
    required String bau,
    required String bendaAsing,
    required String rasa,
    String? keterangan,
    String? reviewPhotoUrl,
    String? digitalSignature,
    int? sppgId,
  }) async {
    final body = <String, dynamic>{
      'packaging_log_id': packagingLogId,
      'kelengkapan': kelengkapan,
      'keutuhan': keutuhan,
      'kebersihan': kebersihan,
      'bau': bau,
      'benda_asing': bendaAsing,
      'rasa': rasa,
    };

    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    } else {
      if (reviewerName != null && reviewerName.isNotEmpty) {
        body['reviewer_name'] = reviewerName;
      }
      if (reviewerSchool != null && reviewerSchool.isNotEmpty) {
        body['reviewer_school'] = reviewerSchool;
      }
    }

    if (keterangan != null && keterangan.isNotEmpty) {
      body['keterangan'] = keterangan;
    }
    if (reviewPhotoUrl != null && reviewPhotoUrl.isNotEmpty) {
      body['review_photo_url'] = reviewPhotoUrl;
    }
    if (digitalSignature != null && digitalSignature.isNotEmpty) {
      body['digital_signature'] = digitalSignature;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (sppgId != null) 'X-Sppg-Id': sppgId.toString(),
    };

    final res = await _client.post(
      '/api/production/community-receipts',
      body: body,
      headers: headers,
    );

    if (res.statusCode != 201) {
      String msg;
      try {
        final json = jsonDecode(res.body);
        msg = (json['error'] ?? json['message'] ?? json).toString();
      } catch (_) {
        msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      }
      throw Exception(msg);
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
