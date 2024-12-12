
import 'dart:async';
import 'dart:convert';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  BluetoothPrint bluetoothPrint = BluetoothPrint.instance;

  bool _connected = false;
  BluetoothDevice? _device;
  String tips = 'no device connect';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initBluetooth());
  }
  

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initBluetooth() async {
    bluetoothPrint.startScan(timeout: const Duration(seconds: 4));

    bool isConnected=await bluetoothPrint.isConnected??false;

    bluetoothPrint.state.listen((state) {
      // ignore: avoid_print
      print('******************* cur device status: $state');

      switch (state) {
        case BluetoothPrint.CONNECTED:
          // ignore: avoid_print
          print('connected device: ${_device?.name}');
          setState(() {
            _connected = true;
            tips = 'connect success';
          });
          break;
        case BluetoothPrint.DISCONNECTED:
          setState(() {
            _connected = false;
            tips = 'disconnect success';
          });
          break;
        default:
          break;
      }
    });

    if (!mounted) return;

    if(isConnected) {
      setState(() {
        _connected=true;
      });
    }
  }


  final Map<String, dynamic> receiptData = {
    'leftColumn': [
      'USER001',
      '123 Street Name',
      '+1234567890',
      DateTime.now().toLocal().toString().split('.')[0],  // Properly formatted date
    ],
    'rightColumn': 'assets/logo/icon_launcher.png'
  };


String padRight(String text, int width) {
  return text.length < width ? text.padRight(width) : text.substring(0, width);
}


Future<List<LineText>> getReceiptLayout(Map<String, dynamic> data) async {
  List<LineText> list = [];
  try {    
    try {
      ByteData logoData = await rootBundle.load(data['rightColumn']);
      List<int> imageBytes = logoData.buffer.asUint8List(
        logoData.offsetInBytes,
        logoData.lengthInBytes
      );
      String base64Image = base64Encode(imageBytes);

      list.add(LineText(
        type: LineText.TYPE_IMAGE,
        content: base64Image,                                
        width: 120,
        height: 120,
        align: LineText.ALIGN_CENTER,
        linefeed: 1  // Feed line after logo
      ));


   for (int i = 0; i < data['leftColumn'].length; i++) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '${data['leftColumn'][i]}\n',       
        align: LineText.ALIGN_CENTER,
        linefeed: 0  
      ));
    }
    } catch (e) {
      print('Logo loading error: $e');      
    }

    //    // Method 1: Using relativeX for inline positioning
    // list.add(LineText(
    //   type: LineText.TYPE_TEXT,
    //   content: 'Item',
    //   align: LineText.ALIGN_LEFT,
    //   linefeed: 0  // Don't move to next line yet
    // ));
    
    // list.add(LineText(
    //   type: LineText.TYPE_TEXT,
    //   content: 'Qty',
    //   relativeX: 150,  // Position relative to previous content
    //   align: LineText.ALIGN_LEFT,
    //   linefeed: 0
    // ));
    
    // list.add(LineText(
    //   type: LineText.TYPE_TEXT,
    //   content: 'Price',
    //   relativeX: 100,  // Position relative to previous content
    //   align: LineText.ALIGN_LEFT,
    //   linefeed: 1  // Now move to next line
    // ));
                              

  } catch (e) {
    print('Layout error: $e');
    // Fallback layout
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Error in layout: $e',
      align: LineText.ALIGN_LEFT,
      linefeed: 1
    ));
  }

  return list;
}
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('BluetoothPrint example app'),
          ),
          body: RefreshIndicator(
            onRefresh: () => bluetoothPrint.startScan(timeout: const Duration(seconds: 4)),
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        child: Text(tips),
                      ),
                    ],
                  ),
                  const Divider(),
                  StreamBuilder<List<BluetoothDevice>>(
                    stream: bluetoothPrint.scanResults,
                    initialData:  [],
                    builder: (c, snapshot) => Column(
                      children: snapshot.data!.map((d) => ListTile(
                        title: Text(d.name??''),
                        subtitle: Text(d.address??''),
                        onTap: () async {
                          setState(() {
                            _device = d;
                          });
                        },
                        trailing: _device!=null && _device!.address == d.address
                        ?const Icon(
                          Icons.check,
                          color: Colors.green,
                        ):null,
                      )).toList(),
                    ),
                  ),
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed:  _connected?null:() async {
                                if(_device!=null && _device!.address !=null){
                                  setState(() {
                                    tips = 'connecting...';
                                  });
                                  await bluetoothPrint.connect(_device!);
                                }else{
                                  setState(() {
                                    tips = 'please select device';
                                  });
                                  // ignore: avoid_print
                                  print('please select device');
                                }
                              },
                              child: const Text('connect'),
                            ),
                            const SizedBox(width: 10.0),
                            OutlinedButton(
                              onPressed:  _connected?() async {
                                setState(() {
                                  tips = 'disconnecting...';
                                });
                                await bluetoothPrint.disconnect();
                              }:null,
                              child: const Text('disconnect'),
                            ),
                          ],
                        ),
                        const Divider(),
                        OutlinedButton(
                        onPressed: _connected ? () async {
                          // ignore: avoid_print
                          print('Attempting to print...');
                          
                          Map<String, dynamic> config = {
                            'width': 380,     // 58mm * 8 dots per mm = ~380 dots
                            'height': 0,      // Auto height
                            'gap': 2,         // Small gap between lines
                            'paperSize': 58   // 58mm paper width
                          };

                          List<LineText> list = [];

                        // Add header
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: 'JOB ORDER',                     
                          weight: 5,
                          align: LineText.ALIGN_CENTER,
                          fontZoom: 2,
                          linefeed: 1
                        ));                                       

                          list.add(
                            LineText(type: LineText.TYPE_TEXT,content: 'JO-241012-778',align: LineText.ALIGN_CENTER,x: 0,  y: 120,linefeed: 1),
                          );

                        // Add separator
                        list.add(LineText(type: LineText.TYPE_TEXT,content: '------------------------------------------------',align: LineText.ALIGN_CENTER,linefeed: 1));

                      // // Get and add header layout
                        List<LineText> headerLayout = await getReceiptLayout(receiptData);
                        list.addAll(headerLayout);  // Add the header layout to main list
                        
                        // Add separator
                        list.add(LineText(type: LineText.TYPE_TEXT,content: '------------------------------------------------',align: LineText.ALIGN_CENTER,linefeed: 1));

                        // Categories header
                        list.add(LineText(type: LineText.TYPE_TEXT,content: 'Categories',weight: 1,align: LineText.ALIGN_CENTER,linefeed: 1));

                        // Textile section
                        list.add(
                          LineText(type: LineText.TYPE_TEXT,content:  'TEXTILE',weight: 1,align: LineText.ALIGN_LEFT,linefeed: 1));
                          list.add(LineText(type: LineText.TYPE_TEXT,content: 'Qty',weight: 1,align: LineText.ALIGN_LEFT,linefeed: 1 ,relativeX: 540));

                        // Sample textile items
                        list.addAll([
                          LineText(type: LineText.TYPE_TEXT, content: 'Item 1                                        5', align: LineText.ALIGN_LEFT, linefeed: 1),
                          LineText(type: LineText.TYPE_TEXT, content: 'Item 2                                        3', align: LineText.ALIGN_LEFT, linefeed: 1),
                        ]);

                        // Add separator
                        list.add(LineText(type: LineText.TYPE_TEXT,content: '------------------------------------------------',align: LineText.ALIGN_CENTER,linefeed: 1));

                        // Uniform section
                        list.add(LineText(type: LineText.TYPE_TEXT,content: 'UNIFORM',weight: 1,align: LineText.ALIGN_LEFT,linefeed: 1));
                        list.add(LineText(type: LineText.TYPE_TEXT,content: 'Qty',weight: 1,align: LineText.ALIGN_LEFT,linefeed: 1 ,relativeX: 540));
                        // Sample uniform items
                        list.addAll([
                          LineText(type: LineText.TYPE_TEXT, content: 'Uniform 1                                      2', align: LineText.ALIGN_LEFT, linefeed: 1),
                          LineText(type: LineText.TYPE_TEXT, content: 'Uniform 2                                      4', align: LineText.ALIGN_LEFT, linefeed: 1),
                        ]);

                        // Add separator
                        list.add(LineText(type: LineText.TYPE_TEXT,content: '------------------------------------------------',align: LineText.ALIGN_CENTER,linefeed: 1));


                        // Linens section
                        list.add(LineText(type: LineText.TYPE_TEXT,content: 'LINENS',weight: 1,align: LineText.ALIGN_LEFT,linefeed: 1));
                       
                        list.add(LineText(type: LineText.TYPE_TEXT,content: 'Qty',weight: 1,align: LineText.ALIGN_LEFT,linefeed: 1 ,relativeX: 540));

                        // Sample linen items
                        list.addAll([
                          LineText(type: LineText.TYPE_TEXT, content: 'Linen 1                                        3', align: LineText.ALIGN_LEFT, linefeed: 1),
                          LineText(type: LineText.TYPE_TEXT, content: 'Linen 2                                        2', align: LineText.ALIGN_LEFT, linefeed: 1),
                        ]);

                        // Total
                        list.addAll([
                          LineText(type: LineText.TYPE_TEXT, content: '------------------------------------------------', align: LineText.ALIGN_CENTER, linefeed: 1),
                          LineText(type: LineText.TYPE_TEXT, content: 'TOTAL                                         19', weight: 1, align: LineText.ALIGN_LEFT, linefeed: 1),
                          LineText(type: LineText.TYPE_TEXT, content: '------------------------------------------------', align: LineText.ALIGN_CENTER, linefeed: 1),
                        ]);


                

                          // // Start with a clean format
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: '\n',linefeed: 1));

                          // // Header
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: 'UROVO TEST RECEIPT',weight: 1,align: LineText.ALIGN_CENTER,fontZoom: 2,  linefeed: 1));

                          // // Date/Time
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: DateTime.now().toString().substring(0, 19),align: LineText.ALIGN_CENTER,linefeed: 1));

                          // // Separator
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: '================================================',align: LineText.ALIGN_CENTER,linefeed: 1));

                          // // Test content
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: 'Item 1 - ',align: LineText.ALIGN_LEFT,linefeed: 0 ));

                          // list.add(LineText(type: LineText.TYPE_TEXT,content: '10.00',align: LineText.ALIGN_RIGHT,linefeed: 1 ));
                          
                          // // Spacing
                          // list.add(LineText(linefeed: 1));

                          // // QR Code
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: 'QR Code:',align: LineText.ALIGN_CENTER,linefeed: 1));

                          // list.add(LineText(type: LineText.TYPE_QRCODE,content: 'https://example.com',size: 200,align: LineText.ALIGN_CENTER,linefeed: 1));

                          // // Another barcode type (Code 39)
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: 'Product Barcode:',align: LineText.ALIGN_CENTER,linefeed: 1));

                          // list.add(LineText(type: LineText.TYPE_BARCODE,content: 'PROD123456',size: 68,align: LineText.ALIGN_CENTER,linefeed: 1));

                          // // Spacing before QR
                          // list.add(LineText(linefeed: 1));

                          // // QR Code with adjusted settings
                          // list.add(LineText(type: LineText.TYPE_QRCODE,content: 'https://www.google.com',  align: LineText.ALIGN_CENTER,size: 8,linefeed: 1));

                          // // Text below QR code
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: 'Scan Me!',align: LineText.ALIGN_CENTER,linefeed: 1));
                          
                          // // Footer
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: '================================================',align: LineText.ALIGN_CENTER,linefeed: 1));

                          // // End with multiple line feeds for paper cutting
                          // list.add(LineText(type: LineText.TYPE_TEXT,content: '\n', linefeed: 1));

                          try {
                            // Print sequence with error handling
                            // ignore: avoid_print
                            print('Starting print sequence...');
                            
                            // Try direct receipt printing first
                            // ignore: avoid_print
                            print('Printing receipt...');
                            final result = await bluetoothPrint.printReceipt(config, list);
                            // ignore: avoid_print
                            print('Print result: $result');
                            
                            // Add a small delay
                            await Future.delayed(const Duration(milliseconds: 500));
                            
                            // Force feed paper at the end
                            await bluetoothPrint.printReceipt(
                              config, 
                              [LineText(type: LineText.TYPE_TEXT, content: '\n\n\n', linefeed: 1)]
                            );
                            
                          } catch (e) {
                            // ignore: avoid_print
                            print('Print error: $e');
                            
                            // Try alternative print method if first one fails
                            try {
                              // ignore: avoid_print
                              print('Trying alternative print method...');
                              await Future.delayed(const Duration(seconds: 1));
                              await bluetoothPrint.printTest();
                            } catch (e2) {
                              // ignore: avoid_print
                              print('Alternative print also failed: $e2');
                            }
                          }
                        } : null,
                        child: const Text('Print Receipt Test'),
                      ),

                        OutlinedButton(
                          onPressed: _connected ? () async {
                            // ignore: avoid_print
                            print('Checking printer status...');
                            final bool? isConnected = await bluetoothPrint.isConnected;
                            // ignore: avoid_print
                            print('Is printer connected: $isConnected');
                            
                            if (isConnected == true) {
                              // Try a minimal print test
                              try {
                                await bluetoothPrint.printReceipt(
                                  {'width': 380, 'height': 0},
                                  [
                                    LineText(
                                    type: LineText.TYPE_TEXT,
                                    content: 'Connection Test\n\n\n',
                                    align: LineText.ALIGN_CENTER,
                                    linefeed: 1

                                  )]
                                );
                              } catch (e) {
                                // ignore: avoid_print
                                print('Test print failed: $e');
                              }
                            }
                          } : null,
                          child: const Text('Check Printer'),
                        ),
                        const Divider(),                       
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        floatingActionButton: StreamBuilder<bool>(
          stream: bluetoothPrint.isScanning,
          initialData: false,
          builder: (c, snapshot) {
            if (snapshot.data == true) {
              return FloatingActionButton(
                onPressed: () => bluetoothPrint.stopScan(),
                backgroundColor: Colors.red,
                child: const Icon(Icons.stop),
              );
            } else {
              return FloatingActionButton(
                  child: const Icon(Icons.search),
                  onPressed: () => bluetoothPrint.startScan(timeout: const Duration(seconds: 4)));
            }
          },
        ),
      ),
    );
  }
}
