import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class HistoricalAlertsScreen extends StatefulWidget {
  const HistoricalAlertsScreen({Key? key}) : super(key: key);

  @override
  State<HistoricalAlertsScreen> createState() => _HistoricalAlertsScreenState();
}

class _HistoricalAlertsScreenState extends State<HistoricalAlertsScreen> {
  late Future<List<Map<String, dynamic>>> _futureAlertas;

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  // Consulta asíncrona de la base de datos local
  void _cargarAlertas() {
    setState(() {
      _futureAlertas = DatabaseHelper.instance.database.then((db) {
        return db.query('alertas', orderBy: 'id DESC');
      });
    });
  }

  // Función para procesar lecturas de sensores en tiempo real (IoT)
  // Puedes llamarla cuando recibas datos de tu ESP32 (MQTT/HTTP)
  Future<void> procesarLecturaSensorReal(String sensor, double valorActual) async {
    const double umbralCritico = 35.0; // Umbral de ejemplo
    bool esCritico = valorActual > umbralCritico;

    if (esCritico) {
      await DatabaseHelper.instance.insertAlerta(
        sensor,
        '$valorActual °C',
        'Crítico',
        DateTime.now().toString().substring(0, 19),
      );
      _cargarAlertas(); // Actualiza la vista automáticamente
    }
  }

  // Botón para simular entradas y probar la interfaz en el emulador
  Future<void> _agregarAlertaPrueba() async {
    final bool esCritico = DateTime.now().second % 2 == 0;

    await DatabaseHelper.instance.insertAlerta(
      esCritico ? 'Sensor de Gas' : 'Sensor de Temperatura',
      esCritico ? '920 ppm' : '24.5 °C',
      esCritico ? 'Crítico' : 'Normal',
      DateTime.now().toString().substring(0, 19),
    );

    _cargarAlertas();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('¡Alerta registrada con éxito en SQLite!'),
        backgroundColor: Colors.pink[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50]?.withOpacity(0.4),
      appBar: AppBar(
        title: const Text(
          'Historial y Alertas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.pink[400],
        elevation: 3,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureAlertas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.pink[400]),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar datos: ${snapshot.error}',
                style: TextStyle(color: Colors.pink[900]),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 70, color: Colors.pink[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay alertas registradas aún.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.pink[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _agregarAlertaPrueba,
                    icon: const Icon(Icons.add),
                    label: const Text('Insertar primera alerta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          final alertas = snapshot.data!;

          return ListView.builder(
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];
              final bool esCritico = alerta['estado'] == 'Crítico';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: esCritico ? Colors.pink.shade300 : Colors.pink.shade100,
                    width: esCritico ? 1.5 : 1,
                  ),
                ),
                color: esCritico ? Colors.pink[550]?.withOpacity(0.12) : Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: esCritico ? Colors.pink[200] : Colors.pink[100],
                    child: Icon(
                      esCritico ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: esCritico ? Colors.pink[900] : Colors.pink[500],
                    ),
                  ),
                  title: Text(
                    '${alerta['sensor']}: ${alerta['valor']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: esCritico ? Colors.pink[900] : Colors.grey[850],
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      'Fecha: ${alerta['fecha']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  trailing: Chip(
                    label: Text(
                      alerta['estado'],
                      style: TextStyle(
                        color: esCritico ? Colors.white : Colors.pink[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: esCritico ? Colors.pink[600] : Colors.pink[100],
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarAlertaPrueba,
        backgroundColor: Colors.pink[400],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Simular Alerta'),
      ),
    );
  }
}