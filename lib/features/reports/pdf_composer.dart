import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_layout.dart';

class PdfComposer {
  // Three rows plus their block header must fit between the repeating page
  // header and footer so the complete block can remain inseparable.
  static const double _photoSize = 2.8 * PdfPageFormat.inch;

  Future<Uint8List> compose(ReportLayout layout) async {
    final images = await _loadImages(layout);
    final document = pw.Document(
      title: layout.title,
      author: layout.contractor.name,
      creator: 'Tower Inspection',
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(54, 60, 54, 36),
        build: (_) => _coverPage(layout),
      ),
    );
    if (layout.items.isNotEmpty) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(48, 36, 48, 36),
          maxPages: 100,
          header: (context) => _pageHeader(layout, context.pageNumber),
          footer: (_) => _pageFooter(layout.contractor),
          build: (_) => _body(layout, images),
        ),
      );
    }
    return document.save();
  }

  Future<Map<String, pw.MemoryImage>> _loadImages(ReportLayout layout) async {
    final images = <String, pw.MemoryImage>{};
    for (final item in layout.items) {
      for (final block in item.photoBlocks) {
        for (final slot in block.slots) {
          final imagePath = slot.reportPath;
          if (imagePath == null || images.containsKey(imagePath)) continue;
          final file = File(imagePath);
          if (!await file.exists()) continue;
          try {
            images[imagePath] = pw.MemoryImage(await file.readAsBytes());
          } on FileSystemException {
            // A missing/unreadable derivative renders as an empty photo box.
          }
        }
      }
    }
    return images;
  }

  pw.Widget _coverPage(ReportLayout layout) {
    final cover = layout.cover;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Spacer(flex: 2),
        pw.Center(
          child: pw.Text(
            'Tower Site Inspection Report',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 48),
        _coverLine('Site Name', cover.siteName),
        _coverLine('ASR', cover.asr),
        _coverLine('Prepared for', cover.preparedFor),
        if (cover.hasAddress) _coverLine('Address', cover.address),
        pw.SizedBox(height: 40),
        pw.Text(
          _safeText(layout.contractor.name),
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.Text(
          _safeText(layout.contractor.address),
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.Text(
          _safeText(layout.contractor.cityStateZip),
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 40),
        _coverLine('Date of Inspection', cover.inspectionDate),
        pw.Spacer(flex: 3),
        _pageFooter(layout.contractor),
      ],
    );
  }

  pw.Widget _coverLine(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(
      _safeText('$label: $value'),
      style: const pw.TextStyle(fontSize: 14),
    ),
  );

  pw.Widget _pageHeader(ReportLayout layout, int pageNumber) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            _safeText(
              '${layout.header.siteName}\n${layout.header.inspectionDate}',
            ),
            style: const pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
        pw.Text(
          _safeText('ASR: ${layout.header.asr}\nPage $pageNumber'),
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  pw.Widget _pageFooter(ReportContractorSpec contractor) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(top: 5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(width: 0.8)),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          _safeText(contractor.name),
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          _safeText(contractor.address),
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          _safeText(contractor.cityStateZip),
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );

  List<pw.Widget> _body(
    ReportLayout layout,
    Map<String, pw.MemoryImage> images,
  ) {
    final widgets = <pw.Widget>[];
    for (final page in layout.bodyPages) {
      final item = page.item!;
      if (page.showItemHeader) {
        widgets.add(_itemHeader(item));
      }

      final photoBlock = page.photoBlock;
      if (photoBlock == null) {
        final observation = item.observation;
        if (observation != null) {
          widgets
            ..add(_observationOnly(observation))
            ..add(pw.SizedBox(height: 12));
        }
        continue;
      }

      widgets.add(_photoBlock(photoBlock, item.observation, images));
      if (photoBlock.blockNumber == item.photoBlocks.length) {
        widgets.add(pw.SizedBox(height: 12));
      }
    }
    return widgets;
  }

  pw.Widget _itemHeader(ReportItemSpec item) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      if (item.showSectionHeader) ...[
        pw.Text(
          _safeText(item.sectionTitle),
          style: const pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
      ],
      _borderedText(item.fullLabel, bold: true),
      _statusRow(item.status),
    ],
  );

  pw.Widget _photoBlock(
    PhotoBlockSpec block,
    ObservationBlockSpec? observation,
    Map<String, pw.MemoryImage> images,
  ) {
    final moveObservationAbovePhotos =
        block.blockNumber == 1 &&
        observation != null &&
        observation.comments.length > 300;
    final photoContent = pw.Inseparable(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _photoBlockHeader(
            block,
            moveObservationAbovePhotos ? null : observation,
          ),
          for (var slotIndex = 0; slotIndex < block.slots.length; slotIndex++)
            _photoRow(
              block.slots[slotIndex],
              images,
              moveObservationAbovePhotos && slotIndex == 0
                  ? null
                  : block.blockNumber == 1 && slotIndex == 0
                  ? observation
                  : null,
            ),
        ],
      ),
    );
    if (!moveObservationAbovePhotos) return photoContent;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [_observationFlow(observation!), photoContent],
    );
  }

  pw.Widget _borderedText(String value, {bool bold = false}) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
    child: pw.Text(
      _safeText(value),
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  pw.Widget _statusRow(StatusRowSpec status) => pw.Table(
    border: pw.TableBorder.all(width: 0.8),
    columnWidths: {
      for (var index = 0; index < status.cells.length; index++)
        index: const pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(
        children: [
          for (final cell in status.cells)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 7,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _checkbox(cell.selected),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      _safeText(cell.label),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  pw.Widget _checkbox(bool selected) => pw.CustomPaint(
    size: const PdfPoint(9, 9),
    painter: (canvas, size) {
      canvas
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(0.8)
        ..moveTo(0.5, 0.5)
        ..lineTo(size.x - 0.5, 0.5)
        ..lineTo(size.x - 0.5, size.y - 0.5)
        ..lineTo(0.5, size.y - 0.5)
        ..strokePath(close: true);
      if (selected) {
        canvas
          ..setLineWidth(1.2)
          ..moveTo(2, 4.5)
          ..lineTo(4, 2)
          ..lineTo(7.5, 7)
          ..strokePath();
      }
    },
  );

  pw.Widget _photoBlockHeader(
    PhotoBlockSpec block,
    ObservationBlockSpec? observation,
  ) => pw.Table(
    border: pw.TableBorder.all(width: 0.8),
    columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth()},
    children: [
      pw.TableRow(
        children: [
          _tableHeaderCell(block.label, drawEnDash: block.continued),
          _tableHeaderCell(
            observation?.title ?? 'Observations and Recommendations',
          ),
        ],
      ),
    ],
  );

  pw.Widget _tableHeaderCell(String value, {bool drawEnDash = false}) {
    const style = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    final parts = value.split(' – ');
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: !drawEnDash || parts.length != 2
          ? pw.Text(_safeText(value), style: style)
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_safeText(parts.first), style: style),
                pw.Row(
                  children: [
                    _enDash(),
                    pw.SizedBox(width: 3),
                    pw.Expanded(
                      child: pw.Text(_safeText(parts.last), style: style),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  pw.Widget _enDash() => pw.CustomPaint(
    size: const PdfPoint(8, 10),
    painter: (canvas, size) {
      canvas
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(0.8)
        ..moveTo(0, size.y / 2)
        ..lineTo(size.x, size.y / 2)
        ..strokePath();
    },
  );

  pw.Widget _photoRow(
    PhotoSlotSpec slot,
    Map<String, pw.MemoryImage> images,
    ObservationBlockSpec? observation,
  ) {
    final image = slot.reportPath == null ? null : images[slot.reportPath];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            height: _photoSize,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
            child: pw.Container(
              width: _photoSize,
              height: _photoSize,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
              child: image == null
                  ? pw.SizedBox()
                  : pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
            child: observation == null || observation.comments.isEmpty
                ? pw.SizedBox(height: _photoSize - 14)
                : pw.Text(
                    _safeText(observation.comments),
                    softWrap: true,
                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                  ),
          ),
        ),
      ],
    );
  }

  pw.Widget _observationOnly(ObservationBlockSpec observation) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _borderedText(observation.title, bold: true),
      pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
        child: observation.comments.isEmpty
            ? pw.SizedBox(height: 2 * PdfPageFormat.inch - 14)
            : pw.Text(
                _safeText(observation.comments),
                softWrap: true,
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
              ),
      ),
    ],
  );

  pw.Widget _observationFlow(ObservationBlockSpec observation) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _borderedText(observation.title, bold: true),
      pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(
          _safeText(observation.comments),
          softWrap: true,
          style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
        ),
      ),
    ],
  );

  String _safeText(String value) => String.fromCharCodes(
    value.runes.expand((rune) {
      if (rune <= 0xff) return [rune];
      return switch (rune) {
        0x2018 || 0x2019 => [0x27],
        0x201c || 0x201d => [0x22],
        0x2013 || 0x2014 => [0x2d],
        0x2022 => [0x2a],
        _ => [0x3f],
      };
    }),
  );
}

Future<Uint8List> composeReportPdf(ReportLayout layout) =>
    PdfComposer().compose(layout);
