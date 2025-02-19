import 'package:flutter/material.dart';

class UploadProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String profile;
  final String phoneNumber;
  const UploadProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.profile,
    required this.phoneNumber,
  });

  @override
  State<UploadProfileScreen> createState() => _UploadPictureScreenState();
}

class _UploadPictureScreenState extends State<UploadProfileScreen> {
  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.08),
                      Text(
                        'ACCESSABILITY',
                        style: TextStyle(
                          color: const Color(0xFF6750A4),
                          fontSize: screenHeight *
                              0.035, // Larger font size for accessibility
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.25),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: Text(
                          'Please upload your profile picture.',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize:
                                screenHeight * 0.02, // Slightly larger text
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      _buildProfilePicture(screenHeight),
                      SizedBox(height: screenHeight * 0.03),
                      SizedBox(
                        width: screenWidth * 0.8,
                        height: screenHeight * 0.07,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6750A4),
                          ),
                          onPressed: () {},
                          child: const Text(
                            'Upload Picture',
                            style: TextStyle(
                              color: Colors.white, // Use Colors.white directly
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w600, // Improved font weight
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight:
                          FontWeight.w500, // Font weight for better readability
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Finish',
                    style: TextStyle(
                      color: Colors.white, // Use Colors.white directly

                      fontSize: 18,
                      fontWeight: FontWeight.w600, // Improved font weight
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture(double screenHeight) {
    return Container(
      width: screenHeight * 0.18,
      height: screenHeight * 0.18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF6750A4), // Updated color
      ),
      child: Icon(
        Icons.person,
        size: screenHeight * 0.1,
        color: Colors.white, // Set the icon color to white for visibility
      ),
    );
  }
}
