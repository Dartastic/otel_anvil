// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_anvil/otel_anvil.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_anvil-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('etch.create_packet records signers + sig pages', () async {
    await tracedAnvil<String>(
      operation: 'etch.create_packet',
      product: 'etch',
      invoke: () async => const AnvilCallResult(
        value: 'ok',
        result: AnvilResult(
          product: 'etch',
          castEid: 'cast-1',
          submissionEid: 'sub-1',
          signaturePagesCount: 4,
          signersCount: 3,
          signersComplete: 0,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('anvil etch.create_packet')!);
    expect(a['anvil.product'], 'etch');
    expect(a['anvil.cast.eid'], 'cast-1');
    expect(a['anvil.signature_pages.count'], 4);
    expect(a['anvil.signers.count'], 3);
  });

  test('pdf.fill records fill_count + size', () async {
    await tracedAnvil<String>(
      operation: 'pdf.fill',
      product: 'pdf_fill',
      invoke: () async => const AnvilCallResult(
        value: 'ok',
        result: AnvilResult(
          product: 'pdf_fill',
          fillCount: 27,
          outputPdfSize: 152300,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('anvil pdf.fill')!);
    expect(a['anvil.fill_count'], 27);
    expect(a['anvil.output_pdf.size_bytes'], 152300);
  });

  test('suppression skips spans', () async {
    await runWithoutAnvilInstrumentationAsync(() async {
      await tracedAnvil<String>(
        operation: 'cast.list',
        invoke: () async => const AnvilCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('anvil '), isEmpty);
  });
}
