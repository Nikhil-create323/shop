import 'package:flutter/material.dart';
import 'package:dummy_apps/screens/Shop.dart';
import 'package:dummy_apps/screens/Auth.dart';
import 'package:dummy_apps/screens/cart.dart';
import 'package:dummy_apps/screens/orders.dart';
import 'package:dummy_apps/widgets/search.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:dummy_apps/screens/admin/home.dart';

class AppDrawer extends StatelessWidget {
  AppDrawer({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService.clear();
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => Shop()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Dummy Shop',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),

            // Use Expanded with ListView so the drawer is scrollable and never overflows
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: Future.wait([AuthService.isLoggedIn(), AuthService.getRole()]),
                builder: (context, snapshot) {
                  final isLoggedIn = snapshot.hasData ? (snapshot.data![0] as bool) : false;
                  final role = snapshot.hasData ? (snapshot.data![1] as String?)?.toLowerCase() : null;
                  final isAdmin = role == 'admin';

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Home'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isAdmin ? const HomeScreen() : Shop(),
                            ),
                          );
                        },
                      ),

                      if (!isAdmin)
                        ListTile(
                          leading: const Icon(Icons.trolley),
                          title: const Text('Cart'),
                          onTap: () {
                            if (!isLoggedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to view cart'),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartWidget(),
                              ),
                            );
                          },
                        ),

                      if (!isAdmin)
                        ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: const Text('Orders'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Orders()),
                            );
                          },
                        ),

                      ListTile(
                        leading: const Icon(Icons.search),
                        title: const Text('Search'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductSearch(),
                            ),
                          );
                        },
                      ),

                      const Divider(),

                      if (!isAdmin)
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Account'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          },
                        ),

                      // Show either Login or Sign out depending on auth state
                      if (!isLoggedIn)
                        ListTile(
                          leading: const Icon(Icons.login),
                          title: const Text('Login'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          },
                        )
                      else
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Sign out'),
                          onTap: () => _signOut(context),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
