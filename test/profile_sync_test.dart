import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/core/localization/app_locale.dart';
import 'package:tg_answer/data/models/tg_account.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/profile/profile_dialog.dart';

void main() {
  setUp(() {
    I18n.instance.currentLanguage.value = AppLanguage.ru;
  });

  group('Profile Synchronization and State Tests', () {
    test('Sergei account no longer has fake hardcoded bio or avatar', () {
      final manager = AccountManager.instance;
      final sergei = manager.accounts.value.firstWhere((a) => a.id == 'sergei');
      expect(sergei.avatarPath, isEmpty);
      expect(sergei.bio, isEmpty);
    });

    test('syncAuthorizedUser updates name, phone, username accurately', () {
      final manager = AccountManager.instance;
      const user = TgUser(
        id: 12345678,
        firstName: 'Сергей',
        lastName: 'Петров',
        username: 'sergei_petrov',
        phoneNumber: '79282965054',
      );

      manager.syncAuthorizedUser(user);

      final current = manager.currentAccount.value;
      expect(current.name, 'Сергей Петров');
      expect(current.phone, '+79282965054');
      expect(current.username, '@sergei_petrov');
    });

    test('syncBio updates bio and synchronizes currentAccount and accounts list', () {
      final manager = AccountManager.instance;
      manager.syncBio('Архитектор решений и инженер');

      expect(manager.currentAccount.value.bio, 'Архитектор решений и инженер');
      final sergei = manager.accounts.value.firstWhere((a) => a.id == 'sergei');
      expect(sergei.bio, 'Архитектор решений и инженер');
    });

    test('syncAvatar updates avatarPath in currentAccount and accounts list', () {
      final manager = AccountManager.instance;
      manager.syncAvatar('/tmp/real_telegram_avatar.jpg');

      expect(manager.currentAccount.value.avatarPath, '/tmp/real_telegram_avatar.jpg');
      final sergei = manager.accounts.value.firstWhere((a) => a.id == 'sergei');
      expect(sergei.avatarPath, '/tmp/real_telegram_avatar.jpg');
    });

    test('mergeProfilePhotos populates myPosts and myArchivedPosts', () {
      final manager = AccountManager.instance;
      final active = [
        TgPost(
          id: 'photo_active',
          text: 'Фото профиля',
          mediaPath: '/tmp/photo1.jpg',
          date: DateTime.now(),
          views: 120,
        ),
      ];
      final archived = [
        TgPost(
          id: 'photo_old',
          text: 'Архивное фото профиля',
          mediaPath: '/tmp/photo_old.jpg',
          date: DateTime.now().subtract(const Duration(days: 30)),
          views: 85,
          isArchived: true,
        ),
      ];

      manager.mergeProfilePhotos(active, archived);

      expect(manager.myPosts.value.length, 1);
      expect(manager.myPosts.value.first.id, 'photo_active');
      expect(manager.myArchivedPosts.value.length, 1);
      expect(manager.myArchivedPosts.value.first.id, 'photo_old');
    });

    test('updatePostMedia updates downloaded media path for matching post', () {
      final manager = AccountManager.instance;
      manager.updatePostMedia('photo_active', '/tmp/downloaded_complete.jpg');

      final updatedPost = manager.myPosts.value.firstWhere((p) => p.id == 'photo_active');
      expect(updatedPost.mediaPath, '/tmp/downloaded_complete.jpg');
    });

    test('addPost adds post to active or archived posts list', () {
      final manager = AccountManager.instance;
      final newPost = TgPost(
        id: 'new_channel_post',
        text: 'Новая публикация в канале',
        date: DateTime.now(),
        views: 10,
      );

      manager.addPost(newPost);
      expect(manager.myPosts.value.any((p) => p.id == 'new_channel_post'), isTrue);
    });
  });

  group('ProfileDialog UI Widget Tests', () {
    testWidgets('ProfileDialog renders user info, sync button, and post tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AccountManager.instance.isSyncingProfile.value = false;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileDialog(),
          ),
        ),
      );
      // initState initiates syncUserProfile() which sets isSyncingProfile to true
      AccountManager.instance.isSyncingProfile.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check header
      expect(find.text('Профиль'), findsOneWidget);
      expect(find.byTooltip('Синхронизировать с Telegram'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Check user info rows
      expect(find.text(tr('phone')), findsOneWidget);
      expect(find.text(tr('bio')), findsOneWidget);
      expect(find.text(tr('username')), findsOneWidget);

      // Check posts tabs
      expect(find.text('Посты'), findsOneWidget);
      expect(find.text('Архив постов'), findsOneWidget);

      // Switch to Archived Posts tab
      await tester.tap(find.text('Архив постов'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch back to Posts tab
      await tester.tap(find.text('Посты'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ProfileDialog renders post cards and opens post detail dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final manager = AccountManager.instance;
      manager.isSyncingProfile.value = false;
      manager.setPosts([
        TgPost(
          id: 'test_grid_post_1',
          text: 'Первый тестовый пост на странице',
          date: DateTime.now(),
          views: 42,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileDialog(),
          ),
        ),
      );
      manager.isSyncingProfile.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll post into view if needed
      await tester.scrollUntilVisible(
        find.text('Первый тестовый пост на странице'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Post title snippet should be visible
      expect(find.text('Первый тестовый пост на странице'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      // Tap on post to open detail
      await tester.tap(find.text('Первый тестовый пост на странице'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Full selectable text in dialog should be visible
      expect(find.byType(SelectableText), findsOneWidget);

      // Verify delete button is present in detail dialog
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    test('AccountManager deletePost deletes post from active and archived collections', () {
      final manager = AccountManager.instance;
      final post1 = TgPost(id: 'del_1', text: 'Пост 1', date: DateTime.now());
      final post2 = TgPost(id: 'del_2', text: 'Пост 2', date: DateTime.now(), isArchived: true);
      manager.setPosts([post1]);
      manager.setPosts([post2], isArchived: true);

      expect(manager.myPosts.value.any((p) => p.id == 'del_1'), isTrue);
      expect(manager.myArchivedPosts.value.any((p) => p.id == 'del_2'), isTrue);

      manager.deletePost('del_1');
      expect(manager.myPosts.value.any((p) => p.id == 'del_1'), isFalse);

      manager.deletePost('del_2');
      expect(manager.myArchivedPosts.value.any((p) => p.id == 'del_2'), isFalse);
    });
  });
}
