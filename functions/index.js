const admin = require("firebase-admin");
const {HttpsError, onCall} = require("firebase-functions/v2/https");

admin.initializeApp();

exports.sendNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  const {toUserId, title, body, orderId, type} = request.data || {};
  if (typeof toUserId !== "string" || toUserId.trim() === "") {
    throw new HttpsError("invalid-argument", "toUserId is required");
  }
  if (typeof title !== "string" || title.trim() === "") {
    throw new HttpsError("invalid-argument", "title is required");
  }
  if (typeof body !== "string" || body.trim() === "") {
    throw new HttpsError("invalid-argument", "body is required");
  }

  try {
    const userSnap = await admin
      .firestore()
      .collection("users")
      .doc(toUserId)
      .get();

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User not found");
    }

    const tokens = userSnap.get("fcmTokens");
    const validTokens = Array.isArray(tokens)
      ? tokens.filter((token) => typeof token === "string" && token.length > 0)
      : [];

    if (validTokens.length === 0) {
      throw new HttpsError("not-found", "No tokens available");
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens: validTokens,
      notification: {
        title: title.trim(),
        body: body.trim(),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "veloce_express_alerts_system_v1",
          sound: "default",
        },
      },
      data: {
        title: title.trim(),
        body: body.trim(),
        ...(typeof orderId === "string" && orderId.trim() !== ""
          ? {orderId: orderId.trim()}
          : {}),
        ...(typeof type === "string" && type.trim() !== ""
          ? {type: type.trim()}
          : {}),
      },
    });

    const failedTokens = [];
    response.responses.forEach((result, index) => {
      if (!result.success) {
        failedTokens.push({
          token: validTokens[index],
          error: result.error ? result.error.message : "Unknown error",
        });
      }
    });

    return {
      success: response.failureCount === 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
      failedTokens,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message || "Notification failed");
  }
});
