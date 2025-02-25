import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/accessability/logic/bloc/user/user_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';
import 'package:frontend/accessability/presentation/widgets/accessability_footer.dart';
import 'package:frontend/accessability/presentation/widgets/bottomSheetWidgets/favorite_widget.dart';
import 'package:frontend/accessability/presentation/widgets/bottomSheetWidgets/safety_assist_widget.dart';
import 'package:frontend/accessability/presentation/widgets/homepageWidgets/bottom_widgets.dart';
import 'package:frontend/accessability/presentation/widgets/homepagewidgets/top_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  _GpsScreenState createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  OverlayEntry? _overlayEntry;
  GoogleMapController? _mapController;
  final Location _location = Location();
  LatLng? _currentLocation;
  String _activeSpaceId = '';
  StreamSubscription? _locationUpdatesSubscription;
  LocationData? _lastLocation;
  Set<Marker> _markers = {};
  GlobalKey inboxKey = GlobalKey();
  GlobalKey settingsKey = GlobalKey();
  GlobalKey youKey = GlobalKey();
  GlobalKey locationKey = GlobalKey();
  GlobalKey securityKey = GlobalKey();
  final String _apiKey = dotenv.env["GOOGLE_API_KEY"] ?? '';
  Set<Circle> _circles = {};
  bool _isNavigating = false;
  int _currentIndex = 0; // Track the current index of the BottomNavigationBar
  bool _showBottomWidgets = false; // Track whether to show BottomWidgets
  String? _selectedUserId; // Track the selected user ID

  final List<Map<String, dynamic>> pwdFriendlyLocations = [
    {
      "name": "Dagupan City Hall",
      "latitude": 16.04361106008402,
      "longitude": 120.33531522527143,
      "details":
          "Wheelchair ramps, accessible restrooms, and reserved parking.",
    },
    {
      "name": "Nepo Mall Dagupan",
      "latitude": 16.051224004022384,
      "longitude": 120.34170650545146,
      "details": "Elevators, ramps, and PWD-friendly restrooms.",
    },
    {
      "name": "Dagupan Public Market",
      "latitude": 16.043166316470707,
      "longitude": 120.33608116388851,
      "details": "Wheelchair-friendly pathways and accessible stalls.",
    },
    {
      "name": "PHINMA University of Pangasinan",
      "latitude": 16.047254394614715,
      "longitude": 120.34250043932526,
      "details": "Wheelchair accessible entrances and parking lots."
    }
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();

    // Add PWD-friendly markers
    _createMarkers().then((markers) {
      setState(() {
        _markers.addAll(markers);
      });
    });


@override
void didChangeDependencies() {
  super.didChangeDependencies();
  print('GPS Screen didChangeDependencies called');
}

@override
void didUpdateWidget(GpsScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  print('GPS Screen didUpdateWidget called');
}

   @override
void dispose() {
  _locationUpdatesSubscription?.cancel(); // Cancel location updates
  super.dispose();
}

    // Check if onboarding is completed before showing the tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authBloc = context.read<AuthBloc>();
      final hasCompletedOnboarding = authBloc.state is AuthenticatedLogin
          ? (authBloc.state as AuthenticatedLogin).hasCompletedOnboarding
          : false;

      if (!hasCompletedOnboarding) {
        _showTutorial();
      }
    });
  }

  void _navigateToSettings() {
    print("Navigating to settings...");

    if (_isNavigating) return; // Prevent duplicate navigation
    _isNavigating = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/settings').then((_) {
        print("Returned from settings.");
        _isNavigating = false; // Re-enable navigation after the route is popped
      });
    });
  }

  // Update user location in Firestore
  Future<void> _updateUserLocation(LatLng location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('UserLocations')
        .doc(user.uid)
        .set({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timestamp': DateTime.now(),
    });
  }

  // Listen for real-time location updates from other users in the space
  void _listenForLocationUpdates() {
  if (_activeSpaceId.isEmpty) {
    print("⚠️ Active space ID is empty. Cannot listen for location updates.");
    return;
  }

  _locationUpdatesSubscription?.cancel(); // Cancel existing listener
  _locationUpdatesSubscription =
      _getSpaceMembersLocations(_activeSpaceId).listen((snapshot) async {
    final updatedMarkers = <Marker>{};

    // Preserve existing PWD-friendly and nearby places markers
    final existingMarkers = _markers
        .where((marker) => !marker.markerId.value.startsWith('user_'));

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['latitude'];
      final lng = data['longitude'];
      final userId = doc.id;

      // Fetch the user's profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      final username = userDoc['username'];
      final profilePictureUrl = userDoc.data()?['profilePicture'] ?? ''; // Handle missing field

      print("🟢 Fetched user data for $username: $profilePictureUrl");

      // Determine if this marker is selected
      final isSelected = userId == _selectedUserId;

      // Create a custom marker icon with the profile picture
      BitmapDescriptor customIcon;
      if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        try {
          customIcon = await _createCustomMarkerIcon(profilePictureUrl, isSelected: isSelected);
        } catch (e) {
          print("❌ Error creating custom marker for $username: $e");
          customIcon = await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(24, 24)),
            'assets/images/others/default_profile.png',
          );
        }
      } else {
        // Use a default icon if no profile picture is available
        customIcon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(24, 24)),
          'assets/images/others/default_profile.png',
        );
      }

      // Add the custom marker
      updatedMarkers.add(
  Marker(
    markerId: MarkerId('user_$userId'),
    position: LatLng(lat, lng),
    infoWindow: InfoWindow(title: username),
    icon: customIcon,
    onTap: () => _onMarkerTapped(MarkerId('user_$userId')),
  ),
);
}

    print("🟢 Updated ${updatedMarkers.length} user markers.");
    setState(() {
      _markers = existingMarkers.toSet().union(updatedMarkers);
    });
  });
}

void _onMarkerTapped(MarkerId markerId) {
  if (markerId.value.startsWith('pwd_')) {
    // Handle PWD-friendly location marker tap
    final location = pwdFriendlyLocations.firstWhere(
      (loc) => loc["name"] == markerId.value.replaceFirst('pwd_', ''),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(location["name"]),
          content: Text(location["details"]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  } else if (markerId.value.startsWith('user_')) {
    // Handle user marker tap
    final userId = markerId.value.replaceFirst('user_', ''); // Extract user ID from marker ID
    setState(() {
      _selectedUserId = userId; // Update the selected user ID
    });
    _listenForLocationUpdates(); // Refresh markers to update the selected state
  }
}

  // Fetch real-time location updates for members in the active space
  Stream<QuerySnapshot> _getSpaceMembersLocations(String spaceId) {
    if (spaceId.isEmpty) {
      return const Stream.empty(); // Return an empty stream if spaceId is empty
    }

    return FirebaseFirestore.instance
        .collection('Spaces')
        .doc(spaceId)
        .snapshots()
        .asyncMap((spaceSnapshot) async {
      final members = List<String>.from(spaceSnapshot['members']);
      return FirebaseFirestore.instance
          .collection('UserLocations')
          .where(FieldPath.documentId, whereIn: members)
          .snapshots();
    }).asyncExpand((event) => event);
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(String imageUrl, {bool isSelected = false}) async {
  print("🟢 Creating custom marker icon for: $imageUrl (isSelected: $isSelected)");

  try {
    // Fetch the profile picture
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      print("❌ Failed to load image: ${response.statusCode}");
      throw Exception('Failed to load image');
    }

    // Decode the profile picture
    final profileBytes = response.bodyBytes;
    final profileCodec = await ui.instantiateImageCodec(profileBytes);
    final profileFrame = await profileCodec.getNextFrame();
    final profileImage = profileFrame.image;

    // Load the appropriate marker shape asset
    final markerShapeAsset = isSelected
        ? 'assets/images/others/marker_shape_selected.png'
        : 'assets/images/others/marker_shape.png';
    final markerShapeBytes = await rootBundle.load(markerShapeAsset);
    final markerShapeCodec = await ui.instantiateImageCodec(markerShapeBytes.buffer.asUint8List());
    final markerShapeFrame = await markerShapeCodec.getNextFrame();
    final markerShapeImage = markerShapeFrame.image;

    // Create a canvas to draw the combined image
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Define the size of the marker
    final markerWidth = markerShapeImage.width.toDouble();
    final markerHeight = markerShapeImage.height.toDouble();

    // Draw the marker shape
    canvas.drawImage(markerShapeImage, Offset.zero, Paint());

    // Draw the profile picture inside the marker shape
    final profileSize = 100.0; // Adjust the size of the profile picture
    final profileOffset = Offset(
      (markerWidth - profileSize) / 1.8, // Center horizontally
      11, // Adjust vertical position
    );

    // Clip the profile picture to a circle
    final clipPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(profileOffset.dx + profileSize / 2, profileOffset.dy + profileSize / 2),
        radius: profileSize / 2,
      ));
    canvas.clipPath(clipPath);

    // Draw the profile picture
    canvas.drawImageRect(
      profileImage,
      Rect.fromLTWH(0, 0, profileImage.width.toDouble(), profileImage.height.toDouble()),
      Rect.fromLTWH(profileOffset.dx, profileOffset.dy, profileSize, profileSize),
      Paint(),
    );

    // Convert the canvas to an image
    final picture = pictureRecorder.endRecording();
    final imageMarker = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
    final byteData = await imageMarker.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      print("❌ Failed to convert image to bytes");
      throw Exception('Failed to convert image to bytes');
    }

    // Create the custom marker icon
    print("🟢 Custom marker icon created successfully");
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  } catch (e) {
    print("❌ Error creating custom marker icon: $e");
    throw Exception('Failed to create custom marker icon: $e');
  }
}

  Future<bool> _onWillPop() async {
    // Show confirmation dialog
    return await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm Exit'),
              content: const Text('Do you really want to exit?'),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(false), // Do not exit
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true), // Exit
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        ) ??
        false; // Return false if dialog is dismissed
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<BitmapDescriptor> _getCustomIcon() async {
    return await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(
          size: Size(24, 24)), // Match the resized image dimensions
      'assets/images/others/accessabilitylogo.png',
    );
  }

  Future<Set<Marker>> _createMarkers() async {
  final customIcon = await _getCustomIcon();
  return pwdFriendlyLocations.map((location) {
    return Marker(
      markerId: MarkerId("pwd_${location["name"]}"), // Add prefix for PWD-friendly markers
      position: LatLng(location["latitude"], location["longitude"]),
      infoWindow: InfoWindow(
        title: location["name"],
        snippet: location["details"],
      ),
      icon: customIcon,
      onTap: () => _onMarkerTapped(MarkerId("pwd_${location["name"]}")),
    );
  }).toSet();
}



  Set<Polygon> _createPolygons() {
    final Set<Polygon> polygons = {};

    for (var location in pwdFriendlyLocations) {
      final LatLng center = LatLng(location["latitude"], location["longitude"]);

      // Create a small circular area around the location
      final List<LatLng> points = [];
      for (double angle = 0; angle <= 360; angle += 10) {
        final double radians = angle * (3.141592653589793 / 180);
        final double latOffset = 0.0005 * cos(radians); // Adjust for size
        final double lngOffset = 0.0005 * sin(radians); // Adjust for size
        points.add(
            LatLng(center.latitude + latOffset, center.longitude + lngOffset));
      }

      polygons.add(
        Polygon(
          polygonId: PolygonId(location["name"]),
          points: points,
          strokeColor: Colors.green,
          fillColor: Colors.green.withOpacity(0.2),
          strokeWidth: 2,
        ),
      );
    }

    return polygons;
  }

  Future<void> _fetchNearbyPlaces(String placeType) async {
    if (_currentLocation == null) {
      print("🚨 Current position is null, cannot fetch nearby places.");
      return;
    }

    String type;
    Color color;
    String iconPath;

    switch (placeType) {
      case 'Hotel':
        type = 'hotels';
        color = Colors.pink;
        iconPath = 'assets/images/others/hotel.png';
        break;
      case 'Restaurant':
        type = 'restaurant';
        color = Colors.blue;
        iconPath = 'assets/images/others/restaurant.png';
        break;
      case 'Bus':
        type = 'bus_station';
        color = Colors.blue;
        iconPath = 'assets/images/others/bus-school.png';
        break;
      case 'Shopping':
        type = 'shopping_mall';
        color = Colors.yellow;
        iconPath = 'assets/images/others/shopping-mall.png';
        break;
      case 'Groceries':
        type = 'grocery_or_supermarket';
        color = Colors.orange;
        iconPath = 'assets/images/others/grocery.png';
        break;
      default:
        print("⚠️ Selected category is not recognized.");
        return;
    }

    final String url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
        "location=${_currentLocation!.latitude},${_currentLocation!.longitude}"
        "&radius=1500&type=$type&key=$_apiKey"; // Use the appropriate type

    print("🔵 Fetching nearby $placeType: $url");

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("🟢 API Response: ${data.toString()}");

      final List<dynamic> places = data["results"];

      final Set<Marker> nearbyMarkers = {};
      final Set<Circle> nearbyCircles = {};

      for (var place in places) {
        final lat = place["geometry"]["location"]["lat"];
        final lng = place["geometry"]["location"]["lng"];
        final name = place["name"];
        LatLng position = LatLng(lat, lng);

        // Add Marker with custom icon
        BitmapDescriptor icon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(24, 24)),
          iconPath,
        );

        // Add Marker
        nearbyMarkers.add(
          Marker(
            markerId: MarkerId(name),
            position: position,
            infoWindow: InfoWindow(title: name),
            icon: icon,
          ),
        );

        // Add Circle with custom color
        nearbyCircles.add(
          Circle(
            circleId: CircleId(name),
            center: position,
            radius: 30, // Adjust size as needed
            strokeWidth: 2,
            strokeColor: color, // Custom stroke color
            fillColor: color.withOpacity(0.5), // Transparent effect
          ),
        );

        print("📍 Added Marker & Circle for: $name at ($lat, $lng)");
      }

      // Preserve existing PWD markers
      final Set<Marker> allMarkers = {};
      allMarkers.addAll(
          _markers.where((marker) => marker.markerId.value.startsWith("pwd_")));
      allMarkers.addAll(nearbyMarkers);

      setState(() {
        _markers.clear();
        _markers.addAll(allMarkers);
        _circles.clear();
        _circles.addAll(nearbyCircles);
      });

      // Adjust the camera to fit all markers
      if (_mapController != null && allMarkers.isNotEmpty) {
        final bounds = _getLatLngBounds(
            allMarkers.map((marker) => marker.position).toList());
        _mapController!
            .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
        print("🎯 Adjusted camera to fit ${allMarkers.length} markers.");
      } else {
        print("⚠️ No bounds to adjust camera.");
      }
    } else {
      print("❌ HTTP Request Failed: ${response.statusCode}");
    }
  }

// Helper function to calculate bounds
  LatLngBounds _getLatLngBounds(List<LatLng> locations) {
    double south = locations.first.latitude;
    double north = locations.first.latitude;
    double west = locations.first.longitude;
    double east = locations.first.longitude;

    for (var loc in locations) {
      if (loc.latitude < south) south = loc.latitude;
      if (loc.latitude > north) north = loc.latitude;
      if (loc.longitude < west) west = loc.longitude;
      if (loc.longitude > east) east = loc.longitude;
    }

    print("📌 Camera Bounds: SW($south, $west) - NE($north, $east)");

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _showTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      List<TargetFocus> targets = [];
      targets.add(TargetFocus(
        identify: "inboxTarget",
        keyTarget: inboxKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Container(
              color: Colors.transparent, // Set a background color
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is your inbox.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: Colors.white),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view your messages.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ));

      targets.add(TargetFocus(
        identify: "settingsTarget",
        keyTarget: settingsKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Container(
              color: Colors.transparent, // Set a background color
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the settings button.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: Colors.white),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to access settings.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ));

      targets.add(TargetFocus(
        identify: "locationTarget",
        keyTarget: locationKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the location button.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: Colors.white),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view your location.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ));

      targets.add(TargetFocus(
        identify: "youTarget",
        keyTarget: youKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the 'You' button.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: Colors.white),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view your profile.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ));

      // Security Target
      targets.add(TargetFocus(
        identify: "securityTarget",
        keyTarget: securityKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the security button.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: Colors.white),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view security settings.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ));

      TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        textSkip: "SKIP",
        paddingFocus: 10,
        opacityShadow: 0.8,
        onFinish: () {
          print("Tutorial finished");
        },
        onClickTarget: (target) {
          print('Clicked on target: $target');
        },
        onSkip: () {
          print("Tutorial skipped");
          return true; // Return a boolean value
        },
      ).show(context: context);
    });
  }

  // Get user location and update it in Firestore
  Future<void> _getUserLocation() async {
  bool serviceEnabled;
  PermissionStatus permissionGranted;

  // Check if GPS is enabled
  serviceEnabled = await _location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await _location.requestService();
    if (!serviceEnabled) return;
  }

  // Check for permissions
  permissionGranted = await _location.hasPermission();
  if (permissionGranted == PermissionStatus.denied) {
    permissionGranted = await _location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) return;
  }

  // Get location
  _location.onLocationChanged.listen((LocationData locationData) {

    final newLocation = LatLng(locationData.latitude!, locationData.longitude!);

    // Only update if the location has changed significantly
    if (_lastLocation == null ||
        _lastLocation!.latitude != locationData.latitude ||
        _lastLocation!.longitude != locationData.longitude) {
      setState(() {
        _currentLocation = newLocation;
      });

      // Update the user's location in Firestore
      _updateUserLocation(newLocation);
      _lastLocation = locationData; // Store LocationData directly
    }
  });
}

  // Update the active space ID
  void _updateActiveSpaceId(String spaceId) {
    if (spaceId.isEmpty) {
      print("⚠️ Cannot update active space ID: spaceId is empty.");
      return;
    }

    setState(() {
      _activeSpaceId = spaceId;
    });

    // Start listening for location updates for the new space
    _listenForLocationUpdates();
  }

@override
Widget build(BuildContext context) {
  return BlocBuilder<UserBloc, UserState>(
    builder: (context, userState) {
      print('BlocBuilder triggered with state: $userState');
      if (userState is UserLoading) {
        print('Userstate is : ${userState}');
        return Center(child: CircularProgressIndicator());
      } else if (userState is UserError) {
        print('Userstate is : ${userState}');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${userState.message}'),
              ElevatedButton(
                onPressed: () {
                  context.read<UserBloc>().add(FetchUserData()); // Retry
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      } else if (userState is UserLoaded) {
        print('Userstate is : ${userState}');
        final user = userState.user;
        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            body: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? const LatLng(16.0430, 120.3333),
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _markers,
                  onMapCreated: _onMapCreated,
                  polygons: _createPolygons(),
                ),
                Topwidgets(
                  inboxKey: inboxKey,
                  settingsKey: settingsKey,
                  onCategorySelected: (selectedType) {
                    _fetchNearbyPlaces(selectedType);
                  },
                  onOverlayChange: (isVisible) {
                    setState(() {
                      if (isVisible) {}
                    });
                  },
                  onSpaceSelected: _updateActiveSpaceId,
                ),
                if (_currentIndex == 0)
                  BottomWidgets(
                    key: ValueKey(_activeSpaceId),
                    scrollController: ScrollController(),
                    activeSpaceId: _activeSpaceId,
                  ),
                if (_currentIndex == 1) const FavoriteWidget(),
                if (_currentIndex == 2) const SafetyAssistWidget(),
              ],
            ),
            bottomNavigationBar: Accessabilityfooter(
              securityKey: securityKey,
              locationKey: locationKey,
              youKey: youKey,
              onOverlayChange: (isVisible) {
                setState(() {});
              },
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        );
      } else {
        print('Userstate is : ${userState}');
        return const Center(child: Text('No user data available'));
      }
    },
  );
}
}

enum OverlayPosition { top, bottom }