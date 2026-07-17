import 'package:flutter/material.dart';

class AccountList extends StatelessWidget {
  const AccountList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text("Item $index"),
            subtitle: Text("Description $index"),
            leading: Icon(Icons.person),
            trailing: IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () {},
            ),
          );
        },
      ),
    );
  }
}
