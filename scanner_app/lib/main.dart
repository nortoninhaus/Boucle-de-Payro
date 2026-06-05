import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sound_helper.dart';

void main() {
  runApp(const BoucleScannerApp());
}

class BoucleScannerApp extends StatelessWidget {
  const BoucleScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bouclé de Payró | Staff Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA68B59), // Warm Gold
          secondary: Color(0xFF48645C), // Slate Teal
          surface: Color(0xFF2B2B2B), // Charcoal Surface
          error: Color(0xFFBA1A1A),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AuthScreen(),
    );
  }
}

// Global API url resolver
String getApiBaseUrl() {
  if (kIsWeb) {
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return 'http://127.0.0.1:5001/inhaus-brain-full-prod/us-central1/api';
    }
  }
  return 'https://us-central1-inhaus-brain-full-prod.cloudfunctions.net/api';
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final List<String> _pin = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedPin();
  }

  Future<void> _checkSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('staff_passcode');
    if (savedPin != null) {
      _loginWithPin(savedPin);
    }
  }

  Future<void> _loginWithPin(String pinCode) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${getApiBaseUrl()}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'passcode': pinCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('staff_passcode', pinCode);

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => DashboardScreen(passcode: pinCode)),
            );
          }
          return;
        }
      }
      
      setState(() {
        _errorMessage = 'PIN inválido. Intente de nuevo.';
        _pin.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión con el servidor.';
        _pin.clear();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onKeyPress(String value) {
    if (_isLoading) return;
    if (_pin.length < 10) {
      setState(() {
        _pin.add(value);
        _errorMessage = null;
      });
    }
    
    // Automatically submit after 4 digits if they want, but let them hit check
  }

  void _onBackspace() {
    if (_pin.isNotEmpty && !_isLoading) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  void _onSubmit() {
    if (_pin.isEmpty || _isLoading) return;
    _loginWithPin(_pin.join());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo placeholder
                Text(
                  'B O U C L É',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 8.0,
                    color: const Color(0xFFA68B59),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PAYRÓ • STAFF PORTAL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    letterSpacing: 4.0,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Ingrese PIN de Acceso',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),
                // Password dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? const Color(0xFFA68B59) : Colors.transparent,
                        border: Border.all(color: const Color(0xFFA68B59), width: 1.5),
                      ),
                    );
                  }),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 48),
                if (_isLoading)
                  const CircularProgressIndicator(color: Color(0xFFA68B59))
                else
                  _buildKeyboard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map((n) => _buildKey(n)).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map((n) => _buildKey(n)).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map((n) => _buildKey(n)).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlKey(Icons.backspace_outlined, _onBackspace),
              _buildKey('0'),
              _buildControlKey(Icons.check_circle_outline, _onSubmit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10, width: 1),
          color: Colors.white.withOpacity(0.02),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildControlKey(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.01),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 28,
          color: const Color(0xFFA68B59),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String passcode;
  const DashboardScreen({super.key, required this.passcode});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalGuests = 0;
  int _checkedIn = 0;
  bool _isLoading = false;
  List<dynamic> _guests = [];
  List<dynamic> _filteredGuests = [];
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all'; // 'all', 'checked_in', 'issued'

  @override
  void initState() {
    super.initState();
    _fetchGuestData();
    _searchController.addListener(_onSearchOrFilterChanged);
  }

  Future<void> _fetchGuestData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('${getApiBaseUrl()}/guests'),
        headers: {
          'Authorization': 'Bearer ${widget.passcode}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['guests'] ?? [];
        if (mounted) {
          setState(() {
            _guests = list;
            _totalGuests = list.length;
            _checkedIn = list.where((g) => g['status'] == 'checked_in').length;
          });
          _onSearchOrFilterChanged();
        }
      }
    } catch (e) {
      debugPrint('Error fetching guest data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchOrFilterChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGuests = _guests.where((guest) {
        // Status filter
        if (_statusFilter == 'checked_in' && guest['status'] != 'checked_in') return false;
        if (_statusFilter == 'issued' && guest['status'] == 'checked_in') return false;

        // Search query
        final name = (guest['guestName'] ?? '').toString().toLowerCase();
        final email = (guest['guestEmail'] ?? '').toString().toLowerCase();
        final company = (guest['company'] ?? '').toString().toLowerCase();
        final code = (guest['id'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query) || company.contains(query) || code.contains(query);
      }).toList();
    });
  }

  Future<void> _addGuestManually(String name, String email, String phone, String company) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFA68B59))),
    );

    try {
      final response = await http.post(
        Uri.parse('${getApiBaseUrl()}/guests'),
        headers: {
          'Authorization': 'Bearer ${widget.passcode}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'guestName': name,
          'guestEmail': email,
          'guestPhone': phone,
          'company': company,
        }),
      );

      Navigator.of(context).pop(); // Close loader

      if (response.statusCode == 200) {
        _showToast('Invitado creado con éxito');
        _fetchGuestData();
      } else {
        _showToast('Error al crear invitado');
      }
    } catch (_) {
      Navigator.of(context).pop();
      _showToast('Error de conexión');
    }
  }

  Future<void> _editGuest(String ticketId, String name, String email, String phone, String company, String status) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFA68B59))),
    );

    try {
      final response = await http.put(
        Uri.parse('${getApiBaseUrl()}/guests/$ticketId'),
        headers: {
          'Authorization': 'Bearer ${widget.passcode}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'guestName': name,
          'guestEmail': email,
          'guestPhone': phone,
          'company': company,
          'status': status,
        }),
      );

      Navigator.of(context).pop(); // Close loader

      if (response.statusCode == 200) {
        _showToast('Invitado actualizado');
        _fetchGuestData();
      } else {
        _showToast('Error al actualizar');
      }
    } catch (_) {
      Navigator.of(context).pop();
      _showToast('Error de conexión');
    }
  }

  Future<void> _deleteGuest(String ticketId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFA68B59))),
    );

    try {
      final response = await http.delete(
        Uri.parse('${getApiBaseUrl()}/guests/$ticketId'),
        headers: {
          'Authorization': 'Bearer ${widget.passcode}',
        },
      );

      Navigator.of(context).pop(); // Close loader

      if (response.statusCode == 200) {
        _showToast('Invitado eliminado');
        _fetchGuestData();
      } else {
        _showToast('Error al eliminar');
      }
    } catch (_) {
      Navigator.of(context).pop();
      _showToast('Error de conexión');
    }
  }

  Future<void> _toggleGuestCheckIn(Map<String, dynamic> guest) async {
    final ticketId = guest['id'];
    final isCheckedIn = guest['status'] == 'checked_in';
    final newStatus = isCheckedIn ? 'issued' : 'checked_in';

    _editGuest(
      ticketId,
      guest['guestName'] ?? '',
      guest['guestEmail'] ?? '',
      guest['guestPhone'] ?? '',
      guest['company'] ?? '',
      newStatus,
    );
  }

  void _exportGuestsToCsv() {
    if (_guests.isEmpty) {
      _showToast('No hay datos para exportar');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('ID,Nombre,Email,Telefono,Empresa,Estado,Fecha de Registro,Fecha de Ingreso');
    for (var g in _guests) {
      final id = g['id'] ?? '';
      final name = g['guestName'] ?? '';
      final email = g['guestEmail'] ?? '';
      final phone = g['guestPhone'] ?? '';
      final company = g['company'] ?? '';
      final status = g['status'] ?? '';
      final issued = g['issuedAt'] ?? '';
      final checked = g['checkedInAt'] ?? '';
      buffer.writeln('"$id","$name","$email","$phone","$company","$status","$issued","$checked"');
    }

    downloadCsvFile(buffer.toString(), 'invitados_boucle_${DateTime.now().millisecondsSinceEpoch}.csv');
    _showToast('CSV Exportado');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: const Color(0xFF1E1E1E), fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFA68B59),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('staff_passcode');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  Map<int, int> _getCheckInsByHour() {
    final Map<int, int> hourlyData = {};
    for (int h = 17; h <= 23; h++) {
      hourlyData[h] = 0;
    }
    for (var guest in _guests) {
      if (guest['status'] == 'checked_in' && guest['checkedInAt'] != null) {
        try {
          final dt = DateTime.parse(guest['checkedInAt']).toLocal();
          final hour = dt.hour;
          if (hour >= 17 && hour <= 23) {
            hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
          }
        } catch (_) {}
      }
    }
    return hourlyData;
  }

  void _showAddGuestDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final compCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        title: Text('Añadir Invitado', style: GoogleFonts.playfairDisplay(color: const Color(0xFFA68B59))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField('Nombre Completo *', nameCtrl),
              _buildDialogField('Correo Electrónico', emailCtrl, inputType: TextInputType.emailAddress),
              _buildDialogField('Teléfono', phoneCtrl, inputType: TextInputType.phone),
              _buildDialogField('Empresa', compCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('CANCELAR', style: GoogleFonts.inter(color: Colors.white38)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA68B59), foregroundColor: const Color(0xFF1E1E1E)),
            child: Text('CREAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) {
                _showToast('Nombre es requerido');
                return;
              }
              Navigator.of(ctx).pop();
              _addGuestManually(nameCtrl.text, emailCtrl.text, phoneCtrl.text, compCtrl.text);
            },
          )
        ],
      ),
    );
  }

  void _showEditGuestDialog(Map<String, dynamic> guest) {
    final nameCtrl = TextEditingController(text: guest['guestName']);
    final emailCtrl = TextEditingController(text: guest['guestEmail']);
    final phoneCtrl = TextEditingController(text: guest['guestPhone']);
    final compCtrl = TextEditingController(text: guest['company']);
    String status = guest['status'] ?? 'issued';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2B2B2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
          title: Text('Editar Invitado', style: GoogleFonts.playfairDisplay(color: const Color(0xFFA68B59))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Nombre Completo *', nameCtrl),
                _buildDialogField('Correo Electrónico', emailCtrl, inputType: TextInputType.emailAddress),
                _buildDialogField('Teléfono', phoneCtrl, inputType: TextInputType.phone),
                _buildDialogField('Empresa', compCtrl),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Estado de check-in:', style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
                    DropdownButton<String>(
                      dropdownColor: const Color(0xFF2B2B2B),
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'issued', child: Text('Pendiente')),
                        DropdownMenuItem(value: 'checked_in', child: Text('Ingresado')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            status = val;
                          });
                        }
                      },
                    )
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('ELIMINAR', style: GoogleFonts.inter(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _showDeleteConfirmDialog(guest['id']);
              },
            ),
            const Spacer(),
            TextButton(
              child: Text('CANCELAR', style: GoogleFonts.inter(color: Colors.white38)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA68B59), foregroundColor: const Color(0xFF1E1E1E)),
              child: Text('GUARDAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  _showToast('Nombre es requerido');
                  return;
                }
                Navigator.of(ctx).pop();
                _editGuest(guest['id'], nameCtrl.text, emailCtrl.text, phoneCtrl.text, compCtrl.text, status);
              },
            )
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(String ticketId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B2B),
        title: Text('Eliminar Invitado', style: GoogleFonts.playfairDisplay(color: Colors.redAccent)),
        content: Text('¿Está seguro de que desea eliminar este ticket? Esta acción no se puede deshacer.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            child: Text('CANCELAR', style: GoogleFonts.inter(color: Colors.white38)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text('ELIMINAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteGuest(ticketId);
            },
          )
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white38),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFA68B59))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _totalGuests - _checkedIn;
    final percent = _totalGuests > 0 ? (_checkedIn / _totalGuests * 100).toStringAsFixed(0) : '0';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2B2B),
        elevation: 0,
        title: Text(
          'B O U C L É',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w400,
            fontSize: 20,
            letterSpacing: 3.0,
            color: const Color(0xFFA68B59),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchGuestData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 950) {
            // Desktop/Tablet Responsive View
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Dashboard Metrics & Charts
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Panel de Control', style: GoogleFonts.playfairDisplay(fontSize: 28, color: Colors.white)),
                        const SizedBox(height: 16),
                        _buildStatCard('Total Invitados', _totalGuests.toString(), Colors.white),
                        const SizedBox(height: 12),
                        _buildStatCard('Ingresados', _checkedIn.toString(), const Color(0xFFA68B59)),
                        const SizedBox(height: 12),
                        _buildStatCard('Restantes', remaining.toString(), Colors.white38),
                        const SizedBox(height: 24),
                        // Donut Visualizer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2B2B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              Text('Proporción de Ingresos', style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 110,
                                width: 110,
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: const Size(110, 110),
                                      painter: DonutChartPainter(total: _totalGuests, checkedIn: _checkedIn),
                                    ),
                                    Center(
                                      child: Text(
                                        '$percent%',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFA68B59)),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text('Ingresados vs Pendientes', style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Timeline Line Chart
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2B2B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Llegadas por Hora', style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 90,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: TimelineLineChartPainter(_getCheckInsByHour()),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('17h', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white24)),
                                  Text('20h', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white24)),
                                  Text('23h', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white24)),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA68B59),
                              foregroundColor: const Color(0xFF1E1E1E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text('ESCANEAR TICKET', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ScannerScreen(passcode: widget.passcode)),
                              );
                              if (result == true) _fetchGuestData();
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                // Divider
                Container(width: 1, color: Colors.white10, height: double.infinity),
                // Right Panel: Attendee Management Tool
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Gestión de Invitados', style: GoogleFonts.playfairDisplay(fontSize: 24, color: Colors.white)),
                            Row(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.download, color: Color(0xFFA68B59)),
                                  label: Text('EXPORTAR CSV', style: GoogleFonts.inter(color: const Color(0xFFA68B59))),
                                  onPressed: _exportGuestsToCsv,
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2B2B2B),
                                    side: const BorderSide(color: Color(0xFFA68B59), width: 1),
                                  ),
                                  icon: const Icon(Icons.add, color: Color(0xFFA68B59)),
                                  label: Text('AÑADIR MANUAL', style: GoogleFonts.inter(color: const Color(0xFFA68B59))),
                                  onPressed: _showAddGuestDialog,
                                )
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search & Filter Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: GoogleFonts.inter(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Buscar por nombre, empresa, email...',
                                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                                  filled: true,
                                  fillColor: const Color(0xFF2B2B2B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildFilterChip('Todos', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Ingresados', 'checked_in'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Pendientes', 'issued'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Guests Table Grid
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B2B2B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFFA68B59)))
                                : _filteredGuests.isEmpty
                                    ? Center(child: Text('No hay invitados que coincidan con la búsqueda', style: GoogleFonts.inter(color: Colors.white38)))
                                    : ListView.separated(
                                        itemCount: _filteredGuests.length,
                                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                                        itemBuilder: (ctx, index) {
                                          final g = _filteredGuests[index];
                                          final isChecked = g['status'] == 'checked_in';
                                          return ListTile(
                                            title: Text(g['guestName'] ?? 'Invitado', style: GoogleFonts.playfairDisplay(fontSize: 16, color: Colors.white)),
                                            subtitle: Text(
                                              '${g['company'] ?? 'Invitado Especial'} • ${g['id'] ?? ''}',
                                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Toggle CheckIn button
                                                IconButton(
                                                  icon: Icon(
                                                    isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                                                    color: isChecked ? const Color(0xFF48645C) : Colors.white24,
                                                  ),
                                                  onPressed: () => _toggleGuestCheckIn(g),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFA68B59)),
                                                  onPressed: () => _showEditGuestDialog(g),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            );
          } else {
            // Mobile Layout
            return RefreshIndicator(
              onRefresh: _fetchGuestData,
              color: const Color(0xFFA68B59),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Panel de Evento', style: GoogleFonts.playfairDisplay(fontSize: 26, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Invitados', _totalGuests.toString(), Colors.white)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('Ingresados', _checkedIn.toString(), const Color(0xFFA68B59))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('Restantes', remaining.toString(), Colors.white38)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _totalGuests > 0 ? _checkedIn / _totalGuests : 0.0,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA68B59)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Main Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA68B59),
                              foregroundColor: const Color(0xFF1E1E1E),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text('ESCANEAR QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ScannerScreen(passcode: widget.passcode)),
                              );
                              if (result == true) _fetchGuestData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.people_outline),
                            label: Text('INVITADOS', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GuestListScreen(passcode: widget.passcode, guests: _guests),
                                ),
                              );
                              if (result == true) _fetchGuestData();
                            },
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Quick add / export in mobile
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Acciones rápidas', style: GoogleFonts.inter(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download, color: Color(0xFFA68B59)),
                              onPressed: _exportGuestsToCsv,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Color(0xFFA68B59)),
                              onPressed: _showAddGuestDialog,
                            ),
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String val, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 8),
          Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.bold, color: valColor)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    final active = _statusFilter == filter;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, color: active ? const Color(0xFF1E1E1E) : Colors.white)),
      selected: active,
      selectedColor: const Color(0xFFA68B59),
      backgroundColor: const Color(0xFF2B2B2B),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = filter;
          });
          _onSearchOrFilterChanged();
        }
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final int total;
  final int checkedIn;
  DonutChartPainter({required this.total, required this.checkedIn});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.18;

    final basePaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = const Color(0xFFA68B59)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, basePaint);

    if (total > 0 && checkedIn > 0) {
      final sweepAngle = (checkedIn / total) * 2 * 3.14159265;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -3.14159265 / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TimelineLineChartPainter extends CustomPainter {
  final Map<int, int> hourlyData;
  TimelineLineChartPainter(this.hourlyData);

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlyData.isEmpty) return;

    final paintLine = Paint()
      ..color = const Color(0xFFA68B59)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFA68B59).withOpacity(0.3),
          const Color(0xFFA68B59).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final paintGrid = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    final list = hourlyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = list.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final divisor = maxVal == 0 ? 1 : maxVal;

    final stepX = size.width / (list.length - 1);
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < list.length; i++) {
      final x = i * stepX;
      final y = size.height - (list[i].value / divisor) * (size.height * 0.7) - 10;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      if (i == list.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }

      // Draw grid line
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);

      // Draw dot
      if (list[i].value > 0) {
        final dotPaint = Paint()
          ..color = const Color(0xFFA68B59)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
      }
    }

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ScannerScreen extends StatefulWidget {
  final String passcode;
  const ScannerScreen({super.key, required this.passcode});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          _isProcessing = true;
        });
        
        // Pause scanning
        _controller.stop();
        
        // Perform backend check-in
        await _processCheckIn(code);
      }
    }
  }

  Future<void> _processCheckIn(String ticketId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFA68B59)),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('${getApiBaseUrl()}/checkIn'),
        headers: {
          'Authorization': 'Bearer ${widget.passcode}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ticketId': ticketId}),
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];
        final guest = data['guest'] ?? {};

        if (status == 'SUCCESS') {
          playSuccessSound();
          _showCheckInResultBottomSheet(
            title: 'ACCESO PERMITIDO',
            subtitle: 'Bienvenido a Bouclé',
            color: const Color(0xFF48645C),
            icon: Icons.check_circle_outline,
            guest: guest,
          );
        } else if (status == 'ALREADY_CHECKED_IN') {
          playWarningSound();
          _showCheckInResultBottomSheet(
            title: 'YA REGISTRADO',
            subtitle: 'Ticket escaneado previamente',
            color: const Color(0xFFC69C59),
            icon: Icons.warning_amber_outlined,
            guest: guest,
            additionalInfo: 'Ingreso original: ${formatTimestamp(data['checkedInAt'])}',
          );
        }
      } else if (response.statusCode == 444) {
        // Ticket ID not found
        playErrorSound();
        _showErrorBottomSheet('TICKET INVÁLIDO', 'El código escaneado no existe.');
      } else {
        playErrorSound();
        _showErrorBottomSheet('ERROR DE ACCESO', 'Ocurrió un error en el servidor.');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading
      playErrorSound();
      _showErrorBottomSheet('ERROR DE CONEXIÓN', 'Compruebe su señal de internet.');
    }
  }

  String formatTimestamp(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showCheckInResultBottomSheet({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required Map<String, dynamic> guest,
    String? additionalInfo,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF2B2B2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
              child: Icon(icon, size: 64, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              guest['guestName'] ?? 'Guest',
              style: GoogleFonts.playfairDisplay(fontSize: 20, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (guest['company'] != null && guest['company'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                guest['company'].toString(),
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFA68B59)),
              ),
            ],
            if (additionalInfo != null) ...[
              const SizedBox(height: 12),
              Text(
                additionalInfo,
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA68B59),
                  foregroundColor: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('CONTINUAR ESCANEO', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isProcessing = false;
                  });
                  _controller.start();
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showErrorBottomSheet(String title, String details) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF2B2B2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withOpacity(0.15)),
              child: const Icon(Icons.cancel_outlined, size: 64, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              details,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('INTENTAR DE NUEVO', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isProcessing = false;
                  });
                  _controller.start();
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Escanear QR',
          style: GoogleFonts.playfairDisplay(letterSpacing: 1),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Custom Overlay Target
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFA68B59), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  // Corner markers or simple gold styling
                  Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12, width: 1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  )
                ],
              ),
            ),
          ),
          // Helper instructions at bottom
          Positioned(
            bottom: 64,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Coloque el código QR dentro del recuadro',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class GuestListScreen extends StatefulWidget {
  final String passcode;
  final List<dynamic> guests;
  const GuestListScreen({super.key, required this.passcode, required this.guests});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  late List<dynamic> _allGuests;
  List<dynamic> _filteredGuests = [];
  final TextEditingController _searchController = TextEditingController();
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    _allGuests = List.from(widget.guests);
    _filteredGuests = _allGuests;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGuests = _allGuests.where((guest) {
        final name = (guest['guestName'] ?? '').toString().toLowerCase();
        final email = (guest['guestEmail'] ?? '').toString().toLowerCase();
        final company = (guest['company'] ?? '').toString().toLowerCase();
        final code = (guest['id'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query) || company.contains(query) || code.contains(query);
      }).toList();
    });
  }

  Future<void> _manualCheckIn(String ticketId) async {
    Navigator.of(context).pop(); // Close details dialog
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFA68B59)),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('${getApiBaseUrl()}/checkIn'),
        headers: {
          'Authorization': 'Bearer ${widget.passcode}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ticketId': ticketId}),
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];
        
        if (status == 'SUCCESS') {
          playSuccessSound();
          _showToast('Registro Exitoso');
          // Update local status
          setState(() {
            _needsRefresh = true;
            final idx = _allGuests.indexWhere((g) => g['id'] == ticketId);
            if (idx != -1) {
              _allGuests[idx]['status'] = 'checked_in';
              _allGuests[idx]['checkedInAt'] = data['guest']['checkedInAt'];
            }
            _onSearchChanged(); // Re-filter
          });
        } else if (status == 'ALREADY_CHECKED_IN') {
          playWarningSound();
          _showToast('Ya registrado previamente');
        }
      } else {
        playErrorSound();
        _showToast('Error al procesar check-in');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading
      playErrorSound();
      _showToast('Error de conexión');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: const Color(0xFF1E1E1E), fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFA68B59),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showGuestDetails(Map<String, dynamic> guest) {
    final isCheckedIn = guest['status'] == 'checked_in';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: Text(
          'Detalle de Invitado',
          style: GoogleFonts.playfairDisplay(color: const Color(0xFFA68B59), fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(guest['guestName'] ?? 'Guest', style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white)),
            if (guest['company'] != null && guest['company'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(guest['company'], style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFA68B59))),
            ],
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            _buildDetailRow('Ticket ID', guest['id'] ?? ''),
            _buildDetailRow('Email', guest['guestEmail'] ?? '-'),
            _buildDetailRow('Teléfono', guest['guestPhone'] ?? '-'),
            _buildDetailRow('Estado', isCheckedIn ? 'INGRESADO' : 'PENDIENTE', color: isCheckedIn ? const Color(0xFF48645C) : Colors.white38),
            if (isCheckedIn && guest['checkedInAt'] != null)
              _buildDetailRow('Hora Entrada', formatTimestamp(guest['checkedInAt'])),
          ],
        ),
        actions: [
          TextButton(
            child: Text('CERRAR', style: GoogleFonts.inter(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          if (!isCheckedIn)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA68B59),
                foregroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('INGRESAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              onPressed: () => _manualCheckIn(guest['id']),
            )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
          Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 13, color: color ?? Colors.white70)),
        ],
      ),
    );
  }

  String formatTimestamp(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lista de Invitados',
          style: GoogleFonts.playfairDisplay(),
        ),
        backgroundColor: const Color(0xFF2B2B2B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_needsRefresh),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, empresa o ID...',
                  hintStyle: GoogleFonts.inter(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFA68B59)),
                  filled: true,
                  fillColor: const Color(0xFF2B2B2B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            // Guest Count summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Búsqueda: ${_filteredGuests.length} invitados', style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
                  Text(
                    'Ingresados: ${_filteredGuests.where((g) => g['status'] == 'checked_in').length}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA68B59)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List View
            Expanded(
              child: _filteredGuests.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron invitados.',
                        style: GoogleFonts.inter(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredGuests.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (ctx, index) {
                        final guest = _filteredGuests[index];
                        final isCheckedIn = guest['status'] == 'checked_in';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2B2B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              guest['guestName'] ?? 'Guest',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                guest['company'] ?? 'Invitado Especial',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: isCheckedIn ? const Color(0xFF48645C).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: isCheckedIn ? const Color(0xFF48645C).withOpacity(0.5) : Colors.white10,
                                ),
                              ),
                              child: Text(
                                isCheckedIn ? 'Ingresado' : 'Pendiente',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isCheckedIn ? const Color(0xFF5A7E73) : Colors.white38,
                                ),
                              ),
                            ),
                            onTap: () => _showGuestDetails(guest),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
