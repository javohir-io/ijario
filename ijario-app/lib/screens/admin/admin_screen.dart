import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/routes.dart';

/// A plain read-out of platform numbers for admins. (Moderation itself
/// happens on a listing: admins get a "delete" action in its menu.)
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<Map<String, dynamic>> _stats = ApiClient.instance.adminStats();

  void _reload() => setState(() => _stats = ApiClient.instance.adminStats());

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final margin = pageMargin(MediaQuery.of(context).size.width, maxContent: 560);
    return BackdropScaffold(
      title: 'Boshqaruv paneli',
      body: FutureBuilder<Map<String, dynamic>>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: p.brand));
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : "Ma'lumotni yuklab bo'lmadi";
            return EmptyState(
              title: 'Yuklanmadi',
              message: message,
              actionLabel: 'Qayta urinish',
              onAction: _reload,
            );
          }
          final s = snapshot.data ?? const <String, dynamic>{};
          int n(String key) => (s[key] as num?)?.toInt() ?? 0;
          final rows = <MapEntry<String, String>>[
            MapEntry('Foydalanuvchilar', formatNumber(n('total_users'))),
            MapEntry("E'lonlar (faol / jami)", '${formatNumber(n('active_properties'))} / ${formatNumber(n('total_properties'))}'),
            MapEntry('Xabarlar', formatNumber(n('total_messages'))),
            MapEntry('Saralashlar', formatNumber(n('total_saved'))),
            MapEntry("Ko'rish so'rovlari", formatNumber(n('total_viewings'))),
            MapEntry('Shikoyatlar', formatNumber(n('total_reports'))),
          ];
          return RefreshIndicator(
            color: p.brand,
            onRefresh: () async => _reload(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, 8, margin, 40),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BDeco.card(p),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: p.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            children: [
                              Expanded(child: Text(rows[i].key, style: BType.body(p.inkMuted))),
                              Text(rows[i].value, style: BType.title(p.ink).copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
