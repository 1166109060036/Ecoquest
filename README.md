# EcoQuest

A gamified Android app that turns everyday eco-friendly actions in Ebetsu City into quests. Players complete a quest, prove it with a photo, and get points, XP and an estimated CO₂e saving right away.

- **App:** Flutter (Dart, Provider) in `lib/`
- **Backend:** Node.js + Express + Socket.IO in `backend/`, deployed on Render (`render.yaml`)
- **Database:** MongoDB Atlas (Mongoose)
- **Email:** Gmail SMTP for password-reset codes
- **Push notifications:** Firebase Cloud Messaging (FCM). Firebase is used only for push. All data stays in MongoDB.

Detailed design notes (in Thai) are in `PROJECT_CONTEXT.md`.

## Backend

```bash
cd backend
npm install
cp .env.example .env   # then fill in the values
npm run dev            # or: npm start
```

| Variable | Required | Purpose |
|---|---|---|
| `MONGODB_URI` | yes | MongoDB Atlas connection string |
| `JWT_SECRET` | yes | Secret used to sign login tokens |
| `GMAIL_USER`, `GMAIL_APP_PASSWORD` | for password reset | Gmail account and its App Password (not the normal password) |
| `ADMIN_EMAILS` | no | Comma-separated emails that can open the Admin pages |
| `FIREBASE_SERVICE_ACCOUNT` | for push | Firebase service account JSON (raw or base64). If not set, push is turned off and in-app notifications still work |
| `PORT` | no | Defaults to 5000 |

To get `FIREBASE_SERVICE_ACCOUNT`, go to Firebase Console, then Project settings, then Service accounts, then **Generate new private key**. Paste the whole JSON file content as the value. **Never commit this file.** `*firebase-adminsdk*.json` is gitignored.

## App

```bash
flutter pub get
flutter run                                                  # uses the deployed Render API
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api   # local backend from the Android emulator
```

The deployed API URL is `_deployedApiUrl` in `lib/utils/constants.dart`. It must end with `/api`.

Push notifications need `android/app/google-services.json` from the same Firebase project as the backend's service account. It is already in the repo. Replace it if you switch to a different Firebase project.

## Deploy (Render)

1. In the Render Dashboard, go to New, then Blueprint, and choose this repo (`render.yaml`).
2. Set `MONGODB_URI`, `JWT_SECRET`, `GMAIL_USER`, `GMAIL_APP_PASSWORD` and `FIREBASE_SERVICE_ACCOUNT` in the service's Environment page.
3. In MongoDB Atlas, go to Network Access and allow `0.0.0.0/0`. Render has no fixed IP address.

On the free tier the service sleeps after about 15 minutes without requests. While it sleeps, the 30-minute check for expiring fridge items does not run. It runs again as soon as the service wakes up.
