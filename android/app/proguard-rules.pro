# flutter_local_notifications persists scheduled reminders (so they survive
# reboot) by serializing them with Gson, using `new TypeToken<List<...>>(){}`
# to capture the generic type at runtime. R8 strips generic signatures by
# default, which breaks that TypeToken lookup and makes every scheduled
# notification throw instead of firing — these rules keep what Gson needs.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**
