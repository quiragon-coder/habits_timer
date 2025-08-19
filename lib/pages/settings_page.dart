import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class SettingsPage extends ConsumerStatefulWidget { const SettingsPage({super.key}); @override ConsumerState<SettingsPage> createState()=>_SettingsPageState(); }
class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? dbPath; String exportText=''; final importCtrl=TextEditingController();
  @override void initState(){ super.initState(); _loadDbPath(); }
  Future<void> _loadDbPath() async { final p = await ref.read(dbProvider).databasePath(); setState(()=>dbPath=p); }
  @override Widget build(BuildContext context){
    final db = ref.watch(dbProvider);
    return Scaffold(appBar: AppBar(title: const Text('Réglages')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(title: const Text('Chemin de la base'), subtitle: Text(dbPath ?? '...')),
        const Divider(),
        ListTile(title: const Text('Exporter JSON'), subtitle: Text(exportText.isEmpty?'Appuie pour exporter':'${exportText.length} caractères'),
          trailing: ElevatedButton.icon(onPressed: () async { final data = await db.exportJson(); setState(()=>exportText = const JsonEncoder.withIndent('  ').convert(data)); }, icon: const Icon(Icons.download), label: const Text('Exporter'))),
        if (exportText.isNotEmpty) Container(margin: const EdgeInsets.only(top:8), padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline)),
          child: SelectableText(exportText, style: const TextStyle(fontFamily:'monospace', fontSize:12))),
        const SizedBox(height: 12), const Text('Importer JSON'), const SizedBox(height:4),
        TextField(controller: importCtrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Colle ici le JSON à importer')),
        const SizedBox(height: 8),
        Row(children: [
          ElevatedButton.icon(onPressed: () async { final map=jsonDecode(importCtrl.text) as Map<String,Object?>; await db.importJson(map, reset:false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import terminé'))); setState((){}); }, icon: const Icon(Icons.upload), label: const Text('Importer')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: () async { final map=jsonDecode(importCtrl.text) as Map<String,Object?>; await db.importJson(map, reset:true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import (reset) terminé'))); setState((){}); }, icon: const Icon(Icons.restore_page), label: const Text('Importer (reset)')),
        ]),
        const Divider(height: 32),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async { await db.resetDatabase(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base réinitialisée'))); setState((){}); },
          icon: const Icon(Icons.delete_forever), label: const Text('Réinitialiser la base')),
      ]),
    );
  }
}
