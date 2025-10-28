import SwiftUI

struct ResultView: View {
    let drivers: [DriverDetourResult]
    
    var body: some View {
        VStack {
            Text("Top Drivers")
                .font(.title)
                .padding()
            
            if drivers.isEmpty {
                Text("No drivers found")
                    .padding()
            } else {
                List(drivers, id: \.driver.id) { result in
                    VStack(alignment: .leading) {
                        Text(result.driver.name)
                            .font(.headline)
                        Text("Detour: \(Int(result.detour / 60)) minutes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Spacer()
        }
        .navigationTitle("Results")
        .background(Color.green.opacity(0.1))
    }
}