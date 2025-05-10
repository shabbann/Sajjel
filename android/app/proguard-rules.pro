# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Flutter embedding
-keep class androidx.lifecycle.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.view.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }

# SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Don't obfuscate model classes
-keep class com.sajjel.app.models.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# For Kotlin coroutine support
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.SerializationKt
-keep,includedescriptorclasses class com.sajjel.app.**$$serializer { *; }
-keepclassmembers class com.sajjel.app.** {
    *** Companion;
}
-keepclasseswithmembers class com.sajjel.app.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Android specific
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Android Window Extensions for latest Android versions
-keep class androidx.window.** { *; }

# Prevent R8 from stripping interface information
-keep class androidx.window.extensions.** { *; }
-keep class androidx.window.extensions.embedding.** { *; }

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Keep the Google Play core library classes and interfaces
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# For native methods, see http://proguard.sourceforge.net/manual/examples.html#native
-keepclasseswithmembernames class * {
    native <methods>;
}

# Prevent obfuscation of types which use @JvmOverloads function parameters.
# This avoids crashes when using wrapped types and default arguments.
-keep class * {
    @kotlin.jvm.JvmOverloads <methods>;
}

# Keep constructor fields that are used by Kotlin constructors.
-keepclasseswithmembers class * {
    public <init>(kotlin.jvm.internal.DefaultConstructorMarker, ...);
}

# Keep all classes that might be loaded from getClassLoader()
-keep public class * {
    public <init>();
}

# Keep serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
} 