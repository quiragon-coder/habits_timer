import 'package:flutter/material.dart';
import '../models/activity.dart';

class ActivityEditPage extends StatefulWidget {
  final Activity? activity;
  const ActivityEditPage({super.key, this.activity});
  @override State<ActivityEditPage> createState() => _ActivityEditPageState();
}
class _ActivityEditPageState extends State<ActivityEditPage> {
  late TextEditingController name; late String emoji; late Color color; double goalHours=0; double goalHoursDay=0; int goalDays=0;
  @override void initState(){ super.initState(); final a=widget.activity; name=TextEditingController(text:a?.name??''); emoji=a?.emoji??'⏱️'; color=Color(a?.colorValue??0xFF6750A4); goalHours=a?.goalHoursPerWeek??0; goalHoursDay=a?.goalHoursPerDay??0; goalDays=a?.goalDaysPerWeek??0; }
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text(widget.activity==null?'Nouvelle activité':'Modifier activité')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === Infos de base ===
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Infos', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom de l’activité', hintText: 'ex: Dessin, Sport, Lecture')),
            const SizedBox(height: 12),
            const Text('Emoji'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in ['⏱️','📚','💪','🧘','🎸','✍️','💻','🧠','🚴','🏃','🎮','🎨','🍳','📖','📝','🛠️','🎧'])
                ChoiceChip(label: Text(e, style: const TextStyle(fontSize: 18)), selected: emoji==e, onSelected: (_){ setState(()=>emoji=e); }),
              ActionChip(label: const Text('Autre…'), onPressed: () async {
                final ctrl = TextEditingController(text: emoji); final val = await showDialog<String>(context: context, builder: (ctx)=>AlertDialog(
                  title: const Text('Emoji personnalisé'), content: TextField(controller: ctrl), actions: [
                    TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Annuler')),
                    ElevatedButton(onPressed: ()=>Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
                  ],
                )); if (val!=null && val.isNotEmpty) setState(()=>emoji=val);
              }),
            ]),
            const SizedBox(height: 12),
            const Text('Couleur'), const SizedBox(height: 8),
            Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8), Text('#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}'),
            ]),
            Slider(value: HSLColor.fromColor(color).hue/360, onChanged: (v){ setState(()=> color = HSLColor.fromColor(color).withHue(v*360).toColor()); }),
            Slider(value: HSLColor.fromColor(color).saturation, onChanged: (v){ setState(()=> color = HSLColor.fromColor(color).withSaturation(v).toColor()); }),
            Slider(value: HSLColor.fromColor(color).lightness, onChanged: (v){ setState(()=> color = HSLColor.fromColor(color).withLightness(v).toColor()); }),
          ]))),

          const SizedBox(height: 12),

          // === Objectifs ===
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Objectifs', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tu peux laisser à 0 si tu ne veux pas d’objectif.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            // Heures / jour
            Row(children: [
              const Text('Heures / jour'),
              Expanded(child: Slider(value: goalHoursDay, onChanged: (v)=>setState(()=>goalHoursDay=v), min:0, max:10, divisions:600, label: _fmtHour(goalHoursDay))),
              SizedBox(width: 64, child: Text(_fmtHour(goalHoursDay), textAlign: TextAlign.end)),
            ]),
            Row(children: [
              const SizedBox(width: 8),
              OutlinedButton(onPressed: ()=>setState(()=>goalHoursDay=_inc(goalHoursDay,-5)), child: const Text('-5m')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: ()=>setState(()=>goalHoursDay=_inc(goalHoursDay,5)), child: const Text('+5m')),
            ]),
            const SizedBox(height: 12),
            // Heures / semaine
            Row(children: [
              const Text('Heures / semaine'),
              Expanded(child: Slider(value: goalHours, onChanged: (v)=>setState(()=>goalHours=v), min:0, max:40, divisions:2400, label: _fmtHour(goalHours))),
              SizedBox(width: 64, child: Text(_fmtHour(goalHours), textAlign: TextAlign.end)),
            ]),
            Row(children: [
              const SizedBox(width: 8),
              OutlinedButton(onPressed: ()=>setState(()=>goalHours=_inc(goalHours,-5)), child: const Text('-5m')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: ()=>setState(()=>goalHours=_inc(goalHours,5)), child: const Text('+5m')),
            ]),
            const SizedBox(height: 12),
            // Jours / semaine
            Row(children: [
              const Text('Jours / semaine'),
              Expanded(child: Slider(value: goalDays.toDouble(), onChanged: (v)=>setState(()=>goalDays=v.round()), min:0, max:7, divisions:7, label:'$goalDays')),
              const SizedBox(width: 64, child: Text('j/sem', textAlign: TextAlign.end)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ActionChip(label: const Text('45 min / jour'), onPressed: () => setState(()=>goalHoursDay = 0.75)),
              ActionChip(label: const Text('1h30 / jour'), onPressed: () => setState(()=>goalHoursDay = 1.5)),
              ActionChip(label: const Text('5 h / semaine'), onPressed: () => setState(()=>goalHours = 5)),
              ActionChip(label: const Text('3 jours / semaine'), onPressed: () => setState(()=>goalDays = 3)),
            ]),
          ]))),

          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Enregistrer')),
        ],
      ),
    );}
  String _fmtHour(double h){
    final totalMin=(h*60).round(); final H=totalMin~/60; final M=totalMin%60; if(H==0) return '${M}m'; if(M==0) return '${H}h'; return '${H}h ${M}m';
  }
  double _inc(double val, double minutes){ final v=((val*60).round()+minutes).clamp(0, 600); return v/60.0; }
  void _save(){
    final a = Activity(id: widget.activity?.id, name: name.text.trim().isEmpty?'Sans titre':name.text.trim(), emoji: emoji, colorValue: color.toARGB32(), goalHoursPerWeek: goalHours, goalHoursPerDay: goalHoursDay, goalDaysPerWeek: goalDays, createdAt: widget.activity?.createdAt);
    Navigator.pop(context, a);
  }
}
