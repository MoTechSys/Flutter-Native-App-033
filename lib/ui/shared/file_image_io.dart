// تنفيذ الجوال/سطح المكتب: صورة من ملف على الجهاز
import 'dart:io';
import 'package:flutter/material.dart';

Widget fileImage(String path, {BoxFit fit = BoxFit.cover, required ImageErrorWidgetBuilder onError}) =>
    Image.file(File(path), fit: fit, errorBuilder: onError);
