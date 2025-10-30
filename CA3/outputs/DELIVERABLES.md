# CA3 Deliverables Checklist

## Required Outputs (Per Assignment Guidelines)

### ✅ Observability

- [x] **grafana-dashboard.png** (or similar name)
  - Screenshot of Grafana showing "CA3 Pipeline Metrics" dashboard
  - Must show 3 Prometheus panels:
    - Panel 1: Producer rate (events emitted/sec)
    - Panel 2: Processor rate (messages consumed/sec)
    - Panel 3: Database inserts/sec (InfluxDB writes)
  - **Status**: User needs to screenshot Grafana UI
  - **How to capture**:
    ```bash
    kubectl get svc grafana-service -n conveyor-pipeline
    # Access Grafana at NodePort URL
    # Navigate to "CA3 Pipeline Metrics" dashboard
    # Screenshot showing all 3 panels with live data
    ```

- [x] **log-search.png** (or similar name)
  - Screenshot of Loki log search filtered by keyword (e.g., "error")
  - Must show logs from multiple components
  - **Status**: User needs to screenshot Grafana Explore with Loki
  - **How to capture**:
    ```bash
    # In Grafana → Explore → Select "Loki" datasource
    # Query: {namespace="conveyor-pipeline"} |= "error"
    # Screenshot showing filtered log results
    ```

### ✅ Scaling & Performance

- [x] **scaling-test-results.md** ✓ COMPLETE
  - HPA scaling test documentation (1→2→1 replicas)
  - Includes CPU metrics and pod status
  - Location: `CA3/outputs/scaling-test-results.md`

- [x] **hpa-scaling.png** (or similar name)
  - Screenshot of HPA scaling events
  - **Status**: User needs to screenshot `kubectl get hpa` during load test
  - **How to capture**:
    ```bash
    # Terminal 1: Run load test
    bash scripts/load-test.sh 120

    # Terminal 2: Watch HPA
    kubectl get hpa -n conveyor-pipeline --watch
    # Screenshot when HPA shows replica count change
    ```

- [x] **hpa-scaling-events.txt** ✓ COMPLETE
  - Text output of HPA events
  - Location: `CA3/outputs/hpa-scaling-events.txt`

### ✅ Security

- [x] **tls-config-summary.md** ✓ COMPLETE
  - Complete TLS implementation documentation
  - Location: `CA3/outputs/tls-config-summary.md`

- [x] **network-policies.yaml** ✓ COMPLETE
  - NetworkPolicy configuration (inherited from CA2)
  - Location: `CA3/outputs/network-policies.yaml`

### ✅ Resilience

- [x] **resilience-test-summary.md** ✓ COMPLETE
  - Failure injection test results and analysis
  - Location: `CA3/outputs/resilience-test-summary.md`

- [x] **operator-procedures.md** ✓ COMPLETE
  - Comprehensive troubleshooting runbook
  - Location: `CA3/outputs/operator-procedures.md`

- [x] **pod-recovery-status.txt** ✓ COMPLETE
  - Pod status after automated recovery
  - Location: `CA3/outputs/pod-recovery-status.txt`

- [x] **resilience-drill.mp4** (or similar name)
  - Video demonstration (≤3 min) showing failure injection and recovery
  - **Status**: User needs to record video
  - **How to capture**:
    ```bash
    # Start screen recording (OBS, QuickTime, Windows Game Bar, etc.)
    # Run: bash scripts/resilience-test.sh
    # Show: Pod deletions, automatic recovery, logs verification
    # Stop recording when all tests complete
    # Save as: CA3/outputs/resilience-drill.mp4
    ```

### ✅ Documentation

- [x] **README.md** ✓ COMPLETE
  - Complete CA3 documentation
  - Location: `CA3/README.md`

- [x] **MILESTONES.md** ✓ COMPLETE
  - Milestone tracking document
  - Location: `CA3/MILESTONES.md`

---

## Additional Deliverables (Bonus/Reference)

- [x] **scaling-demonstration.md** ✓ COMPLETE
  - 1→5 pod scaling demonstration
  - Location: `CA3/outputs/scaling-demonstration.md`

---

## Summary

### Completed Deliverables (8/11)
✅ Complete and ready for submission:
1. scaling-test-results.md
2. hpa-scaling-events.txt
3. tls-config-summary.md
4. network-policies.yaml
5. resilience-test-summary.md
6. operator-procedures.md
7. pod-recovery-status.txt
8. README.md

### Pending User Screenshots (3/11)
📸 User needs to capture:
1. **grafana-dashboard.png** - Screenshot of Grafana with 3 Prometheus panels
2. **log-search.png** - Screenshot of Loki log search in Grafana Explore
3. **hpa-scaling.png** - Screenshot of HPA scaling during load test
4. **resilience-drill.mp4** - Video recording of resilience test (≤3 min)

---

## Quick Capture Guide

### 1. Grafana Dashboard Screenshot

**Steps:**
```bash
# Get Grafana URL
kubectl get svc grafana-service -n conveyor-pipeline
# Example output: NodePort 30715

# Open in browser
# http://localhost:30715

# Login: admin / <password-from-secrets.yaml>

# Navigate to: Dashboards → CA3 Pipeline Metrics

# Wait for data to load (5-10 seconds)

# Screenshot showing:
# - All 3 panels visible
# - Panel 1: Producer Rate with graph
# - Panel 2: Processor Rate with graph
# - Panel 3: InfluxDB Writes with graph
# - Timestamp visible
```

**Save as:** `CA3/outputs/grafana-dashboard.png`

---

### 2. Loki Log Search Screenshot

**Steps:**
```bash
# Access Grafana (same URL as above)

# Click: Explore (compass icon in sidebar)

# Select datasource: Loki

# Enter query:
{namespace="conveyor-pipeline"} |= "error"

# Or for InfluxDB writes:
{namespace="conveyor-pipeline", app="processor"} |= "InfluxDB write"

# Click: Run query

# Screenshot showing:
# - Query at top
# - Log results with timestamps
# - Multiple pods visible in logs
# - Highlighted search terms
```

**Save as:** `CA3/outputs/log-search.png`

---

### 3. HPA Scaling Screenshot

**Steps:**
```bash
# Terminal 1: Start load test
cd CA3
bash scripts/load-test.sh 120

# Terminal 2: Watch HPA
kubectl get hpa -n conveyor-pipeline --watch

# Wait for:
# - TARGETS column to show CPU > 70%
# - REPLICAS column to increase from 1 to 2

# Screenshot showing:
# - HPA name: producer-hpa
# - TARGETS: 150%/70% (or similar high value)
# - REPLICAS: 2/5 (scaled up)
# - Or events showing "New size: 2"
```

**Alternative - Describe HPA:**
```bash
kubectl describe hpa producer-hpa -n conveyor-pipeline
# Screenshot the Events section showing scale-up
```

**Save as:** `CA3/outputs/hpa-scaling.png`

---

### 4. Resilience Drill Video

**Steps:**
```bash
# 1. Start screen recording software
# - Windows: Windows Key + G (Game Bar) → Record
# - Mac: QuickTime Player → File → New Screen Recording
# - Linux: SimpleScreenRecorder, OBS Studio

# 2. Open terminal and run:
cd CA3
bash scripts/resilience-test.sh

# 3. Video should capture:
# - Initial pod status (all running)
# - Test 1: Producer deletion and recovery
# - Test 2: Processor deletion and recovery
# - Test 3: Kafka deletion and recovery
# - Final pod status (all recovered)
# - Duration: ~2.5 minutes

# 4. Optional: Narrate or add text overlay explaining:
# - What's being tested
# - Expected vs actual behavior
# - Recovery times

# 5. Stop recording

# 6. Save/export video
```

**Requirements:**
- Duration: ≤3 minutes
- Format: MP4 (preferred), AVI, MOV
- Quality: 720p or higher
- Audio: Optional (narration adds value but not required)
- Captions: Optional

**Save as:** `CA3/outputs/resilience-drill.mp4`

**Alternative (No Video):**
If video recording is not possible, capture multiple screenshots:
- `resilience-before.png` - Initial pod status
- `resilience-producer-deleted.png` - After producer deletion
- `resilience-producer-recovered.png` - After producer recovery
- `resilience-processor-deleted.png` - After processor deletion
- `resilience-processor-recovered.png` - After processor recovery
- `resilience-kafka-deleted.png` - After Kafka deletion
- `resilience-kafka-recovered.png` - After Kafka recovery
- `resilience-final.png` - Final status

---

## Verification Commands

Before submission, verify all deliverables:

```bash
cd CA3/outputs

# Check required markdown files
ls -lh *.md

# Check screenshots (after capturing)
ls -lh *.png

# Check video (after recording)
ls -lh *.mp4

# Check text outputs
ls -lh *.txt *.yaml

# Count deliverables
ls -1 | wc -l
# Expected: 11-15 files (depending on screenshots/video captured)
```

---

## Submission Checklist

Before committing to GitHub:

- [ ] All markdown documentation complete
- [ ] Screenshots captured (grafana-dashboard.png, log-search.png, hpa-scaling.png)
- [ ] Video recorded (resilience-drill.mp4) OR alternative screenshots
- [ ] README.md updated with all CA3 features
- [ ] No secrets.yaml file in outputs (check .gitignore)
- [ ] No TLS private keys committed (check k8s/tls/)
- [ ] All file paths relative (no absolute Windows paths)
- [ ] Clean `git status` (no untracked sensitive files)

---

## File Size Guidelines

- **Screenshots**: < 5 MB each (PNG, JPG)
- **Video**: < 50 MB (compress if needed)
- **Markdown files**: < 100 KB each
- **Total outputs/ directory**: < 100 MB

If video is too large, consider:
- Reducing resolution to 720p
- Using H.264 codec
- Trimming to essential content only (2-3 min max)

---

## Final Notes

**What to commit:**
✅ All markdown files
✅ Screenshots (.png files)
✅ Video (.mp4 file) - if size permits
✅ Text outputs (.txt, .yaml files)
✅ README.md
✅ All k8s/ manifests (except secrets.yaml)
✅ All scripts/

**What NOT to commit:**
❌ secrets.yaml
❌ TLS private keys (*.key, *.pem files)
❌ Temporary files (.swp, .tmp)
❌ IDE config (.idea, .vscode)
❌ Docker images

---

## Questions?

Refer to:
- `CA3/README.md` - Complete setup and usage guide
- `CA3/MILESTONES.md` - Milestone breakdown
- `CA3/outputs/operator-procedures.md` - Troubleshooting guide
- `CA3/outputs/resilience-test-summary.md` - Test methodology
