import Foundation
import FirebaseFirestore

class FirestoreService {
    private let db = Firestore.firestore()
    
    func fetchGroup(withInviteCode inviteCode: String, completion: @escaping (Group?) -> Void) {
        db.collection("groups").whereField("inviteCode", isEqualTo: inviteCode).getDocuments { snapshot, error in
            guard let document = snapshot?.documents.first else {
                completion(nil)
                return
            }
            do {
                var group = try document.data(as: Group.self)
                group.id = document.documentID
                completion(group)
            } catch {
                completion(nil)
            }
        }
    }
    
    func fetchGroup(withId groupId: String, completion: @escaping (Group?) -> Void) {
        db.collection("groups").document(groupId).getDocument { document, error in
            guard let document = document, document.exists else {
                completion(nil)
                return
            }
            do {
                var group = try document.data(as: Group.self)
                group.id = document.documentID
                completion(group)
            } catch {
                completion(nil)
            }
        }
    }
    
    func fetchGroupMembers(groupId: String, completion: @escaping ([User]) -> Void) {
        db.collection("users").whereField("groups", arrayContains: groupId).getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            var members: [User] = []
            for document in documents {
                do {
                    var user = try document.data(as: User.self)
                    user.id = document.documentID
                    members.append(user)
                } catch {
                    print("Error decoding user: \(error)")
                }
            }
            completion(members)
        }
    }
    
    func fetchTemporaryLocation(userId: String, completion: @escaping (LastKnownLocation?) -> Void) {
        db.collection("temporaryLocations").document(userId).getDocument { document, error in
            guard let document = document, document.exists else {
                completion(nil)
                return
            }
            do {
                var location = try document.data(as: LastKnownLocation.self)
                location.timestamp = document.data()?["timestamp"] as? Timestamp
                completion(location)
            } catch {
                completion(nil)
            }
        }
    }
    
    func fetchUser(userId: String, completion: @escaping (User?) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            guard let document = document, document.exists else {
                completion(nil)
                return
            }
            do {
                var user = try document.data(as: User.self)
                user.id = document.documentID
                completion(user)
            } catch {
                completion(nil)
            }
        }
    }
    
    func updateUser(user: User) {
        guard let userId = user.id else { return }
        do {
            var data = try Firestore.Encoder().encode(user)
            // Remove the id field since it's the document ID
            data.removeValue(forKey: "id")
            db.collection("users").document(userId).setData(data)
        } catch {
            print("Error encoding user: \(error)")
        }
    }
    
    func createGroup(group: Group, completion: @escaping (String?) -> Void) {
        do {
            var data = try Firestore.Encoder().encode(group)
            // Remove the id field since it's the document ID
            data.removeValue(forKey: "id")
            let ref = db.collection("groups").addDocument(data: data)
            completion(ref.documentID)
        } catch {
            completion(nil)
        }
    }
    
    func updateGroup(group: Group) {
        guard let groupId = group.id else { return }
        do {
            var data = try Firestore.Encoder().encode(group)
            // Remove the id field since it's the document ID
            data.removeValue(forKey: "id")
            db.collection("groups").document(groupId).setData(data)
        } catch {
            print("Error encoding group: \(error)")
        }
    }
    
    func createUser(user: User, completion: @escaping (String?) -> Void) {
        do {
            var data = try Firestore.Encoder().encode(user)
            // Remove the id field since it's the document ID
            data.removeValue(forKey: "id")
            let ref = db.collection("users").addDocument(data: data)
            completion(ref.documentID)
        } catch {
            completion(nil)
        }
    }
    
    func updateTemporaryLocation(userId: String, location: LastKnownLocation) {
        do {
            var data = try Firestore.Encoder().encode(location)
            // Remove the timestamp field if it's nil
            if location.timestamp == nil {
                data.removeValue(forKey: "timestamp")
            }
            db.collection("temporaryLocations").document(userId).setData(data)
        } catch {
            print("Error encoding temporary location: \(error)")
        }
    }
    
    func deleteTemporaryLocation(userId: String) {
        db.collection("temporaryLocations").document(userId).delete()
    }
    
    func scheduleTemporaryLocationDeletion(userId: String, timestamp: Timestamp) {
        // Schedule deletion 1 minute after the timestamp
        let deletionTime = timestamp.dateValue().addingTimeInterval(60) // 1 minute
        let timeUntilDeletion = deletionTime.timeIntervalSinceNow
        
        if timeUntilDeletion > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilDeletion) {
                self.deleteTemporaryLocation(userId: userId)
            }
        }
    }
}
