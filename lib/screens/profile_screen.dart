import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isEmailVerified = false;
  File? _profileImage;
  String? _profileImageUrl;

  // Text Controllers
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _homeTownController = TextEditingController();
  final _countryController = TextEditingController();

  // Dropdown values
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedPartnerGender;

  // Multi-select values for interests
  List<String> _selectedInterests = [];

  // Interest options
  final List<String> _interestOptions = [
    'Traveling', 'Photography', 'Music', 'Movies', 'Cooking',
    'Sports', 'Reading', 'Gaming', 'Dancing', 'Art',
    'Fitness', 'Yoga', 'Coffee', 'Nature', 'Pets',
    'Technology', 'Fashion', 'Foodie', 'Adventure', 'Netflix'
  ];

  // Gender options
  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

  // Country options
  final List<String> _countryOptions = [
    'Sri Lanka',
    'India',
    'USA',
    'UK',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Italy',
    'Japan',
    'China',
    'Singapore',
    'Malaysia',
    'Thailand',
    'UAE',
    'South Korea',
    'Netherlands',
    'Sweden',
    'Norway',
    'Denmark',
    'Switzerland',
    'Brazil',
    'Mexico',
    'South Africa',
    'New Zealand',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkEmailVerification();
  }

  void _checkEmailVerification() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _isEmailVerified = user.emailVerified;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _homeTownController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  ImageProvider? _getProfileImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser!.uid;
      print('📂 Loading profile for user: $userId');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _homeTownController.text = data['homeTown'] ?? '';

        String savedCountry = data['country'] ?? '';
        if (_countryOptions.contains(savedCountry)) {
          _countryController.text = savedCountry;
        } else {
          _countryController.text = '';
        }

        _profileImageUrl = data['profileImageUrl'];
        print('📸 Loaded profile image URL: $_profileImageUrl');

        if (data['birthDate'] != null) {
          _selectedDate = (data['birthDate'] as Timestamp).toDate();
        }

        _selectedGender = data['gender'];
        _selectedPartnerGender = data['partnerGender'];

        if (data['interests'] != null) {
          _selectedInterests = List<String>.from(data['interests']);
        }
      } else {
        print('📂 No profile document found for user');
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_countryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your country'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser!.uid;

      print('📝 Saving profile for user: $userId');

      final profileData = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'homeTown': _homeTownController.text.trim(),
        'country': _countryController.text.trim(),
        'birthDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'gender': _selectedGender,
        'partnerGender': _selectedPartnerGender,
        'interests': _selectedInterests,
        'profileImageUrl': _profileImageUrl,
        'email': _auth.currentUser!.email,
        'emailVerified': _isEmailVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('📝 Saving to Firestore with image URL: ${profileData['profileImageUrl']}');

      await _firestore.collection('users').doc(userId).set(profileData, SetOptions(merge: true));

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      print('✅ Profile saved successfully');

    } catch (e) {
      print('❌ Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('My Profile'),
            const SizedBox(width: 8),
            if (_isEmailVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadUserProfile();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _getProfileImage(),
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    child: _profileImage == null && _profileImageUrl == null
                        ? Icon(
                      Icons.person,
                      size: 60,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    )
                        : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.pink,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          onPressed: () {
                            // Image picker disabled for now
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name
            _buildTextField(
              label: 'Full Name',
              icon: Icons.person,
              controller: _nameController,
              enabled: _isEditing,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Bio
            _buildTextField(
              label: 'Bio',
              icon: Icons.description,
              controller: _bioController,
              maxLines: 3,
              enabled: _isEditing,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Birth Date
            _buildDatePicker(theme, isDark),
            const SizedBox(height: 16),

            // Home Town and Country
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Home Town',
                    icon: Icons.location_city,
                    controller: _homeTownController,
                    enabled: _isEditing,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCountryDropdown(theme, isDark),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gender
            _buildDropdown(
              label: 'Gender',
              value: _selectedGender,
              items: _genderOptions,
              onChanged: _isEditing
                  ? (value) => setState(() => _selectedGender = value)
                  : null,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Looking for (Partner Gender)
            _buildDropdown(
              label: 'Interested in',
              value: _selectedPartnerGender,
              items: _genderOptions,
              onChanged: _isEditing
                  ? (value) => setState(() => _selectedPartnerGender = value)
                  : null,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Interests (Multi-select)
            _buildInterestsMultiSelect(isDark),
            const SizedBox(height: 24),

            // Save Button
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Text Field Builder with Theme Support
  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    bool enabled = true,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.pink.shade200 : Colors.pink,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.pink, width: 2),
        ),
        filled: true,
        fillColor: enabled
            ? (isDark ? Colors.grey.shade900 : Colors.white)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), // Fixed: shade850 -> shade800
      ),
    );
  }

  // Date Picker with Theme Support
  Widget _buildDatePicker(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: _isEditing ? () => _selectDate(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Birth Date',
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
          prefixIcon: Icon(
            Icons.cake,
            color: isDark ? Colors.pink.shade200 : Colors.pink,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabled: _isEditing,
          filled: true,
          fillColor: _isEditing
              ? (isDark ? Colors.grey.shade900 : Colors.white)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), // Fixed: shade850 -> shade800
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate != null
                  ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                  : 'Select your birth date',
              style: TextStyle(
                color: _selectedDate != null
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.grey.shade500 : Colors.grey),
              ),
            ),
            if (_isEditing)
              Icon(
                Icons.arrow_drop_down,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  // Dropdown with Theme Support
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
    required bool isDark,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
        ),
        prefixIcon: Icon(
          label == 'Gender' ? Icons.people : Icons.favorite,
          color: isDark ? Colors.pink.shade200 : Colors.pink,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabled: onChanged != null,
        filled: true,
        fillColor: onChanged != null
            ? (isDark ? Colors.grey.shade900 : Colors.white)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), // Fixed: shade850 -> shade800
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          onChanged: onChanged,
          dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          hint: Text(
            'Select $label',
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  // Country Dropdown with Theme Support
  Widget _buildCountryDropdown(ThemeData theme, bool isDark) {
    String? currentValue = _countryController.text.isNotEmpty
        && _countryOptions.contains(_countryController.text)
        ? _countryController.text
        : null;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Country',
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
        ),
        prefixIcon: Icon(
          Icons.public,
          color: isDark ? Colors.pink.shade200 : Colors.pink,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabled: _isEditing,
        filled: true,
        fillColor: _isEditing
            ? (isDark ? Colors.grey.shade900 : Colors.white)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), // Fixed: shade850 -> shade800
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isDense: true,
          isExpanded: true,
          onChanged: _isEditing ? (String? newValue) {
            setState(() {
              _countryController.text = newValue ?? '';
            });
          } : null,
          dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          items: _countryOptions.map((String country) {
            return DropdownMenuItem<String>(
              value: country,
              child: Text(country),
            );
          }).toList(),
          hint: const Text('Select Country'),
          selectedItemBuilder: (BuildContext context) {
            return _countryOptions.map((String country) {
              return Text(country);
            }).toList();
          },
        ),
      ),
    );
  }

  // Interests Multi-select with Theme Support
  Widget _buildInterestsMultiSelect(bool isDark) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Interests',
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
        ),
        prefixIcon: Icon(
          Icons.interests,
          color: isDark ? Colors.pink.shade200 : Colors.pink,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabled: _isEditing,
        filled: true,
        fillColor: _isEditing
            ? (isDark ? Colors.grey.shade900 : Colors.white)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), // Fixed: shade850 -> shade800
      ),
      child: _isEditing
          ? MultiSelectBottomSheetField(
        initialChildSize: 0.4,
        maxChildSize: 0.8,
        title: const Text('Select Interests'),
        buttonText: Text(
          _selectedInterests.isEmpty
              ? 'Select your interests'
              : '${_selectedInterests.length} selected',
          style: TextStyle(
            color: _selectedInterests.isEmpty
                ? (isDark ? Colors.grey.shade500 : Colors.grey)
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        items: _interestOptions.map((e) => MultiSelectItem(e, e)).toList(),
        listType: MultiSelectListType.CHIP,
        selectedColor: Colors.pink,
        onConfirm: (values) {
          setState(() {
            _selectedInterests = values.cast<String>();
          });
        },
        initialValue: _selectedInterests,
        chipDisplay: MultiSelectChipDisplay(
          chipColor: isDark ? Colors.pink.shade900 : Colors.pink.shade50,
          textStyle: TextStyle(
            color: isDark ? Colors.pink.shade200 : Colors.pink,
          ),
          onTap: (item) {
            setState(() {
              _selectedInterests.remove(item);
            });
          },
        ),
      )
          : Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _selectedInterests.isEmpty
            ? [
          Text(
            'No interests selected',
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey,
            ),
          )
        ]
            : _selectedInterests.map((interest) {
          return Chip(
            label: Text(interest),
            backgroundColor: isDark ? Colors.pink.shade900 : Colors.pink.shade50,
            labelStyle: TextStyle(
              color: isDark ? Colors.pink.shade200 : Colors.pink,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}