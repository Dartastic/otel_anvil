// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_anvil_suppression.dart';

const _tracerName = 'dartastic_otel_libs_anvil';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AnvilResult {
  const AnvilResult({
    this.product,
    this.castEid,
    this.weldEid,
    this.submissionEid,
    this.signaturePagesCount,
    this.signersCount,
    this.signersComplete,
    this.fillCount,
    this.outputPdfSize,
    this.requestId,
    this.statusCode,
  });

  /// `pdf_fill` / `etch` / `weld` / `cast` / `workflow` / `paywall`.
  /// Each Anvil product has distinct cost: PDF fills are cheap, Etch
  /// packets price per packet, Weld workflows include hosted UIs.
  final String? product;

  /// `castEid` — Anvil PDF Template id.
  final String? castEid;

  /// `weldEid` — workflow template id.
  final String? weldEid;

  /// `submissionEid`.
  final String? submissionEid;

  /// Number of signature pages added to the output PDF — drives the
  /// signature-page billing line on Etch.
  final int? signaturePagesCount;

  /// Total signers on an Etch packet.
  final int? signersCount;

  /// Count of signers complete.
  final int? signersComplete;

  /// Number of fill operations applied (for PDF fill calls).
  final int? fillCount;

  /// Output PDF size in bytes.
  final int? outputPdfSize;

  /// `X-Anvil-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class AnvilCallResult<T> {
  const AnvilCallResult({required this.value, this.result});
  final T value;
  final AnvilResult? result;
}

/// Wraps an Anvil API call in a CLIENT span. [operation] is one of
/// `pdf.fill`, `pdf.generate`, `pdf.download`, `etch.create_packet`,
/// `etch.send_packet`, `etch.complete_packet`, `etch.get_packet`,
/// `weld.create_forge`, `weld.get_submission`, `cast.list`,
/// `workflow.run`, `workflow.get`, `graphql`.
Future<T> tracedAnvil<T>({
  required String operation,
  required Future<AnvilCallResult<T>> Function() invoke,
  String? product,
}) async {
  if (anvilInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'anvil',
    'rpc.method': operation,
    'anvil.operation': operation,
  };
  if (product != null) m['anvil.product'] = product;

  final span = _tracer().startSpan(
    'anvil $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.product != null) {
        extras.add(OTel.attributeString(
          'anvil.product',
          r.result!.product!,
        ));
      }
      if (r.result!.castEid != null) {
        extras.add(OTel.attributeString(
          'anvil.cast.eid',
          r.result!.castEid!,
        ));
      }
      if (r.result!.weldEid != null) {
        extras.add(OTel.attributeString(
          'anvil.weld.eid',
          r.result!.weldEid!,
        ));
      }
      if (r.result!.submissionEid != null) {
        extras.add(OTel.attributeString(
          'anvil.submission.eid',
          r.result!.submissionEid!,
        ));
      }
      if (r.result!.signaturePagesCount != null) {
        extras.add(OTel.attributeInt(
          'anvil.signature_pages.count',
          r.result!.signaturePagesCount!,
        ));
      }
      if (r.result!.signersCount != null) {
        extras.add(OTel.attributeInt(
          'anvil.signers.count',
          r.result!.signersCount!,
        ));
      }
      if (r.result!.signersComplete != null) {
        extras.add(OTel.attributeInt(
          'anvil.signers.complete',
          r.result!.signersComplete!,
        ));
      }
      if (r.result!.fillCount != null) {
        extras.add(OTel.attributeInt(
          'anvil.fill_count',
          r.result!.fillCount!,
        ));
      }
      if (r.result!.outputPdfSize != null) {
        extras.add(OTel.attributeInt(
          'anvil.output_pdf.size_bytes',
          r.result!.outputPdfSize!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'anvil.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Anvil HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
