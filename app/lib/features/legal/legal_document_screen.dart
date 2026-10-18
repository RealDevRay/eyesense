import 'package:eyesense/features/legal/legal_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LegalDocumentScreen extends StatefulWidget {
  final String title;

  /// Asset path without a language suffix or extension, e.g.
  /// `assets/legal/privacy-policy`.
  final String documentBase;

  /// Language code from preferences. `en` loads the base document; anything
  /// else looks for a `<base>.<language>.md` translation first.
  final String language;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.documentBase,
    required this.language,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  /// Started once. Reading it from `build` would restart the load on every
  /// frame, and the loading spinner's own animation is enough to keep
  /// requesting frames, so the document would never arrive.
  Future<_LegalDocument>? _document;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _document ??= _load(DefaultAssetBundle.of(context));
  }

  Future<_LegalDocument> _load(AssetBundle bundle) async {
    // Asked of the manifest rather than discovered by catching a failed load:
    // a missing asset does not reliably reject, which would leave a reader
    // watching a spinner instead of the document they are entitled to read.
    if (widget.language != 'en') {
      final path = '${widget.documentBase}.${widget.language}.md';
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      if (manifest.listAssets().contains(path)) {
        return _LegalDocument(await bundle.loadString(path), translated: true);
      }
    }
    return _LegalDocument(await bundle.loadString('${widget.documentBase}.md'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<_LegalDocument>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('This document could not be opened in the app.'),
            );
          }

          final document = snapshot.data!;
          final untranslated = widget.language != 'en' && !document.translated;

          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              children: [
                if (untranslated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'This document is only available in English. Contact '
                      'info@devray.qzz.io for another language or format.',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                LegalMarkdown(source: document.source),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegalDocument {
  final String source;
  final bool translated;

  const _LegalDocument(this.source, {this.translated = false});
}
