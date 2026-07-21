# The OCR feature uses ML Kit's bundled Latin recognizer only. The Flutter
# plugin can optionally initialize these language-specific modules, but they
# are intentionally not packaged in this application.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
