# EyeSense Live Pitch Demo Script

**Target Event:** MUA Innovation Week 2026 (12 October 2026)  
**Presenter:** Raymond Robert Klanderman  
**Total Duration:** ~3 Minutes  

---

## 1. Setup & Pre-Flight Checklist
- [ ] Phone volume set to 80% (or connected to external demo speaker).
- [ ] Rear camera lens cleaned.
- [ ] Sample printed sign placed on table: **"MUA Innovation Week 2026 — Welcome"**.
- [ ] Visible chair and doorway in line-of-sight in demo area.
- [ ] Network connection active (Wi-Fi or mobile data).
- [ ] Backup offline video cue ready on second display.

---

## 2. Demonstration Flow

### Scene 1: Introduction (30 seconds)
> *"Judges and guests, visual assistance apps today either bombard users with unverified assertions or require constant internet connectivity for simple tasks. EyeSense is built differently: it is bounded, privacy-first, and designed for genuine blind and low-vision autonomy."*

### Scene 2: Describe Mode (45 seconds)
1. Point phone at the room stage (chair, table, doorway).
2. Tap the large **Describe** button (top action).
3. The app announces *"Taking a picture"* $\to$ *"Describing scene"*.
4. EyeSense speaks aloud:
   > *"A chair is visible near the centre of the image. A doorway is on the right."*
5. Highlight:
   > *"Notice that directions refer strictly to regions of the camera view, and the system never asserts dangerous assumptions like 'it is safe to walk'."*

### Scene 3: Read Text Mode (45 seconds)
1. Point phone at the printed sign: *"MUA Innovation Week 2026 — Welcome"*.
2. Tap **Read Text** (secondary action).
3. EyeSense processes on-device locally in real time (zero cloud roundtrips):
   > *"MUA Innovation Week 2026 Welcome"*
4. Highlight:
   > *"This OCR runs completely on-device using ML Kit without uploading a single pixel to the cloud, guaranteeing privacy and offline resilience."*

### Scene 4: Visual Question Answering (Ask Mode) (45 seconds)
1. Tap **Ask**.
2. Speak or select voice input: *"Where is the door?"*
3. EyeSense takes a fresh frame and answers:
   > *"The doorway is on the right side of the image."*
4. Tap **Stop** mid-playback to demonstrate instant cancellation.
5. Tap **Repeat** to demonstrate deterministic replay without wasteful re-computation.

---

## 3. Honest Backup & Failure Recovery Plan

If the venue Wi-Fi or cellular network degrades during the pitch:
1. Immediately switch to **Read Text** mode: this is 100% on-device and functions seamlessly in airplane mode.
2. If cloud vision fails or times out, EyeSense announces a truthful recovery message: *"Visual analysis timed out. Please try again."*
3. If necessary, switch to the pre-recorded video backup file:
   - Clearly state: *"Judges, due to venue network degradation, I am presenting our verified device screen recording captured earlier today."*
   - Never misrepresent a pre-recorded backup as live inference.
