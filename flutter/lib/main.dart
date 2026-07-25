import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beatrice/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://epoaocjrxkcnonrpwlkm.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwb2FvY2pyeGtjbm9ucnB3bGttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4NjYwODYsImV4cCI6MjEwMDQ0MjA4Nn0.BbY4kvKA250wGemDx-ETqTdYw1PmdOXgdmm0joBT848',
  );
  runApp(const BeatriceApp());
}
