/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Constants
const BATCH_SIZE = 3;
const RETRY_DELAY_MS = 5 * 60 * 1000;   // 5 minutes
const EXPIRE_AFTER_MS = 15 * 60 * 1000; // 15 minutes
const CLEANUP_AFTER_MS = 24 * 60 * 60 * 1000; // 24 hours

// Utility: send FCM notification to one device token
async function sendNotificationToToken(token, payload) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: payload.notification,
      android: payload.android,
      apns: payload.apns,
      data: payload.data || {}
    });
  } catch (err) {
    console.error("FCM send error", err);
  }
}

// Trigger: on create rideRequests -> notify first batch
exports.onRideRequestCreate = functions.firestore
  .document("rideRequests/{requestId}")
  .onCreate(async (snap, ctx) => {
    const requestId = ctx.params.requestId;
    const data = snap.data();
    if (!data) return;

    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + EXPIRE_AFTER_MS);
    const cleanupAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + CLEANUP_AFTER_MS);

    // Normalize driversCandidate array
    const candidates = Array.isArray(data.driversCandidate) ? data.driversCandidate : [];

    // Prepare doc updates: expiresAt, batchIndex, notifiedDriverIds array
    const initial = {
      expiresAt,
      cleanupAt,
      batchIndex: 0,
      notifiedDriverIds: []
    };
    await snap.ref.update(initial);

    // Notify first batch
    await notifyNextBatchForRequest(requestId);
  });

// Helper: notify next batch of drivers for given request
async function notifyNextBatchForRequest(requestId) {
  const reqRef = db.collection("rideRequests").doc(requestId);
  const reqSnap = await reqRef.get();
  if (!reqSnap.exists) return;
  const req = reqSnap.data();

  if (req.status !== "pending") return;

  const candidates = Array.isArray(req.driversCandidate) ? req.driversCandidate : [];
  const alreadyNotified = Array.isArray(req.notifiedDriverIds) ? req.notifiedDriverIds : [];
  const batchIndex = req.batchIndex || 0;

  // Determine start index: batchIndex * BATCH_SIZE (but also skip alreadyNotified just in case)
  // We'll iterate candidates and pick up to BATCH_SIZE drivers not in alreadyNotified
  const toNotify = [];
  for (const c of candidates) {
    if (!c || !c.driverId) continue;
    if (alreadyNotified.includes(c.driverId)) continue;
    toNotify.push(c);
    if (toNotify.length >= BATCH_SIZE) break;
  }

  if (toNotify.length === 0) {
    // No more drivers left -> consider immediate expiration if desired
    return;
  }

  // Fetch user docs for these drivers to get fcmToken and name
  const userPromises = toNotify.map(d => db.collection("users").doc(d.driverId).get());
  const userSnaps = await Promise.all(userPromises);

  // Send notifications
  for (let i = 0; i < toNotify.length; i++) {
    const candidate = toNotify[i];
    const userSnap = userSnaps[i];
    if (!userSnap || !userSnap.exists) continue;
    const user = userSnap.data();
    const token = user.fcmToken;
    const passengerName = req.passengerName || "Someone";
    const addedSeconds = candidate.addedTime || 0;
    const addedMinutes = Math.round(addedSeconds / 60);

    const payload = {
      notification: {
        title: "Ride Request",
        body: `${passengerName} — +${addedMinutes} min`
      },
      apns: {
        payload: {
          aps: {
            category: "RIDE_REQUEST", // must match app's registered category
            "content-available": 1
          }
        }
      },
      data: {
        requestId: requestId,
        passengerName: passengerName,
        // include addedTime only as string if needed by client
        addedTimeSeconds: String(addedSeconds)
      }
    };
    await sendNotificationToToken(token, payload);
  }

  // Update request doc: append notified driver ids, increment batchIndex
  const newNotified = [...alreadyNotified, ...toNotify.map(t => t.driverId)];
  await reqRef.update({
    notifiedDriverIds: newNotified,
    batchIndex: (req.batchIndex || 0) + 1,
    lastNotifiedAt: admin.firestore.Timestamp.now()
  });
}

// Scheduled job: runs every minute to re-notify and expire
exports.scheduledRequestManager = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // 1) Expire requests older than expiresAt
    const expQuery = db.collection("rideRequests")
      .where("status", "==", "pending")
      .where("expiresAt", "<=", now)
      .limit(100);
    const expSnapshots = await expQuery.get();
    const expPromises = [];
    expSnapshots.forEach(snap => {
      expPromises.push(snap.ref.update({ status: "expired", expiredAt: now }));
    });

    // 2) For pending requests, if lastNotifiedAt older than RETRY_DELAY_MS, notify next batch
    // Query pending requests where (lastNotifiedAt <= now - RETRY_DELAY_MS) OR lastNotifiedAt missing and createdAt older than X
    const cutoffForRetry = admin.firestore.Timestamp.fromMillis(now.toMillis() - RETRY_DELAY_MS);
    const pendingQuery = db.collection("rideRequests")
      .where("status", "==", "pending")
      .where("createdAt", "<=", admin.firestore.Timestamp.fromMillis(now.toMillis())) // fetch all pending
      .limit(200);
    const pendingSnap = await pendingQuery.get();

    const retryPromises = [];
    pendingSnap.forEach(doc => {
      const r = doc.data();
      const lastNotifiedAt = r.lastNotifiedAt;
      const expiresAt = r.expiresAt;
      // skip those with no remaining candidates
      const candidates = Array.isArray(r.driversCandidate) ? r.driversCandidate : [];
      const alreadyNotified = Array.isArray(r.notifiedDriverIds) ? r.notifiedDriverIds : [];
      const remaining = candidates.filter(c => !alreadyNotified.includes(c.driverId));
      if (!remaining || remaining.length === 0) {
        // nothing to do
        return;
      }
      // If no lastNotifiedAt (just created) -> skip (onCreate already notified). If it's been >= RETRY_DELAY_MS -> notify
      const needsRetry = !lastNotifiedAt || lastNotifiedAt.toMillis() <= cutoffForRetry.toMillis();
      const notExpired = !expiresAt || expiresAt.toMillis() > now.toMillis();
      if (needsRetry && notExpired) {
        retryPromises.push(notifyNextBatchForRequest(doc.id));
      }
    });

    await Promise.all([...expPromises, ...retryPromises]);
    return null;
  });

// Callable function: driver accepts ride
exports.acceptRide = functions.https.onCall(async (data, context) => {
  const { requestId } = data;
  const driverId = context.auth && context.auth.uid ? context.auth.uid : data.driverId; // allow passing driverId if no auth (for MVP)
  if (!requestId) throw new functions.https.HttpsError('invalid-argument', 'Missing requestId');

  const reqRef = db.collection("rideRequests").doc(requestId);

  // Transaction to ensure first-accept wins
  const result = await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Request not found');
    }
    const req = reqSnap.data();
    if (req.status === 'accepted') {
      throw new functions.https.HttpsError('failed-precondition', 'Already accepted');
    }
    if (req.status === 'expired') {
      throw new functions.https.HttpsError('failed-precondition', 'Request expired');
    }

    tx.update(reqRef, {
      status: 'accepted',
      acceptedBy: driverId,
      acceptedAt: admin.firestore.Timestamp.now()
    });
    return req;
  });

  // Notify passenger
  const passengerId = result.passengerId;
  if (passengerId) {
    const passengerSnap = await db.collection("users").doc(passengerId).get();
    if (passengerSnap.exists) {
      const passenger = passengerSnap.data();
      // Find driver name
      const driverSnap = await db.collection("users").doc(driverId).get();
      const driverName = driverSnap.exists ? (driverSnap.data().name || 'Driver') : 'Driver';
      const token = passenger.fcmToken;
      if (token) {
        await sendNotificationToToken(token, {
          notification: {
            title: "Ride Accepted",
            body: `Your ride has been accepted by ${driverName}`
          },
          data: { requestId }
        });
      }
    }
  }

  return { success: true };
});
