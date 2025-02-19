import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/accessability/presentation/widgets/homepageWidgets/category_item.dart';

class Topwidgets extends StatefulWidget {
  final Function(bool) onOverlayChange;
  final Function(String) onCategorySelected;
  final GlobalKey inboxKey;
  final GlobalKey settingsKey;
  final Function(String) onSpaceSelected;

  const Topwidgets({
    super.key,
    required this.onCategorySelected,
    required this.onOverlayChange,
    required this.inboxKey,
    required this.settingsKey,
    required this.onSpaceSelected,
  });

  @override
  _TopwidgetsState createState() => _TopwidgetsState();
}

class _TopwidgetsState extends State<Topwidgets> {
  bool _isDropdownOpen = false;
  List<Map<String, dynamic>> _spaces = []; // List of spaces
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _activeSpaceId = ''; // ID of the active space
  String _activeSpaceName = 'Create Space'; // Name of the active space

  @override
  void initState() {
    super.initState();
    _fetchSpaces();
  }

  // Fetch spaces from Firestore
  Future<void> _fetchSpaces() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('Spaces')
        .where('members', arrayContains: user.uid)
        .get();

    setState(() {
      _spaces = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
          'creator': doc['creator'],
        };
      }).toList();
    });
  }

  // When a space is selected, update the active space
  void _selectSpace(String spaceId, String spaceName) {
    widget.onSpaceSelected(spaceId); // Notify parent about the selected space
    setState(() {
      _activeSpaceName = spaceName;
      _isDropdownOpen = false;
    });
  }

  // Create a new space
  Future<void> _createSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final spaceName = await _showCreateSpaceDialog();
    if (spaceName == null || spaceName.isEmpty) return;

    // Generate a random verification code
    final verificationCode = _generateVerificationCode();

    await _firestore.collection('Spaces').add({
      'name': spaceName,
      'creator': user.uid,
      'members': [user.uid],
      'verificationCode': verificationCode,
      'createdAt': DateTime.now(),
    });

    _fetchSpaces(); // Refresh the list of spaces
  }

  // Generate a random 6-digit verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Show a dialog to create a space
  Future<String?> _showCreateSpaceDialog() async {
    String? spaceName;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Space'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Space Name'),
            onChanged: (value) => spaceName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    return spaceName;
  }

  // Join a space using a verification code
  Future<void> _joinSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final verificationCode = await _showJoinSpaceDialog();
    if (verificationCode == null || verificationCode.isEmpty) return;

    final snapshot = await _firestore
        .collection('Spaces')
        .where('verificationCode', isEqualTo: verificationCode)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final spaceId = snapshot.docs.first.id;
      await _firestore.collection('Spaces').doc(spaceId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      _fetchSpaces(); // Refresh the list of spaces
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification code')),
      );
    }
  }

  // Show a dialog to join a space
  Future<String?> _showJoinSpaceDialog() async {
    String? verificationCode;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join Space'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Verification Code'),
            onChanged: (value) => verificationCode = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    return verificationCode;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(top: 15.0, left: 20.0, right: 20.0),
          color: Colors.transparent,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Settings button
                  GestureDetector(
                    key: widget.settingsKey,
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.settings, color: Color(0xFF6750A4)),
                    ),
                  ),
                  // My Space Dropdown Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDropdownOpen = !_isDropdownOpen;
                      });
                      widget.onOverlayChange(_isDropdownOpen);
                    },
                    child: Container(
                      width: 175,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              _activeSpaceName.length > 8
                                  ? '${_activeSpaceName.substring(0, 8)}...'
                                  : _activeSpaceName,
                              style: const TextStyle(
                                color: Color(0xFF6750A4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: Icon(
                              _isDropdownOpen
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Inbox button
                  GestureDetector(
                    key: widget.inboxKey,
                    onTap: () {
                      Navigator.pushNamed(context, '/inbox');
                    },
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.chat, color: Color(0xFF6750A4)),
                    ),
                  ),
                ],
              ),
              // Dropdown Content
              if (_isDropdownOpen)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Create Space +'),
                        trailing: const Icon(Icons.add),
                        onTap: _createSpace,
                      ),
                      ListTile(
                        title: const Text('Join Space'),
                        trailing: const Icon(Icons.group_add),
                        onTap: _joinSpace,
                      ),
                      ..._spaces.map((space) {
                        return ListTile(
                          title: Text(space['name']),
                          onTap: () => _selectSpace(space['id'],
                              space['name']), // Update active space
                        );
                      }).toList(),
                    ],
                  ),
                ),
              // Horizontally Scrollable List of Categories
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      CategoryItem(
                        title: 'Hotel',
                        icon: Icons.hotel,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Restaurant',
                        icon: Icons.restaurant,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Bus',
                        icon: Icons.directions_bus,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Shopping',
                        icon: Icons.shop_2,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                      CategoryItem(
                        title: 'Groceries',
                        icon: Icons.shopping_cart,
                        onCategorySelected: widget.onCategorySelected,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
