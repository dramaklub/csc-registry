import 'package:supabase_flutter/supabase_flutter.dart';

const clinicUrl = 'https://dpbfgyhsshoosaolniqb.supabase.co';
const clinicPublishableKey = 'sb_publishable_9B1wMNICNOEHVQ98FUtDEQ_ZbT7bm39';

SupabaseClient get db => Supabase.instance.client;
