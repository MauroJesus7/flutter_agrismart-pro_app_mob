import 'package:ff_setup_to_flutter/home_page.dart';
import 'package:ff_setup_to_flutter/main.dart';
import 'package:ff_setup_to_flutter/models/DiseaseReport.dart';
import 'package:ff_setup_to_flutter/services/ApiService.dart';
import 'package:styled_divider/styled_divider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ManualReportDiseasesScreenWidget extends StatefulWidget {
  const ManualReportDiseasesScreenWidget({super.key});

  @override
  State<ManualReportDiseasesScreenWidget> createState() =>
      _ManualReportDiseasesScreenWidgetState();
}

class _ManualReportDiseasesScreenWidgetState
    extends State<ManualReportDiseasesScreenWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  List<dynamic> crops = [];
  List<dynamic> diseases = [];

  TextEditingController codeController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  String? selectedCrop;
  String? selectedDisease;
  double? latitude;
  double? longitude;
  bool isReportPrivate = false;

  void _showDialog() {
    String formattedLatitude =
        latitude != null ? latitude!.toStringAsFixed(6) : 'Not available';
    String formattedLongitude =
        longitude != null ? longitude!.toStringAsFixed(6) : 'Not available';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Current Location"),
          content: Text(
              "Latitude: $formattedLatitude\nLongitude: $formattedLongitude"),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    ApiService.getCrops().then((data) {
      setState(() {
        crops = data;
      });
    });

    _determinePosition();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services disabled.");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions denied.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions permanently denied.");
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          forceAndroidLocationManager: true);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>> createAndSendDiseaseReport(File? imageFile) async {
    Position? position = await _determinePosition();

    if (position == null) {
      return {"success": false, "message": "Unable to obtain location."};
    }

    try {
      final selectedCropId = crops.firstWhere(
        (crop) => crop['Name'] == selectedCrop,
        orElse: () => null,
      )?['Id'];

      final selectedDiseaseId = diseases.firstWhere(
        (disease) => disease['Name'] == selectedDisease,
        orElse: () => null,
      )?['Id'];

      if (_image == null) {
        return {"success": false, "message": "No image selected."};
      }

      if (selectedCropId != null && selectedDiseaseId != null) {
        var report = DiseaseReport(
          code: codeController.text,
          description: descriptionController.text,
          photoPath: null,
          photo: _image,
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
          cropId: selectedCropId,
          diseaseId: selectedDiseaseId,
          isPrivate: isReportPrivate,
          createdAt: DateTime.now(),
        );

        // Chamada ao serviço de API ajustada para passar a imagem como arquivo
        await ApiService().createDiseaseReport(report, _image);

        // Limpa os controladores e reseta variáveis
        codeController.clear();
        descriptionController.clear();
        _image = null;

        // Atualiza a UI
        setState(() {
          selectedCrop = null;
          selectedDisease = null;
          isReportPrivate = false;
        });

        return {"success": true, "message": "Report created successfully!"};
      } else {
        return {"success": false, "message": "Unselected crop or disease."};
      }
    } catch (e) {
      print("Error creating or sending the report: $e");
      return {
        "success": false,
        "message": "Error creating or sending the report: $e"
      };
    }
  }

  Future<void> _showSuccessDialog(BuildContext context, String message) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 40.0,
              ),
              const SizedBox(height: 10),
              Text(
                "Success", // Mensagem de sucesso
                textAlign: TextAlign.center, // Centraliza o texto
                style: GoogleFonts.outfit(
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            textAlign: TextAlign.center, 
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                "Continue",
                textAlign: TextAlign.center,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text(
                "Go to Home",
                textAlign: TextAlign.center,
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) =>
                          const NavBarApp()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  File? _image;

  // Future<void> _pickImage() async {
  //   final picker = ImagePicker();
  //   final pickedImage = await picker.pickImage(
  //       source: ImageSource
  //           .gallery); // Pode usar ImageSource.camera para tirar uma foto

  //   setState(() {
  //     if (pickedImage != null) {
  //       _image = File(pickedImage.path);
  //     } else {
  //       print('No images selected.');
  //     }
  //   });
  // }

  // void _removeImage() {
  //   setState(() {
  //     _image = null;
  //   });
  // }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('Photo Library',
                 style: GoogleFonts.outfit(
                  fontSize: 18
                 ),
                ),
                onTap: () async {
                  Navigator.of(context).pop(); // Fecha o bottom sheet
                  final XFile? pickedImage = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  _processPickedImage(pickedImage);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text('Camera', style: GoogleFonts.outfit(
                  fontSize: 18
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop(); // Fecha o bottom sheet
                  final XFile? pickedImage = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  _processPickedImage(pickedImage);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _processPickedImage(XFile? pickedImage) {
    setState(() {
      if (pickedImage != null) {
        _image = File(pickedImage.path);
      } else {
        print('No image selected.');
      }
    });
  }

  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: Container(
            margin: const EdgeInsets.only(left: 10),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF606A85),
                size: 30,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 15, 0),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/Mauro-ProfilePhoto.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          centerTitle: false,
          elevation: 0,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Create Report',
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                    child: Text(
                      'Create a manual report choosing options',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                    child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0, 10, 0, 0),
                              child: TextFormField(
                                controller: codeController,
                                autofocus: true,
                                obscureText: false,
                                decoration: InputDecoration(
                                  hintText: 'Enter your Report Code here...',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.normal,
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color(0xFFA1A1A1),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color.fromARGB(255, 10, 187, 166),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  errorBorder: UnderlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE57373),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedErrorBorder: UnderlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE57373),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color:
                                      const Color.fromARGB(255, 197, 199, 203),
                                  width: 0.7,
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: selectedCrop,
                                onChanged: (String? newValue) async {
                                  if (newValue != null) {
                                    setState(() {
                                      selectedCrop = newValue;
                                    });
                                    try {
                                      // Encontrar o ID da cultura com base no nome selecionado
                                      final selectedCropId = crops.firstWhere(
                                        (crop) => crop['Name'] == newValue,
                                        orElse: () => null,
                                      )?['Id'];

                                      if (selectedCropId != null) {
                                        final diseasesData = await ApiService.getDiseasesByCrop(selectedCropId);
                                        setState(() {
                                          diseases = diseasesData;
                                          selectedDisease = null; // Reset a doença selecionada
                                        });
                                      }
                                    } catch (e) {
                                      print('Erro ao carregar doenças: $e');
                                    }
                                  }
                                },
                                items: crops.map<DropdownMenuItem<String>>((dynamic crop) {
                                  return DropdownMenuItem<String>(
                                    value: crop['Name'],
                                    child: Text(crop['Name']),
                                  );
                                }).toList(),
                                hint: const Text('Choose a crop...'),
                                isExpanded: true,
                                underline: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color.fromARGB(255, 0, 0, 0), width: 4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                style: GoogleFonts.outfit(fontSize: 18, color: Colors.black),
                                dropdownColor: Colors.white,
                              ),

                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color:
                                      const Color.fromARGB(255, 197, 199, 203),
                                  width: 0.7,
                                ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: DropdownButton<String>(
                                value: selectedDisease,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedDisease = newValue;
                                  });
                                },
                                items: diseases.map<DropdownMenuItem<String>>(
                                    (dynamic disease) {
                                  return DropdownMenuItem<String>(
                                    value: disease[
                                        'Name'], // Ajuste conforme a sua API
                                    child: Text(disease[
                                        'Name']), // Ajuste conforme a sua API
                                  );
                                }).toList(),
                                hint: const Text('Choose a disease...'),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                                elevation: 2,
                                isExpanded: true,
                                underline: Container(),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                ),
                                dropdownColor: Colors.white,
                              ),
                            ),
                            TextFormField(
                              controller: descriptionController,
                              autofocus: true,
                              obscureText: false,
                              decoration: InputDecoration(
                                labelStyle: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                hintText:
                                    'Short Description of what is going on...',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(0),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color.fromARGB(255, 10, 187, 166),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(0),
                                ),
                                errorBorder: UnderlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color(
                                        0xFFFF5963), // Cor de erro aleatória
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(0),
                                ),
                                focusedErrorBorder: UnderlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color(
                                        0xFFFF5963), // Cor de erro de foco aleatória
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(0),
                                ),
                                contentPadding:
                                    const EdgeInsetsDirectional.fromSTEB(
                                        16, 24, 16, 12),
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 10,
                              minLines: 6,
                              cursorColor:
                                  const Color.fromARGB(255, 10, 187, 166),
                            ),
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _image == null
                                        ? const Icon(Icons.image,
                                            size: 100.0, color: Colors.grey)
                                        : Container(
                                            width: 100.0,
                                            height: 100.0,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10.0), // Raio da borda
                                              border: Border.all(
                                                color:
                                                    Colors.grey, // Cor da borda
                                                width: 1.0, // Largura da borda
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                              child: Image.file(
                                                _image!,
                                                fit: BoxFit.cover,
                                                width: 100.0,
                                                height: 100.0,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 20),
                                  ElevatedButton.icon(
                                    onPressed: _image == null
                                        ? _pickImage
                                        : _removeImage,
                                    icon: Icon(
                                      _image == null
                                          ? Icons.add_photo_alternate
                                          : Icons.delete,
                                      color: _image == null
                                          ? Colors.blue
                                          : Colors.red,
                                      size: 30,
                                    ),
                                    label: Text(
                                      _image == null
                                          ? 'Choose image'
                                          : 'Remove image',
                                      style: GoogleFonts.outfit(
                                          fontSize: 15, color: Colors.black),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              child: SwitchListTile(
                                title: Text(
                                  'Is Private Report',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                  ),
                                ),
                                value: isReportPrivate,
                                onChanged: (bool newValue) {
                                  setState(() {
                                    isReportPrivate = newValue;
                                  });
                                },
                                activeColor:
                                    const Color.fromARGB(255, 10, 187, 166),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                controlAffinity: ListTileControlAffinity
                                    .trailing, // Coloque o controle na extremidade direita
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (_image != null) {
                                    var result = await createAndSendDiseaseReport(_image);
                                    if (result['success']) {
                                      _showSuccessDialog(context, result['message']);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(result['message'])),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Please select an image.")),
                                    );
                                  }
                                },

                                // Configurações do botão
                                icon: const Icon(Icons.add_circle_sharp, size: 25),
                                label: Text('Create', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.normal)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 10, 187, 166),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  minimumSize: const Size(double.infinity, 54),
                                  padding: const EdgeInsets.all(0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),


                          ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
