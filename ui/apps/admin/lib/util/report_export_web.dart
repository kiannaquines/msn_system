import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadCsv(String filename, String contents) {
  final url = Uri.dataFromString(contents, mimeType: 'text/csv', encoding: utf8).toString();
  html.AnchorElement(href: url)..setAttribute('download', filename)..click();
}

void printReport() => html.window.print();
