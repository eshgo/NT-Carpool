import SwiftUI
import MapKit
import CoreLocation

struct DestinationView: View {
    @Binding var currentUser: User
    @State private var address = ""
    @State private var isSearching = false
    @State private var errorMessage = ""
    
    private let firestoreService = FirestoreService()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Your Default Destination")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Destination:")
                    .font(.headline)
                
                if let destination = currentUser.defaultDestination {
                    Text(destination.address)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Text("No destination set")
                        .font(.body)
                        .italic()
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("New Destination:")
                    .font(.headline)
                
                TextField("Enter address", text: $address)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.words)
            }
            
            Button(action: saveDestination) {
                HStack {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Save Destination")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(address.isEmpty || isSearching)
            .opacity(address.isEmpty || isSearching ? 0.6 : 1.0)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .navigationTitle("Set Destination")
        .onAppear {
            // Pre-fill address if user already has a default destination
            if let destination = currentUser.defaultDestination {
                address = destination.address
            }
        }
        .background(Color.green.opacity(0.1))
    }
    
    private func saveDestination() {
        guard !address.isEmpty else { return }
        
        isSearching = true
        errorMessage = ""
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    self.errorMessage = "Could not find location: \(error.localizedDescription)"
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    self.errorMessage = "Could not find location"
                    return
                }
                
                let newDestination = Location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: self.address
                )
                
                self.currentUser.defaultDestination = newDestination
                self.firestoreService.updateUser(user: self.currentUser)
                
                // Save default destination locally
                UserDefaults.standard.set(newDestination.latitude, forKey: "defaultDestinationLatitude")
                UserDefaults.standard.set(newDestination.longitude, forKey: "defaultDestinationLongitude")
                UserDefaults.standard.set(newDestination.address, forKey: "defaultDestinationAddress")
            }
        }
    }
}