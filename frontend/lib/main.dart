import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/home_screen.dart';
import 'services/socket_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VaslApp());
}

class VaslApp extends StatelessWidget {
  const VaslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Initialize real-time Socket communication service
        ChangeNotifierProvider<SocketService>(
          create: (_) => SocketService(),
        ),
        
        // 2. Initialize Auth state provider (Zero-login checks, local cache profile)
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            Provider.of<SocketService>(context, listen: false),
          ),
        ),
        
        // 3. Initialize Chat messaging provider (Optimistic UI updates, group lists)
        ChangeNotifierProvider<ChatProvider>(
          create: (context) => ChatProvider(
            Provider.of<SocketService>(context, listen: false),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'VASL',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
