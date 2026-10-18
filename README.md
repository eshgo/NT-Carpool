# NT Carpool App

This is a carpool coordination app that implements a privacy-first approach to ride sharing.

## Features Implemented

1. **User Onboarding**
   - Name entry
   - Default destination setup
   - Group joining/creation

2. **User Management**
   - Local profile storage with Keychain
   - Driver/Passenger mode toggle
   - Group membership management

3. **Ride Request System**
   - Passenger can request rides
   - Driver can receive notifications
   - Request cancellation

4. **Privacy Features**
   - Location data only used for time calculation
   - No persistent storage of coordinates
   - No sharing of addresses between users

## Architecture

The app follows a client-server model with Firebase backend:

### Client (iOS)
- SwiftUI for UI
- CoreLocation for location services
- MapKit for route calculations
- Keychain for secure user data storage
- Firebase SDK for backend integration

### Backend (Firebase)
- Firestore for data storage
- Cloud Functions for server-side logic
- Firebase Messaging for push notifications

### Data Models
- `User`: Represents a carpool user with name, mode, and groups
- `Group`: Represents a carpool group with name and code
- `GroupMember`: Links users to groups
- `RideRequest`: Represents a ride request with pickup/destination
- `Location`: Wrapper for coordinate data with address

### Services
- `LocationService`: Handles location acquisition and permissions
- `RouteCalculationService`: Calculates detour times using MapKit
- `DataManager`: Manages data synchronization with Firestore
- `PushManager`: Handles push notifications and FCM tokens

### Views
- `OnboardingView`: Initial setup flow
- `HomeView`: Main app interface
- `GroupSelectionView`: Group management
- `ProfileView`: User profile management

## Implementation Notes

### Location Permissions
The app requests "Always" location permissions with clear explanation:
> "Allow 'Always' so we can compute driving time for matching. We never share your address or location with other users."

### Data Storage
- User profiles stored in Keychain for security
- Group and request data synchronized with Firestore
- No coordinates persisted beyond calculation time

### Driver Matching Algorithm
The greedy insertion algorithm is designed to:
1. Build current route stops
2. Try all valid insert positions for new pickups/drop-offs
3. Choose the insertion with minimum extra time
4. Return only the scalar minutes value to backend

### Firebase Integration
- Users, groups, and ride requests stored in Firestore
- Cloud Functions handle ride acceptance and driver notifications
- Firebase Messaging delivers push notifications to drivers
