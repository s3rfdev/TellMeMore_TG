class TgContact {
  const TgContact({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
    required this.status,
    required this.isOnline,
    required this.avatarColor,
    required this.avatarEmoji,
    this.avatarPath,
    this.bio = '',
  });

  final String id;
  final String name;
  final String username;
  final String phone;
  final String status;
  final bool isOnline;
  final int avatarColor;
  final String avatarEmoji;
  final String? avatarPath;
  final String bio;
}

final List<TgContact> mockContacts = [
  const TgContact(
    id: 'taras',
    name: 'Тарас Черненко',
    username: '@taras_dev',
    phone: '+7 (918) 420-11-22',
    status: 'в сети',
    isOnline: true,
    avatarColor: 0xFF53676F,
    avatarEmoji: '🧑🏻‍💻',
    bio: 'Flutter & LLM Developer | Open Source',
  ),
  const TgContact(
    id: 'nha-trang-estate',
    name: 'Карина Терновая',
    username: '@karina_estate_vn',
    phone: '+84 (905) 123-456',
    status: 'была 15 минут назад',
    isOnline: false,
    avatarColor: 0xFFA94F33,
    avatarEmoji: '🏝️',
    bio: 'Недвижимость Нячанг и Дананг 🇻🇳 Аренда и продажа',
  ),
  const TgContact(
    id: 'alex-smirnov',
    name: 'Алексей Смирнов',
    username: '@asmirnov_ai',
    phone: '+7 (999) 789-01-23',
    status: 'в сети',
    isOnline: true,
    avatarColor: 0xFF2F6FA8,
    avatarEmoji: '🚀',
    bio: 'AI Product Manager | AI Copilots & LLM Systems',
  ),
  const TgContact(
    id: 'elena-volkova',
    name: 'Елена Волкова',
    username: '@elena_hr_lead',
    phone: '+7 (903) 555-43-21',
    status: 'была 2 часа назад',
    isOnline: false,
    avatarColor: 0xFF8E3B2F,
    avatarEmoji: '👩‍💼',
    bio: 'Tech Recruiter @ Global IT. Ищу Senior Flutter & Go',
  ),
  const TgContact(
    id: 'dmitry-invest',
    name: 'Дмитрий Романов',
    username: '@d_romanov_vc',
    phone: '+971 (50) 888-99-00',
    status: 'был недавно',
    isOnline: false,
    avatarColor: 0xFF1F7A55,
    avatarEmoji: '💎',
    bio: 'Angel Investor, Web3 & AI syndicates',
  ),
  const TgContact(
    id: 'nikita-sec',
    name: 'Никита Белов',
    username: '@nikita_pentest',
    phone: '+7 (926) 333-22-11',
    status: 'в сети',
    isOnline: true,
    avatarColor: 0xFF445A73,
    avatarEmoji: '🛡️',
    bio: 'AppSec & Network Security Consultant',
  ),
  const TgContact(
    id: 'sofia-design',
    name: 'София Миронова',
    username: '@sofia_uxui',
    phone: '+33 (6) 12-34-56-78',
    status: 'была вчера в 22:40',
    isOnline: false,
    avatarColor: 0xFF8774E1,
    avatarEmoji: '🎨',
    bio: 'Senior Product Designer (Telegram Dark / Glassmorphism)',
  ),
];
