import 'dart:io';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  // Check if device has internet connection
  Future<bool> hasInternet() async {
    return await InternetConnection().hasInternetAccess;
  }

  // Show popup when no internet
  void showNoInternetDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 10),
            Text('No Internet Connection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please connect to the internet to use this app.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              '🔹 Turn on Mobile Data\n🔹 Connect to a WiFi network',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Check again
              bool connected = await hasInternet();
              if (!connected) {
                // If still no internet, show again
                showNoInternetDialog(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Check internet and show popup if needed
  Future<bool> checkAndShowDialog(BuildContext context) async {
    bool hasConnection = await hasInternet();
    if (!hasConnection) {
      showNoInternetDialog(context);
      return false;
    }
    return true;
  }
}