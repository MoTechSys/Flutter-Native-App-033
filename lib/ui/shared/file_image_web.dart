// تنفيذ الويب: لا نظام ملفات — نعرض الغلاف الاحتياطي
import 'package:flutter/material.dart';

Widget fileImage(String path, {BoxFit fit = BoxFit.cover, required ImageErrorWidgetBuilder onError}) =>
    Builder(builder: (c) => onError(c, 'no fs on web', null));
