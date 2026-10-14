import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/data/models/tg_account.dart';
import 'package:tg_answer/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Account isolation & switching test', () {
    final manager = AccountManager.instance;

    test('Initial account is Sergei with isolated chats and contacts', () {
      expect(manager.currentAccount.value.id, 'sergei');
      expect(manager.currentAccount.value.name, 'Сергей');
      expect(manager.currentAccount.value.phone, '+7 928 296 50 54');

      final chats = manager.getChats('sergei');
      expect(chats.isNotEmpty, isTrue);
      expect(chats.any((c) => c.title.contains('AMOS Dev Team')), isTrue);

      final contacts = manager.getContacts('sergei');
      expect(contacts.any((c) => c.name == 'Михаил'), isTrue);
    });

    test('Switching to Natalie updates active account, chats, contacts and selected chat', () {
      manager.switchAccount('natalie');
      expect(manager.currentAccount.value.id, 'natalie');
      expect(manager.currentAccount.value.name, 'Natalie');
      expect(AppState.selectedChatId.value, 'taras');

      final natalieChats = manager.getChats('natalie');
      expect(natalieChats.isNotEmpty, isTrue);
      expect(natalieChats.any((c) => c.id == 'taras'), isTrue);

      final natalieContacts = manager.getContacts('natalie');
      expect(natalieContacts.any((c) => c.id == 'taras'), isTrue);
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

    test('Switching back to Sergei restores Sergei state', () {
      manager.switchAccount('sergei');
      expect(manager.currentAccount.value.id, 'sergei');
      expect(AppState.selectedChatId.value, 'amos-core');
    });

    test('Adding and removing account works cleanly', () {
      const newAcc = TgAccount(
        id: 'test_acc',
        name: 'Test Account',
        phone: '+1 234 567 8900',
        username: '@testacc',
        bio: 'Tester',
      );
      manager.addAccount(newAcc);
      expect(manager.currentAccount.value.id, 'test_acc');
      expect(manager.accounts.value.any((a) => a.id == 'test_acc'), isTrue);

      manager.removeAccount('test_acc');
      expect(manager.accounts.value.any((a) => a.id == 'test_acc'), isFalse);
      expect(manager.currentAccount.value.id, isNot('test_acc'));
    });
  });
}
