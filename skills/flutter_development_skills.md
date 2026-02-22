# Flutter Development Skills

**AI Agent Skills for CommuniQ Flutter Development**

This document provides comprehensive skills and guidelines for AI agents to write, structure, and maintain Flutter code in the CommuniQ project. Use this as a reference for file placement, code patterns, and architectural decisions.

---

## 📁 Folder Structure Overview

```
client/
├── lib/
│   ├── common_widgets/
│   ├── controllers/
│   ├── core/
│   ├── data/
│   ├── l10n/
│   ├── repository/
│   ├── views/
│   ├── get_it.dart
│   └── main.dart
├── assets/
├── test/
└── pubspec.yaml
```

---

## 📂 Detailed Folder Guidelines

### 1. `lib/common_widgets/` - Reusable UI Components

**What to create here:**

- ✅ Reusable buttons (`custom_button.dart`)
- ✅ Reusable text fields (`custom_text_field.dart`)
- ✅ Loading indicators (`loading_indicator.dart`)
- ✅ Custom cards (`custom_card.dart`)
- ✅ Dialog widgets (`custom_dialog.dart`)
- ✅ Common list items (`list_tile_widget.dart`)
- ✅ Any widget used across multiple screens

**Rules:**

- ❌ NO business logic (state management)
- ❌ NO API calls or database operations
- ❌ NO navigation logic
- ✅ Only presentational components
- ✅ Accept data through constructor parameters
- ✅ Use callbacks for user interactions

**Example:**

```dart
// custom_button.dart
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  // ...
}
```

---

### 2. `lib/controllers/` - State Management & Business Logic

**What to create here:**

- ✅ GetX controllers for each feature
- ✅ Bindings for dependency injection
- ✅ Business logic implementation
- ✅ State management (loading, error, success states)

**Structure:**

```
controllers/
├── home_controller/
│   ├── home_controller.dart
│   └── home_bindings.dart
├── conversation_controller/
│   ├── conversation_controller.dart
│   └── conversation_bindings.dart
└── settings_controller/
    ├── settings_controller.dart
    └── settings_bindings.dart
```

**Rules:**

- ✅ Use GetX reactive variables (`.obs`)
- ✅ Inject dependencies via GetIt
- ✅ Implement `onInit()`, `onReady()`, `onClose()`
- ✅ Handle all business logic here
- ❌ NO UI code (widgets, BuildContext)
- ❌ NO direct database/API calls (use repositories)

**Example:**

```dart
// home_controller.dart
class HomeController extends GetxController {
  final RxList<Item> _items = <Item>[].obs;
  final HomeRepository _repository = GetIt.I<HomeRepository>();

  List<Item> get items => _items;

  @override
  void onInit() {
    super.onInit();
    loadItems();
  }

  Future<void> loadItems() async {
    final data = await _repository.getAllItems();
    _items.value = data;
  }
}
```

---

### 3. `lib/core/constants/` - Static Data & Constants

**What to create here:**

- ✅ App keys (`app_keys.dart`) - DB keys, API keys, storage keys
- ✅ Color constants (`app_colors.dart`)
- ✅ Text styles (`app_text_styles.dart`)
- ✅ Asset paths (`app_assets.dart`)
- ✅ API endpoints (`api_endpoints.dart`)
- ✅ Static configuration values
- ✅ Enum definitions
- ✅ Static lists (categories, options, etc.)

**Example - app_keys.dart:**

```dart
class AppKeys {
  static DBKeys dbKeys = const DBKeys();
  static SPKeys spKeys = const SPKeys();
  static APIKeys apiKeys = const APIKeys();
}

class DBKeys {
  const DBKeys();
  String get users => 'users';
  String get conversations => 'conversations';
  String get scenarios => 'scenarios';
}

class SPKeys {
  const SPKeys();
  String get userId => 'user_id';
  String get authToken => 'auth_token';
  String get languageCode => 'language_code';
}
```

**Example - app_colors.dart:**

```dart
class AppColors {
  static const Color primaryColor = Color(0xFF6200EE);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color errorColor = Color(0xFFB00020);
  // ...
}
```

**Example - Static Lists:**

```dart
// app_constants.dart
class AppConstants {
  static const List<String> conversationTypes = [
    'Professional',
    'Casual',
    'Interview',
    'Presentation',
  ];

  static const Map<String, String> languageMap = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
  };
}
```

---

### 4. `lib/core/extensions/` - Dart Extensions

**What to create here:**

- ✅ String extensions (`string_extension.dart`)
- ✅ DateTime extensions (`datetime_extension.dart`)
- ✅ BuildContext extensions (`context_extension.dart`)
- ✅ List extensions (`list_extension.dart`)
- ✅ Number extensions (`number_extension.dart`)

**Example:**

```dart
// string_extension.dart
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }
}

// datetime_extension.dart
extension DateTimeExtension on DateTime {
  String toFormattedString() {
    return '${day}/${month}/${year}';
  }

  bool isToday() {
    final now = DateTime.now();
    return day == now.day && month == now.month && year == now.year;
  }
}

// context_extension.dart
extension ContextExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  void showSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
```

---

### 5. `lib/core/helpers/` - Utility Functions

**What to create here:**

- ✅ Date/time utilities (`date_helper.dart`)
- ✅ Validation utilities (`validation_helper.dart`)
- ✅ Formatting utilities (`formatter_helper.dart`)
- ✅ General utilities (`utility_helper.dart`)
- ✅ Calculation helpers
- ✅ Conversion helpers

**Rules:**

- ✅ Pure functions (no side effects)
- ✅ Stateless utilities
- ❌ NO state management
- ❌ NO dependencies on controllers/repositories

**Example:**

```dart
// validation_helper.dart
class ValidationHelper {
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(phone);
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }
}

// date_helper.dart
class DateHelper {
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    return '${difference.inMinutes}m ago';
  }
}
```

---

### 6. `lib/core/routes/` - Navigation Configuration

**What to create here:**

- ✅ Route definitions (`app_routes.dart`)
- ✅ Route middleware/guards
- ✅ Navigation utilities

**Example:**

```dart
// app_routes.dart
class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String home = '/home';
  static const String conversation = '/conversation';
  static const String scenarioDetail = '/scenario-detail';
  static const String settings = '/settings';

  // Route configuration
  List<GetPage> routes = [
    GetPage(
      name: splash,
      page: () => const SplashView(),
      binding: SplashBindings(),
    ),
    GetPage(
      name: home,
      page: () => const HomeView(),
      binding: HomeBindings(),
    ),
    // ...
  ];
}
```

---

### 7. `lib/core/services/` - Business Services

**What to create here:**

- ✅ Database service (`db_service.dart`)
- ✅ API service (`api_service.dart`)
- ✅ Storage service (`storage_service.dart`)
- ✅ Analytics service (`analytics_service.dart`)
- ✅ Notification service (`notification_service.dart`)
- ✅ Authentication service (`auth_service.dart`)
- ✅ AI/ML service (`ai_service.dart`)
- ✅ Cache service (`cache_service.dart`)

**Rules:**

- ✅ Stateless singletons
- ✅ Registered in GetIt
- ✅ Implement `init()` method if needed
- ✅ Handle errors gracefully
- ❌ NO UI code
- ❌ NO reactive variables (use in controllers)

**Example:**

```dart
// storage_service.dart
class StorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }
}

// ai_service.dart
class AIService {
  Future<String> generateResponse(String userInput) async {
    // Call AI API
    // Process response
    return generatedResponse;
  }

  Future<FeedbackModel> analyzeSpeech(String audioPath) async {
    // Analyze speech patterns
    // Return feedback
    return feedback;
  }
}
```

---

### 8. `lib/core/theme/` - Theme Configuration

**What to create here:**

- ✅ Theme definitions (`app_theme.dart`)
- ✅ Theme constants (`theme_constants.dart`)

**Example:**

```dart
// app_theme.dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primaryColor,
    // ...
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryDark,
    // ...
  );
}
```

---

### 9. `lib/data/models/` - Data Models

**What to create here:**

- ✅ User model (`user_model.dart`)
- ✅ Conversation model (`conversation_model.dart`)
- ✅ Scenario model (`scenario_model.dart`)
- ✅ Feedback model (`feedback_model.dart`)
- ✅ Any data entity

**Rules:**

- ✅ Use Hive annotations for local database
- ✅ Implement `toJson()` and `fromJson()`
- ✅ Implement `copyWith()` for immutability
- ✅ Use code generation (run build_runner)
- ❌ NO business logic
- ❌ NO API calls

**Example:**

```dart
// user_model.dart
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
```

---

### 10. `lib/data/dto/` - Data Transfer Objects

**What to create here:**

- ✅ API request objects (`api_request.dart`)
- ✅ API response objects (`api_response.dart`)
- ✅ Temporary data structures for API communication

**Example:**

```dart
// api_request.dart
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

// api_response.dart
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.statusCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      statusCode: json['statusCode'],
    );
  }
}
```

---

### 11. `lib/l10n/` - Localization Files

**What to create here:**

- ✅ ARB files for each language (`app_en.arb`, `app_es.arb`)
- ✅ Translation strings

**Example:**

```json
// app_en.arb
{
  "appTitle": "CommuniQ",
  "welcome": "Welcome",
  "startConversation": "Start Conversation",
  "settings": "Settings",
  "practice": "Practice",
  "feedback": "Feedback"
}

// app_es.arb
{
  "appTitle": "CommuniQ",
  "welcome": "Bienvenido",
  "startConversation": "Iniciar Conversación",
  "settings": "Configuraciones",
  "practice": "Practicar",
  "feedback": "Retroalimentación"
}
```

---

### 12. `lib/repository/` - Data Access Layer

**What to create here:**

- ✅ Repository interfaces and implementations
- ✅ One repository per feature/domain

**Structure:**

```
repository/
├── user_repository/
│   └── user_repository.dart
├── conversation_repository/
│   └── conversation_repository.dart
└── scenario_repository/
    └── scenario_repository.dart
```

**Rules:**

- ✅ Abstract interface + concrete implementation
- ✅ Handle data fetching (DB, API, cache)
- ✅ Transform data between layers
- ✅ Implement caching strategies
- ❌ NO business logic (belongs in controllers)
- ❌ NO UI code

**Example:**

```dart
// conversation_repository.dart
abstract class ConversationRepository {
  Future<List<ConversationModel>> getAllConversations();
  Future<ConversationModel?> getConversationById(String id);
  Future<void> createConversation(ConversationModel conversation);
  Future<void> updateConversation(ConversationModel conversation);
  Future<void> deleteConversation(String id);
}

class ConversationRepositoryImpl implements ConversationRepository {
  final DBService _db = GetIt.I<DBService>();
  final CacheService _cache = GetIt.I<CacheService>();

  @override
  Future<List<ConversationModel>> getAllConversations() async {
    // Check cache first
    final cached = await _cache.get('conversations');
    if (cached != null) return cached;

    // Fetch from database
    final box = Hive.box<ConversationModel>(AppKeys.dbKeys.conversations);
    final conversations = box.values.toList();

    // Update cache
    await _cache.set('conversations', conversations);

    return conversations;
  }

  // ... other methods
}
```

---

### 13. `lib/views/` - UI Screens

**What to create here:**

- ✅ Screen widgets
- ✅ Screen-specific widgets

**Structure:**

```
views/
├── home_view/
│   ├── screens/
│   │   └── home_view.dart
│   └── widgets/
│       ├── home_header.dart
│       └── conversation_card.dart
├── conversation_view/
│   ├── screens/
│   │   └── conversation_view.dart
│   └── widgets/
│       ├── message_bubble.dart
│       └── input_field.dart
└── settings_view/
    ├── screens/
    │   └── settings_view.dart
    └── widgets/
        └── setting_item.dart
```

**Rules:**

- ✅ Use `GetView<ControllerName>` for screen widgets
- ✅ Wrap reactive parts with `Obx()`
- ✅ Keep screens focused on presentation
- ✅ Extract reusable parts to `widgets/`
- ❌ NO business logic (use controller)
- ❌ NO direct data access (use controller)

**Example:**

```dart
// home_view.dart
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: controller.conversations.length,
          itemBuilder: (context, index) {
            final conversation = controller.conversations[index];
            return ConversationCard(conversation: conversation);
          },
        );
      }),
    );
  }
}

// conversation_card.dart (in widgets/)
class ConversationCard extends StatelessWidget {
  final ConversationModel conversation;

  const ConversationCard({Key? key, required this.conversation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(conversation.title),
        subtitle: Text(conversation.description),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => Get.toNamed(AppRoutes.conversation, arguments: conversation.id),
      ),
    );
  }
}
```

---

### 14. `lib/get_it.dart` - Dependency Injection Setup

**What to create here:**

- ✅ Service registration
- ✅ Repository registration
- ✅ Initialization logic

**Example:**

```dart
// get_it.dart
import 'package:get_it/get_it.dart';

Future<void> setupDependencyInjection() async {
  final getIt = GetIt.instance;

  // Core services
  getIt.registerLazySingleton<DBService>(() => DBService());
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  getIt.registerLazySingleton<AIService>(() => AIService());

  // Repositories
  getIt.registerLazySingleton<ConversationRepository>(
    () => ConversationRepositoryImpl()
  );
  getIt.registerLazySingleton<ScenarioRepository>(
    () => ScenarioRepositoryImpl()
  );

  // Initialize services
  await getIt<DBService>().init();
  await getIt<StorageService>().init();
}
```

---

### 15. `lib/main.dart` - App Entry Point

**What to create here:**

- ✅ App initialization
- ✅ GetX app configuration
- ✅ Theme setup
- ✅ Route configuration

**Example:**

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup dependencies
  await setupDependencyInjection();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'CommuniQ',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes().routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

---

## 🎨 Assets Folder

### `assets/images/`

- App logos
- Background images
- Illustrations
- User avatars (default)

### `assets/icons/`

- Custom icon sets
- Feature-specific icons
- Navigation icons

### `assets/fonts/`

- Custom font files (.ttf, .otf)

### `assets/animations/`

- Lottie files (.json)
- Rive animations (.riv)

---

## 🧪 Test Folder

### `test/unit/`

- Service tests
- Repository tests
- Helper tests
- Model tests

### `test/widget/`

- Widget tests
- Common widget tests

### `test/integration/`

- End-to-end tests
- Feature integration tests

---

## 🔧 Code Generation

After creating/modifying models with Hive annotations:

```bash
# Generate code
flutter packages pub run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate)
flutter packages pub run build_runner watch --delete-conflicting-outputs
```

---

## 📋 Quick Reference: Where to Put What

| What                          | Where                                   | Example                 |
| ----------------------------- | --------------------------------------- | ----------------------- |
| Static data, enums, constants | `core/constants/`                       | Conversation types list |
| Color definitions             | `core/constants/app_colors.dart`        | Primary color           |
| API endpoints                 | `core/constants/api_endpoints.dart`     | Base URL                |
| String utilities              | `core/extensions/string_extension.dart` | `.capitalize()`         |
| Validation functions          | `core/helpers/validation_helper.dart`   | Email validator         |
| Date formatting               | `core/helpers/date_helper.dart`         | Format date             |
| Database operations           | `core/services/db_service.dart`         | Hive initialization     |
| API calls                     | `core/services/api_service.dart`        | HTTP client             |
| AI features                   | `core/services/ai_service.dart`         | Speech analysis         |
| Data models                   | `data/models/`                          | UserModel               |
| API DTOs                      | `data/dto/`                             | LoginRequest            |
| Business logic                | `controllers/`                          | HomeController          |
| Data access                   | `repository/`                           | UserRepository          |
| UI screens                    | `views/[feature]_view/screens/`         | HomeView                |
| Screen widgets                | `views/[feature]_view/widgets/`         | ConversationCard        |
| Reusable widgets              | `common_widgets/`                       | CustomButton            |
| Translations                  | `l10n/`                                 | app_en.arb              |

---

## ✅ Development Workflow Checklist

1. **Creating a new feature:**
   - [ ] Create model in `data/models/`
   - [ ] Run build_runner if using Hive
   - [ ] Create repository in `repository/`
   - [ ] Register repository in `get_it.dart`
   - [ ] Create controller in `controllers/`
   - [ ] Create bindings file
   - [ ] Create view in `views/`
   - [ ] Add route in `core/routes/app_routes.dart`
   - [ ] Create tests

2. **Adding a service:**
   - [ ] Create service in `core/services/`
   - [ ] Register in `get_it.dart`
   - [ ] Initialize if needed (await in main)

3. **Adding constants/static data:**
   - [ ] Add to `core/constants/app_keys.dart` or create new file
   - [ ] Use throughout app via AppKeys

4. **Adding utilities:**
   - [ ] Create in `core/helpers/` for functions
   - [ ] Create in `core/extensions/` for extensions

---

## 🚀 Best Practices

1. **Never** put business logic in views
2. **Never** make API/DB calls directly in controllers (use repositories)
3. **Always** use GetIt for service dependencies
4. **Always** implement error handling
5. **Always** log important operations
6. **Always** track analytics for user actions
7. **Always** use constants instead of hardcoded values
8. **Always** make widgets reusable when possible

---

## 📝 Naming Conventions

- **Files:** snake_case (`user_model.dart`)
- **Classes:** PascalCase (`UserModel`)
- **Variables:** camelCase (`userName`)
- **Constants:** camelCase (`primaryColor`)
- **Private variables:** `_variableName`
- **Folders:** snake_case (`common_widgets/`)

---

**Last Updated:** February 22, 2026
**For:** CommuniQ - AI Based Conversation Simulator
