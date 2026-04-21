const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// ---------------- HELPERS ----------------

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function isRuetStudentEmail(email) {
  return /^[1-9]\d{6}@student\.ruet\.ac\.bd$/.test(email);
}

function otp6() {
  return String(Math.floor(100000 + Math.random() * 900000)); // 6 digits
}

function sha256(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function randomSalt() {
  return crypto.randomBytes(16).toString("hex");
}

function nowTs() {
  return admin.firestore.Timestamp.now();
}

function addSeconds(seconds) {
  return admin.firestore.Timestamp.fromMillis(Date.now() + seconds * 1000);
}

// ---------------- SMTP (from functions config) ----------------
// You set these using:
// firebase functions:config:set smtp.email="..."
// firebase functions:config:set smtp.pass="..."
function getSmtpConfig() {
  // v2 still supports functions.config() via runtime config (deprecated but works for now)
  // eslint-disable-next-line no-undef
  const cfg = require("firebase-functions").config?.() || {};
  const email = cfg.smtp?.email;
  const pass = cfg.smtp?.pass;

  if (!email || !pass) {
    throw new HttpsError(
      "failed-precondition",
      "SMTP config missing. Set smtp.email and smtp.pass using firebase functions:config:set."
    );
  }

  return { email, pass };
}

async function sendOtpEmail(toEmail, otp) {
  const { email, pass } = getSmtpConfig();

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: email,
      pass: pass,
    },
  });

  const subject = "RUET Bus Tracker — Password Reset OTP";
  const text =
    `Your OTP is: ${otp}\n\n` +
    `This OTP expires in 60 seconds.\n` +
    `If you didn't request this, ignore this email.`;

  await transporter.sendMail({
    from: `RUET Bus Tracker <${email}>`,
    to: toEmail,
    subject,
    text,
  });
}

// ---------------- FIRESTORE PATH ----------------
function otpDocRef(email) {
  return db.collection("password_otps").doc(email);
}

// ---------------- SETTINGS ----------------
const OTP_EXPIRES_SECONDS = 60;
const RESEND_COOLDOWN_SECONDS = 30;
const MAX_ATTEMPTS = 5;

// ======================================================
// 1) requestPasswordOtp({email})
// ======================================================
exports.requestPasswordOtp = onCall({ region: "asia-south1" }, async (req) => {
  const email = normalizeEmail(req.data?.email);

  if (!isRuetStudentEmail(email)) {
    throw new HttpsError("invalid-argument", "Only RUET student emails allowed.");
  }

  // Security: don't reveal if user exists, but we can still check internally
  // If user doesn't exist -> still respond success (prevents email enumeration)
  let userExists = true;
  try {
    await admin.auth().getUserByEmail(email);
  } catch (e) {
    userExists = false;
  }

  const ref = otpDocRef(email);
  const snap = await ref.get();
  const now = Date.now();

  if (snap.exists) {
    const d = snap.data() || {};
    const lastSentAt = d.lastSentAt?.toMillis?.() || 0;
    const cooldown = now - lastSentAt;

    if (cooldown < RESEND_COOLDOWN_SECONDS * 1000) {
      const wait = Math.ceil((RESEND_COOLDOWN_SECONDS * 1000 - cooldown) / 1000);
      throw new HttpsError(
        "resource-exhausted",
        `Please wait ${wait}s before requesting another OTP.`
      );
    }
  }

  // Generate OTP and store hash
  const otp = otp6();
  const salt = randomSalt();
  const otpHash = sha256(`${salt}:${otp}`);

  await ref.set(
    {
      otpHash,
      salt,
      expiresAt: addSeconds(OTP_EXPIRES_SECONDS),
      attempts: 0,
      lastSentAt: nowTs(),
    },
    { merge: true }
  );

  // Send email ONLY if user exists (optional; either way respond same)
  if (userExists) {
    await sendOtpEmail(email, otp);
  }

  return { ok: true };
});

// ======================================================
// 2) verifyPasswordOtp({email, otp})
// returns {ok:true, resetToken:"..."} (custom token)
// ======================================================
exports.verifyPasswordOtp = onCall({ region: "asia-south1" }, async (req) => {
  const email = normalizeEmail(req.data?.email);
  const otp = String(req.data?.otp || "").trim();

  if (!isRuetStudentEmail(email)) {
    throw new HttpsError("invalid-argument", "Invalid email.");
  }
  if (!/^\d{6}$/.test(otp)) {
    throw new HttpsError("invalid-argument", "OTP must be 6 digits.");
  }

  const ref = otpDocRef(email);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "OTP not found. Request a new one.");
  }

  const d = snap.data() || {};
  const expiresAt = d.expiresAt?.toMillis?.() || 0;
  const attempts = Number(d.attempts || 0);
  const salt = String(d.salt || "");
  const otpHash = String(d.otpHash || "");

  if (attempts >= MAX_ATTEMPTS) {
    throw new HttpsError("permission-denied", "Too many attempts. Request a new OTP.");
  }

  if (Date.now() > expiresAt) {
    throw new HttpsError("deadline-exceeded", "OTP expired. Request a new OTP.");
  }

  const check = sha256(`${salt}:${otp}`);
  if (check !== otpHash) {
    await ref.set({ attempts: attempts + 1 }, { merge: true });
    throw new HttpsError("permission-denied", "Invalid OTP.");
  }

  // OTP correct -> delete OTP doc (one-time use)
  await ref.delete();

  // Create a short-lived custom token marker in Firestore (reset_sessions)
  // so Flutter can call resetPassword with proof.
  const sessionId = crypto.randomBytes(16).toString("hex");
  const sessionRef = db.collection("reset_sessions").doc(sessionId);

  await sessionRef.set({
    email,
    expiresAt: addSeconds(10 * 60), // session valid 10 minutes
    createdAt: nowTs(),
  });

  return { ok: true, sessionId };
});

// ======================================================
// 3) resetPasswordWithSession({sessionId, newPassword})
// ======================================================
exports.resetPasswordWithSession = onCall({ region: "asia-south1" }, async (req) => {
  const sessionId = String(req.data?.sessionId || "").trim();
  const newPassword = String(req.data?.newPassword || "");

  if (sessionId.length < 10) {
    throw new HttpsError("invalid-argument", "Invalid session.");
  }
  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  const sessionRef = db.collection("reset_sessions").doc(sessionId);
  const snap = await sessionRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }

  const d = snap.data() || {};
  const email = normalizeEmail(d.email);
  const expiresAt = d.expiresAt?.toMillis?.() || 0;

  if (Date.now() > expiresAt) {
    await sessionRef.delete();
    throw new HttpsError("deadline-exceeded", "Session expired. Request OTP again.");
  }

  // Update password using Admin SDK
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password: newPassword });

  // one-time session
  await sessionRef.delete();

  return { ok: true };
});