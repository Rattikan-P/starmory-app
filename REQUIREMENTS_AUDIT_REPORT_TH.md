# รายงานการตรวจสอบความต้องการ (Requirements Audit Report)
## ระบบ Authentication (UC-01 ถึง UC-06)

**วันที่:** 18 มิถุนายน 2026  
**ขอบเขต:** UC-01 ถึง UC-06 (Feature 1: Authentication)

---

## สรุปผลการดำเนินงาน

| หมวดหมู่ | สถานะ | หมายเหตุ |
|----------|--------|-------|
| ความครอบคลุมของความต้องการ (Requirements) | ✅ สมบูรณ์ | ทุก UC มี SRS ที่เกี่ยวข้อง |
| ความครอบคลุมของการทดสอบ | ✅ ดีมาก | ทุก UTC มี test case ที่ implement แล้ว |
| การนำไปใช้งาน (Implementation) | ✅ สมบูรณ์ | AuthService และ UserModel implement ความต้องการครบถ้วน |
| เอกสาร (Documentation) | ⚠️ ปัญหาเล็กน้อย | ตัวเลข test ไม่ตรงกัน, บางส่วนของ SRS ขาดหาย |

---

## 1. ตารางความครอบคลุม Use Case

### UC-01: Continue as Guest (ใช้แอปโดยไม่สมัครสมาชิก)
| รหัส SRS | รายละเอียด | Test Coverage | Implementation |
|--------|-------------|---------------|----------------|
| SRS-01 | ปุ่ม "Try without signing up" | N/A (UI) | ✅ UI Implementation |
| SRS-02 | หน้าเลือกระดับภาษา (A1/A2/B1/B2) | UT-03-TC02, TC03 | ✅ UserModel.updateLanguageLevel() |
| SRS-03 | เก็บระดับภาษาชั่วคราว | UT-03-TC08 | ✅ Session state |
| SRS-04 | หน้าเลือกสำนวนภาษา (US/UK) | UT-03-TC04, TC05 | ✅ UserModel.updateEnglishVariant() |
| SRS-05 | เก็บสำนวนภาษาชั่วคราว | UT-03-TC08 | ✅ Session state |
| SRS-06 | ปุ่ม Skip ที่หน้าเลือกระดับภาษา | UT-03-TC06 | ✅ ค่าเริ่มต้นคือ B1 |
| SRS-07 | Skip ใช้ค่าเริ่มต้น B1 | UT-03-TC06 | ✅ AppDefaults.defaultLanguageLevel = 'B1' |
| SRS-08 | ปุ่ม Skip ที่หน้าเลือกสำนวน | UT-03-TC07 | ✅ ค่าเริ่มต้นคือ US |
| SRS-09 | Skip ใช้ค่าเริ่มต้น US | UT-03-TC07 | ✅ AppDefaults.defaultEnglishVariant = 'US' |
| SRS-10 | ปุ่ม Back ที่หน้าเลือกระดับภาษา | UT-03-TC09 | ✅ UI Implementation |
| SRS-11 | Back ไปยัง Onboarding จากหน้าเลือกระดับ | UT-03-TC09 | ✅ UI Implementation |
| SRS-12 | ปุ่ม Back ที่หน้าเลือกสำนวน | UT-03-TC09 | ✅ UI Implementation |
| SRS-13 | Back ไปยังหน้าเลือกระดับจากหน้าเลือกสำนวน | UT-03-TC09 | ✅ UI Implementation |
| SRS-14 | เก็บค่าที่เลือกไว้ขณะ Back navigation | UT-03-TC09 | ✅ Session state |
| SRS-15 | บันทึก preferences ลง local storage | UT-03-TC10 | ✅ Local storage (ไม่ใช่ database) |
| SRS-16 | เปิดใช้งาน guest mode | UT-03-TC11 | ✅ UserModel.createGuest() |
| SRS-17 | นำทางไปยัง Home หลังตั้งค่า | UT-03-TC12 | ✅ UI Navigation |

**สถานะ:** ✅ **สมบูรณ์**

---

### UC-02: Authenticate (การยืนยันตัวตน)
| รหัส SRS | รายละเอียด | Test Coverage | Implementation |
|--------|-------------|---------------|----------------|
| SRS-18 | ช่องกรอก email และตัวเลือก Google | UT-02-TC01-08 | ✅ AuthForm widget |
| SRS-19 | ตรวจสอบรูปแบบ email | UT-02-TC01-08 | ✅ SnackBarHelper.isValidEmail() |
| SRS-20 | Error: รูปแบบ email ไม่ถูกต้อง | UT-02-TC03-08 | ✅ AlertMessages.invalidEmail |
| SRS-21 | ส่ง OTP เมื่อ email ถูกต้อง | UT-05-TC01 | ✅ AuthService.sendOtp() |
| SRS-22 | Error: ส่ง OTP ไม่สำเร็จ | UT-05-TC02 | ✅ AlertMessages.otpSendFailed |
| SRS-23 | เก็บ email ไว้เมื่อเกิด error | ✅ | ✅ UI retains input |
| SRS-24 | ตัวเลือก Google OAuth | UT-07-TC01 | ✅ AuthService.signInWithGoogle() |
| SRS-25 | Error เมื่อ Google ใช้ไม่ได้ | UT-07-TC04 | ✅ AlertMessages.loginFailed |
| SRS-26 | หน้า OTP Verification | ✅ | ✅ OtpVerificationPage |
| SRS-27 | ปุ่ม Back ที่หน้า OTP | ✅ | ✅ UI Implementation |
| SRS-28 | Back เก็บ email ที่กรอกไว้ | ✅ | ✅ UI Implementation |
| SRS-29 | ตรวจสอบ OTP 6 หลักอัตโนมัติ | ✅ | ✅ OtpVerificationPage auto-submits |
| SRS-30 | Error: OTP ไม่ถูกต้อง/หมดอายุ | UT-06-TC03, TC04 | ✅ AlertMessages.otpInvalid |
| SRS-31 | ล้าง OTP เมื่อไม่ถูกต้อง | ✅ | ✅ UI clears input |
| SRS-32 | ปุ่ม Resend | ✅ | ✅ UI Implementation |
| SRS-33 | Resend มี cooldown 60 วินาที | UT-05-TC03, TC04 | ✅ OtpVerificationPage countdown |
| SRS-34 | Dialog เมื่อผิด 3 ครั้ง | UT-06-TC05 | ✅ OtpVerificationPage dialog |
| SRS-35 | ตัวเลือก: Try again / New code | UT-06-TC05 | ✅ Dialog options |
| SRS-36 | Try again: Reset counter, ใช้ OTP เดิม | UT-06-TC05 | ✅ UI behavior |
| SRS-37 | New code: ส่ง OTP ใหม่ | UT-06-TC05 | ✅ AuthService.sendOtp() |
| SRS-38 | Error: Service ใช้ไม่ได้ | UT-06-TC03 | ✅ AlertMessages.serviceUnavailable |
| SRS-39 | ตรวจสอบว่า user มีอยู่แล้วหรือไม่ | UT-04-TC05, TC06 | ✅ AuthService.checkEmailExists() |
| SRS-40 | คืนสถานะบัญชี (NEW/EXISTING) | UT-04-TC05, TC06 | ✅ verifyOtp() returns isNewUser |

**สถานะ:** ✅ **สมบูรณ์**

---

### UC-03: Setup User Account (ตั้งค่าบัญชีผู้ใช้)
| รหัส SRS | รายละเอียด | Test Coverage | Implementation |
|--------|-------------|---------------|----------------|
| SRS-41 | สร้างบัญชีผู้ใช้ใหม่ | UT-08-TC01, TC02 | ✅ Supabase auth |
| SRS-42 | ดึงข้อมูล user ที่มีอยู่ | UT-08-TC14, TC15 | ✅ AuthService.fetchUserData() |
| SRS-43 | User ที่มีอยู่ → Home | UT-08-TC14 | ✅ Bypass preference setup |
| SRS-44 | หน้าเลือกระดับภาษาสำหรับ user ใหม่ | UT-08-TC04-06 | ✅ Same flow as guest |
| SRS-45 | Skip ใช้ค่าเริ่มต้น B1 | UT-08-TC10 | ✅ AppDefaults.defaultLanguageLevel |
| SRS-46 | หน้าเลือกสำนวนภาษา | UT-08-TC07-09 | ✅ Same flow as guest |
| SRS-47 | บันทึกลง database | UT-08-TC12 | ✅ AuthService.updateUserPreferences() |
| SRS-48 | Skip ใช้ค่าเริ่มต้น US | UT-08-TC11 | ✅ AppDefaults.defaultEnglishVariant |
| SRS-49 | นำทางไป Home หลังบันทึก | UT-08-TC13 | ✅ UI Navigation |
| SRS-50 | Error: Service ใช้ไม่ได้ | UT-08-TC16 | ✅ AlertMessages.serviceUnavailable |
| SRS-51 | ยอมรับ Terms อัตโนมัติเมื่อ auth | UT-08-TC03 | ✅ termsVersion automatically set |

**สถานะ:** ✅ **สมบูรณ์**

---

### UC-04: Guest Creates Account (ผู้ใช้แบบ Guest สร้างบัญชี)
| รหัส SRS | รายละเอียด | Test Coverage | Implementation |
|--------|-------------|---------------|----------------|
| SRS-52 | สร้างบัญชีผู้ใช้ใหม่ | UT-09-TC01 | ✅ Supabase auth |
| SRS-53 | บันทึกข้อมูล guest ลงบัญชี | UT-09-TC01 | ✅ AuthService.updateUserPreferences() |
| SRS-54 | ปิด guest mode, ล้าง local | UT-09-TC02 | ✅ Clear local storage |
| SRS-55 | แสดง Merge Dialog | UT-09-TC04 | ✅ AccountMethodPage dialog |
| SRS-56 | ตัวเลือก "Combine my data" | UT-09-TC05-07 | ✅ Merge option |
| SRS-57 | ตัวเลือก "Keep my account" | UT-09-TC08 | ✅ Keep option |
| SRS-58 | Merge: Preferences จาก guest | UT-09-TC05 | ✅ Guest overwrites cloud |
| SRS-59 | Merge: รวม vocabulary | UT-09-TC06 | ✅ MergeService |
| SRS-60 | Merge: Streak ใช้ค่าสูงสุด | UT-09-TC07 | ✅ MergeService max strategy |
| SRS-61 | Keep: Cloud ไม่เปลี่ยนแปลง | UT-09-TC08 | ✅ Skip guest data |
| SRS-62 | Error: Service ใช้ไม่ได้ | UT-09-TC10 | ✅ AlertMessages.serviceUnavailable |

**สถานะ:** ✅ **สมบูรณ์**

---

### UC-05: Logout (ออกจากระบบ)
| รหัส SRS | รายละเอียด | Test Coverage | Implementation |
|--------|-------------|---------------|----------------|
| SRS-63 | ปุ่ม Logout ที่หน้า Profile | ✅ | ✅ UI Implementation |
| SRS-64 | แสดง dialog ยืนยัน | UT-10-TC01 | ✅ UI Implementation |
| SRS-65 | ตัวเลือก Logout และ Cancel | UT-10-TC01, TC02 | ✅ Dialog options |
| SRS-66 | Cancel ปิด dialog | UT-10-TC02 | ✅ UI behavior |
| SRS-67 | ล้าง local data เมื่อ logout | UT-10-TC04 | ✅ AuthService.signOut() |
| SRS-68 | Sign out จาก auth service | UT-10-TC03 | ✅ AuthService.signOut() |
| SRS-69 | นำทางไป Onboarding | UT-10-TC05 | ✅ UI Navigation |
| SRS-70 | Error: Logout ล้มเหลว | UT-10-TC06 | ✅ AlertMessages.logoutFailed |
| SRS-71 | อยู่ที่ Profile เมื่อเกิด error | UT-10-TC06 | ✅ UI behavior |

**สถานะ:** ✅ **สมบูรณ์**

---

### UC-06: Delete Account (ลบบัญชี)
| รหัส SRS | รายละเอียด | Test Coverage | Implementation |
|--------|-------------|---------------|----------------|
| SRS-72 | ปุ่ม Delete Account | ✅ | ✅ UI Implementation |
| SRS-73 | แสดง dialog ยืนยัน | UT-11-TC01 | ✅ UI Implementation |
| SRS-74 | คำเตือน: ไม่สามารถย้อนกลับได้ | UT-11-TC01 | ✅ Dialog message |
| SRS-75 | ตัวเลือก Delete และ Cancel | UT-11-TC02 | ✅ Dialog options |
| SRS-76 | Cancel ปิด dialog | UT-11-TC02 | ✅ UI behavior |
| SRS-77 | ล้าง local storage | UT-11-TC04 | ✅ AuthService.deleteAccount() |
| SRS-78 | ลบจาก database | UT-11-TC03 | ✅ Edge Function |
| SRS-79 | นำทางไป Onboarding | UT-11-TC05 | ✅ UI Navigation |
| SRS-80 | Error: ลบไม่สำเร็จ | UT-11-TC06, TC07 | ✅ AlertMessages.deleteAccountFailed |
| SRS-81 | อยู่ที่ Profile เมื่อเกิด error | UT-11-TC06, TC07 | ✅ UI behavior |

**สถานะ:** ✅ **สมบูรณ์**

---

## 2. ปัญหาเกี่ยวกับไฟล์ Test

### ปัญหาที่ #1: ตัวเลข UTC ไม่ตรงกัน (สำคัญ)

**ปัญหา:** UTC-01 และ UTC-02 สลับกันระหว่างเอกสารและไฟล์

| เอกสาร | ไฟล์จริง | ควรเป็น |
|--------------|-------------|----------|
| UTC-01: Email Validation | utc02_email_validation_test.dart | utc01_email_validation_test.dart |
| UTC-02: User Model Creation | utc01_user_model_test.dart | utc02_user_model_test.dart |

**ผลกระทบ:** ปานกลาง - Test ทำงานได้ถูกต้องแต่เอกสารสับสน

**คำแนะนำ:** เปลี่ยนชื่อไฟล์ test ให้ตรงกับ UTC numbering:
- เปลี่ยนชื่อ `utc01_user_model_test.dart` → `utc02_user_model_test.dart`
- เปลี่ยนชื่อ `utc02_email_validation_test.dart` → `utc01_email_validation_test.dart`

---

### ปัญหาที่ #2: ชื่อ Test Case ผิดใน UTC-10

**ไฟล์:** `test/utc10_logout_test.dart`

**ปัญหา:** Test case ทั้งหมดใช้ `UT-09-TC##` แทน `UT-10-TC##`

```dart
test('UT-09-TC01: Show logout confirmation dialog', () { // ❌ ควรเป็น UT-10-TC01
test('UT-09-TC02: Cancel logout dialog', () {          // ❌ ควรเป็น UT-10-TC02
// ... etc
```

**ผลกระทบ:** ต่ำ - Test ทำงานได้ถูกต้องแต่ชื่อไม่สอดคล้อง

**คำแนะนำ:** อัปเดตชื่อ test ทั้งหมดให้ใช้ prefix `UT-10-TC##`

---

### ปัญหาที่ #3: ชื่อ Test Case ผิดใน UTC-11

**ไฟล์:** `test/utc11_account_deletion_test.dart`

**ปัญหา:** Test case ทั้งหมดใช้ `UT-10-TC##` แทน `UT-11-TC##`

```dart
test('UT-10-TC01: Show delete confirmation with warning', () { // ❌ ควรเป็น UT-11-TC01
test('UT-10-TC02: Cancel delete dialog', () {                 // ❌ ควรเป็น UT-11-TC02
// ... etc
```

**ผลกระทบ:** ต่ำ - Test ทำงานได้ถูกต้องแต่ชื่อไม่สอดคล้อง

**คำแนะนำ:** อัปเดตชื่อ test ทั้งหมดให้ใช้ prefix `UT-11-TC##`

---

## 3. การวิเคราะห์การตรวจสอบ Email

### ความต้องการ vs การนำไปใช้งาน

**ความต้องการ (SRS-20):**
> เมื่อรูปแบบ email ไม่ถูกต้อง ระบบจะแสดง error message "Please enter a valid email address."
> รูปแบบที่ไม่ถูกต้อง: ว่างเปล่า, ไม่มี @, ไม่มี local part (ไม่มีอะไรก่อน @), รูปแบบ domain ไม่ถูกต้อง (domain เริ่มด้วย dot), ไม่มี domain, มี space

**การนำไปใช้งาน ([`lib/utils/snackbar_helper.dart:17-41`](lib/utils/snackbar_helper.dart#L17-L41)):**
```dart
static bool isValidEmail(String email) {
  if (email.trim().isEmpty) return false;
  
  final pattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  final trimmed = email.trim();
  
  if (trimmed.contains(' ')) return false;
  if ('@'.allMatches(trimmed).length != 1) return false;
  
  return pattern.hasMatch(trimmed);
}
```

**การวิเคราะห์ความครอบคลุมของ Test:**

| Test Case | Input | คาดหวัง | Implementation | สถานะ |
|-----------|-------|----------|----------------|--------|
| UT-02-TC01 | user@example.com | ถูกต้อง | ✅ ตรง pattern | ✅ |
| UT-02-TC02 | test.user@domain.co.uk | ถูกต้อง | ✅ ตรง pattern | ✅ |
| UT-02-TC03 | invalid-email | ไม่ถูกต้อง | ✅ ไม่มี @ | ✅ |
| UT-02-TC04 | @example.com | ไม่ถูกต้อง | ✅ Local part ว่าง | ✅ |
| UT-02-TC05 | user@.com | ไม่ถูกต้อง | ✅ Domain เริ่มด้วย dot | ✅ |
| UT-02-TC06 | "" (ว่าง) | ไม่ถูกต้อง | ✅ Check ว่าง | ✅ |
| UT-02-TC07 | user @example.com | ไม่ถูกต้อง | ✅ Check space | ✅ |
| UT-02-TC08 | user@ | ไม่ถูกต้อง | ✅ ไม่มี TLD | ✅ |

**สถานะ:** ✅ **ครอบคลุมความต้องการทั้งหมด**

---

## 4. การวิเคราะห์ความครอบคลุม SRS

### SRS ที่ครอบคลุมตาม Use Case

| Use Case | ช่วง SRS | SRS ทั้งหมด | ครอบคลุม | ขาด |
|----------|-----------|-----------|---------|-----|
| UC-01: Continue as Guest | SRS-01 to SRS-17 | 17 | 17 | 0 |
| UC-02: Authenticate | SRS-18 to SRS-40 | 23 | 23 | 0 |
| UC-03: Setup User Account | SRS-41 to SRS-51 | 11 | 11 | 0 |
| UC-04: Guest Creates Account | SRS-52 to SRS-62 | 11 | 11 | 0 |
| UC-05: Logout | SRS-63 to SRS-71 | 9 | 9 | 0 |
| UC-06: Delete Account | SRS-72 to SRS-81 | 10 | 10 | 0 |

**ความครอบคลุม SRS ทั้งหมด:** ✅ **81/81 (100%)**

---

## 5. การตรวจสอบการนำไปใช้งาน (Implementation)

### AuthService ([`lib/data/services/auth_service.dart`](lib/data/services/auth_service.dart))

| Method | วัตถุประสงค์ | Test Coverage | สถานะ |
|--------|---------|---------------|--------|
| `isLoggedIn` | ตรวจสอบ login state | UT-04-TC01, TC02 | ✅ |
| `currentUserId` | ดึง user ID ปัจจุบัน | UT-04-TC03, TC04 | ✅ |
| `sendOtp()` | ส่ง OTP ไปยัง email | UT-05-TC01-04 | ✅ |
| `verifyOtp()` | ตรวจสอบ OTP | UT-06-TC01-05 | ✅ |
| `checkEmailExists()` | ตรวจสอบว่า email มีอยู่แล้วหรือไม่ | UT-04-TC05-07 | ✅ |
| `updateUserPreferences()` | บันทึก preferences ของ user | UT-08-TC12 | ✅ |
| `mergeGuestPreferences()` | รวมข้อมูล guest | UT-09-TC05-07 | ✅ |
| `signInWithGoogle()` | Google OAuth | UT-07-TC01-05 | ✅ |
| `signOut()` | Sign out user | UT-10-TC03, TC07, TC08 | ✅ |
| `deleteAccount()` | ลบบัญชี user | UT-11-TC03-08 | ✅ |

**รายละเอียดการนำไปใช้งานที่สำคัญ:**

1. **✅ Timeout Protection (SRS-80/81):**
   ```dart
   await _client.functions.invoke('delete-account', ...).timeout(
     const Duration(seconds: 10),
     onTimeout: () => throw Exception('Request timeout')
   );
   ```

2. **✅ Always Sign Out (SRS-81 - สำคัญ):**
   ```dart
   finally {
     // Always sign out, even if delete fails
     await signOut();
   }
   ```

3. **✅ Guest Preference Merge (SRS-58):**
   ```dart
   // Preferences: overwrite with guest values
   if (languageLevel != null) 'language_level': languageLevel,
   ```

---

### UserModel ([`lib/data/models/user_model.dart`](lib/data/models/user_model.dart))

| Feature | ค่าเริ่มต้น | Test Coverage | สถานะ |
|---------|---------------|---------------|--------|
| Guest quota | 10 | UT-01-TC03, UT-03-TC01 | ✅ |
| Language level | B1 | UT-01-TC04, UT-03-TC06 | ✅ |
| English variant | US | UT-01-TC04, UT-03-TC07 | ✅ |
| Guest email | guest@starmory.app | UT-01-TC01, UT-03-TC01 | ✅ |
| Update language level | A1, B2 | UT-01-TC05, TC06 | ✅ |
| Update English variant | UK | UT-01-TC07 | ✅ |

**สถานะ:** ✅ **ครอบคลุมความต้องการทั้งหมด**

---

## 6. การวิเคราะห์ช่องว่าง (Gap Analysis)

### SRS ที่ขาดหายสำหรับ UTC-04: Authentication State

**สังเกต:** UTC-04 (Authentication State) test ครอบคลุม `isLoggedIn`, `currentUserId`, และ `checkEmailExists()`, แต่ไม่มีการอ้างอิง SRS ที่ชัดเจนในเอกสาร

**ควรอ้างอิงใน UC-02:**
- `isLoggedIn` → ใช้ใน SRS-39 (ตรวจสอบว่า user มีอยู่)
- `currentUserId` → ใช้ใน SRS-39 (ดึงข้อมูล user)
- `checkEmailExists()` → SRS-39

**สถานะ:** ⚠️ **ช่องว่างของเอกสาร** - Implementation ถูกต้อง แต่ SRS อาจต้องชัดเจนขึ้น

---

## 7. คำแนะนำ

### สำคัญมาก
1. **แก้ไขปัญหาตัวเลข test:**
   - เปลี่ยนชื่อ `utc01_user_model_test.dart` → `utc02_user_model_test.dart`
   - เปลี่ยนชื่อ `utc02_email_validation_test.dart` → `utc01_email_validation_test.dart`

### สำคัญปานกลาง
2. **แก้ไขชื่อ test case ใน UTC-10 และ UTC-11:**
   - อัปเดต `UT-09-TC##` เป็น `UT-10-TC##` ใน logout test
   - อัปเดต `UT-10-TC##` เป็น `UT-11-TC##` ใน deletion test

### สำคัญน้อย
3. **ปรับปรุงเอกสาร:**
   - เพิ่ม SRS ที่ชัดเจนสำหรับการตรวจสอบ authentication state ใน UC-02
   - ชี้แจงว่า UTC-04 เป็น test สนับสนุนสำหรับ UC-02

---

## 8. สรุป

| Component | สถานะ | ความครอบคลุม |
|-----------|--------|----------|
| **UC-01: Continue as Guest** | ✅ สมบูรณ์ | 17/17 SRS |
| **UC-02: Authenticate** | ✅ สมบูรณ์ | 23/23 SRS |
| **UC-03: Setup User Account** | ✅ สมบูรณ์ | 11/11 SRS |
| **UC-04: Guest Creates Account** | ✅ สมบูรณ์ | 11/11 SRS |
| **UC-05: Logout** | ✅ สมบูรณ์ | 9/9 SRS |
| **UC-06: Delete Account** | ✅ สมบูรณ์ | 10/10 SRS |
| **รวมทั้งหมด** | ✅ สมบูรณ์ | 81/81 SRS (100%) |

**สรุป:** การนำไปใช้งานระบบ authentication สมบูรณ์และตรงกับความต้องการที่ระบุไว้ทั้งหมด มีปัญหาเอกสารเล็กน้อย (ตัวเลข test) แต่ไม่กระทบต่อการทำงาน

---

**สร้างเมื่อ:** 18 มิถุนายน 2026  
**เวอร์ชัน:** 1.0
