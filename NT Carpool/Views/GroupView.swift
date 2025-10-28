import SwiftUI

struct GroupView: View {
    @State var group: Group
    @State var currentUser: User
    @State private var members: [User] = []
    @State private var showGroupSelection = false
    
    private let firestoreService = FirestoreService()
    
    var body: some View {
        VStack {
            HStack {
                Text("Group Members")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            List(members) { member in
                HStack {
                    Text(member.name)
                    Spacer()
                    if member.isDriver {
                        Text("Driver")
                            .font(.caption)
                            .padding(6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
                .padding(.vertical, 2)
            }
            
            VStack(spacing: 15) {
                Toggle("Driver Mode", isOn: $currentUser.isDriver)
                    .onChange(of: currentUser.isDriver) { oldValue, newValue in
                        firestoreService.updateUser(user: currentUser)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                NavigationLink(destination: DestinationView(currentUser: $currentUser)) {
                    Text("Set Default Destination")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .onChange(of: currentUser.defaultDestination) { oldValue, newValue in
                    // Save default destination locally when it changes
                    if let destination = newValue {
                        UserDefaults.standard.set(destination.latitude, forKey: "defaultDestinationLatitude")
                        UserDefaults.standard.set(destination.longitude, forKey: "defaultDestinationLongitude")
                        UserDefaults.standard.set(destination.address, forKey: "defaultDestinationAddress")
                    }
                    // Update user in Firestore
                    firestoreService.updateUser(user: currentUser)
                }
                
                NavigationLink(destination: RideRequestView(group: group, currentUser: currentUser)) {
                    Text("Request Ride")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("\(group.name) (\(group.inviteCode))")
        .onAppear {
            if let groupId = group.id {
                firestoreService.fetchGroupMembers(groupId: groupId) { members in
                    self.members = members
                }
            }
            
            // Load saved default destination if it exists
            loadSavedDefaultDestination()
        }
        .background(Color.green.opacity(0.1))
    }
    
    private func loadSavedDefaultDestination() {
        // Check if we have saved default destination data
        if let latitude = UserDefaults.standard.object(forKey: "defaultDestinationLatitude") as? Double,
           let longitude = UserDefaults.standard.object(forKey: "defaultDestinationLongitude") as? Double,
           let address = UserDefaults.standard.string(forKey: "defaultDestinationAddress") {
            
            // Only set if user doesn't already have a default destination
            if currentUser.defaultDestination == nil {
                let savedDestination = Location(latitude: latitude, longitude: longitude, address: address)
                currentUser.defaultDestination = savedDestination
            }
        }
    }
}