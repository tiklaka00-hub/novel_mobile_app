# Free hosting (no credit card / no payment)

## Recommended stack (matches this project)

| Part | Free option | Notes |
|------|-------------|--------|
| Backend (FastAPI) | **Hugging Face Spaces** | You already use `lakmasachith-novel-app-backend.hf.space` |
| Database | **SQLite** on the Space | Set `DB_TYPE=sqlite` — no external DB account |
| Flutter app | Install APK / Play internal | App talks to HF URL in release builds |

Other free options (no card usually required): **Render** free web service (spins down), **Koyeb**, **PythonAnywhere** (limited), **Oracle Cloud Always Free** (needs card for verify sometimes).

**Avoid for zero-card:** Railway / some Fly.io trials that force a card.

---

## Local (SQLite)

`backend/.env` or `.env.local`:

```env
DB_TYPE=sqlite
SQLITE_FILE=./novel_app.db
UPLOAD_DIR=./uploads
JWT_SECRET=change-me-locally
ADMIN_USERNAME=admin_Supun
ADMIN_PASSWORD=Ux3@f=7x2
```

```bat
cd backend
.venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Flutter:

```bat
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

---

## Live: Hugging Face Spaces (free)

1. Create a Space: https://huggingface.co/new-space  
   - SDK: **Docker**  
   - Hardware: CPU basic (free)  
   - Visibility: public or private

2. Point the Space at this repo’s `backend/` folder (or push backend files into the Space repo).

3. Space **Secrets / Variables** (Settings → Variables and secrets):

```
DB_TYPE=sqlite
SQLITE_FILE=/data/novel_app.db
UPLOAD_DIR=/data/uploads
JWT_SECRET=<long-random-string>
ADMIN_USERNAME=admin_Supun
ADMIN_PASSWORD=<strong-password>
```

4. Use a **persistent volume** on the Space if available so SQLite + uploads survive rebuilds.  
   If not, data resets on rebuild — acceptable for demos; for durable free DB later use Turso/Neon free tier.

5. Dockerfile in `backend/` should expose port 7860 (HF default) or map correctly.

6. After deploy, API base is:

```
https://YOUR_USERNAME-YOUR_SPACE.hf.space
```

7. Flutter release already falls back to production URL in `api_service.dart`. Update that constant if your Space URL differs.

---

## Same code, both environments

- `DB_TYPE=sqlite` locally and on HF → one code path.
- Optional later: `DB_TYPE=mysql` + free/cloud MySQL without changing app routes.
- Reading-list APIs, bootstrap, and seeds run on startup for both.

---

## Fix Git conflict first (Windows)

You are mid-rebase on `.env.example` only.

```bat
cd C:\lakmal_code\novel_mobile_app

REM Take the remote version of the conflicted file
git checkout --theirs backend/.env.example
git add backend/.env.example

REM Continue rebase
git rebase --continue

REM If an editor opens for the commit message, save and close
REM If more conflicts appear, fix each file then: git add <file> && git rebase --continue

REM When rebase finishes:
git push origin main
```

If rebase is too messy and you are OK discarding local-only commits on main:

```bat
git rebase --abort
git fetch origin
git reset --hard origin/main
```

Then re-copy fixed `backend/app/main.py` and `backend/app/database.py` if needed.
