import SwiftUI

struct GroupSelectionView: View {
    let user: User
    let groups: [Group]
    @State private var selectedGroup: Group?
    @State private var navigateToGroupView = false
    
    var body: some View {
        VStack {
            Text("Select a Group")
                .font(.title)
                .padding()
            
            List(groups, id: \.id) { group in
                Button(action: {
                    selectedGroup = group
                    navigateToGroupView = true
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.headline)
                            Text("Invite Code: \(group.inviteCode)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let group = selectedGroup {
                NavigationLink(destination: GroupView(group: group, currentUser: user), isActive: $navigateToGroupView) {
                    EmptyView()
                }
            }
            
            Spacer()
        }
        .navigationTitle("Your Groups")
        .background(Color.green.opacity(0.1))
    }
}