import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_account.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Account isolation & switching test', () {
    final manager = AccountManager.instance;

    test('Initial account is Natalie with isolated chats and contacts', () {
      expect(manager.currentAccount.value.id, 'natalie');
      expect(manager.currentAccount.value.name, 'Natalie');

      final chats = manager.getChats('natalie');
      expect(chats.isNotEmpty, isTrue);
      expect(chats.any((c) => c.id == 'taras'), isTrue);

      final contacts = manager.getContacts('natalie');
      expect(contacts.any((c) => c.id == 'taras'), isTrue);
    });

    test('Switching to Sergei updates active account, chats, contacts, badge and selected chat', () {
      manager.switchAccount('sergei');
      expect(manager.currentAccount.value.id, 'sergei');
      expect(manager.currentAccount.value.name, 'Sergei');
      expect(manager.currentAccount.value.unreadBadge, 31);
      expect(AppState.selectedChatId.value, 'amos-core');

      final sergeiChats = manager.getChats('sergei');
      expect(sergeiChats.length, greaterThanOrEqualTo(5));
      expect(sergeiChats.first.title, contains('AMOS Dev Team / Core'));
      expect(sergeiChats.any((c) => c.title.contains('Architecture & TDLib C++')), isTrue);
      expect(sergeiChats.any((c) => c.title.contains('Denis (Design Lead)')), isTrue);

      final sergeiContacts = manager.getContacts('sergei');
      expect(sergeiContacts.any((c) => c.name == 'Михаил'), isTrue);
      expect(sergeiContacts.any((c) => c.name == 'Ca BAn'), isTrue);
      expect(sergeiContacts.any((c) => c.name == 'Natalie'), isTrue);
    });

    test('Switching to Ca BAn updates active account, chats, contacts, badge and selected chat', () {
      manager.switchAccount('caban');
      expect(manager.currentAccount.value.id, 'caban');
      expect(manager.currentAccount.value.name, 'Ca BAn');
      expect(manager.currentAccount.value.unreadBadge, 7);
      expect(AppState.selectedChatId.value, 'caban-marketing');

      final cabanChats = manager.getChats('caban');
      expect(cabanChats.length, greaterThanOrEqualTo(4));
      expect(cabanChats.first.title, contains('Marketing & Video Production'));
      expect(cabanChats.any((c) => c.title.contains('Design Review 2026')), isTrue);

      final cabanContacts = manager.getContacts('caban');
      expect(cabanContacts.any((c) => c.name == 'Victor'), isTrue);
      expect(cabanContacts.any((c) => c.name == 'София Миронова'), isTrue);
      expect(cabanContacts.any((c) => c.name == 'Sergei'), isTrue);
    });

    test('Switching back to Natalie restores Natalie state', () {
      manager.switchAccount('natalie');
      expect(manager.currentAccount.value.id, 'natalie');
      expect(AppState.selectedChatId.value, 'taras');
    });
  });
}
