# Keep kotlinx.serialization generated serializers.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class com.qubiccli.app.**$$serializer { *; }
-keepclassmembers class com.qubiccli.app.** {
    *** Companion;
}
-keepclasseswithmembers class com.qubiccli.app.** {
    kotlinx.serialization.KSerializer serializer(...);
}
