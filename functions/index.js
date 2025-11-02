const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Trigger when a new SOS alert is created
 * Sends FCM notification to all admins
 */
exports.sendSosNotification = onDocumentCreated(
  {
    document: 'sosAlerts/{alertId}',
    region: 'asia-southeast1', // Singapore region
  },
  async (event) => {
    try {
      const alertData = event.data.data();
      const alertId = event.params.alertId;

      console.log('🚨 SOS Alert created:', alertId);

      // Get all admin users
      const adminsSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'admin')
        .get();

      if (adminsSnapshot.empty) {
        console.log('❌ No admins found');
        return null;
      }

      // Collect all admin FCM tokens
      const tokens = [];
      adminsSnapshot.forEach(doc => {
        const fcmTokens = doc.data().fcmTokens || [];
        tokens.push(...fcmTokens);
      });

      // Remove duplicates
      const uniqueTokens = [...new Set(tokens)];

      if (uniqueTokens.length === 0) {
        console.log('❌ No admin FCM tokens found');
        return null;
      }

      console.log(`✅ Sending notification to ${uniqueTokens.length} devices`);

      // Prepare notification payload
      const message = {
        data: {
          type: 'sos_alert',
          alertId: alertId,
          studentName: alertData.studentName || 'Unknown',
          studentId: alertData.studentId || 'N/A',
          location: alertData.location || 'Unknown location',
          category: alertData.category || 'emergency',
          description: alertData.description || '',
          createdAt: alertData.createdAt ? alertData.createdAt.toMillis().toString() : Date.now().toString(),
        },
        tokens: uniqueTokens,
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              contentAvailable: true,
            },
          },
        },
      };

      // Send notification
      const response = await admin.messaging().sendEachForMulticast(message);

      console.log(`✅ Successfully sent ${response.successCount} messages`);

      if (response.failureCount > 0) {
        console.log(`❌ Failed to send ${response.failureCount} messages`);
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Token ${uniqueTokens[idx]}: ${resp.error}`);
          }
        });
      }

      return response;
    } catch (error) {
      console.error('❌ Error sending SOS notification:', error);
      return null;
    }
  }
);