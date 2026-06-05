const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");
const axios = require("axios");
require("dotenv").config();

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

// Helper to generate a unique Ticket ID (e.g., BOU-A1B2-C3D4)
function generateRandomCode(length = 4) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

async function createUniqueTicketId() {
  let isUnique = false;
  let ticketId = "";
  let attempts = 0;

  while (!isUnique && attempts < 10) {
    const part1 = generateRandomCode(4);
    const part2 = generateRandomCode(4);
    ticketId = `BOU-${part1}-${part2}`;

    const doc = await db.collection("tickets").doc(ticketId).get();
    if (!doc.exists) {
      isUnique = true;
    }
    attempts++;
  }

  return ticketId;
}

// Middleware helper to check passcode
function verifyPasscode(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Unauthorized: Missing or invalid token format" });
  }
  const token = authHeader.split(" ")[1];
  const requiredPasscode = process.env.STAFF_PASSCODE || "4268";
  if (token !== requiredPasscode) {
    return res.status(401).json({ error: "Unauthorized: Invalid passcode" });
  }
  next();
}

// Route: GHL Webhook
app.post("/ghl-webhook", async (req, res) => {
  try {
    const body = req.body || {};
    console.log("Received GHL webhook payload:", JSON.stringify(body));

    const contactId = body.contact_id || body.contactId || body.id;
    if (!contactId) {
      return res.status(400).json({ error: "Missing GHL contact ID" });
    }

    // Generate unique Ticket ID
    const ticketId = await createUniqueTicketId();
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${ticketId}`;

    // Construct Guest Details
    const firstName = body.first_name || body.firstName || "";
    const lastName = body.last_name || body.lastName || "";
    const guestName = `${firstName} ${lastName}`.trim() || "Invited Guest";
    const guestEmail = body.email || body.guestEmail || "";
    const guestPhone = body.phone || body.guestPhone || "";
    const company = body.company_name || body.company || "";

    // Store in Firestore
    const ticketRef = db.collection("tickets").doc(ticketId);
    const ticketData = {
      id: ticketId,
      guestName,
      guestEmail,
      guestPhone,
      company,
      ghlContactId: contactId,
      status: "issued",
      issuedAt: new Date().toISOString(),
      checkedInAt: null,
    };

    await ticketRef.set(ticketData);
    console.log(`Ticket ${ticketId} created in Firestore for GHL Contact ${contactId}`);

    // Update GHL Contact Custom Fields
    const accessToken = process.env.GHL_ACCESS_TOKEN;
    const ticketIdKey = process.env.GHL_TICKET_ID_KEY || "boucle_ticket_id";
    const qrUrlKey = process.env.GHL_QR_URL_KEY || "boucle_qr_url";

    if (accessToken) {
      try {
        const ghlUrl = `https://services.leadconnectorhq.com/contacts/${contactId}`;
        const ghlPayload = {
          customFields: [
            { key: ticketIdKey, value: ticketId },
            { key: qrUrlKey, value: qrUrl },
          ],
        };

        await axios.put(ghlUrl, ghlPayload, {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Version: "2023-02-21",
            "Content-Type": "application/json",
          },
        });
        console.log(`Successfully updated contact ${contactId} in GHL with ticket ${ticketId}`);
      } catch (ghlError) {
        console.error("Failed to update GHL contact fields:", ghlError.response?.data || ghlError.message);
        // Don't fail the webhook response because the ticket is already saved in our DB
      }
    } else {
      console.warn("GHL_ACCESS_TOKEN not set. Skipping GHL contact update.");
    }

    return res.status(200).json({
      success: true,
      message: "Ticket created successfully",
      ticket: ticketData,
      qrCodeUrl: qrUrl,
    });
  } catch (error) {
    console.error("Error processing webhook:", error);
    return res.status(500).json({ error: "Internal Server Error", message: error.message });
  }
});

// Route: Login verification
app.post("/login", (req, res) => {
  const { passcode } = req.body || {};
  const requiredPasscode = process.env.STAFF_PASSCODE || "4268";

  if (passcode === requiredPasscode) {
    return res.status(200).json({ success: true, token: requiredPasscode });
  } else {
    return res.status(401).json({ success: false, error: "Invalid PIN code" });
  }
});

// Route: Guests list (Requires authentication)
app.get("/guests", verifyPasscode, async (req, res) => {
  try {
    const snapshot = await db.collection("tickets").orderBy("guestName").get();
    const guests = [];
    snapshot.forEach((doc) => {
      guests.push(doc.data());
    });

    return res.status(200).json({ guests });
  } catch (error) {
    console.error("Error fetching guest list:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
});

// Route: Ticket check-in (Requires authentication)
app.post("/checkIn", verifyPasscode, async (req, res) => {
  const { ticketId } = req.body || {};
  if (!ticketId) {
    return res.status(400).json({ error: "Missing ticket ID" });
  }

  try {
    const ticketRef = db.collection("tickets").doc(ticketId);
    const ticketDoc = await ticketRef.get();

    if (!ticketDoc.exists) {
      return res.status(444).json({
        status: "NOT_FOUND",
        error: "Invalid ticket ID. Ticket does not exist.",
      });
    }

    const ticket = ticketDoc.data();

    if (ticket.status === "checked_in") {
      return res.status(200).json({
        status: "ALREADY_CHECKED_IN",
        message: "Guest is already checked in",
        checkedInAt: ticket.checkedInAt,
        guest: ticket,
      });
    }

    const checkedInAt = new Date().toISOString();
    await ticketRef.update({
      status: "checked_in",
      checkedInAt,
    });

    // Update GHL custom field if possible
    const accessToken = process.env.GHL_ACCESS_TOKEN;
    const checkedInKey = process.env.GHL_CHECKED_IN_KEY || "boucle_checked_in";
    if (accessToken && ticket.ghlContactId) {
      try {
        const ghlUrl = `https://services.leadconnectorhq.com/contacts/${ticket.ghlContactId}`;
        const ghlPayload = {
          customFields: [{ key: checkedInKey, value: "Yes" }],
        };

        await axios.put(ghlUrl, ghlPayload, {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Version: "2023-02-21",
            "Content-Type": "application/json",
          },
        });
        console.log(`Updated GHL contact ${ticket.ghlContactId} checked-in status`);
      } catch (ghlError) {
        console.error("Failed to update GHL checked-in status:", ghlError.response?.data || ghlError.message);
      }
    }

    const updatedTicket = { ...ticket, status: "checked_in", checkedInAt };

    return res.status(200).json({
      status: "SUCCESS",
      message: "Check-in successful",
      guest: updatedTicket,
    });
  } catch (error) {
    console.error("Error checking in ticket:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
});

// Run as standard express server if started directly, or export as single Firebase Function
if (require.main === module) {
  const PORT = process.env.PORT || 5001;
  app.listen(PORT, () => {
    console.log(`Express server listening on port ${PORT}`);
  });
}

// Export single Cloud Function mapping all Express routes
exports.api = onRequest(app);
