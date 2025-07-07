import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Model matching the 'cms_socials' table
class CmsSocial {
  final int id;
  final String link;
  final String category;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CmsSocial({
    required this.id,
    required this.link,
    required this.category,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Reusable card widget for a social/email link
class CommunityCard extends StatelessWidget {
  final CmsSocial social;
  const CommunityCard({Key? key, required this.social}) : super(key: key);

  static const _brandData = {
    'facebook': {
      'color': Color(0xFF1877F3),
      'icon': FontAwesomeIcons.facebook,
      'label': 'Facebook',
    },
    'twitter': {
      'color': Color(0xFF000000),
      'icon': FontAwesomeIcons.xTwitter,
      'label': 'Twitter (X)',
    },
    'x': {
      'color': Color(0xFF000000),
      'icon': FontAwesomeIcons.xTwitter,
      'label': 'Twitter (X)',
    },
    'instagram': {
      'color': Color(0xFFE1306C),
      'icon': FontAwesomeIcons.instagram,
      'label': 'Instagram',
    },
    'youtube': {
      'color': Color(0xFFFF0000),
      'icon': FontAwesomeIcons.youtube,
      'label': 'YouTube',
    },
    'tiktok': {
      'color': Color(0xFF010101),
      'icon': FontAwesomeIcons.tiktok,
      'label': 'TikTok',
    },
    'linkedin': {
      'color': Color(0xFF0A66C2),
      'icon': FontAwesomeIcons.linkedin,
      'label': 'LinkedIn',
    },
    'pinterest': {
      'color': Color(0xFFE60023),
      'icon': FontAwesomeIcons.pinterest,
      'label': 'Pinterest',
    },
    'snapchat': {
      'color': Color(0xFFFFFC00),
      'icon': FontAwesomeIcons.snapchat,
      'label': 'Snapchat',
    },
    'reddit': {
      'color': Color(0xFFFF4500),
      'icon': FontAwesomeIcons.reddit,
      'label': 'Reddit',
    },
    'threads': {
      'color': Color(0xFF000000),
      'icon': FontAwesomeIcons.threads,
      'label': 'Threads',
    },
    'whatsapp': {
      'color': Color(0xFF25D366),
      'icon': FontAwesomeIcons.whatsapp,
      'label': 'WhatsApp',
    },
    'telegram': {
      'color': Color(0xFF0088CC),
      'icon': FontAwesomeIcons.telegram,
      'label': 'Telegram',
    },
    'discord': {
      'color': Color(0xFF5865F2),
      'icon': FontAwesomeIcons.discord,
      'label': 'Discord',
    },
    'github': {
      'color': Color(0xFF181717),
      'icon': FontAwesomeIcons.github,
      'label': 'GitHub',
    },
    'medium': {
      'color': Color(0xFF00ab6c),
      'icon': FontAwesomeIcons.medium,
      'label': 'Medium',
    },
    // Email types
    'support_emails': {
      'color': Color(0xFF4285F4),
      'icon': Icons.email,
      'label': 'Support Email',
    },
    'sales_emails': {
      'color': Color(0xFF4285F4),
      'icon': Icons.email,
      'label': 'Sales Email',
    },
    'info_emails': {
      'color': Color(0xFF4285F4),
      'icon': Icons.email,
      'label': 'Info Email',
    },
    'contact_emails': {
      'color': Color(0xFF4285F4),
      'icon': Icons.email,
      'label': 'Contact Email',
    },
    'feedback_emails': {
      'color': Color(0xFF4285F4),
      'icon': Icons.email,
      'label': 'Feedback Email',
    },
    'newsletter_emails': {
      'color': Color(0xFF4285F4),
      'icon': Icons.email,
      'label': 'Newsletter Email',
    },
  };

  @override
  Widget build(BuildContext context) {
    final key = social.category.toLowerCase().replaceAll(' ', '_');
    final brand = _brandData[key] ?? {
      'color': Colors.grey.shade200,
      'icon': Icons.link,
      'label': social.category,
    };
    final color = brand['color'] as Color? ?? Colors.grey.shade200!;
    final icon = brand['icon'];
    final label = brand['label'] as String? ?? social.category;

    return Card(
      color: color.withOpacity(0.12),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: icon is IconData
            ? Icon(icon, color: color, size: 32)
            : FaIcon(icon as IconData, color: color, size: 32),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (social.description != null && social.description!.isNotEmpty)
              Text(social.description!),
            Text(social.link, style: TextStyle(color: Colors.blue)),
            Text('Added: ${social.createdAt.toLocal()}'),
          ],
        ),
        trailing: social.isActive
            ? Icon(Icons.check_circle, color: Colors.green)
            : Icon(Icons.cancel, color: Colors.red),
        onTap: () async {
          String url = social.link.trim();
          if (!url.startsWith('http')) {
            url = 'https://$url';
          }
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not launch URL')),
            );
          }
        },
      ),
    );
  }
}

// --- DEMO USAGE ---
final demoCmsSocials = [
  CmsSocial(
    id: 1,
    link: 'https://www.facebook.com',
    category: 'facebook',
    description: 'Our Facebook page',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CmsSocial(
    id: 2,
    link: 'https://twitter.com',
    category: 'twitter',
    description: 'Follow us on Twitter',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CmsSocial(
    id: 3,
    link: 'mailto:support@example.com',
    category: 'support_emails',
    description: 'Contact our support team',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  CmsSocial(
    id: 4,
    link: 'https://www.youtube.com',
    category: 'youtube',
    description: 'Subscribe to our YouTube channel',
    isActive: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

class CommunityCardDemoList extends StatelessWidget {
  const CommunityCardDemoList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: demoCmsSocials.length,
      itemBuilder: (context, index) {
        return CommunityCard(social: demoCmsSocials[index]);
      },
    );
  }
}

// USAGE:
// 1. Place CommunityCardList(apiUrl: 'https://yourdomain.com/api/community/get_cms_socials.php') in your widget tree.
// 2. Make sure to add http: ^1.2.1 to your pubspec.yaml dependencies.

class CommunityCardList extends StatefulWidget {
  final String apiUrl;
  const CommunityCardList({Key? key, required this.apiUrl}) : super(key: key);

  @override
  State<CommunityCardList> createState() => _CommunityCardListState();
}

class _CommunityCardListState extends State<CommunityCardList> {
  late Future<List<CmsSocial>> _futureSocials;

  @override
  void initState() {
    super.initState();
    _futureSocials = fetchCmsSocials(widget.apiUrl);
  }

  Future<List<CmsSocial>> fetchCmsSocials(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['success'] == true) {
        return (jsonData['data'] as List)
            .map((item) => CmsSocial(
                  id: item['id'],
                  link: item['link'],
                  category: item['category'],
                  description: item['description'],
                  isActive: item['is_active'] is bool
                      ? item['is_active']
                      : item['is_active'].toString() == '1',
                  createdAt: DateTime.parse(item['created_at']),
                  updatedAt: DateTime.parse(item['updated_at']),
                ))
            .toList();
      }
    }
    throw Exception('Failed to load socials');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CmsSocial>>(
      future: _futureSocials,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No socials found.'));
        }
        final socials = snapshot.data!;
        return ListView.builder(
          itemCount: socials.length,
          itemBuilder: (context, index) {
            return CommunityCard(social: socials[index]);
          },
        );
      },
    );
  }
} 