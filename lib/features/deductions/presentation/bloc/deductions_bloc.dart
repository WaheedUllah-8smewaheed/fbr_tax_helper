import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 

part 'deductions_event.dart';
part 'deductions_state.dart';

class DeductionsBloc extends Bloc<DeductionsEvent, DeductionsState> {
  DeductionsBloc() : super(const DeductionsState()) {
    on<ParseTaxCertificate>(_onParseTaxCertificate);
    on<SaveDeductions>(_onSaveDeductions);
  }

  Future<void> _onParseTaxCertificate(
    ParseTaxCertificate event,
    Emitter<DeductionsState> emit,
  ) async {
    emit(state.copyWith(status: DeductionsStatus.parsing));
    try {
      String? text;
      if (event.isPdf) {
        text = await _parsePdf();
      } else if (event.imageSource != null) {
        text = await _parseImage(event.imageSource!);
      }

      if (text != null) {
        final taxAmount = _findTaxAmount(text);
        if (taxAmount != null) {
          emit(
            state.copyWith(
              status: DeductionsStatus.parsed,
              mobileTax: taxAmount,
              message: 'Tax amount found!',
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: DeductionsStatus.failure,
              message:
                  'Could not automatically find tax amount. Please enter it manually.',
            ),
          );
        }
      } else {
        // No file picked or permission denied, revert to initial state
        emit(state.copyWith(status: DeductionsStatus.initial));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: DeductionsStatus.failure,
          message: 'An error occurred during parsing.',
        ),
      );
    }
  }

  void _onSaveDeductions(SaveDeductions event, Emitter<DeductionsState> emit) {
    // In a real app, you would save this to a repository.
    // For now, we just emit a success state with a message.
    final mobileTax = double.tryParse(event.mobileTax) ?? 0.0;
    final electricityTax = double.tryParse(event.electricityTax) ?? 0.0;
    final internetTax = double.tryParse(event.internetTax) ?? 0.0;
    final vehicleTax = double.tryParse(event.vehicleTax) ?? 0.0;

    final message =
        'Saved! Mobile: $mobileTax, Electricity: $electricityTax, Internet: $internetTax, Vehicle: $vehicleTax';

    emit(state.copyWith(status: DeductionsStatus.success, message: message));
  }

  Future<String?> _parseImage(ImageSource source) async {
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      final image = await ImagePicker().pickImage(source: source);
      if (image != null) {
        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        );
        final recognizedText = await textRecognizer.processImage(inputImage);
        textRecognizer.close();
        return recognizedText.text;
      }
    }
    return null;
  }

  Future<String?> _parsePdf() async {
    final storagePermission = await Permission.storage.request();
    if (storagePermission.isGranted || storagePermission.isLimited) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(document).extractText();
        document.dispose();
        return text;
      }
    }
    return null;
  }

  String? _findTaxAmount(String text) {
    final lines = text.toLowerCase().split('\n');
    final taxLine = lines.firstWhere(
      (line) => line.contains('tax'),
      orElse: () => '',
    );

    if (taxLine.isNotEmpty) {
      final RegExp numRegExp = RegExp(
        r'(\d{1,3}(,\d{3})*(\.\d+)?|\d+(\.\d+)?)',
      );
      final Match? match = numRegExp.firstMatch(taxLine);
      return match?.group(0)?.replaceAll(',', '');
    }
    return null;
  }
}
