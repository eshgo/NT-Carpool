import SwiftUI

struct WelcomeView: View {
    @State private var name = ""
    @State private var inviteCode = ""
    @State private var newGroupName = ""
    @State private var isJoiningGroup = true
    @State private var currentUser: User?
    @State private var currentGroup: Group?
    @State private var navigateToGroupView = false
    @State private var navigateToGroupSelection = false
    @State private var userGroups: [Group] = []
    @State private var showGroupSelectionButton = false
    
    private let firestoreService = FirestoreService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to NT Carpool")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                TextField("Your Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Picker("Action", selection: $isJoiningGroup) {
                    Text("Join Group").tag(true)
                    Text("Create Group").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if isJoiningGroup {
                    TextField("Invite Code", text: $inviteCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                } else {
                    TextField("New Group Name", text: $newGroupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                
                Button(action: {
                    if isJoiningGroup {
                        joinGroup()
                    } else {
                        createGroup()
                    }
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(name.isEmpty || (isJoiningGroup ? inviteCode.isEmpty : newGroupName.isEmpty))
                
                if showGroupSelectionButton {
                    Button(action: {
                        if let user = currentUser {
                            fetchUserGroups(user: user) { groups in
                                self.userGroups = groups
                                self.navigateToGroupSelection = true
                            }
                        }
                    }) {
                        Text("Go to My Groups")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // Navigation to group selection if user has multiple groups
                if let user = currentUser {
                    NavigationLink(destination: GroupSelectionView(user: user, groups: userGroups), isActive: $navigateToGroupSelection) {
                        EmptyView()
                    }
                    
                    // Navigation to single group view if user has only one group
                    if let group = currentGroup {
                        NavigationLink(destination: GroupView(group: group, currentUser: user), isActive: $navigateToGroupView) {
                            EmptyView()
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("NT Carpool")
            .onAppear {
                checkForExistingUser()
            }
            .background(Color.green.opacity(0.1))
        }
    }
    
    private func checkForExistingUser() {
        // Check if we have a stored user ID (from previous session)
        if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            // Fetch the existing user to get their current name and data
            firestoreService.fetchUser(userId: userId) { user in
                if let user = user {
                    self.name = user.name
                    self.currentUser = user
                    self.showGroupSelectionButton = true
                    
                    // Check if user has groups
                    if !user.groups.isEmpty {
                        self.fetchUserGroups(user: user) { groups in
                            self.userGroups = groups
                            if groups.count == 1, let firstGroup = groups.first {
                                // If user only belongs to one group, go directly to that group
                                self.currentGroup = firstGroup
                                self.navigateToGroupView = true
                            } else if groups.count > 1 {
                                // If user belongs to multiple groups, let them choose
                                self.navigateToGroupSelection = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func fetchUserGroups(user: User, completion: @escaping ([Group]) -> Void) {
        var groups: [Group] = []
        let dispatchGroup = DispatchGroup()
        
        for groupId in user.groups {
            dispatchGroup.enter()
            // Use the new method to fetch group by ID
            firestoreService.fetchGroup(withId: groupId) { group in
                if let group = group {
                    groups.append(group)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(groups)
        }
    }
    
    private func joinGroup() {
        firestoreService.fetchGroup(withInviteCode: inviteCode) { group in
            guard let group = group else { 
                // Handle case where group is not found
                print("Group not found with invite code: \(inviteCode)")
                return 
            }
            guard let groupId = group.id else {
                print("Group ID is nil")
                return
            }
            
            if let existingUser = self.currentUser {
                // Update existing user
                var updatedUser = existingUser
                updatedUser.name = self.name
                if !updatedUser.groups.contains(groupId) {
                    updatedUser.groups.append(groupId)
                }
                
                self.firestoreService.updateUser(user: updatedUser)
                
                var updatedGroup = group
                if !updatedGroup.members.contains(existingUser.id!) {
                    updatedGroup.members.append(existingUser.id!)
                }
                
                self.firestoreService.updateGroup(group: updatedGroup)
                self.currentUser = updatedUser
                self.showGroupSelectionButton = true
                
                // Refresh user groups and navigate
                self.fetchUserGroups(user: updatedUser) { groups in
                    self.userGroups = groups
                    if groups.count == 1, let firstGroup = groups.first {
                        self.currentGroup = firstGroup
                        self.navigateToGroupView = true
                    } else {
                        self.navigateToGroupSelection = true
                    }
                }
                
                // Save user data locally
                self.saveUserDataLocally(user: updatedUser)
            } else {
                // Create new user
                self.createNewUserAndJoinGroup(groupId: groupId, group: group)
            }
        }
    }
    
    private func createGroup() {
        let newGroup = Group(name: newGroupName, inviteCode: generateInviteCode(), members: [])
        firestoreService.createGroup(group: newGroup) { groupId in
            guard let groupId = groupId else { 
                print("Failed to create group")
                return 
            }
            
            if let existingUser = self.currentUser {
                // Update existing user
                var updatedUser = existingUser
                updatedUser.name = self.name
                if !updatedUser.groups.contains(groupId) {
                    updatedUser.groups.append(groupId)
                }
                
                self.firestoreService.updateUser(user: updatedUser)
                
                var createdGroup = Group(id: groupId, name: self.newGroupName, inviteCode: newGroup.inviteCode, members: [existingUser.id!])
                self.firestoreService.updateGroup(group: createdGroup)
                self.currentUser = updatedUser
                self.showGroupSelectionButton = true
                
                // Refresh user groups and navigate
                self.fetchUserGroups(user: updatedUser) { groups in
                    self.userGroups = groups
                    if groups.count == 1, let firstGroup = groups.first {
                        self.currentGroup = firstGroup
                        self.navigateToGroupView = true
                    } else {
                        self.navigateToGroupSelection = true
                    }
                }
                
                // Save user data locally
                self.saveUserDataLocally(user: updatedUser)
            } else {
                // Create new user
                self.createNewUserAndCreateGroup(groupId: groupId, inviteCode: newGroup.inviteCode)
            }
        }
    }
    
    private func createNewUserAndJoinGroup(groupId: String, group: Group) {
        let newUser = User(name: name, isDriver: false, groups: [groupId], defaultDestination: nil)
        firestoreService.createUser(user: newUser) { userId in
            guard let userId = userId else { return }
            
            var updatedUser = newUser
            updatedUser.id = userId
            var updatedGroup = group
            updatedGroup.members.append(userId)
            
            self.firestoreService.updateUser(user: updatedUser)
            self.firestoreService.updateGroup(group: updatedGroup)
            self.currentUser = updatedUser
            self.showGroupSelectionButton = true
            
            // Save user data locally
            self.saveUserDataLocally(user: updatedUser)
            
            // Navigate to group
            self.currentGroup = updatedGroup
            self.navigateToGroupView = true
        }
    }
    
    private func createNewUserAndCreateGroup(groupId: String, inviteCode: String) {
        let newUser = User(name: name, isDriver: false, groups: [groupId], defaultDestination: nil)
        firestoreService.createUser(user: newUser) { userId in
            guard let userId = userId else { 
                print("Failed to create user")
                return 
            }
            
            var updatedUser = newUser
            updatedUser.id = userId
            var createdGroup = Group(id: groupId, name: self.newGroupName, inviteCode: inviteCode, members: [userId])
            
            self.firestoreService.updateGroup(group: createdGroup)
            self.currentUser = updatedUser
            self.showGroupSelectionButton = true
            
            // Save user data locally
            self.saveUserDataLocally(user: updatedUser)
            
            // Navigate to group
            self.currentGroup = createdGroup
            self.navigateToGroupView = true
        }
    }
    
    private func saveUserDataLocally(user: User) {
        // Save user ID
        if let userId = user.id {
            UserDefaults.standard.set(userId, forKey: "currentUserId")
        }
    }
    
    private func generateInviteCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map{ _ in letters.randomElement()! })
    }
}