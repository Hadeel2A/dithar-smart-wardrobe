🌟 Dithar - Smart Wardrobe System
[Image blocked: Dithar Logo]
An intelligent wardrobe management system empowering independence through accessible fashion technology

developer.apple.com
 
swift.org
 
firebase.google.com
 
raspberrypi.org
 
🎥 View Demo [blocked] • 📱 Screenshots [blocked] • 📖 Documentation [blocked] • 
#installation

---

## 🌍 Overview

**Dithar** is a smart wardrobe management system that integrates **AI-powered clothing recognition**, **RFID tracking technology**, and **accessibility features** to create an inclusive fashion companion.

The system is designed to empower **individuals with visual impairments** by enabling independent clothing identification and outfit coordination, while also helping all users manage their wardrobes more efficiently.

---

## ✨ Key Highlights

- 🤖 **AI-Powered Recognition** – Automatically identifies clothing category, color, and patterns  
- 📡 **Real-time RFID Tracking** – Detects items inside or outside the wardrobe  
- 🎙️ **Voice Accessibility** – Audio descriptions using VoiceOver and AVSpeechSynthesizer  
- 👗 **Smart Recommendations** – AI suggests outfits based on user preferences  
- 🌐 **Community Platform** – Share and explore outfit inspirations  
- 🇸🇦 **Arabic Support** – Full localization for Arabic-speaking users  

---

## 🎯 Problem Statement

### For visually impaired individuals
Selecting and coordinating outfits independently can be challenging and often requires assistance from others.

### For all users
Cluttered wardrobes lead to forgotten items, duplicate purchases, and decision fatigue when deciding what to wear.

### Dithar’s Solution
A **smart wardrobe system** that digitalizes clothing inventory, provides intelligent outfit recommendations, and offers full accessibility support.

---

## 🏗 System Architecture

| Component | Technology | Purpose |
|-----------|------------|--------|
| Mobile App | iOS (Swift / SwiftUI) | User interface |
| Cloud Backend | Firebase Firestore | Real-time data synchronization |
| AI Recognition | CLIP Model | Clothing classification |
| RFID System | UHF RFID + Raspberry Pi | Physical clothing tracking |
| Background Removal | remBG API | Image preprocessing |
| Voice Synthesis | AVSpeechSynthesizer | Audio descriptions |

---

## 🚀 Features

### 📱 Smart Wardrobe Management

- AI recognition of clothing items
- Manual editing of clothing attributes
- RFID tag integration with wardrobe items
- Real-time wardrobe availability tracking

### 👔 Intelligent Outfit Creation

- Category-based outfit generation
- Preference learning based on user behavior
- Save outfits for specific occasions
- Outfit validation to ensure correct combinations

### ♿ Accessibility Excellence

- VoiceOver compatibility
- Detailed audio descriptions
- Accessible gesture navigation
- Arabic & English interface support

### 🌍 Community Features

- Share outfits with other users
- Discover outfit inspirations
- Like and comment on community posts

### 📊 Analytics & Insights

- Track clothing usage frequency
- Identify rarely used items
- Wardrobe statistics and insights

---

## 📱 Screenshots

| Wardrobe | Outfits | Community | Accessibility |
|----------|---------|----------|--------------|
| ![](screenshots/wardrobe.png) | ![](screenshots/outfits.png) | ![](screenshots/community.png) | ![](screenshots/voice.png) |

---

## 🛠 Installation

### Prerequisites

- iPhone running **iOS 15+**
- **Xcode 14+**
- **Swift 5+**

### Optional Hardware

- Raspberry Pi 4 Model B  
- UHF RFID Reader  
- Washable UHF RFID Tags  

---

### Clone the Repository

```bash
git clone https://github.com/Hadeel2A/dithar-smart-wardrobe.git
cd dithar-smart-wardrobe
```

### Setup the iOS App

```bash
cd mobile-app/DitharApp
open DitharApp.xcodeproj
```

### Configure Firebase

- Add `GoogleService-Info.plist`
- Update Firebase configuration if required

### Hardware Setup (Optional)

```bash
cd hardware
pip install -r requirements.txt
python3 rfid_controller.py
```

### Build and Run

1. Select your device in Xcode  
2. Press **⌘ + R** to build and run  

---

## 🔧 Technology Stack

### Mobile Application

- SwiftUI  
- UIKit  
- MVVM Architecture  

### Backend

- Firebase Firestore  
- Firebase Authentication  
- Firebase Storage  

### AI & Image Processing

- CLIP Vision Model  
- remBG background removal  
- Rule-based recommendation engine  

### Hardware Integration

- Raspberry Pi 4  
- UHF RFID Reader  
- Python with Firebase Admin SDK  

---

## 📊 Performance Metrics

| Metric | Target | Achieved |
|------|------|------|
| App Load Time | < 3s | ✅ 2.1s |
| RFID Detection | < 2s | ✅ 1.8s |
| AI Recognition | < 3s | ✅ 2.5s |
| Post Upload | < 10s | ✅ 7.2s |
| System Availability | 99% | ✅ 99.2% |

---

## 🧪 Testing

### User Acceptance Testing

- Participants: 8 users  
- Visually impaired users included  
- Test cases: 20  
- Success rate: **95%**

### Accessibility Testing

- VoiceOver support ✅  
- Screen reader compatibility ✅  
- Accessible gesture navigation ✅  

Run tests:

```bash
cd mobile-app/DitharApp
xcodebuild test -scheme DitharApp
```

---

## 👥 Team

<div align="center">

Rahaf AlFantoukh  
Hadeel Almutairi  
Maha Alswed  
Fatmah Alsufaian  
Dr. Wejdan Alkhaldi  

</div>

---

## 🌟 Impact

### Academic Recognition

- Graduation project with **Excellent rating**
- Accessibility innovation award
- Research prepared for conference submission

### Real-World Impact

- 92% user satisfaction
- Empowered visually impaired beta users
- Reduced unnecessary clothing purchases

---

## 🚧 Future Roadmap

### Version 2.0

- Android version  
- Weather-based outfit recommendations  
- AR virtual try-on  
- Enhanced community features  

### Version 3.0

- Smart mirror integration  
- E-commerce integration  
- Professional styling assistance  
- Global localization support  

---

## 🙏 Acknowledgments

- King Saud University  
- Saudi Vision 2030 innovation initiatives  
- Firebase cloud infrastructure  
- Open-source community  

---

Developed as a **graduation project focused on accessible technology and inclusive fashion solutions**.
