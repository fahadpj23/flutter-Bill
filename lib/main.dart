import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Bill Form',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BillFormScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BillFormScreen extends StatefulWidget {
  const BillFormScreen({super.key});

  @override
  _BillFormScreenState createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  TextEditingController billNoController = TextEditingController();
  TextEditingController customerNameController = TextEditingController();
  TextEditingController mobileNumberController = TextEditingController();
  TextEditingController phoneModelController = TextEditingController();
  TextEditingController imei1Controller = TextEditingController();
  TextEditingController imei2Controller = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController totalAmountController = TextEditingController();
  TextEditingController taxableAmountController = TextEditingController();
  TextEditingController gstAmountController = TextEditingController();

  bool _isScanning = false;
  bool _isScanningIMEI1 = true;
  bool _sealChecked = false;

  // Image data
  Uint8List? _logoImage;
  Uint8List? _sealImage;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _loadImages();

    // Set up listeners to auto-calculate GST
    totalAmountController.addListener(_calculateGST);
  }

  void _calculateGST() {
    if (totalAmountController.text.isNotEmpty) {
      try {
        double totalAmount = double.parse(totalAmountController.text);
        double gstPercent = 18.0; // Fixed at 18%

        double taxableAmount = totalAmount / (1 + gstPercent / 100);
        double gstAmount = totalAmount - taxableAmount;

        setState(() {
          taxableAmountController.text = taxableAmount.toStringAsFixed(2);
          gstAmountController.text = gstAmount.toStringAsFixed(2);
        });
      } catch (e) {
        // Handle parsing errors
      }
    }
  }

  Future<void> _loadImages() async {
    try {
      // Load logo
      final ByteData logoData = await rootBundle.load(
        'assets/mobileHouseLogo.png',
      );
      _logoImage = logoData.buffer.asUint8List();

      // Load seal
      final ByteData sealData = await rootBundle.load(
        'assets/mobileHouseSeal.jpeg',
      );
      _sealImage = sealData.buffer.asUint8List();
    } catch (e) {
      print('Error loading images: $e');
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denial
    }
  }

  void _startScanningIMEI1() {
    setState(() {
      _isScanning = true;
      _isScanningIMEI1 = true;
    });
  }

  void _startScanningIMEI2() {
    setState(() {
      _isScanning = true;
      _isScanningIMEI1 = false;
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
  }

  void _onBarcodeScanned(BarcodeCapture barcodes) {
    if (barcodes.barcodes.isNotEmpty) {
      final String barcode = barcodes.barcodes.first.rawValue ?? '';
      setState(() {
        if (_isScanningIMEI1) {
          imei1Controller.text = barcode;
        } else {
          imei2Controller.text = barcode;
        }
        _isScanning = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scanned IMEI: $barcode')));
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Form Submitted'),
          content: Text('Bill information has been saved successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _printBill() async {
    final pdf = await _generatePdf();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Helper function to convert amount to words
  String _amountToWords(String amount) {
    try {
      double value = double.parse(amount);
      // Simple implementation - you might want to use a more robust package for this
      List<String> units = [
        '',
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
      ];
      List<String> teens = [
        'ten',
        'eleven',
        'twelve',
        'thirteen',
        'fourteen',
        'fifteen',
        'sixteen',
        'seventeen',
        'eighteen',
        'nineteen',
      ];
      List<String> tens = [
        '',
        '',
        'twenty',
        'thirty',
        'forty',
        'fifty',
        'sixty',
        'seventy',
        'eighty',
        'ninety',
      ];

      if (value == 0) return 'zero only';

      int rupees = value.toInt();
      int paise = ((value - rupees) * 100).round();

      String words = '';

      if (rupees >= 1000) {
        words += '${_convertNumber(rupees ~/ 1000)} thousand ';
        rupees %= 1000;
      }

      if (rupees >= 100) {
        words += '${units[rupees ~/ 100]} hundred ';
        rupees %= 100;
      }

      if (rupees >= 20) {
        words += '${tens[rupees ~/ 10]} ';
        rupees %= 10;
      } else if (rupees >= 10) {
        words += '${teens[rupees - 10]} ';
        rupees = 0;
      }

      if (rupees > 0) {
        words += '${units[rupees]} ';
      }

      words += 'rupees';

      if (paise > 0) {
        words += ' and ${_convertNumber(paise)} paise';
      }

      return '${words.trim()} only';
    } catch (e) {
      return 'Amount in words conversion failed';
    }
  }

  String _convertNumber(int number) {
    List<String> units = [
      '',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
    ];
    List<String> teens = [
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    List<String> tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];

    if (number < 10) return units[number];
    if (number < 20) return teens[number - 10];
    return '${tens[number ~/ 10]} ${units[number % 10]}'.trim();
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    // Get current date
    String currentDate =
        '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'GSTIN: 32BSGPJ3340H174',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                // Header with Logo and GSTIN
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,

                  children: [
                    // Logo
                    if (_logoImage != null)
                      pw.Container(
                        height: 100,
                        child: pw.FittedBox(
                          child: pw.Column(
                            children: [
                              pw.Container(
                                height: 22, // Fixed height for image
                                child: pw.Image(pw.MemoryImage(_logoImage!)),
                              ),
                              pw.Text(
                                "3way junction Peringottukara",
                                style: pw.TextStyle(
                                  fontSize: 4,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                              pw.Text(
                                "Mob:9072430483,834830868",
                                style: pw.TextStyle(
                                  fontSize: 4,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                              pw.Text(
                                "Mobile house",
                                style: pw.TextStyle(
                                  fontSize: 4,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                              pw.Text(
                                "GST TAX INVOICE (TYPE-B2C) -CASH SALE",
                                style: pw.TextStyle(
                                  fontSize: 4,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      pw.Text(
                        'MOBILE HOUSE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                    // GSTIN
                    pw.Container(),
                  ],
                ),

                pw.SizedBox(height: 10),

                // State and Invoice Details
                pw.Container(
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  padding: pw.EdgeInsets.all(10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'STATE : KERALA',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.normal,
                              fontSize: 8,
                            ),
                          ),
                          pw.Text(
                            'STATE CODE : 32',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.normal,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Invoice No. : ${billNoController.text.isNotEmpty ? billNoController.text : ""}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.normal,
                              fontSize: 8,
                            ),
                          ),
                          pw.Text(
                            'Invoice Date : $currentDate',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.normal,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),
                pw.Container(
                  height: .5, // Line thickness
                  width: double.infinity, // Full width
                  color: PdfColors.grey300, // Line color
                ),
                // Customer Details
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Customer : ${customerNameController.text.isNotEmpty ? customerNameController.text : ""}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Address: ${addressController.text.isNotEmpty ? addressController.text : ""}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Mobile Tel : ${mobileNumberController.text.isNotEmpty ? mobileNumberController.text : ""}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  columnWidths: {
                    0: pw.FlexColumnWidth(0.5),
                    1: pw.FlexColumnWidth(2.0),
                    2: pw.FlexColumnWidth(0.8),
                    3: pw.FlexColumnWidth(0.5),
                    4: pw.FlexColumnWidth(1.0),
                    5: pw.FlexColumnWidth(0.8),
                    6: pw.FlexColumnWidth(0.5),
                    7: pw.FlexColumnWidth(0.8),
                    8: pw.FlexColumnWidth(1.0),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(),
                      children: [
                        _buildTableHeaderCell('SLNO'),
                        _buildTableHeaderCell('Name of Item/Commodity'),
                        _buildTableHeaderCell('HSNCode'),
                        _buildTableHeaderCell('Qty'),
                        _buildTableHeaderCell('Total Rate'),
                        _buildTableHeaderCell('Total Disc'),
                        _buildTableHeaderCell('GST%'),
                        _buildTableHeaderCell('GST Amt'),
                        _buildTableHeaderCell('Total Amount'),
                      ],
                    ),

                    // Product Row - USING DYNAMIC VALUES
                    pw.TableRow(
                      children: [
                        _buildTableCell('1', alignment: pw.Alignment.center),
                        pw.Container(
                          // Wrap the Padding with Container for alignment
                          alignment: pw.Alignment.center,
                          child: pw.Padding(
                            padding: pw.EdgeInsets.all(4),
                            child: pw.Column(
                              crossAxisAlignment: pw
                                  .CrossAxisAlignment
                                  .center, // Center column content
                              mainAxisAlignment: pw
                                  .MainAxisAlignment
                                  .center, // Center vertically
                              children: [
                                pw.Text(
                                  phoneModelController.text.isNotEmpty
                                      ? phoneModelController.text
                                      : "",
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center, // Center text
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'IMEI1: ${imei1Controller.text.isNotEmpty ? imei1Controller.text : ""}',
                                  style: pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.center, // Center text
                                ),
                                pw.Text(
                                  'IMEI2: ${imei2Controller.text.isNotEmpty ? imei2Controller.text : ""}',
                                  style: pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.center, // Center text
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildTableCell('', alignment: pw.Alignment.center),
                        _buildTableCell('1', alignment: pw.Alignment.center),
                        _buildTableCell(
                          taxableAmountController.text.isNotEmpty
                              ? taxableAmountController.text
                              : "",
                          alignment: pw.Alignment.center,
                        ),
                        _buildTableCell('0.00', alignment: pw.Alignment.center),
                        _buildTableCell(
                          '18',
                          alignment: pw.Alignment.center,
                        ), // Fixed GST 18%
                        _buildTableCell(
                          gstAmountController.text.isNotEmpty
                              ? gstAmountController.text
                              : "",
                          alignment: pw.Alignment.center,
                        ),
                        _buildTableCell(
                          totalAmountController.text.isNotEmpty
                              ? totalAmountController.text
                              : "",
                          alignment: pw.Alignment.center,
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(
                  height: 220,
                  child: pw.Stack(
                    // Add Stack as parent of Positioned
                    children: [
                      pw.Positioned(
                        bottom: 10, // From bottom of Stack
                        right: 20, // From right of Stack
                        child: _sealImage != null
                            ? pw.Container(
                                width: 80,
                                height: 80,
                                child: pw.Transform.rotate(
                                  angle:
                                      35 *
                                      3.14159 /
                                      180, // Convert degrees to radians (45°)
                                  child: pw.Image(pw.MemoryImage(_sealImage!)),
                                ),
                              )
                            : pw.Container(
                                width: 80,
                                height: 80,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  border: pw.Border.all(
                                    color: PdfColors.red,
                                    width: 2,
                                  ),
                                ),
                                child: pw.Center(
                                  child: pw.Text(
                                    'SEAL',
                                    style: pw.TextStyle(
                                      color: PdfColors.red,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                // Total Section
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),

                      pw.Text(
                        '1    ${taxableAmountController.text.isNotEmpty ? taxableAmountController.text : ""}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 2),
                pw.Divider(color: PdfColors.grey400, thickness: 1),

                // Amount in Words - DYNAMIC
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'In Words: ${totalAmountController.text.isNotEmpty ? _amountToWords(totalAmountController.text) : ""}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                    pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          "rounding",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.Text(
                          'Total Amount: ${totalAmountController.text}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 2),

                // GST Breakdown Table - DYNAMIC
                pw.Row(
                  children: [
                    // GST Table - Left side
                    pw.Expanded(
                      flex: 2, // Takes 2/3 of the width
                      child: pw.Table(
                        border: pw.TableBorder.all(
                          color: PdfColors.black,
                          width: 1,
                        ),
                        columnWidths: {
                          0: pw.FlexColumnWidth(1.5),
                          1: pw.FlexColumnWidth(1.0),
                          2: pw.FlexColumnWidth(1.0),
                          3: pw.FlexColumnWidth(1.0),
                          4: pw.FlexColumnWidth(1.0),
                          5: pw.FlexColumnWidth(1.0),
                        },
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(),
                            children: [
                              _buildTableHeaderCell(''),
                              _buildTableHeaderCell('GST 0%'),
                              _buildTableHeaderCell('GST 5%'),
                              _buildTableHeaderCell('GST 12%'),
                              _buildTableHeaderCell('GST 18%'),
                              _buildTableHeaderCell('GST 28%'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell('Taxable'),
                              _buildTableCell('0.00'),
                              _buildTableCell('0.00'),
                              _buildTableCell('0.00'),
                              _buildTableCell(
                                taxableAmountController.text.isNotEmpty
                                    ? taxableAmountController.text
                                    : "0.00",
                              ),
                              _buildTableCell('0.00'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell('CGST Amt'),
                              _buildTableCell('0.00'),
                              _buildTableCell('0.00'),
                              _buildTableCell('0.00'),
                              _buildTableCell(
                                gstAmountController.text.isNotEmpty
                                    ? (double.parse(gstAmountController.text) /
                                              2)
                                          .toStringAsFixed(2)
                                    : "0.00",
                              ),
                              _buildTableCell('0.00'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell('SGST Amt'),
                              _buildTableCell('0.00'),
                              _buildTableCell('0.00'),
                              _buildTableCell('0.00'),
                              _buildTableCell(
                                gstAmountController.text.isNotEmpty
                                    ? (double.parse(gstAmountController.text) /
                                              2)
                                          .toStringAsFixed(2)
                                    : "0.00",
                              ),
                              _buildTableCell('0.00'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Spacer between table and footer
                    pw.SizedBox(width: 20),

                    // Footer with Seal and Signature - Right side
                    pw.Expanded(
                      flex: 1, // Takes 1/3 of the width
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          // Seal at the top
                          pw.SizedBox(height: 10),

                          // Signature Section
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Certified that the particulars given above are true and correct',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                              pw.SizedBox(height: 20),
                              pw.Text(
                                'For MOBILE HOUSE',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 10),
                              pw.Container(
                                width: 150,
                                child: pw.Divider(
                                  color: PdfColors.black,
                                  thickness: 1,
                                ),
                              ),
                              pw.Text(
                                'Authorised Signatory',
                                style: pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  String _getMonthName(int month) {
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  pw.Widget _buildTableHeaderCell(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8),
        textAlign: alignment == pw.Alignment.centerLeft
            ? pw.TextAlign.left
            : alignment == pw.Alignment.center
            ? pw.TextAlign.center
            : pw.TextAlign.right,
      ),
    );
  }

  void _viewBill() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bill No: ${billNoController.text.isEmpty ? "Not provided" : billNoController.text}',
              ),
              Text(
                'Customer: ${customerNameController.text.isEmpty ? "Not provided" : customerNameController.text}',
              ),
              Text(
                'Mobile: ${mobileNumberController.text.isEmpty ? "Not provided" : mobileNumberController.text}',
              ),
              Text(
                'Phone Model: ${phoneModelController.text.isEmpty ? "Not provided" : phoneModelController.text}',
              ),
              Text(
                'IMEI 1: ${imei1Controller.text.isEmpty ? "Not provided" : imei1Controller.text}',
              ),
              Text(
                'IMEI 2: ${imei2Controller.text.isEmpty ? "Not provided" : imei2Controller.text}',
              ),
              Text(
                'Address: ${addressController.text.isEmpty ? "Not provided" : addressController.text}',
              ),
              Text(
                'Total Amount: ${totalAmountController.text.isEmpty ? "Not provided" : "₹${totalAmountController.text}"}',
              ),
              Text('GST %: 18%'), // Fixed GST 18%
              Text(
                'Taxable Amount: ${taxableAmountController.text.isEmpty ? "Not provided" : "₹${taxableAmountController.text}"}',
              ),
              Text(
                'GST Amount: ${gstAmountController.text.isEmpty ? "Not provided" : "₹${gstAmountController.text}"}',
              ),
              Text('Seal: ${_sealChecked ? "Yes" : "No"}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Customer Bill Form',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: _isScanning ? _buildScanner() : _buildForm(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        AppBar(
          title: Text('Scan IMEI ${_isScanningIMEI1 ? '1' : '2'} Barcode'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _stopScanning,
          ),
        ),
        Expanded(
          child: MobileScanner(
            onDetect: _onBarcodeScanned,
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.black,
          child: Text(
            'Position the IMEI barcode within the frame to scan',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24),
            _buildFormFields(),
            SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'BILL INFORMATION',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '$label${isRequired ? ' *' : ''}',
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildFormFields() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(
              controller: billNoController,
              label: 'Bill No',
              icon: Icons.receipt,
              isRequired: true,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: customerNameController,
              label: 'Customer Name',
              icon: Icons.person,
              isRequired: true,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: mobileNumberController,
              label: 'Customer Mobile number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              isRequired: true,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: phoneModelController,
              label: 'Phone Model Name',
              icon: Icons.phone_android,
              isRequired: true,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: imei1Controller,
                    label: 'IMEI 1',
                    icon: Icons.qr_code,
                    isRequired: true,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _startScanningIMEI1,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: imei2Controller,
                    label: 'IMEI 2',
                    icon: Icons.qr_code_2,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _startScanningIMEI2,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: addressController,
              label: 'Address',
              icon: Icons.location_on,
              maxLines: 3,
            ),
            SizedBox(height: 16),

            // Only Total Amount field needed now (GST is fixed at 18%)
            _buildTextField(
              controller: totalAmountController,
              label: 'Total Amount',
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
              isRequired: true,
            ),
            SizedBox(height: 16),

            // Display calculated values with GST info
            Row(
              children: [
                Expanded(
                  child: Text(
                    'GST: 18%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Taxable Amount: ${taxableAmountController.text.isEmpty ? "0.00" : taxableAmountController.text}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'GST Amount: ${gstAmountController.text.isEmpty ? "0.00" : gstAmountController.text}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(width: 12),
                  Icon(
                    Icons.stay_primary_landscape_sharp,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Seal:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(width: 16),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Checkbox(
                      value: _sealChecked,
                      onChanged: (value) {
                        setState(() {
                          _sealChecked = value ?? false;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('□', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _viewBill,
            icon: Icon(Icons.visibility, size: 20),
            label: Text('View Bill', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _printBill,
            icon: Icon(Icons.print, size: 20),
            label: Text('Print', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    billNoController.dispose();
    customerNameController.dispose();
    mobileNumberController.dispose();
    phoneModelController.dispose();
    imei1Controller.dispose();
    imei2Controller.dispose();
    addressController.dispose();
    totalAmountController.dispose();
    taxableAmountController.dispose();
    gstAmountController.dispose();
    super.dispose();
  }
}
