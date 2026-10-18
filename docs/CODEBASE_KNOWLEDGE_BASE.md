# Codebase Knowledge Base & Architecture Reference

> **Project:** TellMeMore TG (Telegram Client with Advanced AI Copilot)  
> **Architecture Pattern:** Clean Architecture & SOLID Principles  
> **Framework:** Flutter 3.x (Multiplatform: Linux Desktop, Android, macOS, Windows)  
> **Backend Integration:** TDLib JSON FFI via Isolate Worker (`TdWorker`)

---

## 1. Architectural Principles

This codebase follows **Clean Architecture** and strict **SOLID** principles:

1. **Single Responsibility Principle (SRP):**
   - Each widget is responsible *only* for presenting its slice of UI and forwarding user events.
   - Domain logic (e.g. Prompt Building, RAG context synthesis, Sherlock psychotype analysis, STT, LLM streaming) lives in dedicated Service classes, completely decoupled from Flutter Widgets.
   - Data access, caching, and persistence reside in Store / Repository layers.

2. **Open/Closed Principle (OCP):**
   - New AI providers or models are added by extending `AiModelService` provider configurations without modifying existing screen widgets.
   - Export formats are handled via polymorphic or strategy-based formatters in `ChatExportService`.

3. **Liskov Substitution Principle (LSP):**
   - Abstractions such as `TdLibService` have concrete implementations (`TdLibServiceNative`) and test/stub implementations (`TdLibServiceStub`) that can be substituted transparently.

4. **Interface Segregation Principle (ISP):**
   - Small, focused callbacks and listener contracts rather than monolithic controller interfaces.

5. **Dependency Inversion Principle (DIP):**
   - High-level presentation widgets depend on abstract services/stores rather than direct native I/O or raw TDLib isolate sockets.

---

## 2. Layered Structure Overview

```
lib/
├── core/                        # Cross-cutting foundational modules
│   ├── localization/            # Multi-language string catalogs (AppLocale)
│   ├── services/                # Low-level platform services (sound, notifications)
│   ├── theme/                   # Telegram dark/light theme definitions
│   ├── utils/                   # Loggers, formatters, link handlers, path resolution
│   └── widgets/                 # Reusable generic UI components (Avatars, Toasts, Badges)
├── data/                        # Data Layer (TDLib FFI & Local Storage)
│   ├── models/                  # Core entities (TgAccount, TgChat, TgMessage)
│   ├── tdlib/                   # Isolate-based TDLib JSON FFI engine
│   └── account_data.dart        # Account session switching and persistence
├── features/                    # Feature Modules (Vertical Slices)
│   ├── ai_copilot/              # AI Copilot, Smart Replies, Sherlock & Dossiers
│   │   ├── models/              # AiSettings, CopilotSession, ContactDossier
│   │   ├── screens/             # Orchestrating views (CopilotScreen, AiSettingsScreen)
│   │   ├── services/            # PromptBuilder, SmartReplyEngine, Voice, Sherlock
│   │   └── widgets/             # Granular presentation widgets (Bubbles, Bars, Dossiers)
│   ├── auth/                    # Login, QR code, phone auth, add account
│   ├── chat/                    # Active Telegram chat view and message timeline
│   ├── chat_list/               # Telegram chat folder list, pinned chats, search
│   ├── contacts/                # Address book and contact picker
│   ├── profile/                 # User profile modal, account settings, bio
│   └── settings/                # App preferences, notifications, theme
├── platform/                    # Desktop window sizing, frame controls
├── shell/                       # Main responsive shell (sidebar + chat/copilot panes)
└── state/                       # Global reactive application state (AppState)
```

---

## 3. Module Index & API Signatures

### 3.1 AI Copilot Feature (`lib/features/ai_copilot/`)
- **`models/`**:
  - `AiSettingsModel`: Configuration for OpenAI / Anthropic / Gemini / DeepSeek / Custom endpoints, temperature, active models, autopilot toggles.
  - `ContactDossier`: Dossier entity containing contact goals, psychotype, manipulation resistance, communication tone, and CRM facts.
  - `CopilotSession`: State of a multi-turn conversation session with the AI Copilot.
- **`services/`**:
  - `AiModelService`: Low-level LLM client supporting streaming, tools, and multi-provider REST APIs.
  - `SmartReplyEngine`: Generates 3 contextual quick-reply chips and 1 comprehensive auto-reply using Sandwich Context.
  - `VoiceTranscriptionService`: Records voice input and transcribes via Whisper API or local models.
  - `ImageDescriptionService`: Generates vision summaries for attached media files.
  - `CopilotSessionStore`: Local persistence and switching of active Copilot sessions.
  - `CopilotPromptBuilder`: Synthesizes top directives, contact dossier, RAG facts, sliding conversation history, and user intent into the Sandwich Context.
- **`widgets/`**:
  - `CopilotHeader`: Top bar displaying active session, target contact badge, model selector chip, and action buttons.
  - `CopilotMessageBubble`: Renders user/assistant messages with markdown, tool logs, copy buttons, and audio player.
  - `CopilotThinkingBubble`: Live status indicator for STT transcription and LLM token generation.
  - `CopilotInputBar`: Multi-line text field, voice recording toggle with duration counter, and attachment picker.
  - `CopilotRagSheet`: Drawer for inspecting retrieved RAG facts, memory lenses, and dialogue compression.
  - `SmartRepliesBar`: Horizontal suggestions bar rendered directly above the chat input.
  - `ContactDossierSheet`: Modal sheet for viewing and editing AI profiling of a contact.

### 3.2 Chat Feature (`lib/features/chat/`)
- **`chat_screen.dart`**: Main chat coordinator.
- **`widgets/`**:
  - `ChatAppBar`: Top header showing contact name, typing status, avatar, call button, dossier button, and overflow menu.
  - `ChatMessageList`: Virtualized reverse ListView rendering `MessageBubble` elements, date separators, and unread badges.
  - `ChatInputBar`: Message input field, emoji picker toggle, voice note recorder, attachment picker, and send button.
  - `ChatPinnedBar`: Header displaying pinned messages with quick jump.
  - `ChatSearchBar`: Inline message search bar with match counter and navigation controls.
  - `MessageBubble`: Single Telegram message bubble supporting text, photo, video, audio, voice, files, and reply previews.

### 3.3 State Management (`lib/state/app_state.dart`)
- `AppState` (ValueNotifier / ChangeNotifier based singleton):
  - `activeAccountId`: Currently selected Telegram account ID.
  - `activeChatId`: Currently open chat ID.
  - `copilotChatId`: Contact ID bound to the active Copilot session.
  - `aiProcessingStatus`: Global processing status string for non-blocking UI spinners.
  - `isCopilotOpen`: Visibility of the AI Copilot side pane.

---

## 4. Refactoring Changelog & Verification Ledger

| Date | Target Component | Original Lines | New Lines (Total) | Status | Verification Check |
|---|---|---|---|---|---|
| 2026-10-16 | Baseline Repository State | 28,713 | 28,713 | PASS | 68/68 Flutter Tests Passing |
| 2026-10-16 | AI Copilot Screen Decomposition | 2,384 | 521 (screen) + 1,980 (modular components) | COMPLETE | 68/68 Flutter Tests Passing |
| 2026-10-16 | Contact Dossier Decomposition | 1,780 | 543 (dialog) + 1,290 (modular components) | COMPLETE | 68/68 Flutter Tests Passing |
| 2026-10-16 | Chat Screen Decomposition | 1,522 | 88 (screen) + 1,471 (modular components) | COMPLETE | 68/68 Flutter Tests Passing |
| 2026-10-16 | AI Settings Screen Decomposition | 1,108 | 151 (screen) + 1,018 (modular components) | COMPLETE | 68/68 Flutter Tests Passing |
| 2026-10-16 | Profile Dialog & Pane Decomposition | 1,838 | 142 (dialog+pane) + 1,073 (modular components) | COMPLETE | 68/68 Flutter Tests Passing |
| 2026-10-18 | AI Role Separation & Multilingual Sandwich Context | 1,745 | 1,820 | COMPLETE | 73/73 Flutter Tests Passing |

### 4.2 Contact Dossier Sheet Decomposition Details
- **`lib/features/ai_copilot/widgets/contact_dossier_sheet.dart`** (543 lines):
  - Class: `ContactDossierDialog`
  - Responsibilities: Coordinator dialog managing tab switching (CRM Dossier vs. LLM Prompt & Memory), form controller lifecycle, and sync with `ContactDossierStore` and `CopilotSessionStore`.
- **`lib/features/ai_copilot/services/sherlock_analysis_service.dart`** (215 lines):
  - Class: `SherlockAnalysisService`
  - Responsibilities: Pure domain service for deep psychological profiling, interlocutor hidden motive detection, and manipulation risk scoring from chat history.
  - Public API: `analyzeChat({required String chatTitle, required List<TgMessage> messages, required String userGoal, int messageLimit = 50, bool isRu = true}): Future<SherlockAnalysisResult>`
- **`lib/features/ai_copilot/widgets/dossier/collapsible_dossier_card.dart`** (128 lines):
  - Widget: `CollapsibleDossierCard`
  - Responsibilities: Reusable collapsible section wrapper with animated chevron, badge counter, and subtitle.
- **`lib/features/ai_copilot/widgets/dossier/dossier_header.dart`** (85 lines):
  - Widget: `DossierHeader`
  - Responsibilities: Contact avatar, name, assistant badge, close icon, and 2-tab navigation bar.
- **`lib/features/ai_copilot/widgets/dossier/dossier_sherlock_card.dart`** (145 lines):
  - Widget: `DossierSherlockCard`
  - Responsibilities: Sherlock psychological summary, message depth slider (5-500 msgs), and run analysis trigger with progress spinner.
- **`lib/features/ai_copilot/widgets/dossier/dossier_goals_and_tone_section.dart`** (195 lines):
  - Widget: `DossierGoalsAndToneSection`
  - Responsibilities: Conversation goal preset chips, expandable multi-line (1-7 lines) goal editor, tone of voice preset chips, and expandable multi-line psychotype editor.
- **`lib/features/ai_copilot/widgets/dossier/dossier_crm_facts_section.dart`** (95 lines):
  - Widget: `DossierCrmFactsSection`
  - Responsibilities: CRM facts list with delete action, input field, and add fact button.
- **`lib/features/ai_copilot/widgets/dossier/dossier_directives_section.dart`** (65 lines):
  - Widget: `DossierDirectivesSection`
  - Responsibilities: Agent system directives editor for the contact session.
- **`lib/features/ai_copilot/widgets/dossier/dossier_rag_section.dart`** (215 lines):
  - Widget: `DossierRagSection`
  - Responsibilities: Depth slider, custom lens input, RAG fact extraction trigger, active summary preview, and clear summary action.
- **`lib/features/ai_copilot/widgets/dossier/dossier_memory_section.dart`** (185 lines):
  - Widget: `DossierMemorySection`
  - Responsibilities: Long dialogue auto-compression switch, trigger threshold slider, raw keep-window slider, compression instructions textfield, and manual compression button.
- **`lib/features/ai_copilot/widgets/dossier/dossier_bottom_actions.dart`** (80 lines):
  - Widget: `DossierBottomActions`
  - Responsibilities: "Chat about contact with Copilot" button, "Export Advisor Card" dialog trigger, Cancel, and Save buttons.

### 4.1 AI Copilot Screen Decomposition Details
- **`lib/features/ai_copilot/screens/ai_copilot_screen.dart`** (521 lines):
  - Responsibilities: High-level screen orchestration, local text/scroll/voice state, lifecycle bindings, and coordinating prompt building and LLM generation.
- **`lib/features/ai_copilot/services/copilot_prompt_builder.dart`** (349 lines):
  - Class: `CopilotPromptBuilder`
  - Responsibilities: Pure domain service for Sandwich Prompt assembly, RAG fact integration, contact dossier synthesis, and sliding conversational context window.
  - Public API:
    - `resolveTargetChat({required CopilotSession session, String? userQuery, String? activeChatId}): TgChat?`
    - `buildSandwichPrompt({required CopilotSession session, required AiSettings settings, required String query, TgChat? matchedChat, bool isRu}): Future<CopilotPromptResult>`
- **`lib/features/ai_copilot/widgets/copilot_header.dart`** (155 lines):
  - Widget: `CopilotHeader`
  - Responsibilities: Top session navigation, avatar badge, agent role indicator, model & provider info, token meter, sandwich inspector button, prompt editor button, and clear history trigger.
- **`lib/features/ai_copilot/widgets/copilot_summary_banner.dart`** (66 lines):
  - Widget: `CopilotSummaryBanner`
  - Responsibilities: Expandable banner displaying compressed dialogue summary tokens and memory text.
- **`lib/features/ai_copilot/widgets/copilot_quick_actions.dart`** (82 lines):
  - Widget: `CopilotQuickActions`
  - Responsibilities: Dynamic horizontal action chips adapted to agent role (negotiation, vacancy hunting, code review, CRM analysis).
- **`lib/features/ai_copilot/widgets/copilot_thinking_bubble.dart`** (63 lines):
  - Widget: `CopilotThinkingBubble`
  - Responsibilities: Non-blocking animated status bubble reflecting live STT transcription progress and LLM token inference.
- **`lib/features/ai_copilot/widgets/copilot_message_bubble.dart`** (265 lines):
  - Widget: `CopilotMessageBubble`
  - Responsibilities: User and Assistant message rendering with markdown links, attachments (photos, voice notes, documents), tool execution logs, error recovery, and retry actions.
- **`lib/features/ai_copilot/widgets/copilot_input_bar.dart`** (238 lines):
  - Widgets: `CopilotInputBar`, `CopilotVoiceBar`
  - Responsibilities: Multi-line text field, attachment preview chip, file picker launcher, voice note recording with live seconds counter, cancel, and submit actions.
- **`lib/features/ai_copilot/widgets/copilot_sandwich_inspector_dialog.dart`** (180 lines):
  - Widget: `CopilotSandwichInspectorDialog`
  - Responsibilities: Modal inspector visualizing prompt layers (top bread, RAG summary, recent messages, bottom bread), token counts, and instant manual compression action.
- **`lib/features/ai_copilot/widgets/copilot_prompt_editor_dialog.dart`** (715 lines):
  - Widget: `CopilotPromptEditorDialog`
  - Responsibilities: Full modal dialog for customizing agent directives, RAG fact extraction depth (slider 10-500 msgs) and prism lens, auto-compression threshold (10-80 msgs) and raw message keep-window (3-20 msgs).

### 4.3 Chat Screen Decomposition Details
- **`lib/features/chat/chat_screen.dart`** (88 lines):
  - Class: `ChatScreen`
  - Responsibilities: Minimalist top-level coordinator for the active Telegram chat. Subscribes to `AppState.selectedChatId`, `AppState.demoMode`, `TdlibService.chats`, and `AccountManager.currentAccount`. Composes `ChatHeader`, `ChatMessageList`, and `ChatInputBar`.
- **`lib/features/chat/widgets/chat_header.dart`** (415 lines):
  - Class: `ChatHeader`
  - Responsibilities: Top navigation bar displaying user/chat identity, status subtitle, back button (on narrow screens), search query input, and bulk selection mode action buttons (forward, delete, export advisor card, export chat history).
- **`lib/features/chat/widgets/chat_message_list.dart`** (290 lines):
  - Class: `ChatMessageList`
  - Responsibilities: Virtualized reverse scroll message feed, pagination history loader, drag-and-drop file overlay target with animated dropzone feedback, and multi-select toggles.
- **`lib/features/chat/widgets/chat_input_bar.dart`** (766 lines):
  - Classes: `ChatInputBar`, `ChatInputBarState`
  - Responsibilities: Rich input container supporting multi-line typing, Enter/Ctrl+Enter keyboard shortcuts, staged file attachment carousel with preview chips and size formatting, AAC voice recording with timer and cancel, inline `@ai` / `/ask` command dispatching, `SmartRepliesBar` toggling, and asynchronous LLM spinner indication.

### 4.4 AI Settings Screen Decomposition Details
- **`lib/features/ai_copilot/screens/ai_settings_screen.dart`** (151 lines):
  - Class: `AiSettingsScreen`
  - Responsibilities: Coordinator for global application and AI configuration sections. Manages live provider models fetching lifecycle and routes active sections.
- **`lib/features/ai_copilot/widgets/settings/settings_header.dart`** (118 lines):
  - Class: `SettingsHeader`
  - Responsibilities: Unified header bar displaying active section icon, localized title, back navigation for mobile devices, and connection refresh action.
- **`lib/features/ai_copilot/widgets/settings/settings_card.dart`** (37 lines):
  - Class: `SettingsCard`
  - Responsibilities: Reusable rounded card container with consistent border styling and header typography.
- **`lib/features/ai_copilot/widgets/settings/settings_key_input.dart`** (109 lines):
  - Class: `SettingsKeyInput`
  - Responsibilities: Monospaced secure text field for API credentials and host URLs with show/hide password toggle and clipboard copy action.
- **`lib/features/ai_copilot/widgets/settings/ai_models_section.dart`** (196 lines):
  - Class: `AiModelsSection`
  - Responsibilities: Provider selection chips, active model dropdown, manual model list synchronization, and provider-specific API key configuration.
- **`lib/features/ai_copilot/widgets/settings/ai_autopilot_section.dart`** (120 lines):
  - Class: `AiAutopilotSection`
  - Responsibilities: Autopilot master switch, direct send toggling, background incoming message comprehension, and dynamic tone matching.
- **`lib/features/ai_copilot/widgets/settings/ai_context_section.dart`** (283 lines):
  - Classes: `AiContextSection`, `SandwichLayerTile`
  - Responsibilities: Context compression enablement, volume (tokens) vs. message count strategy switches, raw window slider (3-20 msgs), and visual breakdown of Sandwich Prompt layers.
- **`lib/features/ai_copilot/widgets/settings/ai_voice_section.dart`** (97 lines):
  - Class: `AiVoiceSection`
  - Responsibilities: Speech-to-text engine selection, Deepgram Nova-2 key management, and automatic language detection.
- **`lib/features/ai_copilot/widgets/settings/ai_cache_section.dart`** (58 lines):
  - Class: `AiCacheSection`
  - Responsibilities: Disk usage metrics for local audio transcripts and cache purging.

### 4.5 Profile Dialog & Profile Pane Decomposition Details
- **`lib/features/profile/profile_dialog.dart`** (86 lines):
  - Class: `ProfileDialog`
  - Responsibilities: Coordinator dialog for the user profile modal. Replaces 1,066 lines of monolithic UI with composition of modular widgets.
- **`lib/features/profile/widgets/profile_pane.dart`** (56 lines):
  - Class: `ProfilePane`
  - Responsibilities: Embedded sidebar/settings profile view, sharing the exact same modular components as `ProfileDialog`.
- **`lib/features/profile/widgets/profile_header.dart`** (88 lines):
  - Class: `ProfileHeader`
  - Responsibilities: Profile modal navigation bar, Telegram user data sync trigger (`TdlibService.instance.syncUserProfile`), edit dialog launcher, and close action.
- **`lib/features/profile/widgets/profile_avatar_section.dart`** (69 lines):
  - Class: `ProfileAvatarSection`
  - Responsibilities: Large circular avatar display, online/offline status, and photo change trigger.
- **`lib/features/profile/widgets/profile_action_buttons.dart`** (79 lines):
  - Class: `ProfileActionButtons`
  - Responsibilities: Quick action cards (set photo, edit profile info, navigate to settings).
- **`lib/features/profile/widgets/profile_info_card.dart`** (88 lines):
  - Class: `ProfileInfoCard`
  - Responsibilities: Account metadata cards (phone number, bio description, Telegram username) with one-tap clipboard copy.
- **`lib/features/profile/widgets/profile_posts_tabs.dart`** (69 lines):
  - Class: `ProfilePostsTabs`
  - Responsibilities: Pill toggle switching between active publications and archived posts.
- **`lib/features/profile/widgets/profile_post_card.dart`** (168 lines):
  - Class: `ProfilePostCard`
  - Responsibilities: Grid view card displaying image/video preview badge, view counter, post text snippet, and formatted publication timestamp.
- **`lib/features/profile/widgets/profile_post_detail_dialog.dart`** (178 lines):
  - Class: `ProfilePostDetailDialog`
  - Responsibilities: Detailed post modal displaying full media, video player launcher (`VideoViewerDialog`), selectable text, and post deletion with confirmation dialog.
- **`lib/features/profile/widgets/profile_create_post_dialog.dart`** (196 lines):
  - Class: `ProfileCreatePostDialog`
  - Responsibilities: New post authoring modal supporting multi-line text, file picker for images/videos, preview badge, and publishing to active or archived store.
- **`lib/features/profile/widgets/profile_posts_section.dart`** (138 lines):
  - Class: `ProfilePostsSection`
  - Responsibilities: Feed coordinator displaying background sync loader, empty states, publication counter, and grid of post cards.

### 4.6 AI Copilot Role Separation & Multilingual Architecture Details
- **Problem Statement**:
  - LLMs frequently exhibited role inversion ("hallucinating counterpart as user" or attributing opponent statements to account owner) when transcripts used generic `Вы:` / `You:` prefixes without explicit role definitions.
  - TDLib isolate worker (`TdWorker`) occasionally reported `is_outgoing: false` during initial database cache sync on Android or cross-device sessions, causing the user's own outgoing messages to be mislabeled with the opponent's contact name.
- **Architectural Solution (Clean Architecture & SOLID)**:
  - **`TdWorker` Data Layer (`lib/data/tdlib/td_worker.dart`)**:
    - Updated message parser in `parseMessage` to check `msg['is_outgoing'] == true || _isFromMe(msg)`. Guarantees message ownership integrity at the data ingestion boundary.
  - **`CopilotPromptBuilder` Domain Service (`lib/features/ai_copilot/services/copilot_prompt_builder.dart`)**:
    - Introduced strict, unambiguous message prefixes: `[Пользователь (Вы)]` / `[User (You)]` for user messages and `[Собеседник ($chatTitle)]` / `[Interlocutor ($chatTitle)]` for counterpart messages.
    - Added explicit **Role Separation Legend & Anti-Hallucination Directive** in both Russian and English system directives.
    - Fully multilingual prompt synthesis driven by `isRu` locale routing.
  - **`SmartReplyEngine` Domain Service (`lib/features/ai_copilot/services/smart_reply_engine.dart`)**:
    - Applied identical role tags and role separation guardrails in contextual auto-reply and voice instruction generation.
  - **`CopilotSessionStore` Storage & Synthesis (`lib/features/ai_copilot/services/copilot_session_store.dart`)**:
    - Updated RAG fact extraction to format transcripts using unambiguous role tags, preventing distorted fact synthesis.
  - **Regression Prevention**:
    - Added dedicated test suite `test/copilot_role_separation_test.dart` verifying Russian and English prompt generation, explicit tags, and role directives.




