import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:restaurant_local_server/restaurant_local_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _defaultPort = 9090;
const _defaultWebSocketPort = 9091;
const _defaultDiscoveryPort = 9092;

Future<void> main(List<String> args) async {
  final port = _intArg(args, '--port') ?? _defaultPort;
  final dataDir = _stringArg(args, '--data-dir') ?? _defaultDataDir();
  final store = SmartShopJsonStore(Directory(dataDir));

  final manager = LocalServerManager(
    config: LocalServerConfig(
      serverName: 'Smart Shop Laptop Server',
      serverVersion: '1.0.0',
      capabilities: const {
        'smart_shop': true,
        'json_database': true,
        'lan_access': true,
      },
      httpConfig: HttpServerConfig(
        httpPort: port,
        webSocketPort: _defaultWebSocketPort,
        discoveryPort: _defaultDiscoveryPort,
        bindAddress: '0.0.0.0',
        enableCors: true,
        enableLogging: true,
      ),
    ),
  );

  manager.addRouteHandler(SmartShopRouteHandler(store));
  await manager.start();

  final ip = await _localIpAddress() ?? 'localhost';
  stdout.writeln('');
  stdout.writeln('Smart Shop server is running');
  stdout.writeln('Local:   http://localhost:$port');
  stdout.writeln('Network: http://$ip:$port');
  stdout.writeln('Data:    ${store.file.path}');
  stdout.writeln('');
  stdout.writeln('Press Ctrl+C to stop.');

  ProcessSignal.sigint.watch().listen((_) async {
    await manager.stop();
    exit(0);
  });
}

class SmartShopRouteHandler implements RouteHandler {
  SmartShopRouteHandler(this.store);

  final SmartShopJsonStore store;

  @override
  void registerRoutes(Router router) {
    router.options('/<ignored|.*>', _options);
    router.get('/', _home);
    router.post('/api/smart-shop/auth/login', _login);
    router.get('/api/smart-shop/database', _getDatabase);
    router.put('/api/smart-shop/database', _putDatabase);
    router.post('/api/smart-shop/database/merge', _mergeDatabase);
    router.get('/api/smart-shop/tables/<table>', _getTable);
    router.put('/api/smart-shop/tables/<table>', _putTable);
  }

  Response _options(Request request) {
    return Response.ok('', headers: _corsHeaders);
  }

  Response _home(Request request) {
    return Response.ok(
      '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Smart Shop Server</title>
    <style>
      body { font-family: system-ui, sans-serif; max-width: 760px; margin: 48px auto; padding: 0 18px; line-height: 1.5; }
      code, a { font-size: 15px; }
      li { margin: 8px 0; }
    </style>
  </head>
  <body>
    <h1>Smart Shop Server</h1>
    <p>Status: running</p>
    <p>This is the laptop database server. Open the Flutter web app separately for the shop UI.</p>
    <h2>API</h2>
    <ul>
      <li><a href="/health">/health</a></li>
      <li><a href="/api/system/info">/api/system/info</a></li>
      <li><a href="/api/smart-shop/database">/api/smart-shop/database</a></li>
      <li><code>GET /api/smart-shop/tables/{table}</code></li>
      <li><code>PUT /api/smart-shop/database</code></li>
      <li><code>PUT /api/smart-shop/tables/{table}</code></li>
    </ul>
  </body>
</html>
''',
      headers: {'Content-Type': 'text/html; charset=utf-8', ..._corsHeaders},
    );
  }

  Future<Response> _getDatabase(Request request) async {
    return _json({'success': true, 'data': await store.read()});
  }

  Future<Response> _login(Request request) async {
    final body = await request.readAsString();
    final data = _decodeMap(body);
    final email = (data['email'] as String? ?? '').trim().toLowerCase();
    final password = data['password'] as String? ?? '';
    if (email.isEmpty || password.isEmpty) {
      return Response.forbidden(
        jsonEncode({'success': false, 'error': 'Email and password required'}),
        headers: {'Content-Type': 'application/json', ..._corsHeaders},
      );
    }
    final database = await store.read();
    final users = database['users'];
    if (users is List) {
      for (final item in users) {
        if (item is! Map) continue;
        final user = Map<String, dynamic>.from(item);
        final userEmail = (user['email'] as String? ?? '').trim().toLowerCase();
        final userPassword = user['pin'] as String? ?? '';
        if (userEmail == email && userPassword == password) {
          return _json({
            'success': true,
            'data': {'user': user, 'database': database},
          });
        }
      }
    }
    return Response.forbidden(
      jsonEncode({'success': false, 'error': 'Invalid login'}),
      headers: {'Content-Type': 'application/json', ..._corsHeaders},
    );
  }

  Future<Response> _putDatabase(Request request) async {
    final body = await request.readAsString();
    final data = _decodeMap(body);
    await store.write(data);
    return _json({'success': true, 'data': await store.read()});
  }

  Future<Response> _mergeDatabase(Request request) async {
    final body = await request.readAsString();
    final data = _decodeMap(body);
    final current = await store.read();
    current.addAll(data);
    await store.write(current);
    return _json({'success': true, 'data': current});
  }

  Future<Response> _getTable(Request request) async {
    final table = request.params['table']!;
    final database = await store.read();
    return _json({'success': true, 'data': database[table] ?? []});
  }

  Future<Response> _putTable(Request request) async {
    final table = request.params['table']!;
    final body = await request.readAsString();
    final decoded = jsonDecode(body);
    final database = await store.read();
    database[table] = decoded;
    await store.write(database);
    return _json({'success': true, 'data': decoded});
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  }

  Response _json(Map<String, dynamic> data) {
    return Response.ok(
      jsonEncode(data),
      headers: {'Content-Type': 'application/json', ..._corsHeaders},
    );
  }

  Map<String, String> get _corsHeaders => const {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization',
  };
}

class SmartShopJsonStore {
  SmartShopJsonStore(this.directory);

  final Directory directory;

  File get file => File('${directory.path}/smart_shop_database.json');

  Future<Map<String, dynamic>> read() async {
    await _ensureExists();
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Database file must contain a JSON object');
    }
    final database = decoded;
    if (_needsSeed(database)) {
      final seeded = _seedDatabase(database);
      await write(seeded);
      return seeded;
    }
    return database;
  }

  Future<void> write(Map<String, dynamic> data) async {
    await directory.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(data)}\n');
  }

  Future<void> _ensureExists() async {
    if (await file.exists()) return;
    await write(
      _seedDatabase({
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'shops': [],
        'users': [],
        'products': [],
        'bills': [],
        'customers': [],
        'suppliers': [],
        'stockMovements': [],
        'settings': {},
      }),
    );
  }

  bool _needsSeed(Map<String, dynamic> database) {
    final users = database['users'];
    return users is! List || users.isEmpty;
  }

  Map<String, dynamic> _seedDatabase(Map<String, dynamic> database) {
    final now = DateTime.now().toIso8601String();
    return {
      ...database,
      'version': database['version'] ?? 1,
      'createdAt': database['createdAt'] ?? now,
      'shops': [
        {
          'id': 'shop_grocery',
          'name': 'Green Mart',
          'type': 'Grocery',
          'currency': 'PKR',
          'ownerAdminId': 'admin',
          'address': 'Main Market',
          'phone': '+92 300 0000000',
          'themeSeed': 0xff0f766e,
          'createdAt': now,
        },
      ],
      'users': [
        {
          'id': 'admin',
          'name': 'Admin',
          'email': 'admin@smartshop.local',
          'pin': 'Admin@123',
          'role': 'admin',
          'shopId': null,
          'biometricEnabled': false,
          'monthlySalary': 0,
          'commissionPercent': 0,
          'phone': '',
          'idCardNumber': '',
          'address': '',
          'photoPath': '',
          'startDate': null,
          'leaves': [],
        },
        {
          'id': 'editor',
          'name': 'Editor',
          'email': 'editor@smartshop.local',
          'pin': 'Editor@123',
          'role': 'editor',
          'shopId': 'shop_grocery',
          'managerId': null,
          'biometricEnabled': false,
          'monthlySalary': 0,
          'commissionPercent': 0,
          'phone': '',
          'idCardNumber': '',
          'address': '',
          'photoPath': '',
          'startDate': null,
          'leaves': [],
        },
        {
          'id': 'seller',
          'name': 'Seller',
          'email': 'seller@smartshop.local',
          'pin': 'Seller@123',
          'role': 'seller',
          'shopId': 'shop_grocery',
          'managerId': null,
          'biometricEnabled': false,
          'monthlySalary': 0,
          'commissionPercent': 0,
          'phone': '',
          'idCardNumber': '',
          'address': '',
          'photoPath': '',
          'startDate': null,
          'leaves': [],
        },
      ],
      'products': database['products'] ?? [],
      'bills': database['bills'] ?? [],
      'customers': database['customers'] ?? [],
      'suppliers': database['suppliers'] ?? [],
      'stockMovements': database['stockMovements'] ?? [],
      'settings': database['settings'] ?? {},
    };
  }
}

String _defaultDataDir() {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;
  return '$home/SmartShopServer';
}

int? _intArg(List<String> args, String name) {
  final value = _stringArg(args, name);
  return value == null ? null : int.tryParse(value);
}

String? _stringArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

Future<String?> _localIpAddress() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback) return address.address;
    }
  }
  return null;
}
