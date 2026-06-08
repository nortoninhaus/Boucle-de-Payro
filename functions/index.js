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
    const qrUrl = `https://us-central1-inhaus-brain-full-prod.cloudfunctions.net/api/qrcodes/${ticketId}.png`;

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

    // Check for companion guests using existing fields in GHL
    const companionTickets = [];
    
    // Parse companion names from Acompañante Payró (acompaante/acompante/acompanante) or standard payload fields
    let companionNames = [];
    let extraGuestsCount = 0;
    const rawCompanions = [];
    
    // Support literal GHL webhook keys
    if (body["Acompañante Payró"]) rawCompanions.push(body["Acompañante Payró"]);
    if (body["Acompañante"]) rawCompanions.push(body["Acompañante"]);
    
    // Snake_case keys as fallback
    if (body.acompaante) rawCompanions.push(body.acompaante);
    if (body.acompante) rawCompanions.push(body.acompante);
    if (body.acompanante) rawCompanions.push(body.acompanante);
    if (body.acompanante_payro) rawCompanions.push(body.acompanante_payro);
    if (body.acompanante_1_nombre) rawCompanions.push(body.acompanante_1_nombre);
    if (body.acompanante_2_nombre) rawCompanions.push(body.acompanante_2_nombre);

    const combinedRaw = rawCompanions.map(c => c.toString().trim()).join(", ").trim();
    if (combinedRaw) {
      if (/^\d+$/.test(combinedRaw)) {
        const val = parseInt(combinedRaw, 10) || 0;
        if (val > 1) {
          extraGuestsCount = val - 1; // subtract main guest
        }
      } else {
        // Normalize separating by " y " or " Y " to commas
        const normalized = combinedRaw.replace(/\s+y\s+/gi, ", ");
        companionNames = normalized
          .split(/[,;\n\r]+/)
          .map(name => name.trim())
          .filter(name => name.length > 0);
        
        // Filter out any numeric fields that might represent quantity
        companionNames = companionNames.filter(name => {
          if (/^\d+$/.test(name)) {
            const val = parseInt(name, 10) || 0;
            const compVal = val > 1 ? val - 1 : 0; // subtract main guest
            if (compVal > extraGuestsCount) {
              extraGuestsCount = compVal;
            }
            return false;
          }
          return true;
        });
      }
    }

    // Check Numero de invitados Payró and ¿Cuántos invitados aprox. serían?
    const numInvitadosRaw = 
      body["Numero de invitados Payró"] || 
      body["¿Cuántos invitados aprox. serían?"] || 
      body.numero_de_invitados || 
      body.numero_invitados || 
      body.numero_de_invitados_payro || 
      body.cuntos_invitados_aprox_seran || 
      "0";
    const numInvitados = parseInt(numInvitadosRaw, 10) || 0;
    
    // Since this number includes the main guest, companion count is numInvitados - 1
    const companionsCountFromNum = numInvitados > 1 ? numInvitados - 1 : 0;

    // Determine final count of companion tickets
    const finalCount = Math.max(companionsCountFromNum, extraGuestsCount, companionNames.length);
    const finalCompanions = [];
    for (let i = 0; i < finalCount; i++) {
      if (i < companionNames.length) {
        finalCompanions.push(companionNames[i]);
      } else {
        finalCompanions.push(`Acompañante ${i + 1} de ${guestName}`);
      }
    }

    // Generate tickets for each companion
    for (let i = 0; i < finalCompanions.length; i++) {
      const compName = finalCompanions[i];
      const compTicketId = await createUniqueTicketId();
      
      const compTicketData = {
        id: compTicketId,
        guestName: compName,
        guestEmail: "",
        guestPhone: "",
        company: company,
        ghlContactId: contactId,
        status: "issued",
        issuedAt: new Date().toISOString(),
        checkedInAt: null,
        isCompanion: true,
        principalName: guestName,
        parentTicketId: ticketId,
      };

      await db.collection("tickets").doc(compTicketId).set(compTicketData);
      companionTickets.push(compTicketData);
      console.log(`Companion ticket ${compTicketId} created for ${compName}`);
    }

    const ticketIdKey = process.env.GHL_TICKET_ID_KEY || "boucl_ticket_id";
    const qrUrlKey = process.env.GHL_QR_URL_KEY || "boucl_qr_code_url";

    // Format final values to update GHL
    let ticketIdValue = ticketId;
    let qrUrlValue = qrUrl;

    if (companionTickets.length > 0) {
      const ticketIds = [ticketId];
      companionTickets.forEach(comp => {
        ticketIds.push(comp.id);
      });
      ticketIdValue = ticketIds.join(", ");
    }

    const customFieldsToUpdate = [
      { key: ticketIdKey, value: ticketIdValue },
      { key: qrUrlKey, value: qrUrlValue },
    ];

    // Update GHL Contact Custom Fields
    const accessToken = process.env.GHL_ACCESS_TOKEN;

    if (accessToken) {
      try {
        const ghlUrl = `https://services.leadconnectorhq.com/contacts/${contactId}`;
        const ghlPayload = {
          customFields: customFieldsToUpdate,
        };

        await axios.put(ghlUrl, ghlPayload, {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Version: "2023-02-21",
            "Content-Type": "application/json",
          },
        });
        console.log(`Successfully updated contact ${contactId} in GHL with all generated tickets`);
      } catch (ghlError) {
        console.error("Failed to update GHL contact fields:", ghlError.response?.data || ghlError.message);
        // Don't fail the webhook response because the tickets are already saved in our DB
      }
    } else {
      console.warn("GHL_ACCESS_TOKEN not set. Skipping GHL contact update.");
    }

    return res.status(200).json({
      success: true,
      message: "Tickets created successfully",
      ticket: ticketData,
      qrCodeUrl: qrUrl,
      companions: companionTickets,
    });
  } catch (error) {
    console.error("Error processing webhook:", error);
    return res.status(500).json({ error: "Internal Server Error", message: error.message });
  }
});

// Route: Dynamic QR image generation (combines main and companion QR codes side-by-side)
app.get("/qrcodes/:ticketId.png", async (req, res) => {
  try {
    const Jimp = require("jimp");
    const { ticketId } = req.params;
    
    // Fetch main ticket
    const ticketDoc = await db.collection("tickets").doc(ticketId).get();
    if (!ticketDoc.exists) {
      return res.status(404).send("Ticket not found");
    }
    const mainTicket = ticketDoc.data();
    
    // Find parent principal ticket to load the correct companions group
    let principalTicket = mainTicket;
    if (mainTicket.isCompanion && mainTicket.parentTicketId) {
      const parentDoc = await db.collection("tickets").doc(mainTicket.parentTicketId).get();
      if (parentDoc.exists) {
        principalTicket = parentDoc.data();
      }
    }
    const parentId = principalTicket.id;

    // Fetch companions (same parentTicketId)
    const companions = [];
    const snap = await db.collection("tickets")
      .where("parentTicketId", "==", parentId)
      .get();
    
    snap.forEach(doc => {
      const data = doc.data();
      if (data.id !== principalTicket.id && data.status !== "cancelled") {
        companions.push(data);
      }
    });
    // Sort companions by issuedAt
    companions.sort((a, b) => (a.issuedAt || "").localeCompare(b.issuedAt || ""));

    const allTickets = [principalTicket, ...companions];
    const N = allTickets.length;
    const qrWidth = 180;
    const qrHeight = 180;
    const canvasWidth = 350;
    const blockHeight = 360;
    const canvasHeight = blockHeight * N;

    // Create white canvas (Jimp white color is 0xFFFFFFFF)
    const canvas = new Jimp(canvasWidth, canvasHeight, 0xFFFFFFFF);
    const font = await Jimp.loadFont(Jimp.FONT_SANS_16_BLACK);

    for (let i = 0; i < N; i++) {
      const t = allTickets[i];
      const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${t.id}`;
      
      const qrImage = await Jimp.read(qrCodeUrl);
      const yOffset = i * blockHeight;
      
      // Paste QR code centered horizontally (85, yOffset + 95)
      canvas.composite(qrImage, 85, yOffset + 95);
      
      // Print name centered
      let displayName = t.guestName || "Invitado";
      if (displayName.length > 28) {
        displayName = displayName.substring(0, 25) + "...";
      }
      
      const textWidth = Jimp.measureText(font, displayName);
      const xText = Math.max(0, (canvasWidth - textWidth) / 2);
      
      canvas.print(font, xText, yOffset + 40, displayName);
      
      // Horizontal Divider
      if (N > 1 && i < N - 1) {
        const dividerY = (i + 1) * blockHeight - 15;
        for (let x = 40; x < canvasWidth - 40; x++) {
          canvas.setPixelColor(0xEEEEEEFF, x, dividerY);
        }
      }
    }

    const buffer = await canvas.getBufferAsync(Jimp.MIME_PNG);
    res.type("image/png");
    res.set("Cache-Control", "public, max-age=86400"); // cache for 1 day
    return res.send(buffer);
  } catch (error) {
    console.error("Error generating combined QR image:", error);
    return res.status(500).send("Error generating QR code image");
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

// Route: Create guest manually (Requires authentication)
app.post("/guests", verifyPasscode, async (req, res) => {
  try {
    const { guestName, guestEmail, guestPhone, company } = req.body || {};
    if (!guestName) {
      return res.status(400).json({ error: "Missing guest name" });
    }

    const ticketId = await createUniqueTicketId();
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${ticketId}`;

    let contactId = null;
    const accessToken = process.env.GHL_ACCESS_TOKEN;
    const ticketIdKey = process.env.GHL_TICKET_ID_KEY || "boucl_ticket_id";
    const qrUrlKey = process.env.GHL_QR_URL_KEY || "boucl_qr_code_url";

    if (accessToken) {
      try {
        const nameParts = guestName.trim().split(" ");
        const firstName = nameParts[0] || "Guest";
        const lastName = nameParts.slice(1).join(" ") || "";

        const ghlPayload = {
          firstName,
          lastName,
          name: guestName,
          email: guestEmail || undefined,
          phone: guestPhone || undefined,
          companyName: company || undefined,
          tags: ["boucle-invite", "manual-invite"],
          customFields: [
            { key: ticketIdKey, value: ticketId },
            { key: qrUrlKey, value: qrUrl },
          ],
        };

        const ghlResponse = await axios.post("https://services.leadconnectorhq.com/contacts/", ghlPayload, {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Version: "2023-02-21",
            "Content-Type": "application/json",
          },
        });

        contactId = ghlResponse.data?.contact?.id || null;
        console.log(`Successfully created manually added contact in GHL: ${contactId}`);
      } catch (ghlError) {
        console.error("Failed to create manual contact in GHL:", ghlError.response?.data || ghlError.message);
      }
    }

    const ticketData = {
      id: ticketId,
      guestName,
      guestEmail: guestEmail || "",
      guestPhone: guestPhone || "",
      company: company || "",
      ghlContactId: contactId,
      status: "issued",
      issuedAt: new Date().toISOString(),
      checkedInAt: null,
    };

    await db.collection("tickets").doc(ticketId).set(ticketData);
    return res.status(200).json({ success: true, ticket: ticketData });
  } catch (error) {
    console.error("Error creating guest manually:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
});

// Route: Update guest details (Requires authentication)
app.put("/guests/:ticketId", verifyPasscode, async (req, res) => {
  try {
    const { ticketId } = req.params;
    const { guestName, guestEmail, guestPhone, company, status } = req.body || {};

    const ticketRef = db.collection("tickets").doc(ticketId);
    const ticketDoc = await ticketRef.get();

    if (!ticketDoc.exists) {
      return res.status(444).json({ error: "Ticket not found" });
    }

    const updates = {};
    if (guestName !== undefined) updates.guestName = guestName;
    if (guestEmail !== undefined) updates.guestEmail = guestEmail;
    if (guestPhone !== undefined) updates.guestPhone = guestPhone;
    if (company !== undefined) updates.company = company;
    if (status !== undefined) {
      updates.status = status;
      if (status === "checked_in") {
        updates.checkedInAt = new Date().toISOString();
      } else {
        updates.checkedInAt = null;
      }
    }

    await ticketRef.update(updates);
    const updatedDoc = await ticketRef.get();
    return res.status(200).json({ success: true, ticket: updatedDoc.data() });
  } catch (error) {
    console.error("Error updating guest:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
});

// Route: Delete guest (Requires authentication)
app.delete("/guests/:ticketId", verifyPasscode, async (req, res) => {
  try {
    const { ticketId } = req.params;
    const ticketRef = db.collection("tickets").doc(ticketId);
    const ticketDoc = await ticketRef.get();

    if (!ticketDoc.exists) {
      return res.status(444).json({ error: "Ticket not found" });
    }

    await ticketRef.delete();
    return res.status(200).json({ success: true, message: "Ticket deleted successfully" });
  } catch (error) {
    console.error("Error deleting guest:", error);
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
