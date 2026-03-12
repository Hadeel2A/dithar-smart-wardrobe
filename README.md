# Dithar
### Smart Wardrobe System

<div align="center">

<img src="docs/dithar-logo.png" alt="Dithar Logo" width="170"/>

An intelligent wardrobe management system designed to simplify clothing organization through AI-powered recognition, RFID-based tracking, and accessible audio interaction.

![Platform](https://img.shields.io/badge/platform-iOS-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![Backend](https://img.shields.io/badge/backend-Firebase-yellow)
![Hardware](https://img.shields.io/badge/hardware-Raspberry%20Pi-green)
![Focus](https://img.shields.io/badge/focus-Accessibility-lightgrey)

</div>

---

## Overview

Dithar is a smart wardrobe system that helps users organize clothing items, identify garments more easily, and make outfit decisions with greater efficiency and independence. The project combines a mobile application with AI-based clothing recognition and RFID technology to maintain a real-time clothing inventory and support outfit selection. It is particularly designed to improve accessibility for visually impaired users through audio descriptions and more independent wardrobe interaction.  [oai_citation:5‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

The project addresses two main user groups. For ordinary users, it helps reduce wardrobe clutter, keeps track of stored items, and supports outfit selection. For visually impaired users, it provides clothing recognition from a photo, stores clothing details digitally, and links each item to an RFID tag for easier retrieval without relying on others.  [oai_citation:6‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)

---

## Problem Statement

Choosing what to wear can be time-consuming and frustrating, especially when wardrobes are cluttered or when clothing items are difficult to identify. For visually impaired individuals, the challenge is even greater because distinguishing colors, patterns, and categories without visual cues may require external help. These limitations reduce independence, make outfit coordination harder, and can lead to underuse of available clothing items.  [oai_citation:7‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

Dithar addresses this problem by turning a traditional wardrobe into a digital and trackable system that supports clothing recognition, item management, and accessible outfit coordination.  [oai_citation:8‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Solution

Dithar provides a smart wardrobe experience through the integration of:

- AI-based image recognition for clothing classification
- RFID-based clothing tracking
- A mobile app for digital wardrobe management
- Audio descriptions for visually impaired users
- Outfit recommendations based on wardrobe contents
- Social sharing and interaction through community features

The system supports both practical organization and inclusive access. Clothing items can be recognized, stored, tagged, searched, filtered, and used to create outfit combinations, while visually impaired users can access garment information through speech output.  [oai_citation:9‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)  [oai_citation:10‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Target Users

### Ordinary Users
- Users with overcrowded wardrobes
- Users who want easier clothing organization
- Users who need support in selecting outfits quickly

### Visually Impaired Users
- Users who need accessible clothing identification
- Users who benefit from audio clothing descriptions
- Users who want greater independence in outfit coordination

These user groups are explicitly reflected in the project vision and presentation materials.  [oai_citation:11‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)  [oai_citation:12‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Core Features

### 1. Add Clothes to the App
Users can take a photo of a clothing item, after which the AI model automatically analyzes and identifies its:
- type
- color
- pattern

After classification, the item can be linked to an RFID tag and saved in the user’s digital wardrobe. Users can later search for items by color, type, or last-used date.  [oai_citation:13‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)

### 2. RFID-Based Item Tracking
Each garment can be associated with an RFID tag. A reader scans the tag and links it to the clothing item, enabling future tracking and wardrobe organization. In the project proposal, the RFID reader is used to identify and track garments when they are added to or removed from the wardrobe, while the Raspberry Pi acts as the edge device that reads RFID data and relays it to the application/backend.  [oai_citation:14‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)  [oai_citation:15‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

### 3. Outfit Creator
Users can browse their digital wardrobe, select clothing items from different categories, arrange them visually, and save complete outfits for future use. Saved outfits may also include tags or notes for occasions such as casual or formal events.  [oai_citation:16‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)

### 4. Match a Similar Outfit
Through the Explore Page, users can browse outfit posts and use a “Match a Similar Outfit” feature. The system analyzes the selected outfit, extracts key details such as clothing type and color palette, and searches the user’s own wardrobe for the closest match. When no exact match exists, the system suggests alternatives.  [oai_citation:17‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)

### 5. AI-Based Recommendations
The system generates outfit recommendations based on:
- stored wardrobe items
- clothing compatibility
- user preferences
- weather
- occasion type

As users interact more with the system, recommendations become more personalized.  [oai_citation:18‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)

### 6. Accessibility Support
A core objective of Dithar is to support visually impaired users through auditory descriptions of clothing items and audio interaction using text-to-speech. The project proposal specifically includes AVSpeechSynthesizer integration for accessibility.  [oai_citation:19‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)  [oai_citation:20‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

### 7. Community Interaction
Dithar also includes social features that allow users to:
- share favorite outfits
- like and comment on shared looks
- browse community inspiration

These features promote engagement and provide additional outfit ideas.  [oai_citation:21‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)  [oai_citation:22‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Interfaces

The project interface is organized around the main user tasks and core flows of the system. Based on the documented features and your current application structure, the user-facing experience includes the following interface areas:

### Wardrobe Management Interface
Used to display stored items, item details, and wardrobe organization functions such as filtering and browsing.

### Add Item Interface
Used to capture a clothing image, review recognition results, and link the clothing item to RFID data before saving it.

### Outfit Creation Interface
Used to select clothing items, visually arrange outfits, and save combinations for later use.

### Recommendation Interface
Used to present suggested outfit combinations based on available items, preferences, weather, and occasion.

### Community Interface
Used to browse shared outfit posts, interact with community content, and match similar looks from the user’s own wardrobe.

### Accessibility Interface
Used to support users with audio descriptions and voice-guided interaction for clothing information and navigation.

These interfaces align with the documented project features, product objectives, and your app modules.  [oai_citation:23‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)  [oai_citation:24‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## System Architecture

<div align="center">
  <img src="docs/system-architecture.jpeg" alt="Dithar System Architecture" width="780"/>
</div>

Dithar combines a mobile application, AI recognition, cloud data management, and RFID hardware into one integrated system. The overall system flow includes clothing image capture, AI-based classification, RFID tag linking, digital wardrobe storage, and user-facing outfit management. This integration is central to the project vision.  [oai_citation:25‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## System Workflow

<div align="center">
  <img src="docs/system-workflow.jpeg" alt="Dithar System Workflow" width="780"/>
</div>

The workflow begins when a user captures a clothing image. The system then recognizes the clothing item, optionally allows the user to modify additional details, supports RFID linking, and finally saves the clothing item into the wardrobe system. Your workflow diagram is an excellent fit for documenting this process visually.

---

## Project Scope

According to the proposal, the scope of Dithar includes:
- an iOS mobile application
- RFID-based clothing tracking
- AI-based clothing recognition
- digital wardrobe organization
- outfit recommendations
- auditory descriptions
- Arabic language support

The proposal explicitly states that advanced functions such as augmented reality fitting, fabric analysis, and e-commerce integration are outside the current project scope.  [oai_citation:26‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Project Objectives

### Product Objectives
The project aims to:
- manually arrange and save outfits
- track whether clothing items are inside or outside the closet
- recognize clothing items automatically
- add and link clothing items with RFID tags
- support visually impaired users with auditory descriptions
- generate outfit recommendations
- allow community sharing
- enable likes and comments
- provide search and filtering options
- save custom outfits for specific events  [oai_citation:27‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

### Project Objectives
The development objectives include:
- identifying and evaluating AI models for clothing recognition
- purchasing and testing RFID equipment and Raspberry Pi
- designing and implementing the database
- connecting Raspberry Pi with the RFID reader
- connecting Raspberry Pi with the database
- designing the user interface
- developing the iOS app using Xcode
- implementing rule-based recommendation logic
- integrating AVSpeechSynthesizer
- conducting application testing  [oai_citation:28‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Technology Stack

### Mobile Application
- Swift
- Xcode
- iOS application development

### Database and Cloud Services
- Firebase Firestore
- Firebase storage infrastructure

### AI and Recognition
- CLIP (fine-tuned version) for AI-based clothing recognition in the proposal
- Google Vision API and DeepFashion Model in the presentation materials
- compatibility models such as Polyvore Outfit Compatibility Model and Type-Aware Embeddings for outfit analysis in the presentation materials  [oai_citation:29‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)  [oai_citation:30‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)

### Accessibility
- AVSpeechSynthesizer (Text-to-Speech)

### Hardware Integration
- UHF RFID Reader
- UHF RFID Tags
- Raspberry Pi
- Visual Studio Code for Raspberry Pi development/integration  [oai_citation:31‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Hardware and Software Resources

The proposal lists the following core resources:

### Hardware
- UHF RFID Reader — 232.5 SAR
- UHF RFID Tags — 1.1 SAR per tag
- Raspberry Pi — 267 SAR
- iPhone test device — team-owned

### Software
- Xcode IDE — free
- Firebase — free
- CLIP (fine-tuned version) — free
- AVSpeechSynthesizer — free
- Visual Studio Code — free  [oai_citation:32‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Results and Project Value

Dithar delivers value in several ways:

- improves wardrobe organization
- reduces time spent choosing outfits
- supports more efficient use of stored clothes
- reduces reliance on others for visually impaired users
- enables more confident outfit coordination
- supports social sharing and inspiration
- combines accessibility, RFID tracking, and AI within one integrated system

These outcomes are consistently reflected in the proposal and presentation materials.  [oai_citation:33‡Smart Wardrobe.pdf](file-service://file-RD5ULfyBzeGt9sgg653hfD)  [oai_citation:34‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)  [oai_citation:35‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Repository Structure

```text
dithar-smart-wardrobe
├── docs
│   ├── dithar-logo.png
│   ├── system-architecture.jpeg
│   └── system-workflow.jpeg
├── screenshots
│   ├── wardrobe.png
│   ├── outfits.png
│   ├── community.png
│   └── voice.png
├── mobile-app
│   ├── DitharApp
│   └── DitharApp.xcodeproj
├── DitharAppTests
├── DitharAppUITests
├── public
├── firebase.json
└── README.md
```

---

## Screenshots

Add application screenshots inside the `screenshots` folder using these names:

- `wardrobe.png`
- `outfits.png`
- `community.png`
- `voice.png`

Then they can be displayed here:

| Wardrobe | Outfits | Community | Accessibility |
|----------|---------|-----------|---------------|
| ![](screenshots/wardrobe.png) | ![](screenshots/outfits.png) | ![](screenshots/community.png) | ![](screenshots/voice.png) |

---

## Team

Prepared by:

- Rahaf AlFantoukh
- Hadeel Almutairi
- Maha Alswed
- Fatimah Alsufaian

Supervised by:

- Dr. Wejdan Alkhaldi  [oai_citation:36‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

## Acknowledgments

- King Saud University
- College of Computer and Information Sciences
- Department of Information Technology
- Graduation Project Proposal and Presentation Materials used to document this repository accurately  [oai_citation:37‡ملف المشروع الجزء الاول .pdf](file-service://file-EvTzGow2dUSEjUyrU7Jnrf)

---

Developed as a graduation project focused on accessible technology, smart wardrobe management, and inclusive fashion support.
