import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart'; // Import av MQTT-klienten
import 'package:mqtt_client/mqtt_server_client.dart';  // Import av MqttServerClient-klassen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT Alarm and Sensor App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MqttServerClient? client;
  String mqttMessage = "No sensor data yet"; // Sanntid sensordata
  String alarmTime = "No alarm set"; // Viser alarmtid
  String debugText = "Debug: Waiting for action..."; // Debug tekst for status
  TextEditingController ipController = TextEditingController(); // For å skrive inn IP-adressen
  TextEditingController portController = TextEditingController(); // For å skrive inn portnummer

  @override
  void initState() {
    super.initState();
    portController.text = '1883'; // Sett standardporten til 1883
  }

  // Koble til MQTT broker
  Future<void> connectToMQTT() async {
    setState(() {
      debugText = "Connecting to MQTT broker...";
    });

    String brokerIP = ipController.text;
    int brokerPort = int.tryParse(portController.text) ?? 1883;

    client = MqttServerClient.withPort(brokerIP, 'flutter_client', brokerPort);
    client!.logging(on: true); // Slå på logging for debugging

    try {
      await client!.connect(); // Koble til MQTT-broker
      setState(() {
        debugText = "Connected to MQTT broker at $brokerIP:$brokerPort";
      });
      print('Connected to MQTT broker');

      // Abonner på sensordata-topic
      client!.subscribe('sensor/data', MqttQos.atMostOnce);

      // Lytt etter innkommende sensordata-meldinger
      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        setState(() {
          mqttMessage = message; // Oppdater skjermen med sensordata
          debugText = "Received message: $message from topic: ${c[0].topic}";
        });

        print('Received message: $message from topic: ${c[0].topic}');
      });
    } catch (e) {
      setState(() {
        debugText = "Failed to connect: $e";
      });
      print('Exception: $e');
      client!.disconnect();
    }
  }

  // Funksjon for å sende alarmtid via MQTT
  void sendAlarmTime(String time) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(time); // Alarmtid som meldingsinnhold

    client!.publishMessage('app/alarmtime', MqttQos.atMostOnce, builder.payload!);
    setState(() {
      debugText = "Alarm time sent: $time";
    });
    print('Alarm time sent: $time');
  }

  // Funksjon for å velge alarmtid ved hjelp av Flutter sin innebygde time picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        alarmTime = '${picked.hour}:${picked.minute}';
      });
      sendAlarmTime(alarmTime); // Sender alarmtid via MQTT
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MQTT Alarm & Sensor App"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                controller: ipController,
                decoration: InputDecoration(labelText: 'Enter Broker IP Address'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                controller: portController,
                decoration: InputDecoration(labelText: 'Enter Broker Port (default 1883)'),
                keyboardType: TextInputType.number,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                connectToMQTT(); // Koble til MQTT broker
              },
              child: Text('Connect to MQTT Broker'),
            ),
            SizedBox(height: 20),
            Text(
              'Sensor Data:',
              style: TextStyle(fontSize: 24),
            ),
            Text(
              mqttMessage,  // Viser sanntid sensordata fra MQTT
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 40),
            Text(
              'Set Alarm Time:',
              style: TextStyle(fontSize: 24),
            ),
            Text(
              alarmTime,  // Viser valgt alarmtid
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _selectTime(context);  // Åpner Flutter sin innebygde time picker
              },
              child: Text('Pick Alarm Time'),
            ),
            SizedBox(height: 40),
            Text(
              'Debug Information:',
              style: TextStyle(fontSize: 24),
            ),
            Text(
              debugText,  // Viser debug-informasjon
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
