# CommuniQ — Node.js Backend

Real-time voice AI practice platform backend. Handles all authentication, session orchestration, evaluation pipeline, XP/gamification, and Firestore writes.

---

## Setup

### 1. Install dependencies
```bash
npm install
```

### 2. Configure environment variables

Copy `.env` and fill in your values:

```env
PORT=3000
FASTAPI_URL=http://localhost:8000

# Firebase Admin SDK (from Service Account JSON)
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your_project.iam.gserviceaccount.com

# Firebase Web API Key (from Firebase Console → Project Settings → General)
FIREBASE_API_KEY=AIza...
```

### 3. Run

Development (with auto-reload):
```bash
npm run dev
```

Production:
```bash
npm start
```

Server starts on `http://localhost:3000`.

---

## API Reference

### Auth

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/auth/register` | ✗ | Create account → returns custom token |
| POST | `/auth/login` | ✗ | Sign in → returns Firebase ID token |
| GET | `/auth/me` | ✓ | Get current user document |

### Sessions

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/sessions/start` | ✓ | Start a new session for a scenario |
| POST | `/sessions/turn` | ✓ | Send audio turn → get AI reply + audio |
| POST | `/sessions/end` | ✓ | End session → triggers evaluation + XP award |
| GET | `/sessions/:sessionId/report` | ✓ | Fetch evaluation report |

### Scenarios

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/scenarios` | ✓ | List scenarios unlocked for user's level |
| GET | `/scenarios/:scenarioId` | ✓ | Get single scenario (systemPrompt excluded) |

### Leaderboard

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/leaderboard` | ✓ | Top 50 users by XP |

### User

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| PATCH | `/user/profile` | ✓ | Update display name |

---

## Architecture

```
Flutter (client)
    │  Authorization: Bearer <firebase_id_token>
    ▼
Node.js (this server)
    │  verifies JWT via Firebase Admin SDK
    │  writes all data to Firestore
    │  calls FastAPI for AI processing
    ▼
FastAPI (ai-server)           Firestore (database)
    │  Groq Whisper (STT)         ▲
    │  Groq LLaMA 3.1 8B          │ Node is the only writer
    │  edge-tts (TTS)             │ Flutter reads via snapshot listeners
    └──────────────────────────────┘
```

**Security rules:**
- Node uses Firebase Admin SDK — bypasses Firestore security rules entirely
- Flutter never writes to Firestore directly
- FastAPI has zero database access

---

## XP & Gamification

**XP per session (based on average score):**
- ≥ 80 avg → +100 XP
- ≥ 60 avg → +70 XP
- ≥ 40 avg → +40 XP
- < 40 avg → +20 XP

**Level thresholds:** 0 / 300 / 700 / 1200 / 2000 XP

**Badges:** `first_session`, `7_day_streak`, `30_day_streak`, `perfect_score`, `level_up`

---

## Folder Structure

```
server/
├── src/
│   ├── config/
│   │   └── firebase.js          Firebase Admin SDK init
│   ├── middleware/
│   │   └── auth.js              JWT verification
│   ├── routes/
│   │   ├── auth.js
│   │   ├── sessions.js
│   │   ├── scenarios.js
│   │   ├── leaderboard.js
│   │   └── user.js
│   ├── controllers/
│   │   ├── authController.js
│   │   ├── sessionController.js
│   │   ├── scenarioController.js
│   │   ├── leaderboardController.js
│   │   └── userController.js
│   ├── services/
│   │   ├── firestoreService.js  All Firestore read/write helpers
│   │   ├── fastApiService.js    Axios calls to FastAPI
│   │   ├── xpService.js         XP, level, streak, badge logic
│   │   └── authService.js       Firebase Auth helpers
│   └── server.js
├── .env
├── package.json
└── README.md
```
