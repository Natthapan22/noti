# UI Issues Log — AI Island (2026-09-21)

อาการที่ผู้ใช้เจอ: "UI เพี้ยน" หลังงานรอบล่าสุด (ยังไม่ commit)
ไฟล์ที่เกี่ยวข้องอยู่ใน `git status` รอบนี้ทั้งหมด

## A. ต้นเหตุหลัก — session identity ไม่นิ่ง

| # | ปัญหา | ที่มา | อาการที่เห็น |
|---|-------|-------|--------------|
| A1 | `AgentSession.id` เป็น `UUID()` ใหม่ทุกครั้งที่ adapter refresh (ทุก 2.5s) | `AgentSession.swift` + `buildSessions()` ทุก adapter | รายการ agent rebuild ทั้งชุดทุก 2.5s → แถวกระพริบ, ScrollView เด้ง |
| A2 | `publishMerged()` เคลียร์ `selectedSessionID` เพราะหา id เดิมไม่เจอ | `AgentManager.publishMerged` | detail pane (กว้าง 260) เปิด/ปิดเองทุก 2.5s → เลย์เอาต์กระตุก, กดเลือกแล้วหลุด |
| A3 | ลายเซ็น sneak peek สร้างจาก `session.id` ที่เปลี่ยนทุกครั้ง | `AgentManager.maybeNotifyAttentionChange` | HUD "attention" เด้งซ้ำทุก 2.5s ไม่หยุด |
| A4 | `updatedAt = Date()` ใหม่ทุกรอบ → `@Published sessions` ยิงตลอด แม้ข้อมูลเท่าเดิม | `DetectingAgentAdapter.refresh` | SwiftUI re-render ทั้ง panel ตลอดเวลา |

## B. ขนาด / ตำแหน่ง notch

| # | ปัญหา | ที่มา | อาการ |
|---|-------|-------|-------|
| B1 | AI Island กว้าง 660 แต่ Home/Shelf กว้าง 640 | `matters.swift` `openNotchSize(for:)` | สลับแท็บแล้ว notch ขยายออกด้านข้าง (จอกระโดด) |
| B2 | `windowSize` hardcode 660/220 ซ้ำกับ `openNotchSize(for:)` | `matters.swift` | ตัวเลขหลุดกันได้ง่าย (drift) |
| B3 | post `notchHeightChanged` ทุกครั้งที่สลับแท็บ → `adjustWindowPosition()` + `setupDragDetectors()` ใหม่ | `BoringViewModel.applyOpenSizeForCurrentView` | ย้าย/รีเซ็ต window กลางอนิเมชัน → กระพริบ + สร้าง monitor ใหม่ไม่จำเป็น (window ขนาดคงที่อยู่แล้ว) |
| B4 | ใช้ `.smooth(duration: 0.28)` ขณะที่ ContentView ใช้ spring | เดียวกัน | อนิเมชันตีกัน (ไฟล์ ContentView ระบุไว้ว่าต้องใช้ spring ร่วม) |
| B5 | set `contentView.frame` + `setContentSize(windowSize)` ซ้ำหลังสร้าง window ที่ขนาดนั้นแล้ว | `boringNotchApp.createBoringNotchWindow` | layout pass เกิน / เสี่ยงขยับ origin ตอน launch |

## C. สถานะเปิด-ปิด notch

| # | ปัญหา | ที่มา | อาการ |
|---|-------|-------|-------|
| C1 | `hideOnClosed` default เปลี่ยน `true` → `false` (ต่างจาก upstream) | `BoringViewModel` | ตอน launch/ก่อน detector ทำงาน: จอที่ไม่มีรอยบาก/fullscreen โชว์แถบดำ + music activity + face ทั้งที่ควรซ่อน |
| C2 | `applicationShouldHandleReopen` สั่ง `openPinned()` ทุกจอ และ hover-leave ปิดไม่ได้ | `boringNotchApp` | เปิดจาก Finder/Dock แล้ว notch ค้างเปิดทุกจอ ต้องคลิกปิดเอง |
| C3 | `open()` ไม่ล้าง `keepOpen` (มีแต่ `close()` ที่ล้าง) | `BoringViewModel` | สถานะ pin รั่วข้ามเส้นทางเปิดแบบอื่น (hover/drag) |
| C4 | คลิกพื้นหลัง panel ตอน pin = ปิด notch | `ContentView.onTapGesture` | กดพลาดในพื้นที่ว่างของ AI Island แล้วปิดทั้งแผง (เจตนาออกแบบ แต่ก้าวก่ายการใช้งาน — บันทึกไว้) |
| C5 | **(ยืนยันจาก screenshot 2026-09-21 11:27)** notch ค้างเปิดทับ IDE โชว์ Demo "Permission granted / schema.prisma" | `keepOpen` กัน hover-leave ปิดถาวร + Demo Mode เปิดอยู่ | แผงดำใหญ่เกาะบนจอ ไม่หายเมื่อเอาเมาส์ออก |
| C6 | **(ยืนยันจาก screenshot 2026-09-21 11:33)** เลือก session แล้ว list+detail ข้างกัน → ดูเหมือนสองก้อนลอยแยก | `AIIslandView` HStack + detail card background | notch ไม่ได้อ่านเป็นแผงเดียว |

## D. ประสิทธิภาพ (ทำให้อนิเมชันกระตุก)

| # | ปัญหา | ที่มา | อาการ |
|---|-------|-------|-------|
| D1 | adapter 9 ตัว poll ทุก 2.5s แต่ cache TTL 2.0s → cache เก่าทุกรอบ | `ProcessDetection` + `DetectingAgentAdapter` | รัน `ps -ax` ซ้ำหลายครั้งต่อรอบ |
| D2 | `ensureCommandLineCache` ปล่อย lock ก่อน fetch → thundering herd | `ProcessDetection` | adapter 9 ตัวยิง `ps` พร้อมกัน → CPU spike → UI กระตุก |
| D3 | `isProcessRunning` spawn `pgrep` แยกต่อชื่อ ทั้งที่มี snapshot `ps` อยู่แล้ว | `ProcessDetection` | spawn process เกินจำเป็น ~9 ครั้ง/รอบ |

## E. ความถูกต้องของข้อมูลที่โชว์

| # | ปัญหา | ที่มา | หมายเหตุ |
|---|-------|-------|----------|
| E1 | แอปเปิดอยู่เฉยๆ ถูกรายงานเป็น `.working` (จุดเขียว) เช่น "Cursor app is open" | `ConcreteAdapters` / `DetectingAgentAdapter.buildSessions` | ขัดกฎที่โปรเจกต์ตั้งไว้เอง ("No fake live agent status") และทำให้ working count / chip เกินจริง |
| E2 | `.completed` กับ `.idle` map เป็น `.neutral` สีเดียวกัน | `AgentTypes.signalColorName` | แยก "เสร็จแล้ว" กับ "พร้อม" ด้วยสีไม่ได้ (คงไว้ตามดีไซน์ 4 สี — บันทึกไว้) |

## F. เรื่องที่ต้องให้คนตัดสินใจ

| # | เรื่อง | รายละเอียด |
|---|--------|-------------|
| F1 | `com.apple.security.app-sandbox` ถูกตั้งเป็น `false` | จำเป็นเพราะ sandbox ห้าม exec `/bin/ps`, `/usr/bin/pgrep` แต่กระทบ distribution/notarization + ลดชั้นป้องกัน ต้องยืนยันว่ารับ trade-off นี้ |
| F2 | build verify ไม่ได้บนเครื่องนี้ | มีแต่ Command Line Tools ไม่มี Xcode.app → ต้อง build ใน Xcode เพื่อยืนยันผล |

## สถานะการแก้

แก้แล้วในโค้ด (2026-09-21) — `xcodebuild` Debug **BUILD SUCCEEDED**
ยังไม่ได้ดูบนจอจริง ต้องเปิดแอปแล้วเช็ค notch เอง

- A1–A4: `DetectingAgentAdapter` เก็บ id ตาม key แล้วข้าม `subject.send` ถ้าข้อมูลเดิม (ไม่สน `updatedAt`)
- D1–D3: cache TTL 4s, ถือ lock ระหว่าง `ps`, `isProcessRunning` อ่านจาก snapshot เดิม
- B1–B2: AI Island กว้างเท่า Home/Shelf (640) สูง 220, `windowSize` คำนวณจากค่านี้
- B3–B4: ไม่ post `notchHeightChanged` ตอนสลับแท็บ, ใช้ interactive spring ชุดเดียวกับ ContentView
- B5: ลบ `contentView.frame` + `setContentSize` ที่ซ้ำ
- C1: `hideOnClosed = true`
- C2–C3: reopen pin เฉพาะจอที่เลือก, `open()` ล้าง `keepOpen` แล้ว `openPinned()` ค่อยตั้งกลับ
- C4–C5: เอา tap-ทั้งแผงตอนเปิดออก (ไม่ชนปุ่ม), hover-leave ปิดได้แม้ pin (grace 1.2s), Dock pin หมดอายุ 5s ถ้าไม่เคย hover
- C6: AI Island แสดง list หรือ detail อย่างใดอย่างหนึ่ง (ไม่ข้างกัน) + detail เลื่อนได้ ไม่มี card แยก
- E1: แอปเปิดเฉยๆ = `.idle` / "Ready", `.working` เฉพาะเมื่อเจอ process ของ agent

คงไว้โดยเจตนา: E2
รอผู้ใช้ตัดสิน: F1 (sandbox ยังปิดอยู่)
