import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  String _pin = '';

  void _onKeypadTap(String value) {
    if (_pin.length < 4) {
      setState(() {
        _pin += value;
        _pinController.text = _pin;
      });
      if (_pin.length == 4) {
        _login();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _pinController.text = _pin;
      });
    }
  }

  Future<void> _login() async {
    final success = await ref.read(authNotifierProvider.notifier).login(_pin);
    if (success && mounted) {
      context.go('/dashboard');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authNotifierProvider).error?.toString() ?? 'خطأ في تسجيل الدخول'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _pin = '';
        _pinController.text = _pin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'نظام إدارة شركة فلاتر المياه',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('الرجاء إدخال رمز المرور (PIN)'),
              const SizedBox(height: 32),
              
              // PIN Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 48),
              
              if (authState.isLoading)
                const CircularProgressIndicator()
              else
                // Keypad
                SizedBox(
                  width: 300,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index == 9) {
                        return const SizedBox.shrink(); // Empty space
                      }
                      if (index == 11) {
                        return IconButton(
                          onPressed: _onBackspace,
                          icon: const Icon(Icons.backspace, size: 32),
                          color: Colors.grey.shade700,
                        );
                      }
                      final number = index == 10 ? '0' : '${index + 1}';
                      return InkWell(
                        onTap: () => _onKeypadTap(number),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade100,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            number,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
