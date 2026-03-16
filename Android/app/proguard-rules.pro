-keeppackagenames **
-keep class skip.** { *; }
-keep class tools.skip.** { *; }
-keep class kotlin.jvm.functions.** {*;}
-keep class com.sun.jna.** { *; }
-dontwarn java.awt.**
-keep class * implements com.sun.jna.** { *; }
-keep class * implements skip.bridge.** { *; }
-keep class **._ModuleBundleAccessor_* { *; }
-keep class orthodox.korea.** { *; }

# OneSignal SDK protection
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# OneSignal dependencies (OpenTelemetry / Jackson)
-dontwarn com.fasterxml.jackson.**
-dontwarn io.opentelemetry.**
