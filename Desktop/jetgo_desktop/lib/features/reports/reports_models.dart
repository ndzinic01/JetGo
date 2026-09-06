class SavedReportFile {
  SavedReportFile({
    required this.fileName,
    required this.filePath,
    required this.contentType,
    required this.savedAtLocal,
  });

  final String fileName;
  final String filePath;
  final String contentType;
  final DateTime savedAtLocal;
}

enum BusinessReportType {
  sales(
    'sales',
    'Izvjestaj o prodaji',
    'Prodane karte, rute, korisnici i naplaceni iznosi po valutama.',
    'jetgo-sales-report.pdf',
  ),
  occupancy(
    'occupancy',
    'Popunjenost letova',
    'Ukupna, zauzeta i slobodna sjedista po letu u odabranom periodu.',
    'jetgo-occupancy-report.pdf',
  ),
  financial(
    'financial',
    'Finansijski izvjestaj',
    'Naplaceno, refundirano i neto po valutama iz PayPal transakcija.',
    'jetgo-financial-report.pdf',
  ),
  users(
    'users',
    'Izvjestaj o korisnicima',
    'Korisnici, uloge, status naloga, rezervacije, placanja i pretrage.',
    'jetgo-users-report.pdf',
  );

  const BusinessReportType(
    this.path,
    this.title,
    this.description,
    this.fallbackFileName,
  );

  final String path;
  final String title;
  final String description;
  final String fallbackFileName;
}

enum ReportFileFormat {
  pdf('PDF');

  const ReportFileFormat(this.label);

  final String label;
}
