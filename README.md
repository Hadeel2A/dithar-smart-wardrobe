
# 🌟 Dithar – Smart Wardrobe System

<div align="center">

<img src="docs/dithar-logo.png" alt="Dithar Logo" width="180"/>

### An intelligent wardrobe management system empowering independence through accessible fashion technology

![Platform](https://img.shields.io/badge/platform-iOS-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![Backend](https://img.shields.io/badge/backend-Firebase-yellow)
![Hardware](https://img.shields.io/badge/hardware-Raspberry%20Pi-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

🎥 Demo • 📱 Screenshots • 📖 Documentation

</div>

---

# 🌍 Overview

**Dithar** is an intelligent wardrobe management system that combines **AI-powered clothing recognition**, **RFID tracking technology**, and **accessibility features** to create an inclusive fashion experience.

The system is designed to empower **visually impaired individuals** by enabling independent clothing identification and outfit coordination while also helping all users organize their wardrobes more efficiently.

Dithar transforms traditional closets into **smart digital wardrobes** capable of recognizing clothing items, tracking them in real time, and recommending outfit combinations.

---

# ✨ Key Highlights

- 🤖 **AI-Powered Recognition** – Automatically identifies clothing type, color, and patterns  
- 📡 **Real-Time RFID Tracking** – Detects whether clothing items are inside or outside the wardrobe  
- 🎙️ **Voice Accessibility** – Audio descriptions using VoiceOver and AVSpeechSynthesizer  
- 👗 **Smart Outfit Recommendations** – AI-based outfit suggestions  
- 🌐 **Community Platform** – Share and explore outfit inspirations  
- 🇸🇦 **Arabic Language Support** – Designed for Arabic-speaking users  

---

# 🎯 Problem Statement

### For visually impaired individuals
Choosing and coordinating outfits independently can be difficult because identifying colors, patterns, and clothing types often requires assistance from others.

### For all users
Cluttered wardrobes often lead to forgotten clothing items, unnecessary purchases, and decision fatigue when selecting outfits.

### Dithar's Solution
Dithar digitalizes wardrobe inventory using **AI recognition and RFID tracking**, allowing users to easily manage clothing items, receive outfit recommendations, and access full accessibility support.

---

# 🏗️ System Architecture

<div align="center">

<img src="docs/system-architecture.png" alt="System Architecture" width="700"/>

</div>

| Component | Technology | Purpose |
|-----------|------------|---------|
| Mobile Application | Swift / SwiftUI | User interface and wardrobe management |
| Backend | Firebase Firestore | Real-time database and storage |
| AI Recognition | CLIP / Image Recognition | Clothing detection and classification |
| RFID System | UHF RFID + Raspberry Pi | Physical item tracking |
| Voice Assistance | AVSpeechSynthesizer | Audio clothing descriptions |

---

# 🚀 Features

## 📱 Smart Wardrobe Management

- Auto-recognition of clothing items using AI
- Manual editing of clothing details
- RFID tag linking for physical tracking
- Real-time wardrobe inventory updates

## 👔 Intelligent Outfit Creation

- Category-based outfit generation
- Preference learning from user selections
- Outfit saving for events and occasions
- Outfit validation ensuring proper combinations

## ♿ Accessibility Excellence

- VoiceOver support for visually impaired users
- Audio descriptions for clothing items
- Accessible gestures and navigation
- Arabic and English interface support

## 🌍 Community Features

- Share outfits with other users
- Discover outfit inspiration
- Like and comment on community posts
- Save outfits to personal wardrobe

## 📊 Analytics & Insights

- Track clothing usage frequency
- Detect rarely used clothing
- Wardrobe statistics by category and color

---

# 📱 Screenshots

<div align="center">

| Wardrobe | Outfits | Community | Accessibility |
|:--:|:--:|:--:|:--:|
| ![Wardrobe](screenshots/wardrobe.png) | ![Outfits](screenshots/outfits.png) | ![Community](screenshots/community.png) | ![Voice](screenshots/voice.png) |

</div>

---

# 🛠 Installation

## Prerequisites

- iOS device running **iOS 15+**
- Xcode **14+**
- Swift **5+**

### Optional Hardware (for RFID features)

- Raspberry Pi 4
- UHF RFID Reader
- UHF RFID Tags

---

## Clone Repository

```bash
git clone https://github.com/Hadeel2A/dithar-smart-wardrobe.git
cd dithar-smart-wardrobe


⸻

Run the iOS App

cd mobile-app
open DitharApp.xcodeproj

Then press ⌘ + R to run the app in Xcode.

⸻

🔧 Technology Stack

Mobile Application
	•	Swift
	•	SwiftUI
	•	UIKit
	•	MVVM Architecture

Backend
	•	Firebase Firestore
	•	Firebase Authentication
	•	Firebase Storage

AI & Image Processing
	•	CLIP Vision Model
	•	Image preprocessing APIs
	•	Rule-based recommendation engine

Hardware Integration
	•	Raspberry Pi 4
	•	UHF RFID Reader
	•	Python scripts for hardware communication

⸻

🧪 Testing

User Acceptance Testing
	•	Participants: 8 users
	•	Visually impaired users included
	•	Test cases: 20
	•	Success rate: 95%

Accessibility Testing
	•	VoiceOver support ✅
	•	Screen reader compatibility ✅
	•	Accessible gestures and navigation ✅

⸻

👥 Team

<div align="center">


Role	Name
Scrum Master & Lead Developer	Rahaf AlFantoukh
UI/UX Designer	Hadeel Almutairi
AI Engineer	Maha Alswed
Hardware Specialist	Fatmah Alsufaian
Supervisor	Dr. Wejdan Alkhaldi

</div>



⸻

🚧 Future Improvements
	•	Android version
	•	Weather-based outfit recommendations
	•	AR virtual try-on
	•	Smart mirror integration
	•	Global localization support

⸻

📄 License

This project is licensed under the MIT License.

⸻

🙏 Acknowledgments
	•	King Saud University
	•	Saudi Vision 2030 innovation initiatives
	•	Firebase cloud infrastructure
	•	Open-source community

⸻


<div align="center">


⭐ If you like this project, consider giving it a star!

Made with ❤️ to support accessible technology

</div>
```
