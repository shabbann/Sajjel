import 'package:flutter/material.dart';

class AppLockDialog extends StatefulWidget {
  @override
  _AppLockDialogState createState() => _AppLockDialogState();
}

class _AppLockDialogState extends State<AppLockDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isEnabled = false;
  bool _isConfirming = false;
  String _tempPassword = '';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEnabled ? 'Change App Lock' : 'Set Up App Lock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isConfirming)
            Text('Confirm your password',
                style: TextStyle(color: Colors.grey)),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_isEnabled && !_isConfirming) {
              // Verify existing password first
              if (_passwordController.text == '1234') { // Replace with secure storage check
                setState(() {
                  _isConfirming = true;
                  _tempPassword = '';
                  _passwordController.clear();
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Incorrect password')),
                );
              }
            } else if (_isConfirming) {
              if (_tempPassword.isEmpty) {
                setState(() {
                  _tempPassword = _passwordController.text;
                  _passwordController.clear();
                });
              } else if (_tempPassword == _passwordController.text) {
                // Save password to secure storage
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('App lock enabled')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Passwords do not match')),
                );
              }
            } else {
              setState(() {
                _isConfirming = true;
                _tempPassword = _passwordController.text;
                _passwordController.clear();
              });
            }
          },
          child: Text(_isConfirming ? 'Confirm' : 'Enable'),
        ),
      ],
    );
  }
}